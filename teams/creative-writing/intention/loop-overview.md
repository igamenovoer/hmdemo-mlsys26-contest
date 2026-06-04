# Loop Overview: creative-writing

## Objective

- Write a Chinese book that introduces how to optimize CUDA operators.
- Make the book useful to ML engineers, systems programmers, and contest participants who can program but need a structured path from CUDA operator basics to practical optimization methods.
- Use a hybrid structure: tutorial chapters for foundations, pattern-catalog chapters for optimization methods, and case-study chapters for realistic operator work.
- Balance technical correctness, readable explanation, small code examples, pseudocode, diagrams, and cited source material.
- Terminal success means completing a full first Chinese book draft package: table of contents, all chapter drafts, source index, technical review records, and unresolved-risk list.

## Participants

- Lead writer: owns the book voice, outline, chapter flow, explanations, examples, and final prose.
- Programmer: checks CUDA operator optimization claims, proposes code examples, reviews technical accuracy, and identifies missing performance details.
- Research assistant: searches the web for reference material, papers, documentation, examples, and supporting facts; records sources for the lead writer and programmer.

## Operating Model

- The loop is lead-writer-centered: the lead writer decomposes the book into chapter work items, requests research, requests technical review, writes drafts, and packages finished sections for operator review.
- The loop first completes the table of contents, then advances one chapter package at a time in table-of-contents order.
- The research assistant gathers source material before each chapter draft and answers focused follow-up questions during revision.
- The programmer reviews the research notes and draft plan before prose drafting, then reviews the finished draft for technical errors.
- The lead writer converts research notes and programmer feedback into chapter drafts, then requests targeted follow-up research or technical review when needed.
- A work item finishes when the section has a readable Chinese draft, a source list, a technical review note, and a short unresolved-risk list.
- The full loop finishes when the lead writer packages the complete first draft for operator acceptance.

## Workspace Expectations

- Keep editable intention source under `teams/creative-writing/intention/`.
- Generated operational material, when requested later, belongs under `teams/creative-writing/execplan/`.
- Keep book drafts, outlines, notes, source summaries, and review notes separated enough that each participant can work without overwriting another participant's output.
- Preserve source links and distinguish direct source claims from inferred writing advice.
- Use chapter-scoped work folders when the generated execplan defines concrete workspace paths.

## Constraints

- Do not invent citations, benchmark results, CUDA behavior, or hardware-specific claims.
- When web search is used, prefer primary sources such as NVIDIA documentation, CUDA Toolkit docs, official library docs, conference papers, and maintained project documentation.
- Keep explanations accessible without watering down important constraints such as memory hierarchy, occupancy, synchronization, launch overhead, tensor-core use, and numerical formats.
- Treat the current repository's CUDA optimization contest context as useful background, not as the only subject of the book.
- Do not let the research assistant write final prose without lead-writer integration.
- Do not let the programmer make unsupported performance claims without source evidence, code evidence, or an explicit caveat.

## Open Questions

- UNRESOLVED - Final chapter list and chapter order.
- UNRESOLVED - Whether examples should target generic CUDA C++, PyTorch extensions, Triton comparison, or this repository's contest kernels.
- UNRESOLVED - Expected book length and publishing format.
