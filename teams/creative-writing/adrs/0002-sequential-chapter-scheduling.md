# ADR 0002: Sequential Chapter Scheduling

## Status

Accepted

## Context

The loop needs a chapter scheduling rule so generated process, state, dedupe, and completion contracts can decide which work item is active and when the next chapter may start.

## Question

How should chapters be scheduled?

## Decision

The loop first completes the table of contents, then advances one chapter package at a time. After a chapter package is ready for operator review and accepted or explicitly deferred, the lead writer advances to the next chapter.

## Consequences

- Future execplan artifacts should model one normal active chapter package at a time.
- The lead writer owns chapter ordering and next-chapter selection after the table of contents is accepted.
- Parallel chapter drafting is out of scope for normal loop execution unless the operator later overrides this decision.
