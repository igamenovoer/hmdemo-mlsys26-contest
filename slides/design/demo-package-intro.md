# Demo Package Introduction Design Notes

## Audience

The deck is for engineers, researchers, and contest participants who understand GPU kernels or LLM inference at a high level, but may not yet know how this repository wraps the FlashInfer Bench starter kit for human-and-agent CUDA optimization work.

## Goals

- Explain what this fork demonstrates: a contest starter kit shaped for Houmao-managed optimization workflows.
- Show the concrete repository surfaces a user will touch: `solution/`, `variants/`, `scripts/`, `docs/`, `context/`, `skillset/`, and OpenSpec files.
- Make the workflow feel operational rather than aspirational: inspect workloads, create variants, deploy, benchmark, review, and pack.
- Set expectations around CUDA 13.0, Blackwell `sm_100a`, Modal benchmarking, and dataset-dependent local evaluation.

## Narrative Arc

1. Start with the contest setting: generate high-performance kernels for FlashInfer Bench workloads.
2. Position this fork as a demo of agent-assisted kernel optimization, not a replacement for benchmark discipline.
3. Walk through the repository map and the live CUDA solution path.
4. Describe the variant workflow as the center of day-to-day experimentation.
5. Close with the operator loop: benchmark evidence, code review, OpenSpec updates when behavior changes, and packaging for submission.

## Visual Direction

Use a quiet technical style with dense but readable slides. Favor code paths, command blocks, workflow diagrams, and small tables over marketing copy. Reuse existing repository images only when they identify the contest or upstream ecosystem; avoid decorative graphics that do not help the viewer understand the workflow.

## Open Questions

- Should the deck include live timing numbers from a specific `moe-base` benchmark run, or stay environment-neutral?
- Should there be a separate deck for CUDA kernel internals after this introduction?
