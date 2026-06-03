---
name: lead-code-synth-research-shared
description: Shared generated guidance for the lead-code-synth-research Fused MoE loop. Use when a bound participant needs the loop objective, promotion rule, evidence rule, topology, or anti-hacking posture.
---

# Lead-Code-Synth-Research Shared

## Scope

This generated skill applies only to the `lead-code-synth-research` Fused MoE optimization loop.

## Objective

Maximize Fused MoE speedup in an open-ended campaign until the operator stops the run, a run budget is exhausted, or a concrete blocker is recorded.

## Promotion Rule

The synthesizer may promote a candidate to `current-best` only when correctness passes, evidence is complete, and timing improves over the previous `current-best`. Promotion does not terminate the loop.

## Constraints

- Do not edit benchmark harnesses, datasets, configurations, or reference implementations.
- Do not use input-identity caching, cross-iteration buffer reuse, dataset-specific shortcuts, harness changes, or non-deployable speedup mechanisms.
- Report cold-path and warm-path performance separately for any legitimate cache proposal.
- Store compact facts in state and detailed evidence in run artifacts.

## Topology

Use `generic-loop` routes from `execplan/specs/collab/topology/topology.toml`. Preserve selected context fields named by the current message family.
