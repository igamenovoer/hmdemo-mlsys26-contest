# Paper Notes

Source: `../source/mlsys26-tech-report.pdf`.

## Core Finding

- The report argues that a general-purpose code agent can produce strong GPU kernels when the workflow is structured around correctness gates, isolated experiments, profiling evidence, reusable optimization skills, and human search correction.
- The reported system used an AutoResearch-style team: Planner, parallel CUDA Coders, Synthesizer, Profiler, Researcher, and a human operator.
- The human role was orchestration: define workflow, enforce anti-hacking and correctness constraints, provide references, and redirect stalled search without manually editing kernel code.

## Architecture Pattern

- Planner receives current best code, NCU profile evidence, and prior-run history, then proposes the next optimization directions.
- Multiple CUDA Coders pursue separate directions in isolated GPU environments.
- Profiler generates NCU reports and bottleneck attribution for specific kernels or workloads.
- Researcher retrieves references and optimization patterns after repeated failures or plateaus.
- Synthesizer reviews Coder outputs, identifies effective changes, and merges or selects the strongest candidate.
- Evaluator behavior is implicit in the paper's protocol: correctness and benchmark validity determine whether a candidate can become the new best solution.

## Process Lessons

- The optimization loop should treat hypothesis, implementation, profiling, benchmark evidence, and revision as separate phases.
- The editable surface must be deliberately restricted so agents improve kernels rather than changing the evaluation setup.
- Candidate changes must pass all correctness checks before performance claims matter.
- After repeated failures in one direction, agents should seek Researcher input or Planner redirection rather than continuing local tweaks.
- Human intervention is most useful when agents plateau, misattribute a failure, revert a good change after an unrelated bug, miss an external reference, or need a more disruptive optimization direction.

## Guardrail Lessons

- Benchmark exploitation is a real risk when agents can inspect the harness.
- The paper specifically warns against speedups from input-identity caching, cross-iteration buffer reuse, and sample-specific shortcuts.
- Any legitimate cache must report cold-path and warm-path performance separately.
- The loop should preserve enough evidence for each accepted speedup to distinguish real kernel improvement from harness exploitation.

## Kernel Optimization Themes

- Fused MoE gains came from keeping metadata construction on GPU, removing hot-path synchronization, compiling multiple GEMM backends, and optimizing routing, gather, quantization, GEMM, activation, and scatter stages.
- For the active Fused MoE definition, remaining long-sequence headroom appears tied to reducing inter-stage data movement, especially around `pull_scatter` and the GEMM2 epilogue.
- DSA Sparse Attention gains came from adaptive Split-K, cp.async pipelining, register-resident accumulators, BF16 partial outputs, branchless online softmax, and merge parallelism.
- DSA TopK gains came from fast-path index remapping when sequence length is at most TopK, fused score computation, bank-conflict-free shared memory layouts, radix TopK, and on-device dispatch.

## Implications For Houmao

- Houmao mail should carry structured handoffs: plan assignments, implementation results, profiler requests, profiler reports, research requests, research summaries, synthesis decisions, evaluation results, and operator interventions.
- The generated loop should use prompt-triggered bounded turns rather than agents waiting inside chat turns.
- Loop state should record current best candidate, run history, failed directions, accepted evidence, rejected hacks, profiler artifacts, and open hypotheses.
- Operator controls should include pause, resume, stop, redirect search, mark a result invalid, request independent review, and force a new planning cycle.
