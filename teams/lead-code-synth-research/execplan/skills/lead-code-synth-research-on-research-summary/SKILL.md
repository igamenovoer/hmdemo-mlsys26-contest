---
name: lead-code-synth-research-on-research-summary
description: Use when Planner, CUDA Coder, or Synthesizer must handle lead-code-synth-research.email.research-summary mail.
---

# Research Summary

## Trigger

- Houmao notifier or operator prompt presents mail with `schema_id = "lead-code-synth-research.email.research-summary"` to Planner, a CUDA Coder, or Synthesizer.

## Inputs

- Research summary mail with request id, source scope, attribution, reusable patterns, speculative ideas, applicability notes, and risks.

## Procedure

1. Inspect metadata and confirm this participant is the intended receiver.
2. Record or apply payload lifecycle through the harness when available.
3. If acting as Planner, preserve planning-relevant ideas in cycle context and avoid current-best writes.
4. If acting as Coder, use the summary only inside the current bounded assignment or later assigned work; do not start unassigned iterative work.
5. If acting as Synthesizer, attach useful ideas to synthesis context or preserved ideas when they affect candidate comparison.
6. Send no automatic reply unless the current assignment or operator prompt explicitly requires one.

## Output

- Recorded research context, updated local notes, or a no-action report.

## Stop

- End the turn after one bounded context application.
