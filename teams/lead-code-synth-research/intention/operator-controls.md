# Operator Controls

## Terminal Posture

- The first Fused MoE loop has no built-in success condition.
- The loop continues until the Human Operator manually stops it.
- Accepted Evaluator promotion evidence lets Planner update the current best candidate, but this does not stop the loop.

## Control Actions

- Stop: terminate the loop when the Human Operator decides enough work has been done.
- Pause: block normal progress without losing loop state.
- Resume: continue a paused loop.
- Redirect: change Planner priorities, assign a new optimization direction, or abandon a stale direction.
- Invalidate: mark a candidate or speedup as invalid after anti-hacking, reproducibility, or correctness concerns.
- Force new cycle: ask Planner to start over from the current best state and recorded history.

## Escalation Posture

- Budget pressure, repeated failures, benchmark exploitation concerns, inconsistent workspace state, or a long plateau should trigger an operator report or recommendation.
- Escalation does not count as successful completion unless the Human Operator explicitly stops the loop.
