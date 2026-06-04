# ADR 0001: Book Draft Success Condition

## Status

Accepted

## Context

The loop needs a terminal success condition so generated process, state, artifact, validation, and operator-acceptance contracts can decide when the loop is done.

## Question

What success condition should the loop reach?

## Decision

The loop succeeds when it completes a full first Chinese book draft package: table of contents, all chapter drafts, source index, technical review records, and unresolved-risk list.

## Consequences

- `loop-overview.md` records whole-book first-draft completion as the terminal condition.
- Future execplan artifacts should model chapter packages as intermediate work and the full first-draft package as the loop terminal artifact.
- The operator remains the acceptance authority for the completed book draft package.
