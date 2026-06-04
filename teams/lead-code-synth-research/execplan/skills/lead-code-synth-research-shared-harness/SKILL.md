---
name: lead-code-synth-research-shared-harness
description: Use when any generated lead-code-synth-research participant must query contracts, validate or render mail, inspect state, or apply loop-local records through the generated harness.
---

# Lead Code Synth Research Shared Harness

## Trigger

- A generated loop skill needs contract lookup, topology or context validation, mail schema lookup, mail validation, mail rendering, state query, record apply, control status, or manual context for `lead-code-synth-research`.

## Inputs

- Loop dir: `teams/lead-code-synth-research`.
- Harness command: `teams/lead-code-synth-research/execplan/harness/bin/lead-code-synth-research-harness`.
- Contracts: `execplan/specs/`.
- Manifest: `execplan/manifest.toml`.

## Procedure

1. Use the harness for generated loop facts instead of raw SQL or ad hoc parsing when a harness command exists.
2. For mail, use `email schema`, `email validate`, and `email render`; use `email apply` only for bookkeeping and never for mailbox delivery.
3. For state, use `state query`, `state validate`, `record validate`, and `record apply`; direct state edits are operator repair only and require later validation.
4. For routing, use `topology query` and `context query` when the next action depends on route or predecessor-context posture.
5. For mode and lifecycle, use `control status`, `control get-mode`, and `control manual-context` before bounded tick work.
6. Route platform mechanics to maintained Houmao skills: mail to `houmao-agent-email-comms`, gateway and notifier posture to `houmao-agent-gateway`, prompts to `houmao-agent-messaging`, workspaces to `houmao-utils-workspace-mgr`, and agent lifecycle to `houmao-agent-instance`.

## Output

- Machine-readable harness output, rendered mail text, validated record status, state query result, or a no-action report.

## Stop

- End the turn after the bounded harness-backed action or after reporting that required contract, state, or payload evidence is missing.
