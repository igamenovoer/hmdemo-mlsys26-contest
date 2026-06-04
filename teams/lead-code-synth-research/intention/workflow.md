# Workflow

## Topology

- Initial topology intent: `generic-loop`.
- Reason: Planner, Coder pool, Synthesizer, Profiler, Researcher, Evaluator, and Human Operator form a directed graph with cycles and parallel branches rather than a strict tree of local-close handoffs.
- Normal communication should use Houmao mail unless the generated execplan chooses a loop-local harness path for specific machine-readable state.

## Cycle

- Seed: current best candidate, active contest definition, allowed edit surface, benchmark protocol, run history, and known bottlenecks.
- Plan: Planner emits one or more optimization assignments.
- Implement: CUDA Coders work independently in isolated workspaces and produce candidate result mail.
- Profile: Profiler handles targeted profiling requests or profiles shortlisted candidates.
- Research: Researcher handles reference and idea requests when local progress stalls or a larger shift is needed.
- Synthesize: Synthesizer compares results, selects or merges the strongest candidate, and summarizes the decision.
- Evaluate: Gatekeeper runs correctness and benchmark gates, rejects invalid results, and records accepted evidence.
- Iterate: Planner receives the updated state and either starts the next cycle, asks for human redirection, or recommends stopping.

## Candidate Lifecycle

- Proposed: Planner has issued an assignment with a hypothesis and evidence expectation.
- Implementing: a Coder owns the candidate in an isolated workspace.
- Testing: the Coder or Evaluator runs correctness and timing checks.
- Profiling: the Profiler produces bottleneck evidence when needed.
- Submitted: the Coder sends result mail with changed files, metrics, failures, and next-step notes.
- Synthesized: the Synthesizer selects, merges, preserves, or rejects candidate ideas.
- Accepted: the Evaluator confirms correctness and valid speedup evidence.
- Rejected: correctness, timeout, benchmark validity, anti-hacking, regression, or reproducibility failed.

## Message Families To Generate Later

- `planning-cycle-start`: operator or Synthesizer asks Planner to start a cycle.
- `optimization-assignment`: Planner sends one work item to a Coder.
- `coder-result`: Coder returns candidate evidence and changed-file summary.
- `profile-request`: Planner, Coder, Synthesizer, or Evaluator asks Profiler for specific evidence.
- `profile-report`: Profiler returns bottleneck attribution and metrics summary.
- `research-request`: Planner, Coder, or Synthesizer asks Researcher for references or implementation options.
- `research-summary`: Researcher returns source-backed ideas and risk notes.
- `synthesis-report`: Synthesizer returns selected candidate, merge notes, and next Planner context.
- `evaluation-report`: Evaluator returns accepted or rejected status with evidence.
- `operator-intervention`: Human Operator redirects, pauses, resumes, stops, invalidates, or changes constraints.

## State To Track

- Current best candidate and active variant.
- Benchmark history and profiler artifacts.
- Assignment ids, candidate ids, workspace paths, and owning agents.
- Failed directions, suspected causes, and directions to avoid repeating.
- Accepted speedups with correctness evidence and reproducibility notes.
- Rejected hacks or invalid candidates.
- Open hypotheses, blocked questions, and operator interventions.
