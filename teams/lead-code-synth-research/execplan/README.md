# Execplan Package: lead-code-synth-research

## Purpose

This directory contains generated operational material for the `lead-code-synth-research` Houmao loop. The editable source authority remains `../intention/` plus accepted execplan ADRs under `adrs/`; files in this directory are generated contracts, generated skills, generated agent bindings, generated harness surfaces, and generated support docs.

## Contents

- `manifest.toml`: package index, stage status, generated-source posture, runtime skill assignment, omissions, and consistency notes for this revision.
- `adrs/`: accepted execplan-generation decisions, including route, blocker, synthesis, naming, and runtime-skill decisions.
- `specs/`: authoritative contracts for objective, topology, communication, state, workspace, run artifacts, and participants.
- `skills/`: generated loop-local Houmao skills for event handling, tick handling, shared harness use, and operator control.
- `agents/`: concrete planned Houmao agent bindings, `lcsr-*` profile material, memo seeds, and notifier prompts.
- `harness/`: generated loop-local command surface for contract validation, schema lookup, mail rendering, sqlite state, and operator control.
- `docs/`: generated human support views that summarize the authoritative artifacts without replacing them.
