# ADR 0001: First Execplan Targets Fused MoE

## Status

Accepted

## Context

The initial intention source left the first optimization target unresolved among Fused MoE, DSA TopK Indexer, DSA Sparse Attention, a reusable kernel-agnostic loop, or a combined campaign. This decision affects the objective contract, allowed edit surface, benchmark commands, workspace setup, and acceptance evidence for the first generated execplan.

## Question

What should the first execplan optimize for?

## Decision

The first execplan optimizes Fused MoE only.

## Consequences

- The intention source should name Fused MoE as the initial active kernel scope.
- Future execplan objective, participant tasks, workspace contracts, and evidence requirements should specialize to the Fused MoE solution surface.
- A later execplan or intention update may generalize the loop to DSA TopK Indexer, DSA Sparse Attention, or a reusable kernel-agnostic campaign.
