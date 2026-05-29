# NCU Inspect

Set up and run a project variant under Nsight Compute. Delegate counter selection, NCU/NSYS interpretation, bottleneck classification, and source attribution to `skillset/runtime/krnopt-cuda-profiling`.

## Boundary

- This subskill creates or reuses a small local dataset; `krnopt-cuda-profiling` decides profiler sections, counters, and drill-downs.
- This subskill packs the variant solution JSON; `krnopt-cuda-profiling` interprets NCU/NSYS reports.
- This subskill picks an idle GPU; `krnopt-cuda-profiling` attributes bottlenecks to source.
- This subskill finds and runs `ncu`; `krnopt-cuda-profiling` produces profiling diagnosis.
- This subskill saves report artifacts; `krnopt-cuda-profiling` guides follow-up profiling passes.

## Steps

1. Use `official-timing` to create or reuse a one-workload result directory.
2. Check idle GPUs.
3. Verify `pixi run -e cu130 ncu` resolves to a working NCU.
4. Create `<result-dir>/ncu`.
5. Run NCU inside the Pixi environment for the selected workload.
6. Save command, logs, and `.ncu-rep` paths.
7. Hand off to `krnopt-cuda-profiling`.

## Probes

- GPU state: `nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits`
- NCU in Pixi: `pixi run -e cu130 bash -lc 'command -v ncu; ncu --version 2>&1 | head -5'`
- NCU on host: `command -v ncu || true`
- NCU under CUDA_HOME: `find "${CUDA_HOME:-}" -type f -name ncu 2>/dev/null | head -5`

Use bare `ncu` inside Pixi when the Pixi probe resolves to a working binary. If it is unavailable or fails because injection libraries are missing, try another discovered NCU path. If privileged counters are blocked, follow local machine policy and never print secrets.

## Run NCU

Prefer a harness that loads the local trace dataset and packed solution, builds official inputs for one workload, warms once, calls CUDA profiler start/stop around the solution launch, and synchronizes. If no harness exists, run the one-workload official benchmark under NCU and keep `--target-processes all`.

Use the working launch order:

```bash
mkdir -p <result-dir>/ncu
CUDA_VISIBLE_DEVICES=<gpu> \
pixi run -e cu130 ncu \
  --profile-from-start off --target-processes all \
  --kernel-name-base demangled \
  --section LaunchStats --page raw --csv \
  --print-summary per-kernel --force-overwrite \
  --export <result-dir>/ncu/<solution-name>-<workload-label>-launch \
  <profile-command> \
  > <result-dir>/ncu/<solution-name>-<workload-label>-launch.out 2>&1
```

If the Pixi probe found a better explicit NCU path than bare `ncu`, replace `ncu` with that path while keeping the same launch order:

```bash
CUDA_VISIBLE_DEVICES=<gpu> pixi run -e cu130 <discovered-ncu-path> ...
```

Do not use this order for project Python workloads:

```bash
"$NCU" ... pixi run -e cu130 <profile-command>
```

That wrapper order can block until timeout because NCU is profiling the Pixi launcher boundary instead of cleanly running inside the already prepared environment. If `pixi run` cannot launch the discovered `ncu`, run that executable directly against the Pixi environment's Python or benchmark executable and preserve only environment values discovered from `pixi run -e cu130 env`. Do not hard-code host paths.

## Handoff

- Command: Exact NCU command and whether Pixi or direct host execution was used.
- Target: GPU id, variant id/path, solution JSON path.
- Workload: Dataset root, category, definition, UUID, axes.
- Artifacts: `.ncu-rep`, `.out`, and any logs under `<result-dir>/ncu`.
- Status: Captured kernels, no-match, launch failure, or permission failure.

Next step: load `krnopt-cuda-profiling` with these artifacts for detailed analysis.
