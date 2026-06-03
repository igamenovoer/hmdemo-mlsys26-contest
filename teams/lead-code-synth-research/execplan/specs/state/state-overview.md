# State Overview

## Authority

Loop state stores compact control-plane facts for scheduling, recovery, validation, promotion, and operator control. Full mail bodies, rendered Markdown, long rationale, detailed profiles, and code diffs belong in mail or run artifacts, with only refs stored in state.

## Backend

Use SQLite by default. `schema.sql` is the field-level authority.

## Entity Families

- runs, participants, work items, attempts, evidence refs, current-best refs, search directions, mail payload lifecycle, operator intent events, and generic events.
- Generic-loop lineage is stored through message refs, work-item ids, search-direction ids, and attempt indexes.

## Invariants

- `execution_mode` is distinct from `run_state`.
- Initial execution mode is `auto` unless operator control changes it.
- `manual` does not imply `paused`.
- A candidate can be promoted only by the synthesizer after correctness, evidence, and timing gates pass.
- Three failed attempts on one search direction are enough to request researcher help.
- Research-assisted failure escalates to the operator.

## Scheduling Queries

Generated tick skills and operator-control surfaces may query active work by participant, pending mail payload, run state, execution mode, unresolved work item, failed attempt count, and operator intent event.
