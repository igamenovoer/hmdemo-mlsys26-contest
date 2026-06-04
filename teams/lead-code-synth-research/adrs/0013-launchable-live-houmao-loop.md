# ADR 0013: Launchable Live Houmao Loop

## Status

Accepted, refined by ADR 0014 and ADR 0015

## Context

The loop could be generated as an offline execplan package, a documentation/spec package, a manual-only package, or a launchable live Houmao loop. The existing intent already depends on six managed agents, isolated workspaces, Houmao mail, generated state, and operator controls.

## Question

Should the first generated loop be executable with live Houmao agents, or only generate an offline execplan package first?

## Decision

The first generated loop should be launchable as a live Houmao loop with managed agents, isolated workspaces, mail/gateway support, and run controls.

## Consequences

- Future execplan material should include agent bindings, workspace contracts, mail schemas, notifier posture, run controls, and launch readiness checks.
- Execution stages should remain separate: `prepare-agents`, `prepare-workspace`, `validate-loop`, `launch-agents`, and `start`.
- Offline docs remain useful support material, but they are not the terminal artifact target.
- Local GPU and retry policies were later clarified by ADR 0014 and ADR 0015.
