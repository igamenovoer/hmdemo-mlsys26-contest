# Loop Overview: lead-code-synth-research

## Objective

Optimize the MLSys26 FlashInfer contest Fused MoE CUDA kernel through a correctness-first multi-agent workflow modeled on `../source/mlsys26-tech-report.pdf` and summarized in `../idea.md`. The loop should generate, debug, profile, research, and synthesize Fused MoE kernel improvements while keeping the human operator in an orchestration role rather than a kernel-coding role. The objective is open-ended speedup maximization until the operator stops the run, a run budget is exhausted, or the team records a concrete blocker.

## Participants

- `planner`: Owns the active objective, current best kernel, profile summaries, run history, and next search direction.
- `coder-1`, `coder-2`, and `coder-3`: Each coder implements one planner-approved CUDA optimization task in an isolated workspace and reports correctness, timing, failures, and code changes.
- `synthesizer`: Reviews coder outputs, rejects invalid or under-evidenced candidates, promotes faster correct candidates to `current-best`, and reports the updated solution state.
- `profiler`: Produces NCU and benchmark-derived bottleneck reports for selected kernels and workloads.
- `researcher`: Retrieves external references and summarizes reusable optimization patterns when the team stalls or needs examples.
- `operator`: External human authority that supplies goals, constraints, references, and search-correction prompts without editing kernel code.

## Operating Model

Use a `generic-loop` topology. Work enters through an operator-selected Fused MoE workload scope, allowed edit surface, correctness command, timing command, and anti-hacking constraints. The planner assigns bounded tasks to coders, coders test candidate implementations, the synthesizer promotes a candidate to `current-best` only when it passes correctness checks, supplies complete evidence, and improves timing over the previous `current-best`. Promotion updates the best known solution but does not terminate the loop. The profiler supplies bottleneck evidence when needed, and the researcher assists stalled implementation paths with references or patch ideas. The loop finishes when the operator stops it, a run budget is exhausted, or the team records a concrete blocker for Fused MoE.

Normal message families should include task assignment, candidate result, profile request, profile report, research request, research brief, synthesis report, search correction, and terminal report.

After three failed coder attempts on one search direction, the coder or planner should request a research brief. If research-assisted retries still fail to produce a promotable candidate, the loop should escalate to the operator for search correction. Generated state should track failed attempts per search direction.

The loop should support both auto and manual runtime modes. Auto mode is the default and uses managed Houmao mail notifier wakeups as the normal participant wakeup path. Manual mode is a fallback in which the operator prompts one bounded participant turn at a time. Participant turns must finish after one bounded pass and must not sleep, poll, or wait in-chat for future work.

## Workspace Expectations

- Give `coder-1`, `coder-2`, and `coder-3` separate workspaces so candidate implementations do not overwrite each other.
- Keep benchmark harnesses, datasets, configurations, and reference implementations fixed.
- Restrict coder edits to the intended CUDA kernel implementation surface for the active task.
- Keep `operator` as runtime authority, not as a normal coding agent.
- Bind concrete Houmao agents later under `execplan/agents/`; this intention source should not create live agents or workspaces.

## Constraints

- Correctness gates acceptance. Numerical errors, runtime failures, and timeouts invalidate a candidate result.
- Disallow input-identity caching, cross-iteration buffer reuse, dataset-specific shortcuts, benchmark-harness changes, and other non-deployable speedup mechanisms.
- If a legitimate cache is proposed, report cold-path and warm-path performance separately.
- Every accepted speedup must name the benchmark command, workload scope, correctness result, and baseline comparator.
- Do not treat reproducing the report result, beating a baseline, or reaching a fixed no-promotion threshold as an automatic terminal condition unless the operator supplies that stop rule for a run.
- The synthesizer is the normal promotion authority for faster correct candidate results; the operator controls terminal stop, override, repair, and search-correction decisions.
- After three failed coder attempts on one search direction, request researcher help; if research-assisted retries still fail, escalate to the operator.
- Treat profiler and researcher outputs as evidence for search decisions, not as automatic authority to change code.

## Open Questions

- Exact benchmark and profiling commands remain to be bound during execplan generation or operator run setup.
