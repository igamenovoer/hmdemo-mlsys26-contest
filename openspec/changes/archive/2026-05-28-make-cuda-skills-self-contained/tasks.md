## 1. Inventory And Source Mapping

- [x] 1.1 List every `kbs/cuda-kernel-optimization-kb` reference under `extern/tracked/domain-skills/domain/cuda`.
- [x] 1.2 Confirm the affected skill directories and reference pages from the inventory.
- [x] 1.3 Map each referenced KB page to its available public source basis, such as paper IDs, GitHub repositories, NVIDIA docs, or project documentation.
- [x] 1.4 Identify any KB-derived item whose only basis is local source-mining notes and mark how it should be represented without a local path.

## 2. CUDA Domain Optimization Rewrite

- [x] 2.1 Rewrite the MoE method pages in `krnopt-cuda-domain-optimization/references/moe-kernel-design/` to replace local KB anchor lists with compact embedded source cards.
- [x] 2.2 Ensure each rewritten MoE card states applicability, affected kernel boundary, constraints, failure modes, validation signals, and online provenance.
- [x] 2.3 Keep `references/moe-kernel-design.md` aligned with the rewritten method pages without adding a local KB dependency.

## 3. Hardware-Aware Optimization Rewrite

- [x] 3.1 Rewrite `krnopt-hw-aware-optimization/references/h100-sm90-moe-practices.md` so Hopper MoE guidance is self-contained and cites online sources instead of local KB paths.
- [x] 3.2 Rewrite `krnopt-hw-aware-optimization/references/hardware-utilization-targets-subskill.md` so utilization guidance is self-contained and cites online sources instead of local KB paths.
- [x] 3.3 Preserve the architecture boundary guidance for SM90, SM100/B200, and consumer Blackwell without importing unsupported mechanisms across generations.

## 4. Verification

- [x] 4.1 Run a search proving no `kbs/cuda-kernel-optimization-kb` references remain under `extern/tracked/domain-skills/domain/cuda`.
- [x] 4.2 Verify no `kbs/`, copied KB `wiki/`, `raw/`, `outputs/`, or `log/` trees were added under the affected skill directories.
- [x] 4.3 Inspect the rewritten pages for compact guidance and online provenance rather than source-only lists.
- [x] 4.4 Check submodule status and parent repository status so the updated domain-skills pointer can be recorded intentionally.
