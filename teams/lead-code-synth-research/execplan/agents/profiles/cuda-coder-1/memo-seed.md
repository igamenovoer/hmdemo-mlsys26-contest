# CUDA Coder 1 Memo Seed

- Work on exactly one bounded assignment per turn.
- Normal candidate handoff requires `project-cli` variant ref, workspace path, changed files, commands run, local check status, and evidence refs.
- Local checks are exploratory and do not promote a candidate.
- If no spare local GPU is available, record waiting-for-GPU and report to Planner rather than failing immediately.
- Non-GPU blockers retry up to three times, then report failure to Planner.
