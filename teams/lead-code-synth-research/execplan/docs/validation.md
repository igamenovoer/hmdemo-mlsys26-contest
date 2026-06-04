# Validation

This generated support view summarizes validation expectations for the finalized execplan package. It does not replace `validate-execplan`, `validate-loop`, or maintained Houmao platform checks.

## Baseline Checks

- Parse every generated TOML file and JSON schema.
- Confirm `../manifest.toml` indexes emitted final docs, ADRs, specs, harness, generated skills, and agent bindings for this revision.
- Confirm every manifest artifact path exists.
- Confirm all ten schema entries in `../specs/comms/templates.toml` have matching JSON schemas and Markdown renderers.
- Confirm topology and predecessor-context contracts validate through the generated harness.
- Confirm sqlite state schema and invariants validate through the generated harness.
- Confirm all six managed bindings use `lcsr-*` concrete ids and match workspace entries.
- Confirm all six managed bindings include a planned CLI tool assignment and credential display name, with both `codex-pro` and `claude-kimi-cred` represented.
- Confirm workspace entries name one in-repo Git worktree path, branch, and states path per `lcsr-*` agent.
- Confirm every managed binding receives every directory under `../../../../skillset/runtime/*`, including symlinked `krnopt-*` skills.
- Confirm NCU sudo policy names `NCU_ROOT_PW` only and does not persist any sudo password value.
- Confirm no old unprefixed concrete agent paths remain in profile, notifier, workspace, or manifest references.
- Confirm generated runtime debris such as `__pycache__/` is absent before handing the package to execution stages.

## Harness Checks

The generated harness command registry is `../harness/commands.toml`. Useful checks include `self-check`, `topology validate`, `context validate`, `email schema`, `email validate`, `email render`, `state init`, `state validate`, `control status`, and `control manual-context`.

GPU or dataset-dependent benchmark checks are intentionally out of the default execplan validation path. Official timing evidence belongs to Evaluator runtime work after launch.

## Next Validation

After finalization, run `$houmao-agent-loop-pro validate-execplan teams/lead-code-synth-research`. Later, after agent and workspace preparation, run `$houmao-agent-loop-pro validate-loop teams/lead-code-synth-research` before launch.

## Revision

CLI credential assignment accepted on `2026-06-04` with plan revision `cli-credential-assignment-stage-0002`; final docs remain current.
