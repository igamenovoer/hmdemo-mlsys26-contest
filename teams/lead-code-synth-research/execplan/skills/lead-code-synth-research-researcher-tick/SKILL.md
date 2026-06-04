---
name: lead-code-synth-research-researcher-tick
description: Use when Researcher must perform one bounded follow-up tick for research mail or manual context in the generated lead-code-synth-research loop.
---

# Researcher Tick

## Trigger

- Notifier or operator prompt asks Researcher to perform follow-up tick work.

## Inputs

- Harness `control status`, pending `research-request` refs, and research source-scope contract.

## Procedure

1. Query control context and stop with no action if the run is paused, stopped, or manual mode without an operator prompt.
2. If one research request is pending and not already answered, answer it using the requested source scope.
3. Default source scope remains parallel local-and-network search unless the request narrows it.
4. Record source-scope notes and send one `research-summary`.
5. If no request is pending, report no action.

## Output

- One research summary or no-action report.

## Stop

- End the turn after one bounded tick pass.
