# Constraints

## Correctness

- Correctness gates precede performance claims.
- Numerical mismatches, crashes, timeouts, invalid outputs, or missing required outputs reject a candidate.
- Benchmark results must name the command, workload scope, candidate id, and relevant environment assumptions.
- First-loop workload scope is active Fused MoE only.
- Promotion to the new best candidate requires project `official-timing`; local checks are exploratory evidence.

## Anti-Hacking

- Agents must not change benchmark harnesses, datasets, reference implementations, or config semantics to improve reported speed.
- Agents must not exploit stable input tensor identities, cross-iteration reuse, sample-specific shortcuts, hidden global state, or precomputed answers.
- Agents must not optimize only for known benchmark samples in a way that would fail the same semantic operator on valid unseen inputs.
- Any deployable cache must report cold-path and warm-path performance separately and explain why the cache is valid outside the harness.

## Edit Surface

- Normal Coder edits are limited to candidate solution or variant source files chosen by the execplan.
- First-loop Coder prompts should not assign DSA TopK or DSA Sparse Attention implementation work.
- Project workflow, benchmark, docs, or config edits require explicit operator approval and should be separate from kernel candidate edits.
- `solution.json`, `.pixi/`, `tmp/`, and ignored external checkouts must not become committed loop outputs.

## Human Role

- The Human Operator may define workflow, supply references, approve constraints, redirect search, invalidate results, and manually stop the loop.
- The Human Operator should not manually write, edit, or hand-tune kernel code for normal candidates if the run is intended to measure agentic kernel generation.

## Evidence

- Accepted candidates need reproducible evidence: `official-timing` command provenance, correctness status, timing summary, changed files, candidate id, and comparison to the previous best.
- Profiler claims need enough context to act on: workload or regime, tool used, dominant kernels, suspected bottleneck, and recommended optimization implication.
- Rejected candidates should still preserve useful findings when they reveal a failed idea, fragile assumption, or partial optimization.

## Resource And Safety Posture

- GPU and dataset dependent checks must run only through explicit benchmark or profiling stages.
- Long-running or expensive benchmark campaigns need operator-visible budget controls.
- Agents should escalate when repeated failures show the current direction is exhausted, the benchmark appears exploitable, or workspace state becomes inconsistent.
- Agents should not treat promotion, budget exhaustion, or plateau detection as automatic successful completion.
