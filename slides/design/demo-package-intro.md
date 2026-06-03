# Houmao System Introduction Design Notes

## Audience

The deck is for engineers, researchers, and technical operators who want to understand what Houmao is, when to use it, and how its design supports supervised multi-agent work. CUDA kernel optimization is used as a concrete example, but the deck should not assume the viewer cares only about CUDA.

## Goals

- Explain Houmao as a coordination system for independent CLI agents.
- Make the design philosophy clear: explicit roles, visible handoffs, operator authority, project-local memory, and composable workflows.
- Describe the target use cases where multi-agent coordination is worth the added structure.
- Show the basic usage model: initialize a project, launch agents, send work, inspect state, and collect results.
- Use the MLSys 2026 FlashInfer CUDA optimization demo as one worked example of Houmao in practice.
- Keep the demo pages as non-video replacement slots until new visuals are ready.

## Narrative Arc

1. Start with Houmao itself: what it is and why it exists.
2. Define the target use cases and design philosophy.
3. Explain the core concepts: managed agents, gateway, mailboxes, project overlay, and skills.
4. Show the operator workflow for launching and controlling agents.
5. Use CUDA kernel optimization as the example loop.
6. Map that example to this repository's surfaces.
7. Reserve non-video demo pages for future replacement visuals.
8. Close with the broader takeaway: inspectable, interruptible agent teams for long-running engineering work.

## Visual Direction

Use a quiet technical style with dense but readable slides. Favor workflow diagrams, command blocks, small tables, and concrete project paths over marketing copy. Existing contest logos can appear on the title slide to signal the example domain, but Houmao should be the first-viewport topic. Do not include video demo assets in this deck; leave demo pages as placeholders until replacement material is ready.

## Open Questions

- What replacement visuals should fill the create-agents, operator-control, and agent-loop demo pages?
- Should there be a follow-up deck specifically for CUDA kernel optimization details?
- Should the usage slide use exact commands from a pinned Houmao release once the target release is selected?
