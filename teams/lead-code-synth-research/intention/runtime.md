# Runtime

## Runtime Posture

- The first generated loop should be launchable as a live Houmao loop.
- It should prepare six managed agents, six isolated workspaces, Houmao mail/gateway communication, generated state, run controls, and launch readiness checks.
- Offline documentation should support operation, but the generated package should not stop at offline execplan material.

## Execution Stages

- `prepare-agents`: prepare the six managed agent bindings and generated skill bindings.
- `prepare-workspace`: prepare or verify six isolated managed-agent workspaces.
- `validate-loop`: check launch readiness without mutating live state.
- `launch-agents`: launch prepared managed agents.
- `start`: send the first loop trigger after agents are live.

## Runtime Controls

- Normal mode should use Houmao mail/gateway support for participant handoffs.
- Operator controls should support pause, resume, stop, redirect, invalidate, and force-new-cycle behavior.
- Manual operator turns should remain possible for repair or supervision, but they are not the default runtime target.

## Compute Posture

- Coder local checks and Profiler tool use should use a spare local GPU when one is available.
- Generated runtime material should not hardcode one GPU id.
- If no spare local GPU is available, generated runtime material should record waiting-for-GPU state and wait for a later wakeup.

## Still Open

- No remaining high-level runtime posture questions are known; detailed schema and harness shapes belong to execplan generation.
