## Context

The C++ NVBench profiler currently exposes `--iterations` as a compatibility option and forwards it to NVBench as both `--min-samples` and `--target-samples` while forcing `--stopping-criterion sample-count`. This is convenient for fixed-length sweeps, but it prevents users from using NVBench's default convergence model, where measurements continue until relative standard deviation drops below a configured threshold. NVBench's documented controls include `--stopping-criterion`, `--min-samples`, `--target-samples`, `--min-time`, and `--max-noise`.

The profiler should remain independent of FlashInfer-Bench and should not add correctness semantics. These options affect only the runtime runner invocation and must not enter artifact build identity.

## Goals / Non-Goals

**Goals:**
- Expose NVBench stopping criterion selection through `hm-nvbench-profile run`.
- Expose fixed sample count and variance-convergence controls with stable profiler option names.
- Preserve existing `--iterations` behavior for users who want fixed sample-count timing.
- Keep timing controls as runtime-only inputs that do not trigger artifact rebuilds.
- Add tests and docs for CLI-to-NVBench argument mapping.

**Non-Goals:**
- Do not change FlashInfer-Bench, `pixi run bench`, Modal benchmark, packing, or project variant behavior.
- Do not add correctness checking, reference computation, or speedup comparison.
- Do not rework artifact generation or workload materialization beyond forwarding runtime options.
- Do not require a GPU-capable test for basic CLI mapping coverage.

## Decisions

1. Preserve `sample-count` as the profiler default. The current profiler behavior is deterministic and fast for local kernel iteration, so default runs should continue to map `--iterations N` to NVBench `--min-samples N --target-samples N --stopping-criterion sample-count`.

2. Add explicit convergence controls instead of a raw passthrough string. The CLI should add `--stopping-criterion`, `--min-samples`, `--target-samples`, `--min-time`, and `--max-noise`. These names match NVBench where practical and are easy to document. A raw `--nvbench-arg` escape hatch is intentionally out of scope for now because it would make validation and help text weaker.

3. Make variance options select or require `stdrel`. If a user passes `--max-noise` or `--min-time` without an explicit criterion, the profiler should use `stdrel` because those options are NVBench `stdrel` parameters. If the user explicitly combines those options with an incompatible criterion, the profiler should fail with a clear message rather than launching NVBench with ignored or confusing parameters.

4. Treat `--iterations` as a compatibility alias. `--iterations` should remain accepted and continue to set sample-count behavior. New explicit sample options should be available as `--min-samples` and `--target-samples`; when they conflict with `--iterations`, the explicit sample options should win or the command should reject the ambiguous combination. The implementation should choose one consistent behavior and document it.

5. Keep artifact identity unchanged. Stopping criterion, sample counts, max noise, min time, timeout, device, random seed, workload selection, and output paths remain runtime controls and must not be recorded in the manifest build hash.

## Risks / Trade-offs

- Ambiguous aliases → Mitigation: document `--iterations` as compatibility sugar and add tests for combinations with `--min-samples` and `--target-samples`.
- NVBench option semantics change upstream → Mitigation: use option names and meanings from the vendored NVBench checkout and keep docs focused on the supported mapping.
- Users expect entropy-specific tuning → Mitigation: allow selecting `entropy` through `--stopping-criterion`, but keep entropy-specific parameter exposure for a later change unless needed.
- Convergence runs may take longer than fixed sample-count runs → Mitigation: preserve `sample-count` default and expose `--timeout`.
