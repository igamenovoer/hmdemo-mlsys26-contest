# ADR 0005: Local-First Automatic Network Research

## Status

Superseded by ADR 0006

## Context

The Researcher needs a source policy. The loop can use local repo material, paper notes, CUDA optimization skills, and project references, but Fused MoE optimization may also benefit from external examples and documentation when local context is thin or progress stalls.

## Question

Should the Researcher be allowed to use network search during automated runs?

## Decision

The Researcher should try local sources first, but may use network search automatically when the agent judges it useful.

## Consequences

- Generated Researcher prompts should prefer local project context and bundled references before web research.
- Network research does not require operator approval each time.
- Research summaries should report whether sources were local or network-derived.
- Future execplan communication contracts should allow research requests to ask for local-only, network-allowed, or network-preferred searches when the sender needs that distinction.
