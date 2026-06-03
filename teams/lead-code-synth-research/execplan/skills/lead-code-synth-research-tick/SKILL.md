---
name: lead-code-synth-research-tick
description: Generated on-tick skill for one bounded scheduling, reconciliation, timeout, manual-context, or completion pass in the lead-code-synth-research loop.
---

# Lead-Code-Synth-Research Tick

## Trigger

Use this skill after a notifier or operator prompt asks a participant to continue loop work, reconcile state, or act in manual mode.

## Procedure

1. Query control context from the generated harness when available.
2. If `run_state` is paused, stopped, completed, or blocked, report that no normal work should proceed.
3. If `execution_mode` is `manual`, process at most one relevant mail event or one owned state item, then stop.
4. If `execution_mode` is `auto`, process notifier-prompted follow-up work, then stop.
5. Planner ticks may assign work, request profiling, request research after three failed attempts, or escalate to operator after research-assisted failure.
6. Synthesizer ticks may review pending candidate results and promote a faster correct candidate with complete evidence.
7. No tick may sleep, poll, or wait in-chat for future events.
