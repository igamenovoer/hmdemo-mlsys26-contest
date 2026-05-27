# Lead-Code-Review Agent Team Idea

## Objective

Optimize the MoE kernel for the MLSys26 contest through a simple lead-review-code loop. The team should keep the work moving by separating decision making, review, and implementation, so each round produces either a concrete kernel change, a clearer diagnosis, or a better next optimization direction.

## Team Members

- `lead`: Owns the objective, keeps track of the best states, maintains the ranked beam of open solution branches, decides what to try next, and assigns work to the reviewer and coders.
- `reviewer`: Inspects candidate solutions, checks evidence, identifies problems or opportunities, and proposes repair, incremental improvement, or structural expansion directions.
- `coder-1`: Implements one lead-approved task and reports what changed.
- `coder-2`: Implements one lead-approved task and reports what changed.
- `coder-3`: Implements one lead-approved task and reports what changed.

## Hyperparameters

- `beam_width = 3`: keep up to three coder lanes active in one round.
- `structural_directions_per_wave = 3`: when expanding a matured solution branch, ask reviewer for three distinct structural directions.
- `maturity_failed_trials = 3`: mark an immature branch as matured after three counted local trials fail to improve it.
- `structural_wave_quota = 3`: close a matured branch after it has been used as the seed for three structural expansion waves.
- `promotion_target = open-best`: compare a matured local branch against the best promoted active branch, not necessarily against the best solution ever seen.

## Agent Coordination

The coordination is a generic beam search over open solution branches. `lead` maintains open ends with stable ids, lineage, priority, evidence, trial count, structural wave count, and a state marker: `immature`, `matured`, `closed`, `blocked`, or `pruned`.

The initial base solution is treated as an already `matured` open end, so the first round begins with structural expansion rather than incremental tuning.

`lead` tracks two best references: `global-best`, the best correct solution seen anywhere in the run, and `open-best`, the best promoted solution among branches that are still active. `global-best` is evidence; `open-best` is the comparator for promotion.

1. If any `immature` open ends exist, `lead` selects up to `beam_width` highest-priority immature open ends and assigns one to each available coder lane.
2. Each assigned coder works from that open end's current solution, implements one attempt, and reports the resulting candidate state.
3. `reviewer` evaluates each candidate against the previous solution in the same local branch, not against `global-best` or `open-best`.
4. If the candidate improves over its local comparator, `lead` closes or supersedes the previous local open end and creates a successor `immature` open end with trial count reset to zero.
5. If the candidate does not improve, `lead` records a failed counted trial for that open end; after `maturity_failed_trials` failed local trials, the open end becomes `matured`.
6. If an assigned attempt cannot be evaluated because of a concrete runtime or evaluation blocker, `lead` marks the open end `blocked`; once the blocker is resolved, the same open end can return to `immature` without losing its lineage or trial history.
7. When no `immature` open ends remain, `lead` selects the best-performing `matured` open end that still has structural waves available and asks `reviewer` for `structural_directions_per_wave` structural directions from that matured state.
8. `lead` materializes those reviewer directions as new `immature` child open ends, increments the structural wave count of the selected matured open end, and dispatches up to `beam_width` children to coder lanes.
9. A matured open end closes after it has used `structural_wave_quota` structural expansion waves, or when a structural child improves and takes over that exploration tree.
10. Only a final matured candidate from a local exploration tree is compared against `promotion_target`; if it improves, `lead` updates `open-best`, while `global-best` may still record any better correct solution seen anywhere.
11. The loop repeats until the beam is exhausted, no open-best candidate remains, or the operator stops or changes the goal.
