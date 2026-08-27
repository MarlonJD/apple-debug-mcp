#!/usr/bin/env python3
"""Bounded adaptive post-fix verification for repository casebooks.

The module is deliberately transport-neutral. Casebooks own authorized process,
Simulator, and MCP operations and provide one bounded callback per attempt;
this runner owns only decision state, deadlines, escalation, cleanup evidence,
and bounded result retention.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
import hashlib
import json
from pathlib import Path
import re
import time
from typing import Any, Callable, Mapping, Protocol, Sequence


class VerificationLevel(str, Enum):
    QUICK = "quick"
    STANDARD = "standard"
    STRICT = "strict"


class VerificationOutcome(str, Enum):
    VERIFIED = "verified"
    FAILED = "failed"
    INCONCLUSIVE = "inconclusive"


class VerificationPhase(str, Enum):
    BASELINE = "baseline"
    CANDIDATE = "candidate"


class StateStatus(str, Enum):
    FRESH = "fresh"
    RESTORED = "restored"
    NOT_REQUIRED = "notRequired"
    FAILED = "failed"
    UNKNOWN = "unknown"


class EscalationReason(str, Enum):
    TIMING = "timing"
    CONCURRENCY = "concurrency"
    STATE_LEAKAGE = "stateLeakage"
    INCONSISTENT_OBSERVATION = "inconsistentObservation"
    KNOWN_FLAKINESS = "knownFlakiness"
    EXPLICIT_POLICY = "explicitPolicy"


ALLOWED_AUTOMATIC_REASONS = frozenset(
    {
        EscalationReason.TIMING.value,
        EscalationReason.CONCURRENCY.value,
        EscalationReason.STATE_LEAKAGE.value,
        EscalationReason.INCONSISTENT_OBSERVATION.value,
        EscalationReason.KNOWN_FLAKINESS.value,
    }
)


@dataclass(frozen=True)
class AdaptivePolicy:
    level: VerificationLevel
    baseline_attempts: int
    candidate_attempts: int
    per_attempt_seconds: float
    cumulative_seconds: float

    @classmethod
    def for_level(cls, level: VerificationLevel | str) -> "AdaptivePolicy":
        parsed = VerificationLevel(level)
        values = {
            VerificationLevel.QUICK: (1, 1, 5.0, 15.0),
            VerificationLevel.STANDARD: (2, 2, 15.0, 60.0),
            VerificationLevel.STRICT: (3, 3, 30.0, 180.0),
        }[parsed]
        return cls(parsed, *values)

    def as_dict(self) -> dict[str, Any]:
        return {
            "level": self.level.value,
            "baselineAttempts": self.baseline_attempts,
            "candidateAttempts": self.candidate_attempts,
            "perAttemptSeconds": self.per_attempt_seconds,
            "cumulativeSeconds": self.cumulative_seconds,
        }


@dataclass(frozen=True)
class StateResult:
    status: StateStatus
    diagnostic: str | None = None
    operation: str | None = None

    def as_dict(self) -> dict[str, Any]:
        result: dict[str, Any] = {"status": self.status.value}
        if self.operation:
            result["operation"] = self.operation
        if self.diagnostic:
            result["diagnostic"] = _bounded_text(self.diagnostic, 4096)
        return result


@dataclass(frozen=True)
class Observation:
    """One callback's complete, bounded decision observation.

    For baseline observations, ``decisive`` means the pre-fix failure was
    reproduced and ``signature`` identifies the observed failure. For candidate
    observations, ``accepted`` means the fix passed and ``regressionDecisive``
    means the candidate or a guardrail decisively regressed.
    """

    decisive: bool = False
    signature: Any = None
    accepted: bool = False
    guardrails_passed: bool = True
    regression_decisive: bool = False
    complete: bool = True
    stale: bool = False
    contaminated: bool = False
    diagnostic: str | None = None
    evidence: tuple[Mapping[str, Any], ...] = ()
    escalation_reasons: tuple[str, ...] = ()
    identity: Mapping[str, Any] | None = None

    def as_summary(self) -> dict[str, Any]:
        summary: dict[str, Any] = {
            "decisive": self.decisive,
            "accepted": self.accepted,
            "guardrailsPassed": self.guardrails_passed,
            "regressionDecisive": self.regression_decisive,
            "complete": self.complete,
            "stale": self.stale,
            "contaminated": self.contaminated,
        }
        if self.signature is not None:
            summary["signature"] = _bounded_json(self.signature, 4096)
        if self.diagnostic:
            summary["diagnostic"] = _bounded_text(self.diagnostic, 4096)
        if self.escalation_reasons:
            summary["escalationReasons"] = list(self.escalation_reasons[:8])
        if self.identity is not None:
            summary["identityPresent"] = True
        return summary


@dataclass(frozen=True)
class AttemptContext:
    phase: VerificationPhase
    attempt_number: int
    level: VerificationLevel
    started_at: float
    deadline: float
    cumulative_deadline: float

    @property
    def remaining_seconds(self) -> float:
        return max(0.0, min(self.deadline, self.cumulative_deadline) - self.started_at)

    def as_dict(self, now: float) -> dict[str, Any]:
        return {
            "phase": self.phase.value,
            "attempt": self.attempt_number,
            "level": self.level.value,
            "deadlineSecondsFromStart": self.deadline,
            "cumulativeDeadlineSecondsFromStart": self.cumulative_deadline,
            "observedElapsedSeconds": max(0.0, now),
        }


@dataclass(frozen=True)
class BaselineEvidence:
    identity: Mapping[str, Any]
    decisive: bool
    signature: Any
    evidence: tuple[Mapping[str, Any], ...] = ()
    stale: bool = False
    contaminated: bool = False


@dataclass(frozen=True)
class VerificationIdentity:
    executable_sha256: str
    macho_uuid: str
    architecture: str
    build_source_identity: Any
    environment: Any
    target: Any
    scenario_oracle: Any
    canonical_executable_path: str | None = None

    def as_dict(self) -> dict[str, Any]:
        result: dict[str, Any] = {
            "computed": True,
            "executableSHA256": self.executable_sha256,
            "macho": {
                "uuid": self.macho_uuid,
                "architecture": self.architecture,
            },
            "buildSourceIdentity": _bounded_json(self.build_source_identity, 4096),
            "environment": _bounded_json(self.environment, 4096),
            "target": _bounded_json(self.target, 4096),
            "scenarioOracle": _bounded_json(self.scenario_oracle, 4096),
        }
        if self.canonical_executable_path:
            result["canonicalExecutablePath"] = self.canonical_executable_path
        return result


class MonotonicClock(Protocol):
    def now(self) -> float:
        ...


class _SystemMonotonicClock:
    def now(self) -> float:
        return time.monotonic()


AttemptCallback = Callable[[AttemptContext], Observation]
StateCallback = Callable[[AttemptContext], StateResult]


@dataclass
class AdaptiveVerificationResult:
    outcome: VerificationOutcome
    level: VerificationLevel
    default_level: VerificationLevel
    policy_selection: dict[str, Any]
    policy: AdaptivePolicy
    pre_fix_identity: Mapping[str, Any] | None
    candidate_identity: Mapping[str, Any] | None
    pre_fix_failure_signature: dict[str, Any]
    post_fix_acceptance: dict[str, Any]
    regression_guardrails: dict[str, Any]
    attempts: list[dict[str, Any]]
    fresh_state: list[dict[str, Any]]
    cleanup: list[dict[str, Any]]
    escalations: list[dict[str, Any]]
    representative_evidence: list[dict[str, Any]]
    diagnostics: list[str]
    elapsed_seconds: float
    cumulative_budget_exhausted: bool
    evidence_truncated: bool
    decision_reason: str | None

    def as_dict(self) -> dict[str, Any]:
        return {
            "schemaVersion": 1,
            "outcome": self.outcome.value,
            "level": self.level.value,
            "defaultLevel": self.default_level.value,
            "policySelection": self.policy_selection,
            "policy": self.policy.as_dict(),
            "identities": {
                "preFix": self.pre_fix_identity,
                "candidate": self.candidate_identity,
            },
            "preFixFailureSignature": self.pre_fix_failure_signature,
            "postFixAcceptance": self.post_fix_acceptance,
            "regressionGuardrails": self.regression_guardrails,
            "attempts": self.attempts,
            "state": {
                "fresh": self.fresh_state,
                "cleanup": self.cleanup,
            },
            "escalations": self.escalations,
            "representativeEvidence": self.representative_evidence,
            "diagnostics": self.diagnostics,
            "timing": {
                "elapsedSeconds": self.elapsed_seconds,
                "cumulativeBudgetExhausted": self.cumulative_budget_exhausted,
            },
            "decisionReason": self.decision_reason,
            "evidenceBounds": {
                "attemptSummariesReturned": len(self.attempts),
                "representativeEvidenceReturned": len(self.representative_evidence),
                "diagnosticsReturned": len(self.diagnostics),
                "truncated": self.evidence_truncated,
            },
        }


def compute_identity(
    executable_path: str | Path,
    *,
    macho_uuid: str,
    architecture: str,
    build_source_identity: Any,
    environment: Any,
    target: Any,
    scenario_oracle: Any,
) -> dict[str, Any]:
    """Compute the reusable identity from the executable and explicit inputs.

    The file digest is always computed here; callers cannot make a replay
    manifest string stand in for the executable identity. UUIDs are normalized
    and every determinant is retained in the exact comparison record.
    """

    path = Path(executable_path)
    if not path.is_absolute() or not path.is_file() or path.is_symlink():
        raise ValueError("identity executable must be an absolute regular non-symlink file")
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(chunk)
    digest = hasher.hexdigest()
    normalized_uuid = normalize_uuid(macho_uuid)
    if normalized_uuid is None:
        raise ValueError("identity Mach-O UUID must be a non-zero canonical UUID")
    if not architecture or "\x00" in architecture:
        raise ValueError("identity architecture is invalid")
    return VerificationIdentity(
        executable_sha256=digest,
        macho_uuid=normalized_uuid,
        architecture=architecture,
        build_source_identity=build_source_identity,
        environment=environment,
        target=target,
        scenario_oracle=scenario_oracle,
        canonical_executable_path=str(path.resolve()),
    ).as_dict()


def normalize_uuid(value: str) -> str | None:
    candidate = value.strip().lower()
    if re.fullmatch(r"[0-9a-f]{32}", candidate):
        compact = candidate
    elif re.fullmatch(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", candidate):
        compact = candidate.replace("-", "")
    else:
        return None
    if set(compact) == {"0"}:
        return None
    return f"{compact[:8]}-{compact[8:12]}-{compact[12:16]}-{compact[16:20]}-{compact[20:]}"


def identities_match(left: Mapping[str, Any] | None, right: Mapping[str, Any] | None) -> bool:
    if not isinstance(left, Mapping) or not isinstance(right, Mapping):
        return False
    if left.get("computed") is not True or right.get("computed") is not True:
        return False
    return _canonical_json(left) == _canonical_json(right)


def run_adaptive_verification(
    baseline_attempt: AttemptCallback,
    candidate_attempt: AttemptCallback,
    *,
    level: VerificationLevel | str | None = None,
    fresh_state: StateCallback | None = None,
    cleanup: StateCallback | None = None,
    pre_fix_identity: Mapping[str, Any] | None = None,
    candidate_identity: Mapping[str, Any] | None = None,
    reusable_baseline: BaselineEvidence | None = None,
    clock: MonotonicClock | Callable[[], float] | None = None,
) -> AdaptiveVerificationResult:
    """Run a bounded verification state machine with quick as the default."""

    clock_source = clock or _SystemMonotonicClock()

    def now() -> float:
        value = clock_source.now() if hasattr(clock_source, "now") else clock_source()  # type: ignore[misc]
        if not isinstance(value, (int, float)):
            raise TypeError("monotonic clock must return a number")
        return float(value)

    start = now()
    requested = VerificationLevel(level) if level is not None else VerificationLevel.QUICK
    selection = {
        "mode": "explicit" if level is not None else "default",
        "requestedLevel": requested.value,
        "automaticEscalationAllowed": level is None or requested != VerificationLevel.STRICT,
    }
    if level is not None:
        selection["reason"] = EscalationReason.EXPLICIT_POLICY.value
    current_level = requested
    current_policy = AdaptivePolicy.for_level(current_level)
    attempt_counts = {VerificationPhase.BASELINE: 0, VerificationPhase.CANDIDATE: 0}
    attempts: list[dict[str, Any]] = []
    fresh_records: list[dict[str, Any]] = []
    cleanup_records: list[dict[str, Any]] = []
    escalations: list[dict[str, Any]] = []
    representative: list[dict[str, Any]] = []
    diagnostics: list[str] = []
    evidence_truncated = False
    cumulative_budget_exhausted = False
    decisive_failure = False
    stop_reason: str | None = None
    cleanup_failed = False
    fresh_failed = False
    baseline_signatures: list[Any] = []
    baseline_reused = False
    baseline_reuse_rejected_reason: str | None = None
    candidate_accepted = 0
    guardrail_results: list[bool] = []

    def append_diagnostic(value: Any) -> None:
        nonlocal evidence_truncated
        if value is None:
            return
        text = _bounded_text(str(value), 4096)
        if len(diagnostics) >= 32:
            evidence_truncated = True
            return
        if text != str(value):
            evidence_truncated = True
        diagnostics.append(text)

    def append_evidence(phase: VerificationPhase, value: Mapping[str, Any]) -> None:
        nonlocal evidence_truncated
        if len(representative) >= 8:
            evidence_truncated = True
            return
        item = _bounded_json(dict(value), 4096)
        if not isinstance(item, dict):
            item = {"value": item}
        item["phase"] = phase.value
        representative.append(item)

    def append_attempt(value: dict[str, Any]) -> None:
        nonlocal evidence_truncated
        if len(attempts) >= 32:
            evidence_truncated = True
            return
        attempts.append(value)

    def next_level(level_value: VerificationLevel) -> VerificationLevel | None:
        return {
            VerificationLevel.QUICK: VerificationLevel.STANDARD,
            VerificationLevel.STANDARD: VerificationLevel.STRICT,
            VerificationLevel.STRICT: None,
        }[level_value]

    def maybe_escalate(observation: Observation | None, phase: VerificationPhase) -> bool:
        nonlocal current_level, current_policy, stop_reason
        if observation is None:
            return False
        reasons = [reason for reason in observation.escalation_reasons if reason in ALLOWED_AUTOMATIC_REASONS]
        if not reasons:
            return False
        target = next_level(current_level)
        if target is None:
            stop_reason = "strict policy exhausted after typed runtime trigger"
            return False
        elapsed = max(0.0, now() - start)
        target_policy = AdaptivePolicy.for_level(target)
        if elapsed >= target_policy.cumulative_seconds:
            stop_reason = "cumulative deadline prevents escalation"
            return False
        escalations.append(
            {
                "from": current_level.value,
                "to": target.value,
                "phase": phase.value,
                "reasons": reasons[:5],
                "elapsedSeconds": elapsed,
            }
        )
        current_level = target
        current_policy = target_policy
        return True

    def state_for(
        callback: StateCallback | None,
        context: AttemptContext,
        records: list[dict[str, Any]],
        kind: str,
    ) -> StateResult:
        if callback is None:
            result = StateResult(StateStatus.NOT_REQUIRED, operation=f"{kind}-not-required")
        else:
            try:
                result = callback(context)
                if not isinstance(result, StateResult):
                    raise TypeError(f"{kind} callback must return StateResult")
            except Exception as error:  # callback failures are evidence, not unbounded retries
                result = StateResult(StateStatus.FAILED, str(error), operation=kind)
        end = now()
        if end > min(context.deadline, context.cumulative_deadline):
            result = StateResult(
                StateStatus.FAILED,
                f"{kind} returned after its bounded deadline",
                operation=kind,
            )
        record = {"phase": context.phase.value, "attempt": context.attempt_number, **result.as_dict()}
        if len(records) < 32:
            records.append(record)
        else:
            nonlocal_evidence[0] = True
        return result

    # A mutable cell lets the nested state helper mark bounded evidence without
    # making every callback path carry another nonlocal declaration.
    nonlocal_evidence = [False]

    def run_attempt(phase: VerificationPhase, callback: AttemptCallback) -> Observation | None:
        nonlocal cumulative_budget_exhausted, fresh_failed, cleanup_failed, decisive_failure, stop_reason, evidence_truncated
        ordinal = attempt_counts[phase] + 1
        elapsed = max(0.0, now() - start)
        cumulative_deadline = start + current_policy.cumulative_seconds
        if elapsed >= current_policy.cumulative_seconds:
            cumulative_budget_exhausted = True
            stop_reason = "cumulative deadline exhausted before attempt"
            append_attempt({
                "phase": phase.value,
                "attempt": ordinal,
                "level": current_level.value,
                "status": "budgetExceeded",
                "elapsedSeconds": elapsed,
            })
            return None
        attempt_counts[phase] += 1
        attempt_start = now()
        deadline = min(attempt_start + current_policy.per_attempt_seconds, cumulative_deadline)
        context = AttemptContext(
            phase=phase,
            attempt_number=ordinal,
            level=current_level,
            started_at=attempt_start,
            deadline=deadline,
            cumulative_deadline=cumulative_deadline,
        )
        fresh_result = state_for(fresh_state, context, fresh_records, "fresh-state")
        if fresh_result.status in {StateStatus.FAILED, StateStatus.UNKNOWN}:
            fresh_failed = True
            append_attempt({
                "phase": phase.value,
                "attempt": ordinal,
                "level": current_level.value,
                "status": "freshStateUnavailable",
                "freshState": fresh_result.as_dict(),
            })
            stop_reason = fresh_result.diagnostic or "fresh state could not be established"
            return None

        observation: Observation
        callback_error: str | None = None
        try:
            observation = callback(context)
            if not isinstance(observation, Observation):
                raise TypeError("attempt callback must return Observation")
        except Exception as error:
            callback_error = str(error)
            observation = Observation(complete=False, diagnostic=callback_error)
        callback_end = now()
        late = callback_end > min(context.deadline, context.cumulative_deadline)
        if late:
            observation = Observation(
                **{
                    **observation.__dict__,
                    "complete": False,
                    "regression_decisive": False,
                    "diagnostic": (observation.diagnostic or "") + "; observation returned after its bounded deadline",
                }
            )
            cumulative_budget_exhausted = callback_end - start >= current_policy.cumulative_seconds
        expected_identity = pre_fix_identity if phase == VerificationPhase.BASELINE else candidate_identity
        if expected_identity is not None and observation.identity is not None and not identities_match(observation.identity, expected_identity):
            observation = Observation(
                **{
                    **observation.__dict__,
                    "complete": False,
                    "stale": True,
                    "diagnostic": (observation.diagnostic or "") + "; computed observation identity mismatch",
                }
            )
            append_diagnostic("computed observation identity mismatch")
        cleanup_result = state_for(cleanup, context, cleanup_records, "cleanup")
        if cleanup_result.status in {StateStatus.FAILED, StateStatus.UNKNOWN}:
            cleanup_failed = True
            if not decisive_failure:
                stop_reason = cleanup_result.diagnostic or "cleanup could not establish a reliable next state"
        cleanup_end = now()
        if cleanup_end > min(context.deadline, context.cumulative_deadline):
            cleanup_failed = True
            if not decisive_failure:
                stop_reason = "cleanup returned after its bounded deadline"
        summary = {
            "phase": phase.value,
            "attempt": ordinal,
            "level": current_level.value,
            "startedElapsedSeconds": max(0.0, attempt_start - start),
            "returnedElapsedSeconds": max(0.0, callback_end - start),
            "deadlineSeconds": current_policy.per_attempt_seconds,
            "late": late,
            "freshState": fresh_result.as_dict(),
            "cleanupState": cleanup_result.as_dict(),
            "observation": observation.as_summary(),
        }
        if callback_error:
            summary["callbackError"] = _bounded_text(callback_error, 4096)
        append_attempt(summary)
        append_diagnostic(observation.diagnostic)
        if len(observation.evidence) > 8:
            evidence_truncated = True
        for evidence in observation.evidence[:8]:
            append_evidence(phase, evidence)
        if late:
            cumulative_budget_exhausted = cumulative_budget_exhausted or cleanup_end - start >= current_policy.cumulative_seconds
        if observation.regression_decisive and phase == VerificationPhase.CANDIDATE and not late:
            decisive_failure = True
            stop_reason = observation.diagnostic or "decisive post-fix regression"
        return observation

    # Identity-gated baseline reuse is processed before any callback. A reused
    # record counts as one observation, but never satisfies a larger policy by
    # itself. It is rejected when its computed identity is not an exact match.
    if reusable_baseline is not None:
        if not identities_match(reusable_baseline.identity, pre_fix_identity):
            baseline_reuse_rejected_reason = "baseline identity mismatch"
        elif reusable_baseline.stale or reusable_baseline.contaminated or not reusable_baseline.decisive:
            baseline_reuse_rejected_reason = "baseline reuse is stale, contaminated, or non-decisive"
        else:
            baseline_reused = True
            baseline_signatures.append(_canonical_signature(reusable_baseline.signature))
            append_evidence(VerificationPhase.BASELINE, {
                "kind": "reusedBaseline",
                "identityMatch": True,
                "signature": reusable_baseline.signature,
            })
            for evidence in reusable_baseline.evidence[:2]:
                append_evidence(VerificationPhase.BASELINE, evidence)
    if baseline_reuse_rejected_reason:
        append_diagnostic(baseline_reuse_rejected_reason)

    while not decisive_failure:
        required_baseline = current_policy.baseline_attempts
        while (
            len(baseline_signatures) < required_baseline
            and attempt_counts[VerificationPhase.BASELINE] < required_baseline
            and not decisive_failure
        ):
            observation = run_attempt(VerificationPhase.BASELINE, baseline_attempt)
            if observation is None:
                break
            valid = observation.complete and not observation.stale and not observation.contaminated
            escalated = False
            if valid and observation.decisive and observation.signature is not None:
                signature = _canonical_signature(observation.signature)
                if baseline_signatures and signature != baseline_signatures[0]:
                    append_diagnostic("baseline observations conflict")
                    escalated = maybe_escalate(
                        Observation(escalation_reasons=(EscalationReason.INCONSISTENT_OBSERVATION.value,)),
                        VerificationPhase.BASELINE,
                    )
                    if not escalated:
                        stop_reason = stop_reason or "baseline observations conflict"
                        break
                    continue
                baseline_signatures.append(signature)
            else:
                if observation.stale:
                    append_diagnostic("baseline observation is stale")
                elif observation.contaminated:
                    append_diagnostic("baseline observation is contaminated")
                elif not observation.decisive:
                    append_diagnostic("pre-fix failure was not decisively reproduced")
                    stop_reason = stop_reason or "pre-fix failure was not decisively reproduced"
                escalated = maybe_escalate(observation, VerificationPhase.BASELINE)
                if not escalated:
                    break
            if not escalated:
                escalated = maybe_escalate(observation, VerificationPhase.BASELINE)
            if cleanup_failed or fresh_failed or cumulative_budget_exhausted:
                break
            required_baseline = current_policy.baseline_attempts
        if decisive_failure:
            break
        baseline_ready = len(baseline_signatures) >= current_policy.baseline_attempts
        if not baseline_ready:
            break

        required_candidate = current_policy.candidate_attempts
        while (
            candidate_accepted < required_candidate
            and attempt_counts[VerificationPhase.CANDIDATE] < required_candidate
            and not decisive_failure
        ):
            observation = run_attempt(VerificationPhase.CANDIDATE, candidate_attempt)
            if observation is None:
                break
            guardrail_results.append(observation.guardrails_passed)
            if observation.regression_decisive:
                decisive_failure = True
                break
            valid = observation.complete and not observation.stale and not observation.contaminated
            escalated = False
            if valid and observation.guardrails_passed and observation.accepted:
                candidate_accepted += 1
            else:
                if not observation.guardrails_passed:
                    append_diagnostic("candidate regression guardrail did not pass")
                if observation.stale:
                    append_diagnostic("candidate observation is stale")
                if observation.contaminated:
                    append_diagnostic("candidate observation is contaminated")
                stop_reason = stop_reason or "candidate acceptance or guardrail threshold was not reached"
                escalated = maybe_escalate(observation, VerificationPhase.CANDIDATE)
                if not escalated:
                    break
            if not escalated:
                escalated = maybe_escalate(observation, VerificationPhase.CANDIDATE)
            if cleanup_failed or fresh_failed or cumulative_budget_exhausted:
                break
            required_candidate = current_policy.candidate_attempts
        if len(baseline_signatures) < current_policy.baseline_attempts and not decisive_failure:
            # A later candidate trigger can raise the strict baseline
            # threshold. The trigger is the explicit reason to collect only
            # the missing additional baseline observation(s).
            continue
        break

    if nonlocal_evidence[0]:
        evidence_truncated = True
    elapsed = max(0.0, now() - start)
    cumulative_budget_exhausted = cumulative_budget_exhausted or elapsed >= current_policy.cumulative_seconds
    baseline_required = current_policy.baseline_attempts
    candidate_required = current_policy.candidate_attempts
    baseline_reliable = len(baseline_signatures) >= baseline_required
    candidate_reliable = candidate_accepted >= candidate_required
    if decisive_failure:
        outcome = VerificationOutcome.FAILED
    elif (
        not baseline_reliable
        or not candidate_reliable
        or not guardrail_results
        or not all(guardrail_results)
        or cleanup_failed
        or fresh_failed
        or cumulative_budget_exhausted
    ):
        outcome = VerificationOutcome.INCONCLUSIVE
    else:
        outcome = VerificationOutcome.VERIFIED

    selection["automaticEscalations"] = len(escalations)
    if baseline_reuse_rejected_reason:
        selection["baselineReuseRejected"] = baseline_reuse_rejected_reason
    return AdaptiveVerificationResult(
        outcome=outcome,
        level=current_level,
        default_level=VerificationLevel.QUICK,
        policy_selection=selection,
        policy=current_policy,
        pre_fix_identity=pre_fix_identity,
        candidate_identity=candidate_identity,
        pre_fix_failure_signature={
            "reproduced": baseline_reliable,
            "requiredAgreeingObservations": baseline_required,
            "agreeingObservations": len(baseline_signatures),
            "signature": baseline_signatures[0] if baseline_signatures else None,
            "reused": baseline_reused,
        },
        post_fix_acceptance={
            "accepted": candidate_reliable,
            "requiredObservations": candidate_required,
            "acceptedObservations": candidate_accepted,
        },
        regression_guardrails={
            "passed": bool(guardrail_results) and all(guardrail_results),
            "observations": guardrail_results[:32],
            "decisiveFailure": decisive_failure,
        },
        attempts=attempts,
        fresh_state=fresh_records,
        cleanup=cleanup_records,
        escalations=escalations,
        representative_evidence=representative,
        diagnostics=diagnostics,
        elapsed_seconds=elapsed,
        cumulative_budget_exhausted=cumulative_budget_exhausted,
        evidence_truncated=evidence_truncated,
        decision_reason=stop_reason,
    )


def _canonical_signature(value: Any) -> Any:
    return _bounded_json(value, 4096)


def _canonical_json(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def _bounded_text(value: str, limit: int) -> str:
    if len(value) <= limit:
        return value
    return value[:limit] + "..."


def _bounded_json(value: Any, byte_limit: int) -> Any:
    try:
        encoded = _canonical_json(value)
    except (TypeError, ValueError):
        encoded = _canonical_json(str(value))
    if len(encoded.encode("utf-8")) <= byte_limit:
        try:
            return json.loads(encoded)
        except json.JSONDecodeError:
            return encoded
    prefix = encoded.encode("utf-8")[:byte_limit]
    return StringTruncation.decode(prefix)


class StringTruncation:
    @staticmethod
    def decode(value: bytes) -> str:
        return value.decode("utf-8", errors="replace") + "..."


__all__ = [
    "AdaptivePolicy",
    "AdaptiveVerificationResult",
    "AttemptContext",
    "BaselineEvidence",
    "EscalationReason",
    "Observation",
    "StateResult",
    "StateStatus",
    "VerificationLevel",
    "VerificationOutcome",
    "VerificationPhase",
    "compute_identity",
    "identities_match",
    "normalize_uuid",
    "run_adaptive_verification",
]
