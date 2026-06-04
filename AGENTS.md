# Agent Instructions

## Project

This repository is a Pixi-managed Python starter kit for the MLSys 2026 FlashInfer AI Kernel Generation Contest. It contains helper scripts for packing and benchmarking a solution plus Triton/CUDA template implementations under `solution/`.

## OpenSpec

Use OpenSpec for non-trivial feature or workflow changes:

- Propose changes with the OpenSpec skills/commands before implementation when behavior, workflow, or project conventions change.
- Keep active change work under `openspec/changes/`.
- Keep accepted specifications under `openspec/specs/`.
- Archive completed changes with OpenSpec so specs stay current.

The repo has OpenSpec skills installed for both Codex and Claude Code:

- Codex: `.codex/skills/openspec-*`
- Claude Code: `.claude/skills/openspec-*`

Useful CLI checks:

```bash
openspec list
openspec list --specs
openspec validate <change-or-spec>
```

## Development

Use Pixi for project commands:

```bash
pixi run test
pixi run lint
pixi run typecheck
pixi run pack
pixi run -e cu130 nvcc --version
pixi run project-cli variant list
pixi run project-cli workload source list
```

`pixi run bench` requires a CUDA-capable local environment and `FIB_DATASET_PATH`.
`pixi run modal-bench` requires Modal setup.

Use `pixi run -e cu130 ...` for CUDA 13.0 / Blackwell `sm_100a` work. That environment sets `CUDA_HOME` to the PyPI `cuda-toolkit` CUDA 13 layout, adds its `bin` directory to `PATH`, and exports `TORCH_CUDA_ARCH_LIST=10.0a` plus `TVM_FFI_CUDA_ARCH_LIST=10.0a`.

For CUDA header-only library work, use the CUDA Toolkit headers already visible to `nvcc` first. CCCL headers such as CUB, Thrust, and libcu++ are provided by the CUDA Toolkit and can usually be included directly with `<cub/...>`, `<thrust/...>`, or `<cuda/...>`. The local checkout at `extern/orphan/cccl/` is reference material for reading source and examples, not a submission dependency. CUTLASS/CuTe headers are available under `thirdparty/` for project use, and can also be inspected under `extern/orphan/cutlass/include/` with examples under `extern/orphan/cutlass/examples/`; if a solution needs CUTLASS headers at submission time, vendor the required headers intentionally under the solution bundle rather than relying on ignored `extern/orphan/` paths, local install prefixes, or `CPATH`.

Use `project-cli` for repo-local management tasks:

```bash
pixi run project-cli variant list
pixi run project-cli variant new moe-trial --definition <exact-definition>
pixi run project-cli variant deploy moe-trial
pixi run project-cli variant stock moe-trial
pixi run project-cli variant status
pixi run project-cli variant diff moe-trial
pixi run project-cli workload source list
pixi run project-cli workload list --source contest-local --definition <exact-definition> --limit 5
pixi run project-cli workload set list
```

`project-cli` intentionally has no `eval timing` command; use `pixi run bench`, `pixi run modal-bench`, or the underlying scripts for evaluation.

## Layout

- `solution/triton/`: Triton implementation templates.
- `solution/cuda/`: CUDA TVM-FFI template. The configured CUDA entry point is `kernel.cu::kernel`; `binding.py` is only a Python helper placeholder.
- `scripts/`: pack, local benchmark, and Modal benchmark helpers.
- `src/hmdemo_mlsys26_contest/`: importable Python package scaffold.
- `tests/unit/`: fast unit tests.
- `tests/integration/`: integration tests.
- `tests/manual/`: manually run checks.
- `docs/`: project documentation.
- `context/`: working context and design notes.
- `skillset/`: project-local agent skills.
- `skillset/dev/`: developer-facing skills for maintaining, evolving, and operating this project; not used for CUDA kernel optimization.
- `skillset/runtime/`: skills for agents that optimize CUDA kernels, automatically or with human assistance.
- `extern/tracked/`: tracked external dependencies or submodules.
- `extern/orphan/`: local-only external checkouts; ignored by Git.
- `tmp/`: disposable local files; ignored by Git.

## Guardrails

- Do not commit generated `solution.json`, `.pixi/`, `tmp/`, or files under `extern/orphan/`.
- When generating Markdown files, do not hard-break prose lines; keep each paragraph or list item on one logical line.
- Prefer small, focused edits that preserve the starter-kit shape expected by the contest evaluator.
- Keep GPU or dataset-dependent checks out of the default unit test path.
- Preserve Python 3.12 compatibility.

<!-- BEGIN agent-style v0.3.5 -->
<!-- SPDX-License-Identifier: CC-BY-4.0 -->
<!-- Adapter: AGENTS.md cross-agent standard -->
<!-- Target path: <repo root>/AGENTS.md -->
<!-- Load class: single-file; install_mode: append-block -->

# agent-style v0.3.5 — AGENTS.md adapter

agent-style is a literature-backed English technical-prose writing ruleset for AI agents. This adapter is the compact rule payload that AGENTS.md-aware tools (Codex, Jules, Zed, Warp, Gemini CLI, VS Code, Aider via `.aider.conf.yml`, and others) load at session start.

## Self-Verification Handshake

When asked "is agent-style active?" or "what writing rules apply here?", answer: `agent-style v0.3.5 active: 21 rules (RULE-01..12 canonical + RULE-A..I field-observed); full bodies at .agent-style/RULES.md.`

## Load Statement

This adapter is loaded as the root `AGENTS.md` file at the repository root. AGENTS.md-aware tools do not auto-import a second file; the compact directives below are what reach context. Full rule bodies at `.agent-style/RULES.md` are a human-readable reference but are not auto-loaded by AGENTS.md consumers.

## The 21 Rules (Compact Directives)

Canonical rules (from Strunk & White 1959, Orwell 1946, Pinker 2014, Gopen & Swan 1990):

- **RULE-01 Curse of knowledge**: Name your intended reader; do not assume they share your tacit knowledge.
- **RULE-02 Passive voice**: Prefer active voice when the agent is known and worth naming.
- **RULE-03 Concrete language**: Prefer concrete, specific terms over abstract category words like "factors" or "aspects".
- **RULE-04 Needless words**: Cut filler phrases like "in order to", "due to the fact that", "may potentially".
- **RULE-05 Dying metaphors**: Delete clichés like "pushes the boundaries", "paradigm shift", or "state of the art".
- **RULE-06 Plain English**: Prefer "use" over "leverage", "method" over "methodology", "feature" over "functionality".
- **RULE-07 Affirmative form**: Prefer "trivial" to "not important", "forgot" to "did not remember".
- **RULE-08 Claim calibration**: Calibrate verbs to evidence; do not write "proves" when the evidence is "suggests".
- **RULE-09 Parallel structure**: Express coordinate ideas in the same grammatical form.
- **RULE-10 Related words together**: Keep subject close to verb and modifier close to modified; split long parentheticals.
- **RULE-11 Stress position**: Place new or important information at the end of the sentence.
- **RULE-12 Long sentences**: Split sentences over 30 words; vary length across a paragraph.

Field-observed rules (maintainer observation of LLM output, 2022-2026):

- **RULE-A Bullet overuse**: Keep prose in paragraphs when ideas connect; bullets only for genuine lists; avoid forced 3-item triads.
- **RULE-B Dash overuse**: Do not use em or en dashes as casual sentence punctuation; prefer commas, semicolons, colons, parentheses.
- **RULE-C Same-starts**: Do not open two or more consecutive sentences with the same word.
- **RULE-D Transitions**: Do not open sentences with "Additionally", "Furthermore", "Moreover", "In addition".
- **RULE-E Summary closers**: Do not end every paragraph with a sentence that restates its point.
- **RULE-F Term consistency**: Once you define a term or abbreviation, keep using it; do not alternate synonyms.
- **RULE-G Title case**: Use title case for section and subsection headings; articles and short prepositions stay lowercase.
- **RULE-H Citation discipline (critical)**: Support factual claims with verifiable citation or concrete evidence; never fabricate citations.
- **RULE-I Contractions**: Prefer "it is" / "does not" / "cannot" over "it's" / "doesn't" / "can't" in formal technical prose.

## Escape Hatch

*"Break any of these rules sooner than say anything outright barbarous."* — George Orwell, "Politics and the English Language" (1946), Rule 6. Rules are guides to clarity, not ends in themselves.

## Full Rule Bodies (Canonical)

Full directive text, BAD/GOOD example pairs, and rationale per rule: see `.agent-style/RULES.md` in this project, or https://raw.githubusercontent.com/yzhao062/agent-style/v0.3.5/RULES.md for the pinned canonical source.
<!-- END agent-style -->
