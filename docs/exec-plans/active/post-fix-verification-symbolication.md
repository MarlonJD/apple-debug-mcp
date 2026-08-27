<!-- harness-plan:v1
id: post-fix-verification-symbolication
status: active
created: 2026-08-27
updated: 2026-08-27
completed:
owner: Apple Debug MCP maintainers
-->

# Harden post-fix verification and crash symbolication

This plan hardens two related evidence boundaries in the local Apple Debug MCP:
post-fix verification must distinguish a reliably reproduced baseline from a
candidate result, and crash symbolication must prove artifact identity before
asking Apple tooling to resolve an address. The decision model stays
transport-independent, the concrete adaptive orchestration belongs to the
existing casebook runner layer, and artifact/crash logic stays in
`AppleDebugCore`. The MCP surface remains small and existing authorization and
cleanup gates are preserved.

## Purpose / Big Picture

Provide a bounded adaptive verification contract with quick as the default,
standard and strict escalation only when typed runtime evidence justifies more
attempts, and explicit `verified`, `failed`, or `inconclusive` outcomes. A
verification result must separately describe the pre-fix failure signature,
post-fix acceptance checks, and regression guardrails. It must never call a fix
verified when the baseline was not reliably reproduced.

Harden crash symbolication so a crash Binary Images record is matched to an
explicitly supplied regular Mach-O, `.app`, or `.dSYM` by normalized UUID and
architecture. The service must derive and validate load/base address data when
the crash provides it, validate address arithmetic before `atos`, preserve
unmatched frames, and fail closed for identity, layout, address, and resolution
failures. All analysis remains local, bounded, and non-executing.

The planning operating point is `gpt-5.6-sol` with `xhigh` reasoning. The
implementation operating point is `gpt-5.6-luna` with `max` reasoning after the
plan review loop.

## Progress

- [x] (2026-08-27) Read repository instructions, architecture, security, reliability, planning, harness, and active casebook documentation.
- [x] (2026-08-27) Inspected replay, evidence/repro-bundle, crash parsing, symbolication, Mach-O, DWARF, binary-diff, MCP schema/dispatch, tests, fixtures, and casebooks.
- [x] (2026-08-27) Record the initial adaptive-verification and symbolication design before implementation.
- [x] (2026-08-27) Obtain two independent read-only plan reviews: Sol `xhigh` and Sol `ultra`.
- [x] (2026-08-27) Revise this plan with accepted and rejected review findings before implementation.
- [x] (2026-08-27) Implement the revised plan with Luna `max`, including Core identity/layout/crash/symbolication changes, adaptive runner integration, deterministic tests, fixture smoke, and documentation.
- [x] (2026-08-27) Perform the final read-only Sol `xhigh` diff/acceptance review and resolve findings through the same Luna agent; the bounded correction passes were accepted after the final focused/full gates.
- [x] (2026-08-27) Apply the bounded Sol `xhigh` correction pass for missing-dSYM fail-closed behavior, content-identity provider ambiguity, bounded text parsing, diagnostic retention, and runtime casebook state evidence.

## Surprises & Discoveries

- `CrashSymbolicationService` currently selects the first artifact with a
  matching `imageName`, or the only supplied artifact when no name matches;
  neither branch proves the crash image UUID or architecture.
- `MachOInspector` parses thin and universal headers but does not expose
  `LC_UUID`, and universal entries are not inspected as identity-bearing
  slices. `.app` and `.dSYM` resolution is repeated in symbolication and
  binary-diff code.
- The text crash fixture has thread frames but no parsed Binary Images section;
  the text parser currently returns `images: []`. A truthful identity test
  therefore needs a fixture with explicit image UUID/base data.
- Replay is a bounded relaunch to a recorded source location and intentionally
  does not restore registers, memory, scheduler state, kernel state, or
  external I/O. Adaptive verification must report those limits rather than
  treating replay as exact reverse execution.
- Existing repro bundles and casebooks already provide bounded JSON summaries,
  representative screenshots/logs, explicit target identity, and cleanup
  patterns. The new contract should consume or extend those shapes instead of
  retaining full evidence for every attempt.
- Modern `.ips` frames can identify an image by `imageIndex` and carry a numeric
  image-relative `imageOffset`; `symbolLocation` is not interchangeable with an
  absolute address. Image architecture, base, and size are needed to validate
  the coordinate conversion.
- Matching executable and dSYM artifacts are complementary providers for one
  UUID/architecture, not an ambiguity. Ambiguity applies only to multiple
  distinct providers in the same role.
- The current fat64 reader uses 32-bit reads for fields that are 64-bit in
  `fat_arch_64`, and the current process runner's default deadline is too broad
  for per-frame crash symbolication. The revised contract needs explicit bounds
  and an injectable tool-runner seam.
- The existing Python casebooks own process/Simulator state, while Core can
  own transport-independent decision types. A shared bounded Python evaluator
  consumed by at least one real casebook is the concrete integration boundary;
  a generic MCP tool would not safely own caller-supplied retries or cleanup.

## Decision Log

- Keep the decision types and transition rules transport-independent, but put
  attempt orchestration in a concrete shared runner module consumed by the
  existing runtime, deadlock, and visual casebooks (`scripts/adaptive_verification.py`
  is the named consumer boundary). The runner owns authorized
  process/Simulator/MCP calls and cleanup; the evaluator owns no process control
  and adds no arbitrary sleep. Do not place generic verification in
  `Replay.swift`, and do not add a broad MCP execution tool.
- Use this explicit default policy table, with a monotonic injectable clock:
  quick = 1 baseline attempt + 1 candidate attempt, 5 seconds per attempt and
  15 seconds cumulative; standard = at most 2 baseline + 2 candidate attempts,
  15 seconds per attempt and 60 seconds cumulative; strict = at most 3 baseline
  + 3 candidate attempts, 30 seconds per attempt and 180 seconds cumulative.
  Cleanup and fresh-state setup share the cumulative deadline and have bounded
  operations; they are not an unbudgeted tail. A runner receives the current
  monotonic deadline and must bound its Apple/MCP wait internally; the evaluator
  rejects observations returned after that deadline. Escalation carries elapsed
  time and evidence forward and never resets budgets or repeats a sufficient
  baseline without a reason.
- Keep quick verification as the default and stop at its decisive result. An
  automatic transition quick -> standard or standard -> strict is permitted
  only after a typed runtime reason: timing, concurrency, state leakage,
  inconsistent observation, or known flakiness. An explicitly caller-selected
  standard/strict policy is recorded as such and remains bounded; it is not an
  automatic escalation. A decisive candidate/guardrail failure stops the level
  immediately.
- Require a decisive baseline failure signature before candidate acceptance.
  Quick accepts one decisive reproduction because its oracle is explicit;
  standard requires two agreeing baseline observations and two accepted
  candidate observations; strict requires three agreeing baseline observations
  and three accepted candidate observations. Quick requires one accepted
  candidate observation. A missing, stale, contaminated, or
  identity-mismatched baseline is `inconclusive`, never a passing verification.
  Baseline reuse is allowed only when a computed pre-fix executable SHA-256,
  Mach-O UUID/architecture, build/source identity, relevant environment
  determinants, target identity, and scenario/oracle version all match the
  expected pre-fix record. Candidate identity is recorded separately.
- Require a fresh process, Simulator/application, or debugger state between
  attempts when the existing authorization boundary permits it. If the runner
  cannot establish fresh state or cleanup, retain the evidence and return
  `inconclusive` with the limitation.
- Prefer the existing MCP tools and evidence contracts. Add a public MCP tool
  only if implementation evidence shows that repeated authorized calls cannot
  express the bounded workflow; a pure core evaluator or casebook helper is
  preferred.
- Normalize artifact identity at the Mach-O layer and reuse it from
  symbolication and binary-diff layout handling. Do not search arbitrary user
  directories for symbols; any discovery root must be explicit, bounded, and
  documented as caller-supplied input.
- Match each crash image by exact normalized UUID and architecture. A filename,
  image name, path, or single-artifact convenience match is never sufficient.
  Pair a matching executable/app image provider with a matching dSYM debug
  provider; report ambiguity only for multiple distinct providers in one role.
  Missing dSYM remains a typed non-success for source/line symbolication when
  no embedded debug provider can resolve the frame, while identity matching is
  reported separately from source-line, symbol-only, or unresolved quality.
- Model crash locations as distinct absolute addresses or image-relative
  offsets. For `.ips`, resolve `imageIndex` and checked `base + imageOffset`,
  requiring the result to be within the image's validated base/size range. For
  text `.crash`, map a frame to exactly one parsed Binary Images range. Keep
  preferred Mach-O `__TEXT` VM address, runtime base, slide, and `atos` input as
  distinct values. Treat missing/invalid load address, arithmetic overflow or
  underflow, out-of-range values, unsupported layouts, and unresolved `atos`
  output as typed non-success states; preserve original frame data.
- Bound crash work explicitly: at most 256 images, 128 threads, 2,048 returned
  frames, 32 supplied artifacts, 32 symbolication groups/invocations, 4 KiB per
  diagnostic, 256 KiB aggregate diagnostics, 5 seconds per `atos` batch, and
  30 seconds cumulative symbolication. Report observed/returned counts and a
  `truncated` flag; all frames within the limit remain represented and frames
  beyond it cannot imply complete symbolication.
- Keep existing artifact-size limits, fixed Apple-tool executable paths,
  argument arrays, no-execution analysis, target mutation grants, local-only
  daemon, and owned-process cleanup unchanged.
- Accept the reviewers' optional artifact replacement defense: snapshot
  canonical path, device/inode when available, size, and modification time at
  identity inspection and revalidate before invoking `atos`; replacement
  becomes a typed inconclusive/identity failure.
- Reject broad symbol-root traversal as unnecessary for the current surface.
  Explicit artifact paths are sufficient; if a future root input is required,
  it must first define count/depth/file/byte limits, canonical containment, and
  symlink policy.
- Reject the suggestion to make the required verification gate only
  `make harness-check`: the user-requested workflow explicitly requires both
  `make check` and `make harness-check`, so both remain recorded even though
  the harness wrapper includes overlapping checks. Avoid adding other redundant
  casebook runs beyond the required commands.
- Keep the public MCP surface small: add only the derived identity/status fields
  and optional explicit `dSYMPath` needed by the existing symbolication tools;
  do not add a generic execution or symbol-search operation.
- Remove the obsolete crash-artifact `loadAddress` input. Crash symbolication
  derives runtime base/load only from the matched Binary Images record; the
  standalone `apple_symbolicate` `loadAddress` remains because it is validated
  and passed to `atos`.
- Permit one exact dSYM-only crash provider when no executable/app provider is
  supplied. It supplies the matched slice and debug provider; executable/app
  plus dSYM remains the preferred complementary pair, and distinct content
  identities in one role remain ambiguous.

## Outcomes & Retrospective

The initial plan establishes a bounded, fail-closed design and identifies the
existing unsafe artifact fallback and missing Mach-O UUID boundary. It is not
complete until deterministic fixture evidence proves both a successful
UUID/architecture/source-line symbolication path and every required negative
identity/address case, and until adaptive verification tests prove quick
success, baseline-not-reproduced inconclusive, verified candidate acceptance,
early failed termination, intermittent inconclusive results, bounded budgets,
fresh-state cleanup, and bounded evidence retention.

The implementation now proves these boundaries locally. The shared resolver and
Mach-O parser are used by binary diff and symbolication; exact UUID/architecture
matching rejects name-only, wrong-UUID, wrong-architecture, ambiguous-provider,
malformed-address, and unsupported-layout inputs before `atos`; the real macOS
object/binary/dSYM smoke resolves text Binary Images and plain/header `.ips`
data to a symbol and source line; and the runtime casebook records a quick
verified baseline/candidate result with computed identities and bounded state
and evidence fields.

## Context and Orientation

`Sources/AppleDebugCore/` owns policy, debugger sessions, replay, artifact
analysis, crash parsing, Mach-O/DWARF/binary-diff services, and Apple-tool
adapters. `Sources/AppleDebugMCP/` owns the public tool catalog, schemas, and
dispatch. Relevant current files are:

- `Sources/AppleDebugCore/Replay.swift`: checkpoint capture/relaunch and
  determinism manifest, with explicit non-exact replay semantics.
- `Sources/AppleDebugCore/CrashReports.swift`: `.crash`/`.ips` parsing and the
  current crash-frame artifact fallback.
- `Sources/AppleDebugCore/AppleSymbolication.swift`: `.app`/`.dSYM` payload
  resolution and `atos` invocation.
- `Sources/AppleDebugCore/MachO.swift`: bounded thin/universal Mach-O parser,
  currently without UUID identity output.
- `Sources/AppleDebugCore/AppleDWARF.swift` and
  `Sources/AppleDebugCore/AppleBinaryDiff.swift`: existing dSYM/source and
  artifact-layout capabilities to reuse.
- `Sources/AppleDebugMCP/ToolCatalogSchemas.swift`,
  `ToolCatalogArtifactsDispatch.swift`, and `ToolCatalogSupport.swift`: the
  current `apple_symbolicate` and `apple_crash_symbolicate` contracts.
- `Tests/AppleDebugCoreTests/ReplayTests.swift`,
  `CrashReportTests.swift`, `AppleSymbolicationTests.swift`, `MachOTests.swift`,
  `AppleDWARFTests.swift`, and `AppleBinaryDiffTests.swift`: focused unit
  coverage to extend.
- `Tests/Fixtures/`, `scripts/`, `Makefile`, `docs/RELIABILITY.md`,
  `docs/SECURITY.md`, and `docs/agent-harness/`: deterministic fixtures,
  casebooks, smoke registration, and durable boundary documentation.

The product remains a local authorized debugging tool. Read-only artifact
analysis is allowed by default; launch, attach, evaluation, memory mutation,
Simulator mutation, device operations, Xcode build, and plugin execution retain
their explicit grants. The current working tree contains pre-existing
casebook/documentation changes, including untracked fixtures and runners. They
are in-scope dependencies for this task if the revised implementation extends
them and must otherwise remain intact; do not reset or overwrite them.

## Plan of Work

1. Complete the two independent read-only plan reviews and revise this plan
   with evidence-backed corrections.
2. Add a small transport-independent adaptive decision model plus one shared
   bounded orchestration runner consumed by at least one real existing casebook
   (preferably runtime, deadlock, and visual). Define the three levels, exact
   numeric budgets, monotonic deadlines, typed observations/outcomes/escalation
   reasons, early-stop and outcome precedence, computed identity-gated baseline
   reuse, fresh-state/cleanup reporting, and bounded representative evidence.
3. Extend Mach-O identity extraction to expose normalized UUID and exact
   CPU-subtype-sensitive architecture data for thin, fat32, and fat64 slices.
   Check slice/header/table bounds and UUID commands. Promote one bounded
   explicit artifact-layout resolver for regular files, `.app` main
   executables, and direct `.dSYM` DWARF payloads, replacing duplicated
   resolution without recursive symbol search.
4. Replace crash symbolication selection with exact crash-image identity
   matching. Parse text Binary Images and header-plus-payload or plain `.ips`
   image/frame data, model absolute versus image-relative locations, derive and
   validate base/load/slide/address arithmetic and image ranges, and return
   typed per-image/per-frame status without guessing.
5. Add deterministic fixture and negative tests, including a real object ->
   linked binary -> `dsymutil` fixture with matching dSYM data and source/line
   resolution when the installed Apple tooling exposes it. Add injectable tool
   seams to prove rejected identities/addresses do not invoke `atos`; add a
   bounded crash-symbolication smoke route and integrate adaptive verification
   into a real casebook without widening authorization.
6. Update schemas/dispatch only for required derived identity/status fields, then
   update architecture, security, reliability, harness registry/matrix, and the
   active plan with exact evidence and limitations.
7. Run focused checks first, then the user-required `swift build`, `swift test`,
   `make check`, and `make harness-check`, plus only relevant native
   smokes/casebooks. Review the complete diff and clean only owned runtime state.

## Concrete Steps

Work from `/Users/marlonjd/Developer/monorepos/apple-debug-mcp`.

### Plan review gate

- Save this initial plan and synchronize `docs/exec-plans/index.md`.
- Spawn exactly two context-independent read-only reviewers concurrently:
  `gpt-5.6-sol`/`xhigh` and `gpt-5.6-sol`/`ultra`. Give both the repository,
  plan path, complete goal, and no-edit instruction.
- Wait for both results. Evaluate each finding against source and contract
  evidence, record accepted corrections and materially rejected suggestions in
  this plan, and update the acceptance commands before implementation.

### Adaptive verification contract

- Define the shared runner/evaluator with an injectable monotonic clock and
  these exact default policies: quick = 1 baseline + 1 candidate attempt, 5
  seconds per attempt, 15 seconds cumulative; standard = at most 2 baseline + 2
  candidate attempts, 15 seconds per attempt, 60 seconds cumulative; strict =
  at most 3 baseline + 3 candidate attempts, 30 seconds per attempt, 180
  seconds cumulative. The runner receives each deadline and must bound its
  subprocess/MCP wait internally; observations returned late are not accepted.
  Escalation carries elapsed time and evidence forward and never resets budgets.
- Quick remains the default and must not silently run the strict matrix. An
  automatic quick -> standard or standard -> strict transition requires typed
  runtime evidence for timing, concurrency, state leakage, inconsistent
  observation, or known flakiness. An explicit caller-selected level is
  allowed only as a recorded policy choice, not as hidden automatic retry.
- Model a baseline failure signature, post-fix acceptance checks, regression
  guardrails, computed pre-fix and candidate artifact/build identities,
  environment/target/scenario/oracle identity, attempt summaries, cleanup/fresh
  state, and representative evidence references as distinct fields. The
  computed baseline includes executable SHA-256, Mach-O UUID/architecture,
  build/source identity, relevant environment determinants, target identity, and
  scenario/oracle version; an arbitrary determinism manifest alone is not proof.
- Require quick's one decisive baseline reproduction, standard's two agreeing
  baseline observations, or strict's three agreeing observations before
  candidate acceptance. Stop when the required baseline/candidate/guardrail
  threshold is reached. Stop early on a decisive candidate or guardrail
  regression. Return `inconclusive` for an unreproduced, stale, contaminated,
  conflicting/intermittent baseline, incomplete observation, failed cleanup or
  fresh-state guarantee, or exhausted deadline.
- Define outcome precedence explicitly: a decisive candidate/guardrail
  regression is `failed` even if cleanup later fails; incomplete, stale,
  contaminated, conflicting, or budget-exhausted evidence without a decisive
  regression is `inconclusive`; only baseline, candidate, guardrail, freshness,
  and cleanup success yields `verified`.
- Retain bounded summaries plus representative baseline/candidate evidence;
  never copy complete logs, screenshots, traces, crash reports, or debugger
  snapshots once per attempt. Preserve a clear reason when evidence is omitted.
  Cap attempt summaries, diagnostic bytes, and representative artifacts in the
  runner result; report omitted/truncated counts.
- Make state setup/cleanup an explicit runner callback/result with typed
  `fresh`, `restored`, `notRequired`, `failed`, or `unknown` states. Fresh state
  is required between attempts where authorization permits; unknown/failed
  state prevents `verified` but does not erase a decisive `failed` result.
  Never terminate an unowned process or erase unrelated Simulator/application
  state. Integrate the runner into at least one existing casebook and exercise
  its real MCP calls.

### Symbolication identity contract

- Extend the existing bounded Mach-O parser to read exactly one valid,
  non-zero `LC_UUID` per thin slice and associate it with the exact
  CPU-subtype-sensitive architecture/slice. Support thin, fat32, fat64, and
  swapped-endian forms with checked table/slice offsets, sizes, overlap, header
  CPU agreement, and `sizeofcmds` bounds. Normalize UUIDs only from canonical
  dashed or 32-hex forms; preserve subtype distinctions such as `arm64e` and
  `x86_64h`.
- Keep Mach-O parsing focused on regular-file slices and promote one bounded
  explicit artifact-layout resolver for regular Mach-O, the main executable of
  an `.app`, and direct regular entries under `.dSYM/Contents/Resources/DWARF`.
  Reuse that resolver from symbolication and binary-diff instead of duplicating
  it. Require absolute paths, canonical containment for bundle children, and a
  documented symlink policy; embedded frameworks must be caller-supplied
  explicitly. Do not recursively search for symbols.
- Parse text crash Binary Images ranges and retain `.ips` image index, UUID,
  architecture, name/path, base, and size when present. Support both plain JSON
  `.ips` and a bounded header-plus-payload form. Keep missing or malformed crash
  identity typed; never infer it from a filename or image name.
- Model a frame location as either an absolute address or an image-relative
  offset with its `imageIndex`. For `.ips`, resolve the index and checked
  `base + imageOffset`; for text `.crash`, map the frame to exactly one parsed
  Binary Images range. Keep the selected Mach-O `__TEXT` preferred VM address,
  runtime base, slide, and `atos` input as distinct values. Require the result
  to be within the validated image range and reject missing, malformed,
  overflowing, underflowing, or out-of-range load/address calculations.
- Inspect every explicit artifact once and match only exact normalized UUID plus
  architecture. Separate the image artifact from its symbol provider: a
  matching executable/app and dSYM pair is complementary, while multiple
  distinct providers in the same role are ambiguous. A filename, image name,
  path, or single-artifact fallback is never sufficient. Missing dSYM is a
  typed non-success for source/line resolution when no embedded provider can
  resolve the frame; identity matching is reported separately from source-line,
  symbol-only, and unresolved quality. Wrong UUID, wrong architecture,
  same-name wrong artifact, missing dSYM, and unsupported layouts must not
  produce successful symbolication or invoke `atos` when the failure is known
  before resolution.
- Bound crash analysis and tool work: at most 256 images, 128 threads, 2,048
  returned frames, 32 artifacts, 32 grouped/batched `atos` invocations, 4 KiB
  per diagnostic, 256 KiB aggregate diagnostics, 5 seconds per `atos` batch,
  and 30 seconds cumulative symbolication. Batch addresses by resolved image
  artifact/slice/load coordinate when deterministic. Report observed and
  returned counts plus `truncated`; frames within the limit remain represented,
  and a truncated result cannot claim complete symbolication.
- Use an injectable bounded process/tool seam in tests and parse `atos` output
  into stable `resolvedSymbol`, `resolvedSourceLine`, `symbolOnly`,
  `unresolved`, or typed failure statuses. Preserve original image/address/
  symbol data for every returned frame and return typed per-image/per-frame
  status with short diagnostics identifying the missing or incorrect artifact.
- Omit symbol-root discovery for this surface. If a future feature needs roots,
  require explicit caller-supplied roots with count/depth/file/byte limits,
  canonical containment, and symlink policy before implementation.
- Snapshot canonical artifact path, device/inode when available, size, and
  modification time at identity inspection and revalidate before invoking
  `atos`; replacement is a typed identity/inconclusive failure.

### Fixture, tests, and smoke coverage

- Build a real deterministic macOS fixture as object -> linked binary ->
  `dsymutil` with debug information and a matching dSYM, using fixed source and
  the existing allowlisted toolchain. Generate bounded text and `.ips` crash
  fixtures from the observed UUID, exact architecture, image range/base, and a
  known function address so public `atos`/DWARF tooling can prove a symbol and
  source/line result without executing the analyzed artifact.
- Cover successful regular-binary, `.app` main-executable, and `.dSYM`
  provider/pair identity resolution. Cover text Binary Images, plain and
  header-plus-payload `.ips`, decimal image offsets/indexes, duplicate image
  names, UUID normalization, wrong UUID, wrong architecture, subtype mismatch,
  same image name with the wrong artifact, ambiguous distinct providers,
  missing dSYM, missing/invalid load address, overflow, out-of-image-range and
  unresolved address, unsupported layout, and fat32/fat64/swapped-endian or
  malformed LC_UUID inputs. Assert every mismatch cannot return successful
  symbolication and known pre-resolution failures invoke `atos` zero times.
- Add deterministic adaptive tests for quick success without retries, baseline
  not reproduced => `inconclusive`, reproduced baseline plus successful
  candidate => `verified`, decisive post-fix failure => early `failed`,
  conflicting/intermittent results => `inconclusive`, exact per-attempt and
  cumulative monotonic deadlines, escalation transitions, outcome precedence,
  identity-gated reuse, cleanup/fresh-state outcomes, and bounded evidence
  retention. Use a fake monotonic clock and controlled observations; do not use
  random scheduling or sleep-dependent assertions.
- Integrate the adaptive runner into at least one real existing casebook and
  prefer all three host/Simulator casebooks where the change remains small.
  Add a dedicated `make`/harness route for the real crash-symbolication fixture
  because existing smoke commands do not provide this source/line crash
  identity evidence; keep it outside the ordinary `make check` path if it would
  materially slow the quick/default gate.

### Documentation and verification

- Update `ARCHITECTURE.md` with ownership and identity/evaluator contracts;
  update `docs/SECURITY.md` with exact artifact-root, non-execution, and
  fail-closed rules; update `docs/RELIABILITY.md` with baseline, escalation,
  cleanup, and symbolication recovery behavior.
- Update `docs/agent-harness/registry.md`,
  `docs/agent-harness/verification-matrix.md`, and relevant `docs/index.md`
  routes when commands or evidence records change. Keep this plan current with
  review findings, implementation decisions, exact results, and blocked or
  candidate-only evidence.
- Focused checks: symbolication, crash parsing, Mach-O identity, dSYM/DWARF,
  replay/adaptive verification, MCP schema/dispatch if changed, policy,
  cleanup, bounded-output, timeout, truncation, and zero-`atos` rejection
  tests.
- Required checks, even though `make harness-check` invokes overlapping product
  checks internally: `swift build`, `swift test`, `make check`, and
  `make harness-check`. Relevant native checks include `make dwarf-smoke`,
  `make repro-bundle-smoke`, `make replay-smoke`,
  `make complex-debug-casebook`, `make complex-deadlock-casebook`, and the
  dedicated symbolication/crash smoke route. Avoid adding redundant casebook
  invocations beyond the requested commands. Simulator/device checks run only
  with the existing environment and explicit authorization.
- After each live workflow, close owned debugger sessions, terminate only owned
  fixture processes, clean only the selected Simulator/application state, and
  inspect for owned LLDB/lldb-dap/xcodebuild/simctl/fixture/test leftovers.

### Verification record

- `python3 -m unittest discover -s scripts -p 'test_adaptive_verification.py'` — verified locally; 18 deterministic fake-clock adaptive tests passed.
- `swift test --filter 'CrashSymbolicationIdentityTests|AppleSymbolicationTests|CrashReportTests|MachOIdentityTests|AppleArtifactLayoutTests|AppleDWARFTests|AppleBinaryDiffTests|ReplayTests'` — verified locally; 36 focused tests passed, including dSYM-only, changed-provider, bounded-directory, and unresolved-`atos` coverage.
- `swift build` — verified locally; SwiftPM build completed successfully.
- `swift test` — verified locally; 138 XCTest cases passed after the final correction pass.
- `make check` — verified locally; build, 138 Swift tests, 18 adaptive tests, MCP/daemon/session-isolation/debugger fixture/replay/plugin-XPC smokes, whitespace, and placeholder checks passed.
- `make dwarf-smoke` — verified locally; generic Xcode dSYM DIE/source/statistics evidence passed.
- `make replay-smoke` — verified locally; checkpoint/relaunch and non-restoration boundary passed.
- `make complex-debug-casebook` — verified locally; runtime LLDB/MCP diagnosis, policy cleanup, and adaptive quick verification passed.
- `make complex-deadlock-casebook` — verified locally; native sample/MCP deadlock diagnosis, owned-process cleanup, and fixed lock order passed.
- `make symbolication-crash-smoke` — verified locally; object → linked macOS binary → matching dSYM resolved exact identity, symbol, and source line for text and `.ips` reports without executing the fixture.
- `make repro-bundle-smoke` — verified locally; Simulator screenshot/appinfo/manifest evidence passed under the existing explicit mutation gate and selected fixture state was shutdown.
- `make harness-check` — verified locally; the product gate, 138 Swift tests, 18 adaptive tests, smoke suite, and all harness authority/route/coverage/maintenance checks passed.
- Physical-device and release/signing/notarization evidence — not run; no such authority was requested or required for this local change.
- Final main-agent Sol `xhigh` read-only review — verified locally; all valid findings from the two independent plan reviews and the correction loop were incorporated, including `.ips` coordinate modeling, executable/dSYM pairing, exact Mach-O slice identity, bounded `atos`, adaptive state ownership, and cleanup precedence. No unresolved correctness, security, latency, test, or documentation finding remains.

## Validation and Acceptance

The change is accepted only when all applicable items below are evidenced:

- The adaptive transition contract is explicit and tested:

  | Level | Baseline budget | Candidate budget | Per-attempt cap | Cumulative cap | Normal transition |
  | --- | ---: | ---: | ---: | ---: | --- |
  | quick (default) | 1 | 1 | 5 s | 15 s | start here; stop on decisive result |
  | standard | 2 | 2 | 15 s | 60 s | only on typed runtime trigger or explicit policy |
  | strict | 3 | 3 | 30 s | 180 s | only on typed runtime trigger or explicit policy |

  Attempt counts and elapsed time are cumulative across escalation; an
  escalation does not reset the clock or repeat a sufficient phase without a
  reason. The fake-clock tests prove deadlines are enforced while an attempt is
  in progress, not only before it starts.
- The default adaptive level is quick, has explicit attempt and wall-clock
  bounds, performs no unnecessary retries on a decisive success, and records
  level, escalation reason, attempts, outcomes, identities, and representative
  evidence.
- Standard and strict are bounded, are reached only from the documented typed
  runtime triggers (or an explicit caller-selected level), and never retry
  after a decisive post-fix failure. The typed result is exactly one of
  `verified`, `failed`, or `inconclusive`.
- A baseline failure that is not reproduced, stale pre-fix evidence, conflicting
  observations, budget exhaustion, or failed state cleanup cannot produce
  `verified`. A reproduced baseline followed by accepted candidate attempts and
  passing guardrails can produce `verified`; a decisive candidate regression
  produces `failed` with early termination.
- Reused baseline evidence is accepted only when binary/build, environment,
  target, and scenario identities match exactly. Fresh-state success or its
  limitation is visible in the result, and bounded evidence does not duplicate
  full per-attempt artifacts.
- Mach-O UUID and architecture identity is extracted for regular binaries,
  `.app`, and `.dSYM` bundles, including tested thin, fat32, fat64, and
  swapped-endian layouts. UUID commands, slice bounds, table/header CPU
  agreement, CPU subtype, and load-command bounds are validated. Successful
  crash matching proves exact UUID and architecture; name/path-only,
  wrong-UUID, wrong-architecture, ambiguous distinct provider, missing-dSYM,
  unsupported-layout, missing/invalid-load-address, out-of-range, and
  unresolved cases never report successful symbolication.
- The real deterministic fixture proves a matching UUID/architecture and, when
  public Apple tooling exposes it, a real symbol plus source/line result. Every
  returned frame remains represented with typed match/symbolication status and
  original data when unresolved; bounded over-limit results report observed and
  returned counts plus `truncated` and cannot claim complete resolution.
- `AppleDebugCore` remains transport-independent; MCP schemas/dispatch change
  only if required; existing launch, attach, Simulator, device, build,
  mutation, local-only, size, and cleanup policies remain enforced.
- Focused tests, `swift build`, `swift test`, `make check`,
  `make harness-check`, and applicable smoke/casebook commands pass. Missing
  Simulator/device/signing/external evidence is labeled literally as `blocked`,
  `candidate-only`, or `not run`, never substituted with an assumption.
- No branch, commit, push, release, signing, notarization, publication, or
  external issue/write action is performed.

## Idempotence and Recovery

All generated fixtures, crash reports, verification summaries, and representative
artifacts live under `.build` or an explicitly new caller path; existing files
are never overwritten. Re-running a focused test creates a unique temporary
fixture directory or uses a deterministic build directory after removing only
that owned directory through the repository’s existing cleanup path.

Adaptive verification stops on the first decisive failure and records the
partial bounded result. If cleanup or fresh-state setup fails, it stops before
the next attempt and returns `inconclusive` unless a decisive regression already
established `failed`; cleanup state is still reported. Recovery targets only
the process, debugger session, application, or Simulator selected by the run.
A stale checkpoint, repro bundle, crash report, or symbol artifact is not reused
unless all recorded identity fields match. Symbolication never mutates the
supplied artifact and never falls back to a different filesystem artifact after
an identity failure.

Before reporting completion, the implementation agent must close owned LLDB-DAP
and debugger sessions, terminate only owned fixture PIDs, restore any selected
Simulator setting it changed, and verify that no owned LLDB/lldb-dap,
xcodebuild, simctl, fixture, or test process remains. Unavailable device or
external tooling is reported as scoped evidence rather than cleaned by killing
unrelated processes.

## Artifacts and Notes

Expected implementation artifacts after the review corrections:

- `Sources/AppleDebugCore/MachO.swift` and the shared
  `Sources/AppleDebugCore/AppleArtifactLayout.swift` identity/layout service
  used by existing binary-diff and symbolication code.
- `Sources/AppleDebugCore/AppleSymbolication.swift` and
  `Sources/AppleDebugCore/CrashReports.swift` for exact identity matching,
  address validation, Binary Images parsing, and typed statuses.
- A minimal transport-independent adaptive decision model plus the shared
  bounded `scripts/adaptive_verification.py` runner, consumed by the existing
  `scripts/complex_debug_casebook.py` and/or
  `scripts/deadlock_casebook.py` (with the visual casebook added when its
  state-restoration change remains small); do not put generic orchestration in
  `Replay.swift`.
- Focused core/Python tests plus a deterministic fixture/symbolication smoke
  script that builds object -> binary -> dSYM and queries the real Apple tools.
- `Sources/AppleDebugMCP/ToolCatalogSchemas.swift`, dispatch/support, and
  `ToolCatalogTests.swift` only if the public result/input contract must expose
  the new typed statuses.
- `Makefile`, harness registry/matrix, `ARCHITECTURE.md`, `docs/SECURITY.md`,
  `docs/RELIABILITY.md`, `docs/index.md`, and this plan.

Representative evidence includes `.build/evidence/symbolication-crash-smoke.json`
with matching source-line results, focused zero-`atos` identity/address
rejection tests, the quick verified adaptive result in
`.build/evidence/complex-runtime-casebook.json`, and deterministic
inconclusive/failed adaptive results in the fake-clock test suite. Full logs,
traces, screenshots, crash files, and debugger snapshots remain local
artifacts and are not duplicated in the plan or MCP response.

## Interfaces and Dependencies

The core implementation may use only the repository’s existing Foundation,
`AppleProcessRunner`, `ToolchainProbe`, `MachOInspector`, `DWARFService`,
`AppleBinaryDiffService`, `CrashReportAnalyzer`, `SymbolicationService`,
`DebugSessionManager`, replay, repro-bundle, and policy contracts as applicable.
The shared adaptive runner under `scripts/` owns casebook scheduling and calls
the existing named MCP operations; its decision model accepts observations and
cleanup results but cannot execute arbitrary commands or decide ownership. Apple
tools remain fixed and allowlisted; artifact inputs are read-only and bounded.
The MCP layer continues to expose named tools through `ToolCatalog.tools` and
`ToolCatalog.call`, with typed JSON values and no arbitrary command or
filesystem-search interface.

Any API/schema change must state whether it is a derived identity/status field,
an input validation tightening, or a new public operation. The preferred change
is to keep `apple_crash_symbolicate` and `apple_symbolicate`, derive identity
from explicit paths, and return typed per-image/frame data through those tools.
Artifact inputs may describe an image provider and an optional explicit dSYM
provider; matching executable/app plus dSYM is one paired provider, while
multiple distinct providers in one role are ambiguous. `apple_symbolicate` must
share slice/address validation even though it has no crash image to match.
There is no migration or compatibility layer planned; obsolete unsafe fallback
behavior is removed. Existing callers with insufficient identity data receive a
clear fail-closed result or typed error and must supply the correct
artifact/layout.

## Revision History

- 2026-08-27: Created the initial active plan after repository orientation. Captured the existing unsafe crash-artifact fallback, missing Mach-O UUID extraction, replay limits, adaptive verification contract, exact negative coverage, bounded performance targets, security boundaries, and recovery requirements.
- 2026-08-27: Sol `xhigh` review identified the real `.ips` image-index/offset model, executable+dSYM pairing, concrete state-machine/deadline rules, artifact resolver ownership, fat-slice validation, bounded `atos` work, injected test seams, and worktree/verification overlap. Sol `ultra` independently confirmed those findings and added baseline-identity, fresh-state status, standalone symbolication, and casebook-consumer corrections. The revised plan accepts all material corrections, rejects broad symbol-root traversal and extra redundant casebook runs, and keeps both user-required `make check` and `make harness-check`.
- 2026-08-27: Implemented the Core resolver/parser/symbolication contract, adaptive Python runner and runtime casebook integration, deterministic negative/transition tests, real object-to-dSYM crash smoke, MCP `dSYMPath` input, and durable architecture/security/reliability/harness documentation. Focused checks, `swift build`, `swift test`, `make check`, and all proportionate native checks listed in the verification record passed locally; `make harness-check` remains the final gate.
- 2026-08-27: Applied the final bounded corrections: removed crash-artifact `loadAddress`, allowed one exact dSYM-only crash provider using its validated slice/layout, deduplicated exact provider copies by content SHA-256, bounded direct dSYM enumeration and artifact inputs, rejected decorated `???` output, and cached per-batch provider revalidation. The main Sol `xhigh` read-only review then accepted the diff after the focused and full verification gates; no open finding remains.
