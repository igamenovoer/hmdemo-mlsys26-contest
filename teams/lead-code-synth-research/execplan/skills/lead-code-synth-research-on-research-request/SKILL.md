---
name: lead-code-synth-research-on-research-request
description: Use when Researcher must handle lead-code-synth-research.email.research-request mail for local-and-network research.
---

# Research Request

## Trigger

- Houmao notifier or operator prompt presents mail with `schema_id = "lead-code-synth-research.email.research-request"` to Researcher.

## Inputs

- Research request mail with target kernel family, concrete question, failure or bottleneck context, source scope, and requested output shape.
- Local repo references and permitted network search.

## Procedure

1. Inspect metadata and confirm receiver id is Researcher.
2. Use the requested source scope; default `local-and-network` means search local references and network sources concurrently.
3. Keep source attribution explicit and separate local-derived, network-derived, and jointly supported ideas.
4. Summarize reusable patterns, speculative ideas, applicability notes, and risks for Fused MoE CUDA optimization.
5. Validate/render `research-summary` and send it to the requester; forward selected planning-relevant ideas to Planner only when the generated route or requester context asks for it.

## Output

- One `research-summary` mail with source-scope notes and attribution.

## Stop

- End the turn after one bounded research answer.
