# State Overview

Generated state is durable control-plane bookkeeping, not working memory. It stores compact ids, refs, statuses, ownership, scalar decisions, evidence links, and transition audit. Full analysis, rationale, rendered mail, source material, benchmark logs, and profiler output stay in mail, role-local workspaces, or run artifacts.

The selected generated state backend is sqlite because the loop has stable entity families, repeated cycles, active ownership, retry counters, and queryable slot status. Harness generation must expose initialization, read-only query, invariant validation, record validation, and controlled record-application surfaces without owning mailbox delivery or platform lifecycle.

Core entity families are control state, participants, planning cycles, assignments, attempts, candidates, evidence refs, artifacts, mail payload lifecycle, research summaries, profile reports, synthesis reports, evaluation reports, retry records, operator intent events, and current-best history.

Planner owns planning cycles, assignment creation, synthesis context records, and current-best writes after accepted Evaluator evidence. Coders own bounded-attempt and candidate evidence for their assignments. Synthesizer owns synthesis reports, candidate lineage, and preserved ideas. Researcher owns research summaries and source-scope notes. Evaluator owns evaluation evidence and promotion recommendations. Runtime or the responsible agent records waiting-for-GPU and retry state according to failure policy.

Scheduling queries must support: next Planner work, Coder slot status by cycle, Synthesizer readiness with partial results, waiting-for-GPU records due for retry after wakeup, non-GPU retry records below the limit, failed assignments after three retries, pending synthesis reports for Evaluator and Planner, pending evaluation reports for Planner, pause or manual-mode posture, and operator stop state.

State must not store full source diffs, full benchmark logs, downloaded network pages, full profiler traces, hidden mailbox content, API credentials, or mutable platform lifecycle state owned by maintained Houmao skills.
