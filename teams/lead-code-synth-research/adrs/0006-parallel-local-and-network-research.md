# ADR 0006: Parallel Local And Network Research

## Status

Accepted

## Context

ADR 0005 allowed automatic network search, but kept a local-first ordering. The operator revised the policy so the Researcher should try local references and network search at the same time.

## Question

How should the Researcher combine local references and network search during automated runs?

## Decision

The Researcher should run local-reference search and network search concurrently by default when handling research requests.

## Consequences

- Generated Researcher prompts should not wait for local-source exhaustion before using network search.
- Network search remains allowed without per-request operator approval.
- Research summaries should report which findings came from local references, network sources, or both.
- Future execplan communication contracts should allow explicit source-scope overrides when a sender needs local-only or network-only research, but the default is parallel local-and-network search.
