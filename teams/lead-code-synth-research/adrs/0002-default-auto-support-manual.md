# ADR 0002: Default to Auto Mode and Support Manual Mode

## Status

Accepted

## Context

The initial intention source left runtime wakeup posture unresolved between managed Houmao mail notification and manual operator-prompted bounded passes. This decision affects generated communication contracts, notifier prompts, on-event skills, on-tick skills, operator controls, and launch validation.

## Question

How should the first generated loop run?

## Decision

The loop should support both auto and manual modes, with auto mode as the default. In auto mode, managed Houmao mail notifier wakeups are the normal participant wakeup path. In manual mode, the operator prompts bounded participant turns.

## Consequences

- The intention source should remove runtime-mode ambiguity and record auto as the default mode.
- Future execplan communication and agent-binding surfaces should include mail notifier prompts and generated on-event dispatch for templated message families.
- Future operator-control surfaces should support switching to manual mode for bounded operator-prompted turns.
- Generated agent behavior must not rely on in-chat sleeps, polling, or waiting for future work.
