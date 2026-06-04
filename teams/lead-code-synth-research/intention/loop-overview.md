# Loop Overview: lead-code-synth-research

## Objective

- Implement a Houmao-managed multi-agent CUDA kernel optimization system modeled on the workflow described in `../source/mlsys26-tech-report.pdf`.
- The system should coordinate agents that plan, implement, profile, research, synthesize, and validate CUDA kernel improvements for this MLSys 2026 FlashInfer contest repository.
- The core goal is to reproduce the paper's disciplined correctness-first search process in Houmao: agents write and optimize kernels, while the human operator defines constraints, monitors progress, redirects stalled search, and approves major workflow decisions.

## Participants

- Human Operator: defines goals and constraints, approves terminal results, redirects stalled or unsafe search, and does not hand-tune kernel code as part of the normal loop.
- Planner: reads the current best kernel, benchmark history, profiler reports, failed attempts, and operator constraints, then proposes the next optimization directions.
- CUDA Coder pool: multiple isolated implementation agents that each pursue one assigned optimization direction in a separate workspace.
- Synthesizer: compares Coder outputs, extracts useful changes, merges or selects the strongest candidate, and reports the updated best solution.
- Profiler: runs or requests NCU/timing analysis and turns raw measurements into bottleneck-focused reports.
- Researcher: searches local references and, when permitted, external references for implementation ideas after repeated failures or plateaus.
- Gatekeeper or Evaluator: runs correctness and benchmark gates, detects invalid speedups, records evidence, and rejects changes that alter harnesses, datasets, configs, or reference behavior.

## Operating Model

- Preferred topology: `generic-loop`, because results move through a directed cycle with parallel Coder branches and explicit returns to Planner, Synthesizer, Evaluator, Profiler, and Researcher.
- Work begins from a current best variant, known workload definition, benchmark protocol, allowed edit surface, and current run history.
- Each cycle starts when the Planner issues one or more optimization hypotheses with expected evidence and risk notes.
- CUDA Coders implement in isolated workspaces, run the required correctness checks, benchmark their candidates, and send structured result summaries with changed files, metrics, failures, and next-step recommendations.
- The Profiler supports specific candidates or representative workloads with timing and bottleneck evidence, especially when the next optimization depends on attribution rather than guesswork.
- The Researcher is invoked when several attempts fail, when the Planner asks for external patterns, or when a Coder needs reference-backed implementation options.
- The Synthesizer chooses, merges, or rejects candidate changes, then hands an updated best candidate and rationale to the Evaluator and Planner.
- The Evaluator accepts a candidate only after correctness passes and benchmark evidence supports a real speedup under the fixed contest harness.
- The loop repeats until the operator accepts the final result, the budget expires, or the system records that progress is blocked and needs human redirection.

## Workspace Expectations

- Each Coder should use an isolated workspace or branch so parallel experiments cannot overwrite each other.
- The live solution surfaces are `solution/cuda/kernel.cu`, `solution/cuda/binding.py`, `solution/triton/kernel.py`, `config.toml`, and variant material managed by `project-cli`.
- The benchmark harness, dataset, reference implementation, contest config semantics, and evaluator scripts must remain fixed unless the operator explicitly starts a separate project change.
- Generated run evidence should be stored under this loop's future `runs/` area or another explicit execplan path, not mixed into source directories.
- Candidate results should preserve enough evidence to reproduce the decision: variant id or workspace path, commands run, correctness status, timing summary, relevant profiler report, and changed-file summary.

## Constraints

- Correctness is the first gate. Any numerical mismatch, runtime failure, timeout, or invalid harness modification rejects the candidate.
- Anti-hacking rules are mandatory. Agents must not use input-identity caches, cross-iteration sample reuse, dataset-specific shortcuts, benchmark harness edits, reference edits, or config changes that make measured speedups non-deployable.
- Humans normally orchestrate the search and do not write, edit, or hand-tune kernel code for agent-submitted candidates.
- Candidate speedups must distinguish cold-path and warm-path behavior when a legitimate deployable cache is involved.
- Agents should seek major direction changes after plateaus instead of only making incremental tweaks.
- GPU or dataset dependent checks must stay outside default unit tests and run only through explicit benchmark or profiling commands.
- `execplan/` remains generated operational material and should not be created during this intent authoring step.

## Open Questions

- How many CUDA Coders should run in parallel for the first Houmao implementation, and what resource budget should each receive?
- Should the first implementation target only the active Fused MoE definition, or should the loop be general enough for DSA TopK and DSA Sparse Attention later?
- Which benchmark command is the first acceptance gate: local `pixi run bench`, Modal `pixi run modal-bench`, the project `official-timing` skill, or a staged combination?
- Should the Researcher be allowed to use network search during automated runs, or only local repo and source material unless the operator approves escalation?
- What terminal success condition should stop the loop: best validated speedup, a fixed number of cycles, budget exhaustion, or operator acceptance after review?
