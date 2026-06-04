# Participants

## Managed Agent Roster

- Planner.
- CUDA Coder 1.
- CUDA Coder 2.
- Synthesizer.
- Researcher.
- Evaluator.
- Profiler is not a managed agent; profiling is a generated tool/skill surface.

## Human Operator

- Owns workflow intent, budget, escalation choices, terminal acceptance, and anti-hacking policy.
- Redirects search when agents plateau, misattribute failures, or miss important references.
- Avoids writing or hand-tuning kernel code for normal agent-submitted candidates so the system can test agentic optimization.

## Planner

- Inputs: current best candidate, run history, failed attempts, profiler reports, Researcher notes, Evaluator results, and operator constraints.
- Outputs: one or more optimization assignments with target workload regime, hypothesis, allowed edit surface, expected evidence, and stop conditions.
- Should propose more disruptive directions after plateau evidence instead of staying with small local tweaks.
- Owns writes to current-best candidate state after accepted Evaluator promotion evidence.

## CUDA Coder Pool

- First-loop pool size: two parallel CUDA Coders.
- Both Coders use the same role profile; they differ by workspace and Planner-assigned optimization direction.
- Inputs: one Planner assignment, allowed workspace, current best source, relevant skills or references, and benchmark commands.
- Outputs: candidate implementation, correctness status, timing summary, changed-file summary, failure analysis, and recommended next step.
- Each assignment is one bounded attempt: implement one direction, run local checks if available, report evidence, then stop.
- Must work in isolated workspaces and must not edit the benchmark harness, datasets, reference code, or contest config semantics.

## Synthesizer

- Inputs: Coder results, profiler evidence, rejected attempts, and current best candidate.
- Outputs: selected or merged candidate, rationale, conflict notes, suspected regressions, and next Planner context.
- Should preserve useful partial ideas even when a full candidate fails.
- May select or merge Coder outputs into a promotion candidate, but cannot promote it.

## Profiler Tool Surface

- Inputs: candidate id, workload or workload regime, profiling question, and command context from a managed agent.
- Outputs: bottleneck attribution, kernel timing summary, relevant NCU metrics, and optimization implications as tool output or artifacts.
- Should focus on evidence that changes the next decision, such as whether a bottleneck is launch overhead, memory movement, occupancy, bank conflicts, register pressure, or GEMM throughput.
- Should not require a separate Profiler mailbox or live managed-agent session.

## Researcher

- Inputs: concrete research question, failure pattern, target kernel family, and allowed source scope.
- Outputs: summarized patterns, candidate implementation ideas, source links or local references, and risk notes.
- Should be invoked after repeated failures, missing reference knowledge, or a Planner request for larger directional options.
- Uses parallel local-and-network search by default; network search does not require per-request operator approval.

## Gatekeeper Or Evaluator

- Inputs: candidate workspace, changed files, commands to run, timing evidence, and anti-hacking checklist.
- Outputs: accepted or rejected evaluation result, correctness evidence, speedup evidence, invalidation reason, reproducibility notes, and promotion evidence for Planner.
- Must reject candidates that pass by exploiting harness behavior rather than improving deployable kernel behavior.
- Alone validates promotion eligibility after `official-timing`, but does not write current-best state.
