## 1. Baseline Mode Hygiene

- [x] 1.1 Add explicit `moe-base` GEMM mode constants or guards so naive, debug-cache, and real-compute paths are distinguishable in source.
- [x] 1.2 Disable final-output cache replay for the default official validation path while preserving any cache or naive comparison helper as an explicit development mode.
- [x] 1.3 Update `docs/contest/moe-base.md` to describe the default mode and any development-only comparison modes.

## 2. CUTLASS Layout Reconnaissance

- [x] 2.1 Add source comments or helper functions documenting GEMM1 mapping from contest tensors to CUTLASS operand and scale layouts.
- [x] 2.2 Add source comments or helper functions documenting GEMM2 mapping from contest tensors to CUTLASS operand and scale layouts.
- [x] 2.3 Compile the CUDA solution with the selected CUTLASS headers included through the existing pack path.

## 3. Real-Compute GEMM Bridge

- [ ] 3.1 Implement a minimal `sm_100a` real-compute GEMM1 bridge for compact local rows, using CUTLASS directly if feasible or an `sm_100a` CUTLASS-bridged dequantized path if native block-scale layout is blocked.
- [ ] 3.2 Validate GEMM1 bridge output against the naive GEMM1 path on at least one small local workload.
- [ ] 3.3 Implement a minimal `sm_100a` real-compute GEMM2 bridge for compact local rows, using CUTLASS directly if feasible or an `sm_100a` CUTLASS-bridged dequantized path if native block-scale layout is blocked.
- [ ] 3.4 Validate final output against the official low-bit correctness thresholds with cache replay disabled.

## 4. Official Validation

- [ ] 4.1 Run `pixi run pack` and a CUDA 13 TVM-FFI compile/build check.
- [ ] 4.2 Run the official local MoE evaluation command on an idle GPU only, without relying on final-output cache replay.
- [ ] 4.3 Record the validation commands, result summary, and remaining limitations in `docs/contest/moe-base.md`.
- [ ] 4.4 Run `pixi run test`, `pixi run lint`, `pixi run typecheck`, and `openspec validate implement-moe-base-cutlass-gemm`.
