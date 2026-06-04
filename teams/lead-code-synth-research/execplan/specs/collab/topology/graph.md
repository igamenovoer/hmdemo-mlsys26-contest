# Topology Graph

The selected topology is `generic-loop`. Planner fans out up to two assignments to symmetric CUDA Coders, Coder results route to Synthesizer, Synthesizer sends promotion reports to Evaluator and context-only copies to Planner, and Evaluator returns accepted or rejected promotion evidence to Planner. Researcher is a request/reply support participant. Profiler is a generated tool surface, not a managed participant node with a mailbox.

```mermaid
flowchart LR
    Operator[Human Operator] -->|planning-cycle-start or operator-intervention| Planner[Planner]
    Planner -->|optimization-assignment| Coder1[CUDA Coder 1]
    Planner -->|optimization-assignment| Coder2[CUDA Coder 2]
    Coder1 -->|coder-result| Synth[Synthesizer]
    Coder2 -->|coder-result| Synth
    Coder1 -->|gpu-wait-report or failure-report| Planner
    Coder2 -->|gpu-wait-report or failure-report| Planner
    Planner -->|research-request| Researcher[Researcher]
    Coder1 -->|research-request| Researcher
    Coder2 -->|research-request| Researcher
    Synth -->|research-request| Researcher
    Researcher -->|research-summary| Planner
    Researcher -->|research-summary| Coder1
    Researcher -->|research-summary| Coder2
    Researcher -->|research-summary| Synth
    Planner -. profile-request .-> Profiler[Profiler Tool]
    Coder1 -. profile-request .-> Profiler
    Coder2 -. profile-request .-> Profiler
    Synth -. profile-request .-> Profiler
    Eval -. profile-request .-> Profiler
    Profiler -. profile-report artifact .-> Planner
    Profiler -. profile-report artifact .-> Coder1
    Profiler -. profile-report artifact .-> Coder2
    Profiler -. profile-report artifact .-> Synth
    Profiler -. profile-report artifact .-> Eval
    Synth -->|synthesis-report promotion input| Eval[Evaluator]
    Synth -->|synthesis-report context only| Planner
    Eval -->|evaluation-report| Planner
    Planner -->|current-best write after accepted evaluation| State[(Generated State)]
```
