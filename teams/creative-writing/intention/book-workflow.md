# Book Workflow

## Work Intake

- The operator names a chapter, section, topic, or open question.
- The lead writer turns the request into a draft objective and notes what evidence or technical review is needed.
- If the table of contents is not accepted yet, the lead writer makes the table of contents the active work item.
- After the table of contents is accepted, the lead writer advances one chapter package at a time in table-of-contents order.
- Parallel chapter drafting is outside normal execution unless the operator explicitly overrides the scheduling rule.

## Research Round

- The research assistant searches for relevant sources and creates a source summary for the requested topic.
- Source summaries should preserve links, publication or update dates when visible, and the specific claim each source supports.
- The research assistant should avoid treating blog summaries as authoritative when official documentation or papers are available.
- The research assistant returns material to the lead writer and programmer, not directly to the final manuscript.

## Technical Review

- The programmer reviews the research summary and draft objective.
- The programmer writes technical notes, likely pitfalls, example ideas, and any corrections needed before prose drafting.
- The programmer should prefer concrete operator examples, such as reductions, GEMM-like kernels, attention kernels, MoE routing, elementwise fusion, layout transforms, and memory-bound copy or cast kernels.

## Drafting

- The lead writer drafts the section using the source summary and technical notes.
- Drafts should explain the intuition first, then the CUDA mechanism, then the optimization tradeoff.
- Claims that depend on a specific architecture, library, or benchmark should carry their context.
- The lead writer writes in Chinese by default and may keep source titles, API names, kernel names, and code identifiers in English.

## Completion

- A section is ready for operator review when it has a readable draft, a source list, and programmer review notes.
- A chapter is ready for operator review when its chapter package has a readable Chinese draft, source list, programmer review notes, unresolved caveats, and a concise operator summary.
- The next chapter starts only after the current chapter package is accepted or explicitly deferred.
- Open questions remain explicit in the intention material until the operator decides them or the loop records a conservative default.
