#!/usr/bin/env python3
"""Deterministic contract tests for adaptive_verification.py."""

from __future__ import annotations

import unittest

from adaptive_verification import (
    AdaptivePolicy,
    BaselineEvidence,
    EscalationReason,
    Observation,
    StateResult,
    StateStatus,
    VerificationLevel,
    VerificationOutcome,
    compute_identity,
    identities_match,
    run_adaptive_verification,
)


class FakeClock:
    def __init__(self) -> None:
        self.value = 0.0

    def now(self) -> float:
        return self.value

    def advance(self, seconds: float) -> None:
        self.value += seconds


def observation_sequence(values: list[Observation], clock: FakeClock, step: float = 0.0):
    calls: list[int] = []

    def callback(_context):
        calls.append(1)
        if step:
            clock.advance(step)
        return values.pop(0)

    callback.calls = calls  # type: ignore[attr-defined]
    return callback


class AdaptiveVerificationTests(unittest.TestCase):
    def test_policy_defaults_are_exact(self) -> None:
        self.assertEqual(
            [
                AdaptivePolicy.for_level(level).as_dict()
                for level in (VerificationLevel.QUICK, VerificationLevel.STANDARD, VerificationLevel.STRICT)
            ],
            [
                {"level": "quick", "baselineAttempts": 1, "candidateAttempts": 1, "perAttemptSeconds": 5.0, "cumulativeSeconds": 15.0},
                {"level": "standard", "baselineAttempts": 2, "candidateAttempts": 2, "perAttemptSeconds": 15.0, "cumulativeSeconds": 60.0},
                {"level": "strict", "baselineAttempts": 3, "candidateAttempts": 3, "perAttemptSeconds": 30.0, "cumulativeSeconds": 180.0},
            ],
        )

    def test_default_quick_verifies_without_unnecessary_retries(self) -> None:
        clock = FakeClock()
        baseline = observation_sequence([Observation(decisive=True, signature={"kind": "crash"})], clock)
        candidate = observation_sequence([Observation(accepted=True)], clock)

        result = run_adaptive_verification(baseline, candidate, clock=clock)

        self.assertEqual(result.outcome, VerificationOutcome.VERIFIED)
        self.assertEqual(result.level, VerificationLevel.QUICK)
        self.assertEqual(len(baseline.calls), 1)  # type: ignore[attr-defined]
        self.assertEqual(len(candidate.calls), 1)  # type: ignore[attr-defined]
        self.assertEqual(result.policy.cumulative_seconds, 15.0)

    def test_baseline_not_reproduced_is_inconclusive(self) -> None:
        clock = FakeClock()
        baseline = observation_sequence([Observation(decisive=False)], clock)
        candidate = observation_sequence([Observation(accepted=True)], clock)

        result = run_adaptive_verification(baseline, candidate, clock=clock)

        self.assertEqual(result.outcome, VerificationOutcome.INCONCLUSIVE)
        self.assertEqual(len(candidate.calls), 0)  # type: ignore[attr-defined]
        self.assertFalse(result.pre_fix_failure_signature["reproduced"])

    def test_decisive_candidate_failure_stops_before_more_attempts(self) -> None:
        clock = FakeClock()
        baseline = observation_sequence([Observation(decisive=True, signature="same")], clock)
        candidate = observation_sequence([
            Observation(accepted=False, guardrails_passed=False, regression_decisive=True),
            Observation(accepted=True),
        ], clock)

        result = run_adaptive_verification(baseline, candidate, clock=clock)

        self.assertEqual(result.outcome, VerificationOutcome.FAILED)
        self.assertEqual(len(candidate.calls), 1)  # type: ignore[attr-defined]

    def test_explicit_standard_requires_two_agreeing_phases(self) -> None:
        clock = FakeClock()
        baseline = observation_sequence([
            Observation(decisive=True, signature="same"),
            Observation(decisive=True, signature="same"),
        ], clock)
        candidate = observation_sequence([Observation(accepted=True), Observation(accepted=True)], clock)

        result = run_adaptive_verification(
            baseline,
            candidate,
            level=VerificationLevel.STANDARD,
            clock=clock,
        )

        self.assertEqual(result.outcome, VerificationOutcome.VERIFIED)
        self.assertEqual(result.policy_selection["mode"], "explicit")
        self.assertEqual(len(result.attempts), 4)

    def test_typed_timing_trigger_escalates_without_resetting_attempts(self) -> None:
        clock = FakeClock()
        trigger = Observation(
            decisive=True,
            signature="same",
            escalation_reasons=(EscalationReason.TIMING.value,),
        )
        baseline = observation_sequence([trigger, Observation(decisive=True, signature="same")], clock)
        candidate = observation_sequence([Observation(accepted=True), Observation(accepted=True)], clock)

        result = run_adaptive_verification(baseline, candidate, clock=clock)

        self.assertEqual(result.outcome, VerificationOutcome.VERIFIED)
        self.assertEqual(result.level, VerificationLevel.STANDARD)
        self.assertEqual(result.escalations[0]["reasons"], [EscalationReason.TIMING.value])
        self.assertEqual(len(baseline.calls), 2)  # type: ignore[attr-defined]

    def test_standard_to_strict_escalation_preserves_candidate_count(self) -> None:
        clock = FakeClock()
        baseline = observation_sequence([
            Observation(decisive=True, signature="same", escalation_reasons=(EscalationReason.CONCURRENCY.value,)),
            Observation(decisive=True, signature="same"),
            Observation(decisive=True, signature="same"),
        ], clock)
        candidate = observation_sequence([
            Observation(accepted=True, escalation_reasons=(EscalationReason.KNOWN_FLAKINESS.value,)),
            Observation(accepted=True),
            Observation(accepted=True),
        ], clock)

        result = run_adaptive_verification(baseline, candidate, clock=clock)

        self.assertEqual(result.outcome, VerificationOutcome.VERIFIED)
        self.assertEqual(result.level, VerificationLevel.STRICT)
        self.assertEqual(len(candidate.calls), 3)  # type: ignore[attr-defined]
        self.assertEqual([item["from"] for item in result.escalations], ["quick", "standard"])

    def test_late_attempt_is_rejected_by_per_attempt_deadline(self) -> None:
        clock = FakeClock()

        def baseline(context):
            self.assertEqual(context.level, VerificationLevel.QUICK)
            clock.advance(5.1)
            return Observation(decisive=True, signature="late")

        candidate = observation_sequence([Observation(accepted=True)], clock)
        result = run_adaptive_verification(baseline, candidate, clock=clock)

        self.assertEqual(result.outcome, VerificationOutcome.INCONCLUSIVE)
        self.assertEqual(len(candidate.calls), 0)  # type: ignore[attr-defined]
        self.assertTrue(result.attempts[0]["late"])

    def test_late_candidate_regression_is_not_decisive(self) -> None:
        clock = FakeClock()
        baseline = observation_sequence([Observation(decisive=True, signature="same")], clock)

        def candidate(_context):
            clock.advance(5.1)
            return Observation(guardrails_passed=False, regression_decisive=True)

        result = run_adaptive_verification(baseline, candidate, clock=clock)

        self.assertEqual(result.outcome, VerificationOutcome.INCONCLUSIVE)
        self.assertFalse(result.regression_guardrails["decisiveFailure"])


    def test_cumulative_deadline_is_shared_with_cleanup(self) -> None:
        clock = FakeClock()

        def baseline(_context):
            clock.advance(4.0)
            return Observation(decisive=True, signature="same")

        def cleanup(_context):
            clock.advance(12.0)
            return StateResult(StateStatus.FRESH, operation="owned-cleanup")

        candidate = observation_sequence([Observation(accepted=True)], clock)
        result = run_adaptive_verification(baseline, candidate, cleanup=cleanup, clock=clock)

        self.assertEqual(result.outcome, VerificationOutcome.INCONCLUSIVE)
        self.assertEqual(len(candidate.calls), 0)  # type: ignore[attr-defined]
        self.assertTrue(result.cumulative_budget_exhausted)

    def test_cleanup_failure_after_regression_keeps_failed_precedence(self) -> None:
        clock = FakeClock()
        baseline = observation_sequence([Observation(decisive=True, signature="same")], clock)
        candidate = observation_sequence([
            Observation(accepted=False, regression_decisive=True, guardrails_passed=False),
        ], clock)

        def cleanup(_context):
            if _context.phase.value == "baseline":
                return StateResult(StateStatus.NOT_REQUIRED, operation="baseline-cleanup-not-required")
            return StateResult(StateStatus.FAILED, "owned target did not terminate", "terminate-owned-target")

        result = run_adaptive_verification(baseline, candidate, cleanup=cleanup, clock=clock)

        self.assertEqual(result.outcome, VerificationOutcome.FAILED)
        self.assertEqual(result.cleanup[0]["status"], StateStatus.NOT_REQUIRED.value)
        self.assertEqual(result.cleanup[1]["status"], StateStatus.FAILED.value)

    def test_unknown_fresh_state_prevents_verified(self) -> None:
        clock = FakeClock()
        baseline = observation_sequence([Observation(decisive=True, signature="same")], clock)
        candidate = observation_sequence([Observation(accepted=True)], clock)

        def fresh(_context):
            return StateResult(StateStatus.UNKNOWN, "Simulator ownership was not established", "fresh-simulator")

        result = run_adaptive_verification(baseline, candidate, fresh_state=fresh, clock=clock)

        self.assertEqual(result.outcome, VerificationOutcome.INCONCLUSIVE)
        self.assertEqual(len(baseline.calls), 0)  # type: ignore[attr-defined]

    def test_restored_and_not_required_states_are_recorded(self) -> None:
        clock = FakeClock()
        baseline = observation_sequence([Observation(decisive=True, signature="same")], clock)
        candidate = observation_sequence([Observation(accepted=True)], clock)
        states = iter([StateResult(StateStatus.RESTORED), StateResult(StateStatus.FRESH)])

        result = run_adaptive_verification(
            baseline,
            candidate,
            fresh_state=lambda _context: next(states),
            clock=clock,
        )

        self.assertEqual(result.outcome, VerificationOutcome.VERIFIED)
        self.assertEqual([item["status"] for item in result.fresh_state], ["restored", "fresh"])
        self.assertEqual([item["status"] for item in result.cleanup], ["notRequired", "notRequired"])

    def test_conflicting_baseline_is_never_verified(self) -> None:
        clock = FakeClock()
        baseline = observation_sequence([
            Observation(decisive=True, signature="first"),
            Observation(decisive=True, signature="second"),
        ], clock)
        candidate = observation_sequence([Observation(accepted=True)], clock)

        result = run_adaptive_verification(
            baseline,
            candidate,
            level=VerificationLevel.STANDARD,
            clock=clock,
        )

        self.assertEqual(result.outcome, VerificationOutcome.INCONCLUSIVE)
        self.assertEqual(len(candidate.calls), 0)  # type: ignore[attr-defined]
        self.assertIn("baseline observations conflict", result.diagnostics)

    def test_identity_gated_reuse_accepts_exact_computed_identity_only(self) -> None:
        path = __file__
        identity = compute_identity(
            path,
            macho_uuid="12345678-1234-1234-1234-123456789abc",
            architecture="arm64e",
            build_source_identity={"sourceSHA256": "source"},
            environment={"mode": "fixture"},
            target={"name": "host"},
            scenario_oracle={"version": 1},
        )
        self.assertTrue(identities_match(identity, dict(identity)))
        altered = dict(identity)
        altered["executableSHA256"] = "0" * 64
        self.assertFalse(identities_match(identity, altered))

        clock = FakeClock()
        baseline = observation_sequence([Observation(decisive=True, signature="same")], clock)
        candidate = observation_sequence([Observation(accepted=True)], clock)
        result = run_adaptive_verification(
            baseline,
            candidate,
            pre_fix_identity=identity,
            reusable_baseline=BaselineEvidence(identity, True, "same"),
            clock=clock,
        )

        self.assertEqual(result.outcome, VerificationOutcome.VERIFIED)
        self.assertEqual(len(baseline.calls), 0)  # type: ignore[attr-defined]
        self.assertTrue(result.pre_fix_failure_signature["reused"])

    def test_mismatched_reuse_is_rejected_and_requires_fresh_baseline(self) -> None:
        clock = FakeClock()
        baseline = observation_sequence([Observation(decisive=True, signature="new")], clock)
        candidate = observation_sequence([Observation(accepted=True)], clock)
        result = run_adaptive_verification(
            baseline,
            candidate,
            pre_fix_identity={"computed": True, "executableSHA256": "new"},
            reusable_baseline=BaselineEvidence({"computed": True, "executableSHA256": "old"}, True, "old"),
            clock=clock,
        )

        self.assertEqual(result.outcome, VerificationOutcome.VERIFIED)
        self.assertEqual(len(baseline.calls), 1)  # type: ignore[attr-defined]
        self.assertIn("baseline identity mismatch", result.diagnostics)

    def test_candidate_identity_mismatch_is_stale(self) -> None:
        clock = FakeClock()
        baseline = observation_sequence([Observation(decisive=True, signature="same")], clock)
        candidate = observation_sequence([
            Observation(accepted=True, identity={"computed": True, "executableSHA256": "other"}),
        ], clock)
        expected = {"computed": True, "executableSHA256": "candidate"}

        result = run_adaptive_verification(
            baseline,
            candidate,
            candidate_identity=expected,
            clock=clock,
        )

        self.assertEqual(result.outcome, VerificationOutcome.INCONCLUSIVE)
        self.assertTrue(result.attempts[-1]["observation"]["stale"])

    def test_bounded_evidence_reports_truncation(self) -> None:
        clock = FakeClock()
        huge = {"diagnostic": "x" * 10_000}
        baseline = observation_sequence([
            Observation(decisive=True, signature="same", diagnostic="x" * 10_000, evidence=(huge,) * 10),
        ], clock)
        candidate = observation_sequence([Observation(accepted=True, evidence=(huge,) * 10)], clock)
        result = run_adaptive_verification(baseline, candidate, clock=clock)

        payload = result.as_dict()
        self.assertTrue(payload["evidenceBounds"]["truncated"])
        self.assertLessEqual(max((len(item) for item in result.diagnostics), default=0), 4_099)
        self.assertLessEqual(len(result.representative_evidence), 8)


if __name__ == "__main__":
    unittest.main()
