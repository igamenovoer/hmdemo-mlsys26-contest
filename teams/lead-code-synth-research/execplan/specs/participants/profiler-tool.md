# Profiler Tool Surface

Profiler is a generated tool or skill surface invoked by managed agents for targeted profiling questions. It produces profile reports as artifacts or structured evidence refs and does not have its own managed-agent session, mailbox, or workspace.

When Nsight Compute requires sudo for privileged counters, the invoking managed agent may read the sudo password from the `NCU_ROOT_PW` environment variable at command execution time. The Profiler surface must never print, persist, summarize, or mail the `NCU_ROOT_PW` value.
