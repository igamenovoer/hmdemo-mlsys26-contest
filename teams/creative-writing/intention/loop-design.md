# Loop Design

## Default Topology

- Use a lead-writer-centered tree loop.
- The lead writer is the central participant for planning, synthesis, revision, and operator-facing output.
- The research assistant and programmer are specialist participants that respond to chapter-scoped requests.
- The operator is outside the normal loop and receives finished chapter packages, unresolved decisions, and requests for direction.

## Book Defaults

- Language: Chinese.
- Reader: programmers who understand general software development and basic ML concepts, but do not yet have a reliable CUDA operator optimization workflow.
- Structure: hybrid tutorial, optimization pattern catalog, and case studies.
- Examples: small runnable CUDA C++ examples where practical, pseudocode when full runnable setup would distract, and diagrams or tables when they clarify memory movement or scheduling.
- Evidence posture: primary sources first, implementation evidence second, clear caveats when evidence is incomplete.

## Work Item Shape

- Each work item targets one chapter, section, subsection, example, diagram, or unresolved technical question.
- A work item has a brief from the lead writer, research notes from the research assistant, technical notes from the programmer, a draft from the lead writer, and a completion summary.
- Each work item carries an explicit status: planned, researching, technical-review, drafting, revision, ready-for-operator-review, accepted, or blocked.
- Normal execution has one active chapter package at a time after the table of contents is accepted.

## Message Flow

- Operator to lead writer: book goal, priorities, review feedback, or acceptance.
- Lead writer to research assistant: topic, source preferences, claims to verify, and expected summary shape.
- Research assistant to lead writer and programmer: source summary with links, dates when visible, supported claims, and uncertainty notes.
- Lead writer to programmer: draft objective, source summary, proposed examples, and questions that need technical review.
- Programmer to lead writer: technical review, code-example ideas, caveats, and correction requests.
- Lead writer to operator: chapter package with draft, source list, technical review status, and open decisions.

## Normal Cycle

- The lead writer starts with the table of contents, then selects the next chapter package in accepted table-of-contents order.
- The lead writer asks the research assistant for sources and the programmer for any pre-draft technical concerns.
- The research assistant returns source notes.
- The programmer reviews the source notes and writes a technical note.
- The lead writer drafts the section.
- The programmer reviews the draft for technical accuracy.
- The lead writer revises the draft and sends a finished package to the operator.

## Completion Criteria

- A chapter package is complete when it has Chinese prose, source notes, programmer review notes, unresolved caveats, and a concise operator summary.
- A book milestone is complete when all chapters in that milestone are accepted or explicitly deferred.
- The full loop is complete when the table of contents, all chapter drafts, source index, technical review records, and unresolved-risk list are packaged for operator acceptance as a complete first Chinese book draft.

## Recovery And Blocking

- If research returns weak sources, the research assistant marks the source gap and asks for narrower search terms or accepts a caveated summary.
- If the programmer finds a technical error, the lead writer revises before sending the package to the operator.
- If the lead writer cannot choose between chapter directions, the lead writer records a conservative default and asks the operator only when the choice changes the book's audience, scope, or correctness.
- If a participant is unavailable, the lead writer may continue with a caveated draft, but cannot mark the work item complete without source notes and technical review notes.
