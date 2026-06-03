# Houmao Introduction Slide Plan

## Page 1: Title

- Slide content is only the title and subtitle.
- No visible keypoint list on this page.
- The speaker can briefly frame the talk verbally as a CUDA-kernel optimization story enabled by durable multi-agent operations.

## Page 2: Houmao Example Placeholder

- Slide content is a full-slide replacement visual slot.
- Do not include the upstream video asset in this repository.
- Use this page later for a static walkthrough, screenshot sequence, or other non-video visual.

## Page 3: Why Multi Agent System?

- Use ChatDev as the concrete motivating example for why multi-agent systems can be useful.
- Slide design: left side shows the ChatDev chat-chain figure rendered to `slides/assets/chatdev-chat-chain.png`, with a compact quantitative comparison table directly under the image; right side uses a two-column benefit table with `Multi-agent` and `Single-agent` columns.
- Quantitative table under the image: GPT-Engineer single-agent baseline has completeness 0.502, executability 0.358, consistency 0.789, quality 0.142; MetaGPT multi-agent has completeness 0.483, executability 0.415, consistency 0.760, quality 0.152; ChatDev multi-agent has completeness 0.560, executability 0.880, consistency 0.802, quality 0.395.
- Example workflow: design -> coding -> code completion -> code review -> testing.
- Example role pairs: CEO/CTO, CTO/programmer, reviewer/programmer, and tester/programmer.
- Benefit table: more total context because each agent has its own context window, while a single agent has one fixed context window.
- Benefit table: cleaner context because design, code, and review stay separated, while single-agent evidence competes in one transcript.
- Benefit table: sharper prompts because each agent has one objective, while a single prompt mixes many objectives.
- Benefit table: independent samples because the reviewer is not the author, while single-agent self-check shares the same blind spots.
- Speaker note: connect this to Houmao by saying that useful multi-agent work is not just "many chats"; it requires visible roles, handoff state, and recovery surfaces.

## Page 4: Option 1: Code-First Frameworks

- Slide design: left two-thirds is a direct HTML/CSS square diagram that visually represents code classes wrapping LLM APIs, not a formal UML class diagram; right one-third is a pros/cons list.
- Diagram text should use regular weight, not bold.
- Diagram concept: code-first frameworks model agents as code classes that wrap LLM APIs, with class-to-class communication implemented as method calls, typed messages, or graph edges.
- Diagram should show four code-class boxes in a square layout: `PlannerAgent class` wrapping OpenAI API on the upper left, `CoderAgent class` wrapping Claude API on the upper right, `ReviewerAgent class` wrapping OpenAI API on the lower right, and `TestAgent class` wrapping Claude API on the lower left; each API should be highlighted as a nested box.
- Diagram center should contain an `Orchestrator class` box, with L-shaped bidirectional arrows that start from the orchestrator's left or right side and connect to each agent.
- Pros: Precise control: workflow and state transitions are explicit.
- Pros: Testable orchestration: routing, checkpoints, and traces are code.
- Pros: Backend-ready: natural fit for productized services.
- Cons: More software: orchestration must be designed, tested, and maintained.
- Cons: Lower CLI fidelity: real terminal sessions are not primary.
- Cons: Higher startup cost: slower for exploratory delegation.

## Page 5: Option 2: CLI-Native Helpers

- Slide design: left two-thirds is a direct HTML/CSS conceptual architecture diagram with two stacked graphs; right one-third is a pros/cons list.
- Diagram text should use regular weight, not bold.
- Top graph concept: Claude subagents are delegated workers inside one main session; each subagent has its own context and returns a summary/result to the main session, without direct subagent-to-subagent coordination.
- Bottom graph concept: Claude agent teams are a lead session plus separate teammate sessions coordinated through a shared task list and mailbox/message system; teammates can message each other directly.
- Source grounding: Claude Code docs describe subagents as specialized workers with their own context window, prompt, tools, model, and permissions, and describe agent teams as a lead session, teammate sessions, shared task list, and mailbox.
- Pros: Fastest start: lowest setup cost.
- Pros: Easy delegation: natural for brief helper tasks.
- Pros: Native behavior: strong product integration.
- Cons: Product-bounded control: external customization is limited.
- Cons: Weak isolation: mixed providers and runtimes are hard.
- Cons: Limited recovery: custom mail routing and deep recovery are hard.

## Page 6: Option 3: Houmao

- Slide design: left half is a direct HTML/CSS conceptual architecture diagram; right half is a pros/cons list.
- Diagram concept: Houmao runs independent CLI agent processes with per-agent agent gateways, not an in-process object graph or central orchestrator.
- Diagram should show an operator feeding several agent gateways, each gateway attached to a real `tmux` CLI process with isolated runtime home.
- Diagram should show agents coordinating through a shared durable mailbox for inter-agent messages.
- Add caption under the graph: `computer use for TUI coding agent`.
- Pros: Real CLI processes: agents are named, inspectable, and recoverable.
- Pros: Durable coordination: prompts, mail, artifacts, and loop contracts persist.
- Pros: Runtime heterogeneity: tools, models, skills, projects, containers, and hosts can differ.
- Cons: Operational machinery: gateways, mailboxes, profiles, and queues must be managed.
- Cons: Too heavy for simple tasks: prefer first-tier tools when enough.
- Cons: Bigger learning curve: more concepts before the first useful run.

## Page 7: Choice Guide

- Slide design: no left/right split; use two sections, `Do Not Complicate Yourself` and `When To Consider Houmao`.
- In the `When To Consider Houmao` list, bold only the critical decision keywords: `Isolated agent runtime`, `Full communication control`, `Dynamic organization`, and `Custom fault tolerance`; after the colon, phrase each explanation as `you want to ...`.
- First principle: use a single agent, subagent, or tool-native agent team first when it satisfies the task.
- Switch to Houmao only when those first-tier tools become obviously limiting.
- Consider Houmao when you want isolated agent runtime, especially for mixed-vendor agents with different tools, models, thinking levels, MCP servers, skills, memory, worktrees, containers, or hosts.
- Consider Houmao when inter-agent communication must be fully controlled: direct prompts, mail messages, what context enters each mail, queueing policy, message drop behavior, routing rules, and archival rules.
- Consider Houmao when the organization must change dynamically: skills, role structure, objectives, communication protocol, routing policy, or completion criteria.
- Consider Houmao when fault tolerance must be strong and customizable: LLM API errors, network loss, sudden process kills, system reboot, stale gateways, stuck queues, or recovery from partially damaged state.
- If the work is brief, single-provider, and fits the product's built-in team model, do not start with Houmao.

## Page 8: Positive Use Cases

- Use case: reproduce a multi-agent system paper when no official source code is provided and you want to customize the system rather than only mimic the paper.
- Use case: prototype a multi-agent system in one day while observing live sessions, inter-agent communication, prompts, skills, and routing behavior in real time.
- Use case: adjust prompts, skills, organization, and communication rules on the fly while the prototype is running.
- Use case: drive a Claude + Codex multi-agent development team using OpenClaw / Hermes agents, where different agent providers and tool surfaces need one operator-controlled runtime.
- Use case: run in an unstable environment where LLM APIs, networks, processes, or hosts may fail, and you do not want to spend the project designing ad hoc recovery logic.
- Main framing: these tasks require operating and modifying the agent system itself, not just delegating one answer to a helper.

## Page 9: Negative Use Cases

- Negative case: if you want to develop a production multi-agent system that should run for 10,000 hours without problems, use a code-first framework with engineered deployment, tests, monitoring, and SLAs.
- Negative case: if you want to parallelize one-off tasks such as searching the web for different topics, use subagents.
- Negative case: if you want to call Codex from Claude or Claude from Codex, and you have no interest in watching the process, use skills and headless tool calls.
- Negative case: if you want to try an agent loop quickly and only care about the output, use tool-native agent teams.
- Main framing: these tasks need a result or a production service more than an inspectable, operator-controlled agent environment.

## Page 10: Toy Example Section

- Transition from architecture to a simple, concrete Houmao use case.
- Title: `Toy Example`.
- Subtitle: `A Three-Agent Creative Writing Team`.

## Page 11: Creative Writing Team Roles

- Introduce three agents from `/path/to/houmao-examples/teams/creative-writing`: `story-writer`, `character-designer`, and `story-reviewer`.
- Team definition asset: `slides/assets/creative-writing-team-definition.md`.
- `story-writer` is the lead writer, loop owner, and final decision maker for each chapter.
- `character-designer` owns character profiles, relationship notes, and continuity details.
- `story-reviewer` owns logic, pacing, consistency, and story-level critique.
- The operator starts and observes the run while agents coordinate through routed mailbox messages.

## Page 12: Creative Writing Workflow

- Use direct HTML/CSS, not Mermaid.
- Split the slide into left and right halves.
- Left half: operator drives all agents manually; no mailbox is involved. Show a human driving an operator agent, and show three prompt lines from that operator agent to `story-writer`, `character-designer`, and `story-reviewer`.
- Right half: operator triggers the agent loop once; agents coordinate by mail. Show the control topology as `operator -> story-writer -> {character-designer, story-reviewer}`, with one mailbox connected to `story-writer`, `character-designer`, and `story-reviewer`.

## Page 13: Agent Creation Placeholder

- Full-slide replacement visual page.
- Title: `Agent Creation`.
- Do not include the original local video asset.
- This page is reserved for a replacement visual that demonstrates creating the creative-writing agents.

## Page 14: Manual Driving Placeholder

- Full-slide replacement visual page.
- Title: `Manual Driving`.
- Do not include the original local video asset.
- This page is reserved for a replacement visual that demonstrates the operator driving all creative-writing agents manually, without mailbox loop automation.

## Page 15: Agent Loop Placeholder

- Full-slide replacement visual page.
- Title: `Agent Loop`.
- Do not include the original local video asset.
- This page is reserved for a replacement visual that demonstrates the agent loop that lets `story-writer` coordinate work with `character-designer` and `story-reviewer`.

## Page 16: What The Toy Example Shows

- Only show five surfaces demonstrated by the toy example: agent creation, manual driving, auto driving, mailbox subsystem, and agent gateway.
- Agent creation: define `story-writer`, `character-designer`, and `story-reviewer` as managed agents.
- Manual driving: operator prompts each agent directly and observes the responses.
- Auto driving: operator starts the loop and lets `story-writer` coordinate the work.
- Mailbox subsystem: agents exchange requests and replies through durable mail.
- Agent gateway: operator can inspect, prompt, interrupt, and recover live agents.

## Page 17: CUDA Kernel Optimization Section

- Transition from the creative writing team into the CUDA optimization case.
- Title: `CUDA Kernel Optimization`.
- Subtitle: `How Houmao turns kernel tuning into a durable multi-agent search loop.`

## Page 18: Roles and Agent Loop

- Transition from the creative writing team to CUDA kernel optimization using the TeX writeup's "plan-code-profile" framing.
- Explain the open-end ledger: each open end records an exploration direction and an attempt count.
- Use direct HTML/CSS for graphing, not Mermaid.
- Show the loop: correctness-passing seed -> open-end ledger -> reviewer plan -> coder variant -> correctness/timing/profiling -> lead decision.
- Show outcomes: promote as new base, repair and retry, or mature/close after three non-improving attempts and trigger structural search.
- Present the five-process run shape conceptually: one lead, one reviewer, and three coders; do not show full process names in the diagram; arrows should only show sender -> receiver, not reply paths.
- Lead owns search state, active open ends, dispatch, promotion, rejection, and the durable KB.
- Reviewer owns timing/profiling interpretation and generates incremental repairs or structural directions from evidence.
- Coders own scoped CUDA edits as isolated variants and return correctness/timing/implementation reports.
- Show the lead-centered topology with no worker-to-worker edges, because all global state must pass through the lead.
- Emphasize that the run works because hypotheses, attempts, evidence, and stop conditions are durable.

## Page 19: Knowledge Base Construction

- Explain that agents were not asked to rediscover CUDA practice from scratch.
- Show the KB construction flow: source material -> raw notes -> LLM-wiki KB -> concept pages -> task-shaped skills.
- Include source material categories: CUDA guidance and prior notes, CUTLASS/CuTe and FlashInfer code, MoE papers and benchmark code, timing extracts and profiler reports.
- Emphasize that the KB is broad enough for lookup but structured enough to distill into reusable role doctrine.

## Page 20: Cuda Optimization Skills

- Explain that the second layer is the `krnopt-*` skill lane: short, task-shaped instructions loaded by each role for concrete work.
- Map role to skill lane: lead uses variant/workload/search skills; reviewer uses profiling/timing/generic/structural optimization skills; coders use CUDA coding, binding, and variant management skills.
- Map skill family to constraint: coding/binding, profiling/timing, and generic/structural/hardware-aware optimization.
- Make the point that Houmao coordinates the agents while skills define what good CUDA work means for each role.

## Page 21: Kernel Performance Trajectory

- Show the promoted main-chain trajectory across roughly 67 supervised rounds.
- Include the representative promotions: `beeb3551`, `284334c5`, `5d4a4591`, `d4f799d`, `a8512227`, `4410713d`, and `6b9a47b`.
- Include the main measured speedups from the writeup and KB: medium `2.14x`, medium `5.28x`, all `30.80x`, all `32.12x / 7.26x`, all `35.17x / 9.53x`, all `32.71x / 6.33x`, all `47.60x / 6.22x`.
- End with the clean official Docker self-test headline: 19/19 public MoE workloads pass, `27.63x` mean speedup, `6.31x` minimum speedup.

## Page 22: Mail Between Agents

- Show that the mailbox is durable, inspectable run state rather than hidden chat context.
- Use real header excerpts from the archived mailbox index with ellipses above and below omitted message bodies.
- Include lead -> reviewer kickoff, reviewer -> lead reply, lead -> coder dispatch, coder -> lead implementation reply, and a later round-057 message.
- Note that the archive records 656 message files across five mailboxes.

## Page 23: Reproducing Paper with Houmao Section

- Introduce the new section with title `Reproducing Paper with Houmao`.
- Subtitle: `Turning a human-assisted technical report into an executable agent loop.`

## Page 24: Source Technical Report

- Use a two-column page: `Video Demonstration` on the left, `What To Do` on the right.
- Show Luo et al.'s MLSys26 FlashInfer technical report as the source.
- Explain that the report describes a human-orchestrated, agentic kernel optimization workflow.
- Extract the workflow: Planner -> CUDA Coders -> Synthesizer -> Profiler -> Planner.
- Extract the human role: orchestration, plateau correction, anti-hacking policy, and reference injection.
- Extract kernel families, acceptance policy, and failure modes.
- State Houmao's task: convert prose rules into durable roles, mail routes, workspaces, state, and lifecycle controls.
- Use a visible video placeholder block as the demonstration block.

## Page 25: From Paper To Intention

- Use a two-column page: `Video Demonstration` on the left, `What To Do` on the right.
- Show step 1: create loop intention by reading the paper.
- Show step 2: clarify intent.
- Map outputs to `intention/loop-overview.md`, `paper-notes/original-paper.md`, and ADRs for scope, stall detection, state management, anti-hacking, workspace isolation, budgets, recovery, and operator controls.
- Make clear that this pass decides what is automated, what remains operator-controlled, and what evidence is required before accepting a kernel.
- Use a visible video placeholder block as the demonstration block.

## Page 26: From Intention To Execplan

- Use a two-column page: `Video Demonstration` on the left, `What To Do` on the right.
- Show step 3: generating loop artifacts.
- Show step 4: clarify execplan.
- Map outputs to `execplan/manifest.toml`, `specs/`, generated event skills, agent bindings, harness surface, `docs/operator-guide.md`, `docs/runtime-model.md`, `docs/validation.md`, and `docs/artifact-index.md`.
- Explain that this converts the informal report loop into concrete participants, state schema, mail templates, command envelopes, and validation rules.
- Use a visible video placeholder block as the demonstration block.

## Page 27: Prepare and Validate

- Use a two-column page: `Video Demonstration` on the left, `What To Do` on the right.
- Show step 5: prepare agents and workspace.
- Show validation as part of the same page.
- Map outputs to profiles, bindings, worktrees, shared datasets, immutable benchmark assets, manifest checks, schema checks, workspace checks, and generated harness checks.
- Explain that this is where the paper-derived plan becomes launchable infrastructure.
- Use a visible video placeholder block as the demonstration block.

## Page 28: Run the Loop

- Use a two-column page: `Video Demonstration` on the left, `What To Do` on the right.
- Show step 6: running the loop.
- Map outputs to Planner dispatches, Coder exploration, Synthesizer merges, Profiler reports, Researcher-on-stall, mailbox state, `state.db`, and artifacts.
- Explain that the run is inspectable while it executes and remains outside any single chat context.
- Use a visible video placeholder block as the demonstration block.

## Source Anchors

- Houmao README: `/path/to/houmao/README.md`
- Houmao docs overview: `/path/to/houmao/docs/getting-started/overview.md`
- Loop authoring guide: `/path/to/houmao/docs/getting-started/loop-authoring.md`
- CUDA optimization KB: `kbs/cuda-kernel-optimization-kb/`
- Project KB: `kbs/project-kb/`
- Kernel variant manager skill: `skillset/krnopt-kernel-variant-mgr/SKILL.md`
- Workload manager skill: `skillset/krnopt-workload-mgr/SKILL.md`
- CUDA coding skill: `skillset/krnopt-cuda-coding/SKILL.md`
- CUDA profiling skill: `skillset/krnopt-cuda-profiling/SKILL.md`
- In-contest TeX writeup: `extern/tracked/mlsys26-full-agent-writeup/tex/main.tex`
- Agentic exploration KB loop mechanics: `extern/tracked/mlsys26-full-agent-writeup/records/agentic-exploration-kb/wiki/concepts/loop-mechanics.md`
- Agentic exploration KB team topology: `extern/tracked/mlsys26-full-agent-writeup/records/agentic-exploration-kb/wiki/concepts/team-topology.md`
- Agentic exploration KB skill posture: `extern/tracked/mlsys26-full-agent-writeup/records/agentic-exploration-kb/wiki/concepts/skill-posture.md`
- Agentic exploration KB promotion trajectory: `extern/tracked/mlsys26-full-agent-writeup/records/agentic-exploration-kb/wiki/concepts/promotion-trajectory.md`
- Agentic exploration KB mailbox index: `extern/tracked/mlsys26-full-agent-writeup/records/agentic-exploration-kb/wiki/concepts/mailbox/index.md`
- Luo et al. live-demo intention: `context/design/houmao-setup/team-luo-etal/intention/loop-overview.md`
- Luo et al. source-paper architecture note: `context/design/houmao-setup/team-luo-etal/source-paper/agentic-arch.md`
- Multi-agent failure modes survey: `https://arxiv.org/abs/2503.13657`
- Multi-agent coordination and memory engineering: `https://www.mongodb.com/company/blog/technical/why-multi-agent-systems-need-memory-engineering`
- Coordination/routing framing: `https://tacnode.io/post/multi-agent-coordination`
- LangGraph multi-agent concepts: `https://langchain-ai.lang.chat/langgraphjs/concepts/multi_agent/`
