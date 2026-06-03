# Runtime Model

## Purpose

Summarize the runtime model derived from generated contracts.

## Model

Houmao mail notifier support is the normal driver in `auto` mode. The notifier detects open mail and prompts the target participant agent. The agent inspects the in-body `schema_id`, selects the matching generated on-event skill, processes one bounded event, optionally runs a bounded tick pass, and stops.

Manual mode suspends or disables notifier wakeups for this loop and lets the operator prompt one bounded participant turn at a time. Manual mode is not paused.

Participants must not sleep, poll, tail logs, or wait in-chat for future work.
