# Harness-Ready Certification

The harness-ready claim is repository-local and bounded to one source commit, one direct-child attestation commit, one local evaluation target, and one fresh evidence window. It is not a product release, device authorization, notarization, deployment, or production claim.

## Convergence owner and command

- Owner: Apple Debug MCP maintainers
- Project-native gate: ./scripts/harness_check.sh
- Authorized safe repair: update repository-local docs, scripts, tests, and evidence after a named finding; rerun the gate
- Evidence issuer: the maintainer or agent that ran the named commands
- Evidence key custody: an owner-only local key file outside the repository; never commit the key
- Optional production verifier: N/A; this repository has no production deployment action
- Escalation boundary: secrets, physical-device authorization, signing, release, external writes, destructive operations, and product scope changes require explicit human direction

## Source and attestation commits

The first complete implementation and harness checkpoint is source commit S. A direct-child attestation commit A may update only the coverage matrix, certification manifest, and referenced HMAC evidence records. A must not contain implementation changes. Any later commit invalidates the bounded certification.

## Revalidation and invalidation

Run make harness-check manually at task completion and after changes to commands, architecture, coverage, plans, security boundaries, or evidence. Refresh records and the manifest for a new source/attestation pair. Keep the claim invalid when a required check, record, identity, coverage digest, or freshness window changes.

## Evidence rules

Evidence records are exact-schema v2 JSON files under docs/agent-harness/evidence/. Each verified or justified N/A coverage row links to one fresh HMAC-consistent record bound to the source commit, repository identity, and apple-debug-mcp-local evaluation target. The HMAC checks local consistency; it does not authenticate an external provider or human approval.

## Production-authority applicability

The production-authority coverage row is N/A because this repository is a local CLI and has no deployment action. The certification manifest keeps the required production_authority object with null values.

## Optional production attestation

Do not request --require-production-attestation for this repository unless a provider-backed production target and independent authority are explicitly added. Local tests cannot establish that evidence.
