# Loop Overview: lead-code-synth-research

## Objective

- Implement a Houmao-managed multi-agent CUDA kernel optimization system modeled on the workflow described in `../source/mlsys26-tech-report.pdf`.
- The first implementation should coordinate agents that plan, implement, profile, research, synthesize, and validate CUDA kernel improvements for the active Fused MoE definition in this MLSys 2026 FlashInfer contest repository.
- The core goal is to reproduce the paper's disciplined correctness-first search process in Houmao: agents write and optimize kernels, while the human operator defines constraints, monitors progress, redirects stalled search, and approves major workflow decisions.
- First-scope target: `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`.

## Participants

- Human Operator: defines goals and constraints, controls terminal stop, redirects stalled or unsafe search, and does not hand-tune kernel code as part of the normal loop.
- Planner: reads and owns current-best candidate state, benchmark history, profiler reports, failed attempts, and operator constraints, then proposes the next optimization directions.
- CUDA Coder pool: two isolated implementation agents with the same role profile; each pursues one assigned optimization direction in a separate workspace.
- Synthesizer: compares Coder outputs, extracts useful changes, selects or merges a promotion candidate, and reports candidate lineage and rationale.
- Profiler tool surface: generated harness commands or skills for NCU/timing analysis and bottleneck-focused reports; not a managed agent.
- Researcher: searches local references and network sources concurrently by default.
- Gatekeeper or Evaluator: runs correctness and benchmark gates, detects invalid speedups, records promotion evidence for Planner, and rejects changes that alter harnesses, datasets, configs, or reference behavior.

## Operating Model

- Runtime posture: launchable live Houmao loop with managed agents, isolated workspaces, mail/gateway support, generated state, run controls, launch readiness checks, and local spare-GPU selection for exploratory checks.
- Preferred topology: `generic-loop`, because results move through a directed cycle with parallel Coder branches and explicit returns to Planner, Synthesizer, Evaluator, and Researcher; profiler evidence is attached as generated tool output.
- Work begins from a current best variant, known workload definition, benchmark protocol, allowed edit surface, and current run history.
- Each cycle starts when the Planner issues up to two optimization hypotheses with expected evidence and risk notes.
- The two CUDA Coders each perform one bounded attempt per assignment: implement one direction, run local checks on a spare local GPU when available, report evidence, then stop or enter waiting-for-GPU state if GPU capacity is unavailable.
- The Profiler tool surface supports specific candidates or representative workloads with timing and bottleneck evidence, especially when the next optimization depends on attribution rather than guesswork.
- The Researcher is invoked when several attempts fail, when the Planner asks for external patterns, or when a Coder needs reference-backed implementation options; its default source policy is parallel local-and-network search.
- The Synthesizer chooses, merges, or rejects candidate changes, then hands a promotion candidate and rationale to the Evaluator and Planner.
- The Evaluator validates promotion eligibility only after the project `official-timing` path confirms correctness and speedup under the fixed contest harness; Planner writes the current-best state from accepted Evaluator evidence.
- The loop repeats until the Human Operator manually stops it; promotion, budget pressure, and blocked-search reports do not automatically complete the loop.

## Workspace Expectations

- Each of the six managed agents should use an isolated workspace.
- The two Coder workspaces are the normal edit surfaces for candidate kernel or variant source.
- Planner, Synthesizer, Researcher, and Evaluator should coordinate through Houmao mail, generated state, run artifacts, and explicit evidence refs rather than shared filesystem writes.
- The live solution surfaces are `solution/cuda/kernel.cu`, `solution/cuda/binding.py`, `solution/triton/kernel.py`, `config.toml`, and variant material managed by `project-cli`.
- The benchmark harness, dataset, reference implementation, contest config semantics, and evaluator scripts must remain fixed unless the operator explicitly starts a separate project change.
- Generated run evidence should be stored under this loop's future `runs/` area or another explicit execplan path, not mixed into source directories.
- Candidate results should preserve enough evidence to reproduce the decision: variant id or workspace path, commands run, correctness status, timing summary, relevant profiler report, and changed-file summary.

## Constraints

- Correctness is the first gate. Any numerical mismatch, runtime failure, timeout, or invalid harness modification rejects the candidate.
- The first loop is Fused MoE only; DSA TopK and DSA Sparse Attention are out of scope for this implementation unless the operator starts a later extension.
- Anti-hacking rules are mandatory. Agents must not use input-identity caches, cross-iteration sample reuse, dataset-specific shortcuts, benchmark harness edits, reference edits, or config changes that make measured speedups non-deployable.
- Humans normally orchestrate the search and do not write, edit, or hand-tune kernel code for agent-submitted candidates.
- Candidate speedups must distinguish cold-path and warm-path behavior when a legitimate deployable cache is involved.
- Coder exploration may use local checks, but promotion to the new best Fused MoE candidate requires `official-timing`.
- Planner updates current-best state from accepted Evaluator promotion evidence, and that update does not stop the loop.
- Agents should seek major direction changes after plateaus instead of only making incremental tweaks.
- GPU or dataset dependent checks must stay outside default unit tests and run only through explicit benchmark or profiling commands.
- `execplan/` remains generated operational material and should not be created during this intent authoring step.

## Open Questions

- Exact generated schema and harness command shapes belong to execplan generation.
