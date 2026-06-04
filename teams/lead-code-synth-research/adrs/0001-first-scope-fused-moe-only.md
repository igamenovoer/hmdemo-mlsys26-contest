# ADR 0001: First Scope Fused MoE Only

## Status

Accepted, refined by ADR 0002, ADR 0003, ADR 0012, ADR 0013, ADR 0014, and ADR 0015

## Context

The loop intent could target only the active Fused MoE definition, a reusable framework seeded by Fused MoE, or all contest kernels from the start. This choice affects generated objectives, participant prompts, benchmark contracts, workspace layout, state records, and terminal acceptance.

## Question

Which implementation scope should this Houmao loop target first?

## Decision

The first implementation targets the active Fused MoE definition only.

## Consequences

- Intention source should define the first loop around `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`.
- DSA TopK and DSA Sparse Attention remain paper context and possible future extensions, not first-loop implementation scope.
- Future execplan objective, benchmark, workspace, and participant contracts should specialize the first generated loop for Fused MoE.
- Benchmark acceptance, terminal success, resource posture, runtime posture, compute posture, and retry policy were later clarified by ADR 0002, ADR 0003, and ADR 0012 through ADR 0015.
