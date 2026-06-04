# ADR 0003: Manual Stop Terminal Posture

## Status

Accepted

## Context

The first Fused MoE loop needs a terminal posture. Promotion through `official-timing` defines a new best candidate, but it does not necessarily mean the broader optimization campaign should stop.

## Question

When should the first Fused MoE loop consider itself successfully complete?

## Decision

The loop has no built-in success condition. It keeps running until the Human Operator manually stops it.

## Consequences

- Promoted candidates update the current best state but do not terminate the loop.
- Generated process contracts should model stop as an operator-control action, not as an automatic result of promotion, budget exhaustion, or first improvement.
- Budget, plateau, invalid-speedup, and blocked-search conditions should trigger escalation or recommendation, not automatic successful completion.
- Future execplan control surfaces should support manual stop, pause, resume, redirect, invalidate, and force-new-cycle behavior.
