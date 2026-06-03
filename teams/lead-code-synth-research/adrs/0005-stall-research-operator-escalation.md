# ADR 0005: Stall Escalates to Research Then Operator

## Status

Accepted

## Context

The intention source said the researcher assists stalled implementation paths, but it did not define when a path is stalled or when the operator should be pulled in. This decision affects timeout handling, message routing, on-tick responsibilities, recovery, and operator-control semantics.

## Question

What stall rule should the generated loop use?

## Decision

After three failed coder attempts on one search direction, the coder or planner should ask the researcher for help. If the research-assisted retry path still fails to produce a promotable candidate, the loop should escalate to the operator for search correction.

## Consequences

- The intention source should define a concrete stall threshold for research requests.
- Future execplan process and communication contracts should include research request, research brief, and operator escalation paths.
- Generated state should track failed attempts per search direction well enough to avoid ambiguous or repeated escalation.
