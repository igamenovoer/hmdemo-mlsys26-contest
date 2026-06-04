# Participants

## Human Operator

- Owns workflow intent, budget, escalation choices, terminal acceptance, and anti-hacking policy.
- Redirects search when agents plateau, misattribute failures, or miss important references.
- Avoids writing or hand-tuning kernel code for normal agent-submitted candidates so the system can test agentic optimization.

## Planner

- Inputs: current best candidate, run history, failed attempts, profiler reports, Researcher notes, Evaluator results, and operator constraints.
- Outputs: one or more optimization assignments with target workload regime, hypothesis, allowed edit surface, expected evidence, and stop conditions.
- Should propose more disruptive directions after plateau evidence instead of staying with small local tweaks.

## CUDA Coder Pool

- Inputs: one Planner assignment, allowed workspace, current best source, relevant skills or references, and benchmark commands.
- Outputs: candidate implementation, correctness status, timing summary, changed-file summary, failure analysis, and recommended next step.
- Must work in isolated workspaces and must not edit the benchmark harness, datasets, reference code, or contest config semantics.

## Synthesizer

- Inputs: Coder results, profiler evidence, rejected attempts, and current best candidate.
- Outputs: selected or merged candidate, rationale, conflict notes, suspected regressions, and next Planner context.
- Should preserve useful partial ideas even when a full candidate fails.

## Profiler

- Inputs: candidate id, workload or workload regime, profiling question, and command context.
- Outputs: bottleneck attribution, kernel timing summary, relevant NCU metrics, and optimization implications.
- Should focus on evidence that changes the next decision, such as whether a bottleneck is launch overhead, memory movement, occupancy, bank conflicts, register pressure, or GEMM throughput.

## Researcher

- Inputs: concrete research question, failure pattern, target kernel family, and allowed source scope.
- Outputs: summarized patterns, candidate implementation ideas, source links or local references, and risk notes.
- Should be invoked after repeated failures, missing reference knowledge, or a Planner request for larger directional options.

## Gatekeeper Or Evaluator

- Inputs: candidate workspace, changed files, commands to run, timing evidence, and anti-hacking checklist.
- Outputs: accepted or rejected result, correctness evidence, speedup evidence, invalidation reason, and reproducibility notes.
- Must reject candidates that pass by exploiting harness behavior rather than improving deployable kernel behavior.
