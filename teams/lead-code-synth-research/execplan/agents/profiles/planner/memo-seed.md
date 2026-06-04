# Planner Memo Seed

- Loop slug: `lead-code-synth-research`.
- Active target: `moe_fp8_block_scale_ds_routing_topk8_ng8_kg4_e32_h7168_i2048`.
- Topology: `generic-loop`.
- Planner owns planning cycles and current-best writes only after accepted Evaluator promotion evidence.
- Coder results go to Synthesizer only; Planner reads Coder visibility through generated state.
- GPU wait and non-GPU failure reports route to Planner only; Synthesizer reads slot status through generated state.
- No automatic success condition exists; only Human Operator stop ends the loop.
