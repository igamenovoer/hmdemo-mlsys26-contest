---
layout: cover
class: text-center
---

<h1 style="font-size: 2.35rem; line-height: 1.16; font-weight: 700;">
  Fast Prototyping Multi Aagent System<br/>
  with Loosely Coupled CLI Agents
</h1>

Introduction to Houmao Agent Orchestration Framework

<div class="mt-3 text-sm">
  Houmao（猴毛）:
  <a href="https://github.com/igamenovoer/houmao" target="_blank">https://github.com/igamenovoer/houmao</a>
</div>

---
layout: default
class: p-0
---

<div class="h-full w-full bg-black flex items-center justify-center">
  <video
    src="../assets/lcsr-tmux-viewer-window-8x.mp4"
    class="h-full w-full object-contain"
    autoplay
    muted
    loop
    playsinline
    controls
  />
</div>

<div class="option-side-title" style="margin: 0.95rem 0 0.45rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.05rem; font-weight: 700; line-height: 1.2;">进一步控制 Agent Loop</div>

<div style="color: #334155; font-size: 0.95rem; line-height: 1.55;">
  如果你需要对 agent loop 做更细粒度的控制，可以使用 <code>houmao-agent-loop-lite</code> 或 <code>houmao-agent-loop-pro</code> skills。
</div>

---
layout: default
---

# 为什么需要 Multi Agent System?

<div class="grid grid-cols-[1.15fr_0.85fr] gap-6 mt-4 items-start">
<div>
  <img src="../assets/chatdev-chat-chain.png" class="w-full border border-zinc-300" />
  <div class="mt-2 text-[11px] text-zinc-500">ChatDev chat chain：把 design、coding、testing 拆成 role-pair dialogues，并通过 artifact handoffs 串起来。</div>

  <table class="mt-3 w-full text-[12px] leading-tight border-collapse">
    <thead>
      <tr class="border-b border-zinc-300 text-left">
        <th class="py-1 pr-2">Method</th>
        <th class="py-1 pr-2">Paradigm</th>
        <th class="py-1 pr-2 text-right">Complete</th>
        <th class="py-1 pr-2 text-right">Executable</th>
        <th class="py-1 pr-2 text-right">Consistent</th>
        <th class="py-1 text-right">Quality</th>
      </tr>
    </thead>
    <tbody>
      <tr class="border-b border-zinc-200">
        <td class="py-1 pr-2">GPT-Engineer</td>
        <td class="py-1 pr-2">single</td>
        <td class="py-1 pr-2 text-right">0.502</td>
        <td class="py-1 pr-2 text-right">0.358</td>
        <td class="py-1 pr-2 text-right">0.789</td>
        <td class="py-1 text-right">0.142</td>
      </tr>
      <tr class="border-b border-zinc-200">
        <td class="py-1 pr-2">MetaGPT</td>
        <td class="py-1 pr-2">multi</td>
        <td class="py-1 pr-2 text-right">0.483</td>
        <td class="py-1 pr-2 text-right">0.415</td>
        <td class="py-1 pr-2 text-right">0.760</td>
        <td class="py-1 text-right">0.152</td>
      </tr>
      <tr class="font-semibold">
        <td class="py-1 pr-2">ChatDev</td>
        <td class="py-1 pr-2">multi</td>
        <td class="py-1 pr-2 text-right">0.560</td>
        <td class="py-1 pr-2 text-right">0.880</td>
        <td class="py-1 pr-2 text-right">0.802</td>
        <td class="py-1 text-right">0.395</td>
      </tr>
    </tbody>
  </table>
</div>
<div class="text-sm">

<div class="mt-2 text-[14px] leading-snug text-zinc-700">
  ChatDev 是一个有代表性的 multi-agent software engineering system，它把不同角色分工协作的软件开发过程组织成一条清晰的协作流程。
</div>

<table class="mt-4 w-full text-[15px] leading-snug border-collapse">
  <thead>
    <tr class="border-b border-zinc-300 text-left">
      <th class="py-2 pr-4">多智能体</th>
      <th class="py-2">单智能体</th>
    </tr>
  </thead>
  <tbody>
    <tr class="border-b border-zinc-200">
      <td class="py-2 pr-4">总 context 容量更大：每个智能体都有自己的 context 窗口</td>
      <td class="py-2">只有一个固定的 context 窗口</td>
    </tr>
    <tr class="border-b border-zinc-200">
      <td class="py-2 pr-4">context 更干净：设计、编码、评审彼此分离</td>
      <td class="py-2">所有信息都挤在同一段对话里</td>
    </tr>
    <tr class="border-b border-zinc-200">
      <td class="py-2 pr-4">提示词更聚焦：每个智能体只负责一个目标</td>
      <td class="py-2">一个提示词里混杂多个目标</td>
    </tr>
    <tr class="border-b border-zinc-200">
      <td class="py-2 pr-4">采样更独立：评审者不是作者本人</td>
      <td class="py-2">自检会继承同样的盲点</td>
    </tr>
  </tbody>
</table>

<div class="mt-3 text-xs text-zinc-500">来源：Qian et al., <em>ChatDev</em>, arXiv:2307.07924.</div>

</div>
</div>

---

# 方案一：代码驱动框架

<div class="code-option-grid text-sm">
<div>

<div class="agent-square">
  <div class="agent-node node-planner">
    <div class="agent-name">PlannerAgent class</div>
    <div class="agent-api"><span>OpenAI API</span></div>
  </div>
  <div class="agent-node node-coder">
    <div class="agent-name">CoderAgent class</div>
    <div class="agent-api"><span>Claude API</span></div>
  </div>
  <div class="agent-node node-reviewer">
    <div class="agent-name">ReviewerAgent class</div>
    <div class="agent-api"><span>OpenAI API</span></div>
  </div>
  <div class="agent-node node-test">
    <div class="agent-name">TestAgent class</div>
    <div class="agent-api"><span>Claude API</span></div>
  </div>
  <div class="orchestrator-node">
    <div class="agent-name">Orchestrator class</div>
  </div>

  <div class="orchestrator-edge edge-planner"><span>plan</span></div>
  <div class="orchestrator-edge edge-coder"><span>code</span></div>
  <div class="orchestrator-edge edge-reviewer"><span>review</span></div>
  <div class="orchestrator-edge edge-test"><span>test</span></div>
</div>

</div>
<div>

<div class="option-side-title" style="margin: 0 0 0.55rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.15rem; font-weight: 700; line-height: 1.2;">优点</div>

- **控制更精细**：流程怎么走、状态怎么切换，都是明确写出来的
- **更容易验证**：路由、检查点、运行轨迹都在代码里
- **更适合正式落地**：天然贴近产品化和后台部署场景

<div class="option-side-title" style="margin: 0.9rem 0 0.55rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.15rem; font-weight: 700; line-height: 1.2;">缺点</div>

- **工程负担更重**：编排系统本身要设计、测试、维护，硬编码流程也得预先覆盖各种异常情况
- **用户难以实时介入**：除非专门设计交互界面，否则过程通常不可交互
- **迭代更困难**：系统一旦要调整，往往就得重启流程或重写程序，工程工作很多

</div>
</div>

<style>
.option-side-title {
  margin: 0.9rem 0 0.55rem;
  padding-bottom: 0.2rem;
  border-bottom: 1px solid #cbd5e1;
  color: #0f172a;
  font-size: 1.15rem;
  font-weight: 700;
  line-height: 1.2;
}

.option-side-title:first-child {
  margin-top: 0;
}

.code-option-grid {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 1.5rem;
}

.loop-example-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 0.6rem;
  align-items: start;
  margin-top: 0.65rem;
}

.loop-example-grid-wide-ai {
  grid-template-columns: minmax(0, 1fr);
}

.loop-example-stack {
  display: grid;
  gap: 0.6rem;
}

.loop-example-grid-side {
  grid-template-columns: minmax(0, 1fr) minmax(0, 2fr);
  gap: 0.85rem;
}

.loop-example-grid-half {
  grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
  gap: 0.85rem;
}

.loop-example-grid-side .loop-example-panel {
  padding: 0.62rem;
}

.loop-example-grid-half .loop-example-panel {
  padding: 0.62rem;
}

.loop-example-grid-side .loop-example-code {
  font-size: 0.85rem;
  line-height: 1.32;
}

.loop-example-grid-half .loop-example-code {
  font-size: 0.85rem;
  line-height: 1.32;
}

.loop-example-panel {
  border: 1px solid #cbd5e1;
  border-radius: 8px;
  background: #f8fafc;
  padding: 0.58rem;
}

.loop-example-label {
  color: #0f172a;
  font-size: 0.8rem;
  font-weight: 700;
  letter-spacing: 0;
  margin-bottom: 0.45rem;
}

.loop-example-code {
  min-height: 0;
  white-space: pre-wrap;
  overflow-wrap: anywhere;
  border-radius: 8px;
  background: #111827;
  color: #e5e7eb;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 0.85rem;
  line-height: 1.28;
  padding: 0.5rem;
}

.loop-example-tree {
  margin: 0;
  line-height: 1.2;
  white-space: pre;
  overflow-wrap: normal;
  overflow: hidden;
}

.loop-example-md {
  border-radius: 8px;
  border: 1px solid #cbd5e1;
  background: #ffffff;
  color: #0f172a;
  font-size: 0.85rem;
  line-height: 1.32;
  padding: 0.62rem 0.72rem;
}

.loop-example-md h3 {
  margin: 0 0 0.28rem;
  color: #0f172a;
  font-size: 1.02rem;
  font-weight: 700;
}

.loop-example-md p {
  margin: 0.2rem 0 0.34rem;
}

.loop-example-md ul {
  margin: 0.24rem 0 0;
  padding-left: 1rem;
}

.loop-example-md li {
  margin: 0.12rem 0;
}

.loop-example-md code {
  border-radius: 4px;
  background: #eef2ff;
  color: #1e40af;
  font-weight: 700;
  padding: 0.02rem 0.16rem;
}

.loop-example-md-compact {
  line-height: 1.2;
  padding: 0.46rem 0.62rem;
}

.loop-example-md-compact h3 {
  font-size: 0.98rem;
}

.generated-skills-table {
  width: 100%;
  margin-top: 0.34rem;
  border-collapse: collapse;
  font-size: 0.78rem;
  line-height: 1.16;
}

.generated-skills-table th {
  padding: 0.14rem 0.35rem;
  border-bottom: 1px solid #94a3b8;
  color: #0f172a;
  font-weight: 700;
  text-align: left;
}

.generated-skills-table td {
  padding: 0.14rem 0.35rem;
  border-top: 1px solid #e2e8f0;
  vertical-align: top;
}

.generated-skills-table code {
  border-radius: 4px;
  background: #eef2ff;
  color: #1e40af;
  font-weight: 700;
  padding: 0.02rem 0.14rem;
}

.tmux-response-title {
  margin-bottom: 0.35rem;
  color: #f8fafc;
  font-weight: 700;
}

.tmux-response-text {
  margin: 0.3rem 0 0.45rem;
  color: #e5e7eb;
}

.tmux-table {
  width: 100%;
  margin: 0.3rem 0 0.45rem;
  border-collapse: collapse;
  table-layout: fixed;
  color: #e5e7eb;
  font-size: 0.85rem;
  line-height: 1.25;
  white-space: normal;
}

.tmux-table th {
  padding: 0.18rem 0.35rem;
  border-bottom: 2px solid #94a3b8;
  color: #f8fafc;
  font-weight: 700;
  text-align: left;
}

.tmux-table td {
  padding: 0.22rem 0.35rem;
  border-top: 1px solid #475569;
  vertical-align: top;
}

.tmux-table tbody tr:first-child td {
  border-top: 0;
}

.tmux-col-narrow {
  width: 4.4rem;
}

.tmux-col-medium {
  width: 9rem;
}

.tmux-col-wide {
  width: auto;
}

.loop-example-code code,
.loop-example-code .tmux-table code {
  border-radius: 0;
  background: transparent !important;
  color: #93c5fd !important;
  font-weight: 700;
  padding: 0;
}

.tmux-impact-table {
  font-size: 0.85rem;
  line-height: 1.2;
  table-layout: fixed;
}

.tmux-impact-table th,
.tmux-impact-table td {
  padding: 0.18rem 0.3rem;
  white-space: normal;
}

.tmux-impact-table .tmux-col-medium {
  width: auto;
}

.tmux-exec-table {
  font-size: 0.85rem;
  line-height: 1.22;
}

.tmux-agent-status-table {
  line-height: 1.18;
}

.tmux-agent-status-table th,
.tmux-agent-status-table td {
  padding: 0.16rem 0.26rem;
}

.tmux-agent-status-table th:nth-child(1),
.tmux-agent-status-table td:nth-child(1) {
  width: 9.8rem;
}

.tmux-agent-status-table th:nth-child(2),
.tmux-agent-status-table td:nth-child(2) {
  width: 12.4rem;
}

.tmux-exec-command {
  width: 9.6rem;
}

.tmux-exec-prompt {
  width: 17.5rem;
}

.loop-example-note {
  margin-top: 0.05rem;
  color: #475569;
  font-size: 0.55rem;
  line-height: 1.1;
}

.agent-square {
  position: relative;
  width: 100%;
  height: 320px;
}

.agent-node {
  position: absolute;
  z-index: 2;
  display: flex;
  height: 98px;
  width: 42%;
  flex-direction: column;
  justify-content: center;
  border: 2px solid #2563eb;
  border-radius: 8px;
  background: #eff6ff;
  padding: 0 14px;
  box-shadow: 0 8px 18px rgba(15, 23, 42, 0.08);
}

.orchestrator-node {
  position: absolute;
  left: 50%;
  top: 50%;
  z-index: 3;
  display: flex;
  height: 74px;
  width: 38%;
  align-items: center;
  justify-content: center;
  border: 2px solid #7c3aed;
  border-radius: 8px;
  background: #f5f3ff;
  padding: 0 12px;
  text-align: center;
  transform: translate(-50%, -50%);
  box-shadow: 0 10px 22px rgba(15, 23, 42, 0.12);
}

.agent-name {
  color: #172554;
  font-size: 17px;
  font-weight: 400;
  line-height: 1.15;
}

.agent-api {
  margin-top: 9px;
  color: #0f172a;
  font-size: 14px;
  font-weight: 400;
  line-height: 1.2;
}

.agent-api span {
  display: inline-block;
  border: 1.5px solid #0284c7;
  border-radius: 6px;
  background: #f0f9ff;
  padding: 5px 9px;
}

.node-planner {
  left: 0;
  top: 0;
}

.node-coder {
  right: 0;
  top: 0;
}

.node-reviewer {
  right: 0;
  bottom: 0;
}

.node-test {
  left: 0;
  bottom: 0;
}

.orchestrator-edge {
  position: absolute;
  z-index: 1;
  box-sizing: border-box;
  color: #334155;
  font-size: 12px;
  font-weight: 400;
}

.orchestrator-edge span {
  position: absolute;
  white-space: nowrap;
}

.orchestrator-edge::before,
.orchestrator-edge::after {
  position: absolute;
  width: 0;
  height: 0;
  content: "";
}

.edge-planner {
  left: 21%;
  top: 98px;
  width: 10%;
  height: 47px;
  border-bottom: 2px solid #334155;
  border-left: 2px solid #334155;
}

.edge-planner::before {
  left: -7px;
  top: -9px;
  border-bottom: 9px solid #334155;
  border-left: 6px solid transparent;
  border-right: 6px solid transparent;
}

.edge-planner::after {
  bottom: -7px;
  right: -9px;
  border-left: 6px solid transparent;
  border-bottom: 6px solid transparent;
  border-top: 6px solid transparent;
  border-left: 9px solid #334155;
}

.edge-planner span {
  left: 6px;
  bottom: 4px;
}

.edge-coder {
  left: 69%;
  top: 98px;
  width: 10%;
  height: 47px;
  border-bottom: 2px solid #334155;
  border-right: 2px solid #334155;
}

.edge-coder::before {
  right: -7px;
  top: -9px;
  border-bottom: 9px solid #334155;
  border-left: 6px solid transparent;
  border-right: 6px solid transparent;
}

.edge-coder::after {
  bottom: -7px;
  left: -9px;
  border-bottom: 6px solid transparent;
  border-right: 9px solid #334155;
  border-top: 6px solid transparent;
}

.edge-coder span {
  right: 6px;
  bottom: 4px;
}

.edge-reviewer {
  left: 69%;
  top: 175px;
  width: 10%;
  height: 47px;
  border-right: 2px solid #334155;
  border-top: 2px solid #334155;
}

.edge-reviewer::before {
  right: -7px;
  bottom: -9px;
  border-left: 6px solid transparent;
  border-right: 6px solid transparent;
  border-top: 9px solid #334155;
}

.edge-reviewer::after {
  left: -9px;
  top: -7px;
  border-bottom: 6px solid transparent;
  border-right: 9px solid #334155;
  border-top: 6px solid transparent;
}

.edge-reviewer span {
  right: 6px;
  top: 4px;
}

.edge-test {
  left: 21%;
  top: 175px;
  width: 10%;
  height: 47px;
  border-left: 2px solid #334155;
  border-top: 2px solid #334155;
}

.edge-test::before {
  left: -7px;
  bottom: -9px;
  border-left: 6px solid transparent;
  border-right: 6px solid transparent;
  border-top: 9px solid #334155;
}

.edge-test::after {
  right: -9px;
  top: -7px;
  border-bottom: 6px solid transparent;
  border-left: 6px solid transparent;
  border-top: 6px solid transparent;
  border-left: 9px solid #334155;
}

.edge-test span {
  left: 6px;
  top: 4px;
}
</style>

---

# 方案二：CLI 原生工具

<div class="native-option-grid text-sm">
<div>

<div class="native-agent-diagrams">
  <div class="native-panel subagent-graph">
    <div class="native-title">Subagents</div>
    <div class="native-node native-main">Main Claude<br/>session</div>
    <div class="native-node native-sub-a">Explore subagent</div>
    <div class="native-node native-sub-b">Review subagent</div>
    <div class="native-node native-sub-c">Debug subagent</div>
    <div class="native-line line-right sub-delegate-a"><span>delegate</span></div>
    <div class="native-line line-left line-dashed sub-summary-a"><span>summary</span></div>
    <div class="native-line line-right sub-delegate-b"></div>
    <div class="native-line line-left line-dashed sub-summary-b"></div>
    <div class="native-line line-right sub-delegate-c"></div>
    <div class="native-line line-left line-dashed sub-summary-c"></div>
  </div>

  <div class="native-panel team-graph">
    <div class="native-title">Agent team</div>
    <div class="native-node native-lead">Team lead</div>
    <div class="native-node native-coordination">
      <div>Shared task list</div>
      <div class="coord-divider"></div>
      <div>Mailbox / messages</div>
    </div>
    <div class="native-node native-mate-a">Teammate A</div>
    <div class="native-node native-mate-b">Teammate B</div>
    <div class="native-node native-mate-c">Teammate C</div>
    <div class="native-line line-right team-lead-link"></div>
    <div class="native-line line-right team-link-a"><span>tasks + mail</span></div>
    <div class="native-line line-right team-link-b"></div>
    <div class="native-line line-right team-link-c"></div>
    <div class="native-vline team-peer-link"></div>
  </div>
</div>

</div>
<div>

<div class="option-side-title" style="margin: 0 0 0.55rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.15rem; font-weight: 700; line-height: 1.2;">优点</div>

- **上手最快**：几乎不用额外搭系统，启动成本最低
- **文档和生态更齐全**：官方说明、使用资料和周边支持通常更完整
- **原生体验更强**：整体使用感受更像产品自带的一部分

<div class="option-side-title" style="margin: 0.9rem 0 0.55rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.15rem; font-weight: 700; line-height: 1.2;">缺点</div>

- **可控性受产品限制**：可能因厂商限制而过早终止，消息格式、处理优先级和恢复机制也未必能定制
- **平台绑定更强**：通常不支持跨平台通信，不同家的 agent 很难直接协作
- **隔离性受限**：不能让不同 agent 分别使用不同第三方模型、用户权限、Docker 环境或项目

</div>
</div>

<style>
.native-option-grid {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 1.5rem;
}

.native-agent-diagrams {
  position: relative;
  width: 100%;
  height: 370px;
}

.native-panel {
  position: absolute;
  left: 0;
  width: 100%;
  height: 174px;
  border: 2px solid #cbd5e1;
  border-radius: 8px;
  background: #f8fafc;
}

.subagent-graph {
  top: 0;
}

.team-graph {
  bottom: 0;
}

.native-title {
  position: absolute;
  left: 16px;
  top: 10px;
  color: #334155;
  font-size: 14px;
  font-weight: 400;
}

.native-node {
  position: absolute;
  z-index: 2;
  box-sizing: border-box;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 2px solid #2563eb;
  border-radius: 8px;
  background: #eff6ff;
  color: #172554;
  padding: 0 10px;
  text-align: center;
  font-size: 13px;
  font-weight: 400;
  line-height: 1.15;
  box-shadow: 0 8px 18px rgba(15, 23, 42, 0.08);
}

.native-main {
  left: 4%;
  top: 34px;
  width: 25%;
  height: 118px;
  border-color: #7c3aed;
  background: #f5f3ff;
  color: #4c1d95;
}

.native-sub-a,
.native-sub-b,
.native-sub-c {
  left: 64%;
  width: 27%;
  height: 36px;
}

.native-sub-a {
  top: 22px;
}

.native-sub-b {
  top: 72px;
}

.native-sub-c {
  top: 122px;
}

.native-lead {
  left: 4%;
  top: 50px;
  width: 20%;
  height: 78px;
  border-color: #7c3aed;
  background: #f5f3ff;
  color: #4c1d95;
}

.native-coordination {
  left: 33%;
  top: 32px;
  width: 25%;
  height: 112px;
  flex-direction: column;
  border-color: #0f766e;
  background: #f0fdfa;
  color: #134e4a;
}

.coord-divider {
  width: 78%;
  height: 1px;
  margin: 10px 0;
  background: #99f6e4;
}

.native-mate-a,
.native-mate-b,
.native-mate-c {
  left: 72%;
  width: 23%;
  height: 36px;
}

.native-mate-a {
  top: 22px;
}

.native-mate-b {
  top: 72px;
}

.native-mate-c {
  top: 122px;
}

.native-line {
  position: absolute;
  z-index: 1;
  height: 2px;
  background: #334155;
  color: #334155;
  font-size: 12px;
  font-weight: 400;
}

.native-line span,
.native-vline span {
  position: absolute;
  white-space: nowrap;
}

.native-line span {
  left: 50%;
  top: -21px;
  transform: translateX(-50%);
}

.native-line::after,
.native-line::before,
.native-vline::after,
.native-vline::before {
  position: absolute;
  width: 0;
  height: 0;
  content: "";
}

.line-right::after {
  right: -1px;
  top: -5px;
  border-bottom: 6px solid transparent;
  border-left: 9px solid #334155;
  border-top: 6px solid transparent;
}

.line-left::before {
  left: -1px;
  top: -5px;
  border-bottom: 6px solid transparent;
  border-right: 9px solid #334155;
  border-top: 6px solid transparent;
}

.line-dashed {
  background: repeating-linear-gradient(
    to right,
    #64748b 0,
    #64748b 8px,
    transparent 8px,
    transparent 14px
  );
}

.sub-delegate-a,
.sub-summary-a,
.sub-delegate-b,
.sub-summary-b,
.sub-delegate-c,
.sub-summary-c {
  left: 29%;
  width: 35%;
}

.sub-delegate-a {
  top: 38px;
}

.sub-summary-a {
  top: 50px;
}

.sub-delegate-b {
  top: 88px;
}

.sub-summary-b {
  top: 100px;
}

.sub-delegate-c {
  top: 138px;
}

.sub-summary-c {
  top: 150px;
}

.sub-summary-a span {
  top: 7px;
}

.team-lead-link {
  left: 24%;
  top: 89px;
  width: 9%;
}

.team-link-a,
.team-link-b,
.team-link-c {
  left: 58%;
  width: 14%;
}

.team-link-a {
  top: 38px;
}

.team-link-b {
  top: 88px;
}

.team-link-c {
  top: 138px;
}

.native-vline {
  position: absolute;
  z-index: 1;
  left: 66%;
  top: 38px;
  width: 2px;
  height: 100px;
  background: #7c3aed;
  color: #334155;
  font-size: 12px;
  font-weight: 400;
}

.native-vline span {
  right: 8px;
  top: 50%;
  transform: translateY(-50%);
}

.native-vline::before {
  left: -5px;
  top: -1px;
  border-bottom: 9px solid #7c3aed;
  border-left: 6px solid transparent;
  border-right: 6px solid transparent;
}

.native-vline::after {
  bottom: -1px;
  left: -5px;
  border-left: 6px solid transparent;
  border-right: 6px solid transparent;
  border-top: 9px solid #7c3aed;
}
</style>

---

# 方案三：Houmao（猴毛）

<div class="houmao-option-grid text-sm">
<div>

<div class="houmao-model">
  <div class="hm-node hm-operator">
    Operator
    <span>human / script / agent</span>
  </div>

  <div class="hm-line hm-operator-drop"></div>
  <div class="hm-line hm-control-bus"></div>
  <div class="hm-line hm-drop-a"></div>
  <div class="hm-line hm-drop-b"></div>
  <div class="hm-line hm-drop-c"></div>

  <div class="hm-agent-stack hm-stack-a">
    <div class="hm-node hm-gateway">Agent gateway</div>
    <div class="hm-stack-line"></div>
    <div class="hm-node hm-cli">claude · tmux<span>isolated runtime home</span></div>
  </div>
  <div class="hm-agent-stack hm-stack-b">
    <div class="hm-node hm-gateway">Agent gateway</div>
    <div class="hm-stack-line"></div>
    <div class="hm-node hm-cli">codex · tmux<span>isolated runtime home</span></div>
  </div>
  <div class="hm-agent-stack hm-stack-c">
    <div class="hm-node hm-gateway">Agent gateway</div>
    <div class="hm-stack-line"></div>
    <div class="hm-node hm-cli">gemini · tmux<span>isolated runtime home</span></div>
  </div>

  <div class="hm-line hm-mail-a"></div>
  <div class="hm-line hm-mail-a-h"></div>
  <div class="hm-line hm-mail-b"></div>
  <div class="hm-line hm-mail-c"></div>
  <div class="hm-line hm-mail-c-h"></div>
  <div class="hm-node hm-mailbox">
    Shared mailbox
    <span>durable inter-agent messages</span>
  </div>
</div>
<div class="hm-caption">computer use for TUI coding agent</div>

</div>
<div>

<div class="option-side-title" style="margin: 0 0 0.55rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.15rem; font-weight: 700; line-height: 1.2;">优点</div>

- **实时观测和交互**：每个 agent 都是可直接查看、可直接介入的真实 CLI 进程
- **快速迭代，深度定制**：无代码，运行过程中也能直接调整提示词、agent 间通信、skills 和任务安排
- **运行环境更灵活**：工具、模型、技能、项目、容器和主机都可以不同

<div class="option-side-title" style="margin: 0.9rem 0 0.55rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.15rem; font-weight: 700; line-height: 1.2;">缺点</div>

- **agent 行为不确定**：相比硬编码流程，prompt 和 skill 驱动的 agent 行为每次运行都可能不同
- **可靠性不足**：依赖自定义逻辑解析 TUI 信息，不如硬编码或内部 API 调用稳定
- **学习门槛更高**：第一次真正跑起来之前，要先理解更多概念

</div>
</div>

<style>
.houmao-model {
  position: relative;
  width: 100%;
  height: 340px;
  border: 2px solid #cbd5e1;
  border-radius: 8px;
  background: #f8fafc;
}

.houmao-option-grid {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 1.5rem;
}

.hm-caption {
  margin-top: 8px;
  color: #475569;
  font-size: 12px;
  line-height: 1.2;
  text-align: center;
}

.hm-node {
  position: absolute;
  z-index: 2;
  box-sizing: border-box;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  border: 2px solid #2563eb;
  border-radius: 8px;
  background: #eff6ff;
  color: #172554;
  padding: 0 10px;
  text-align: center;
  font-size: 13px;
  font-weight: 500;
  line-height: 1.15;
  box-shadow: 0 8px 18px rgba(15, 23, 42, 0.08);
}

.hm-node span {
  display: block;
  margin-top: 5px;
  color: #475569;
  font-size: 10px;
  font-weight: 400;
}

.hm-operator {
  left: 34%;
  top: 16px;
  width: 32%;
  height: 56px;
  border-color: #7c3aed;
  background: #f5f3ff;
  color: #4c1d95;
}

.hm-agent-stack {
  position: absolute;
  top: 118px;
  width: 28%;
  height: 118px;
}

.hm-stack-a {
  left: 3%;
}

.hm-stack-b {
  left: 36%;
}

.hm-stack-c {
  left: 69%;
}

.hm-gateway,
.hm-cli {
  left: 0;
  width: 100%;
}

.hm-gateway {
  top: 0;
  height: 36px;
  border-color: #0284c7;
  background: #f0f9ff;
  color: #075985;
  font-size: 12px;
}

.hm-cli {
  top: 60px;
  height: 58px;
  border-color: #334155;
  background: #ffffff;
  color: #0f172a;
}

.hm-stack-line {
  position: absolute;
  left: 50%;
  top: 36px;
  z-index: 1;
  width: 2px;
  height: 24px;
  background: #334155;
}

.hm-line {
  position: absolute;
  z-index: 1;
  background: #334155;
}

.hm-operator-drop {
  left: 50%;
  top: 72px;
  width: 2px;
  height: 25px;
}

.hm-control-bus {
  left: 16%;
  top: 97px;
  width: 68%;
  height: 2px;
}

.hm-drop-a,
.hm-drop-b,
.hm-drop-c {
  top: 97px;
  width: 2px;
  height: 21px;
}

.hm-drop-a {
  left: 17%;
}

.hm-drop-b {
  left: 50%;
}

.hm-drop-c {
  left: 83%;
}

.hm-mailbox {
  left: 27%;
  bottom: 16px;
  width: 46%;
  height: 58px;
  border-color: #be123c;
  background: #fff1f2;
  color: #881337;
}

.hm-mail-a,
.hm-mail-b,
.hm-mail-c {
  top: 236px;
  width: 2px;
  height: 30px;
  background: repeating-linear-gradient(
    to bottom,
    #be123c 0,
    #be123c 7px,
    transparent 7px,
    transparent 12px
  );
}

.hm-mail-a {
  left: 17%;
}

.hm-mail-b {
  left: 50%;
}

.hm-mail-c {
  left: 83%;
}

.hm-mail-a-h,
.hm-mail-c-h {
  top: 266px;
  height: 2px;
  background: #be123c;
}

.hm-mail-a-h {
  left: 17%;
  width: 10%;
}

.hm-mail-c-h {
  left: 73%;
  width: 10%;
}
</style>

---

# 要不要用 Houmao？

<div class="option-side-title" style="margin: 0 0 0.55rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.15rem; font-weight: 700; line-height: 1.2;">不要把事情搞复杂</div>

- 如果单个 agent、subagent，或者工具原生的 agent team 已经够用，就先用它们。
- 只有当这些一线工具明显开始成为瓶颈时，再考虑切到 Houmao。

<div style="height: 1rem;"></div>

<div class="option-side-title" style="margin: 0 0 0.55rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.15rem; font-weight: 700; line-height: 1.2;">什么时候考虑 Houmao</div>

- **最大化可观测性和交互能力**：你希望尽可能实时看到 agent 在做什么，并且随时介入调整
- **隔离的 agent 运行环境**：你希望混用不同平台的 agent，并给它们配置不同的工具、模型、思考强度、MCP server、skills、记忆、worktree、容器或主机
- **完整控制通信机制**：你希望自己决定 prompt 怎么路由、消息怎么发、队列怎么排、哪些消息要丢弃、路由规则怎么写，以及归档如何处理
- **组织结构可动态调整**：你希望随着系统运行，持续修改 skills、角色、目标、协议、路由方式或完成条件
- **自定义容错能力**：你希望在 API 报错、网络中断、进程被杀、机器重启或状态部分损坏后，仍然能自己控制恢复过程

---

# 推荐使用场景

这些场景里，Houmao 额外带来的复杂度通常是值得的。

<div style="margin-top: 0.8rem; overflow: hidden; border: 1.5px solid #cbd5e1; border-radius: 14px; background: linear-gradient(180deg, #ffffff 0%, #f8fafc 100%); box-shadow: 0 10px 24px rgba(15, 23, 42, 0.06);">
  <table class="w-full text-[15px] leading-snug border-collapse">
    <thead>
      <tr class="text-left" style="background: linear-gradient(90deg, #dbeafe 0%, #eff6ff 100%);">
        <th class="px-4 py-3" style="width: 50%; border-right: 1px solid #cbd5e1; color: #172554; font-weight: 700;">场景</th>
        <th class="px-4 py-3" style="color: #172554; font-weight: 700;">为什么适合 Houmao</th>
      </tr>
    </thead>
    <tbody>
      <tr style="background: rgba(255,255,255,0.95);">
        <td class="px-4 py-3 align-top" style="border-top: 1px solid #e2e8f0; border-right: 1px solid #e2e8f0;">复现一篇没有官方源码的 multi-agent 论文</td>
        <td class="px-4 py-3 align-top" style="border-top: 1px solid #e2e8f0;">支持深度定制 agent 行为，同时复用 CLI 已有能力，让你把精力放在行为设计上，而不是先实现一整套可靠 agent 系统</td>
      </tr>
      <tr style="background: rgba(248,250,252,0.92);">
        <td class="px-4 py-3 align-top" style="border-top: 1px solid #e2e8f0; border-right: 1px solid #e2e8f0;">在一天内快速做出一个 multi-agent system 原型</td>
        <td class="px-4 py-3 align-top" style="border-top: 1px solid #e2e8f0;">支持实时调整 agent 行为，也不用一开始就把所有行为细节都想清楚</td>
      </tr>
      <tr style="background: rgba(255,255,255,0.95);">
        <td class="px-4 py-3 align-top" style="border-top: 1px solid #e2e8f0; border-right: 1px solid #e2e8f0;">用 OpenClaw / Hermes 驱动 Claude + Codex 开发团队</td>
        <td class="px-4 py-3 align-top" style="border-top: 1px solid #e2e8f0;">提供通信机制和 agent 生命周期管理，并且本身就是按“由其他 agent 驱动”来设计的</td>
      </tr>
      <tr style="background: rgba(248,250,252,0.92);">
        <td class="px-4 py-3 align-top" style="border-top: 1px solid #e2e8f0; border-right: 1px solid #e2e8f0;">在不稳定的运行环境里工作</td>
        <td class="px-4 py-3 align-top" style="border-top: 1px solid #e2e8f0;">agent 是独立进程，一个挂掉不会拖垮其他 agent；同时也能通过 mailbox 里的消息记录恢复工作</td>
      </tr>
    </tbody>
  </table>
</div>

<div style="margin-top: 1rem; color: #334155; font-size: 0.95rem;">共性是：你需要操作并深度定制这个 agent system，而不是只关心它的输出。</div>

<div style="height: 1.1rem;"></div>
<div style="border-top: 2px solid #cbd5e1;"></div>
<div style="height: 1.1rem;"></div>

---

# 不适合的场景

如果你并不需要 Houmao 这种操作层控制能力，那就先用更轻量、或者更产品化的工具。

<div style="margin-top: 0.8rem; overflow: hidden; border: 1.5px solid #cbd5e1; border-radius: 14px; background: linear-gradient(180deg, #ffffff 0%, #f8fafc 100%); box-shadow: 0 10px 24px rgba(15, 23, 42, 0.06);">
  <table class="w-full text-[15px] leading-snug border-collapse">
    <thead>
      <tr class="text-left" style="background: linear-gradient(90deg, #fee2e2 0%, #fef2f2 100%);">
        <th class="px-4 py-3" style="width: 50%; border-right: 1px solid #cbd5e1; color: #7f1d1d; font-weight: 700;">场景</th>
        <th class="px-4 py-3" style="color: #7f1d1d; font-weight: 700;">更合适的第一选择</th>
      </tr>
    </thead>
    <tbody>
      <tr style="background: rgba(255,255,255,0.95);">
        <td class="px-4 py-3 align-top" style="border-top: 1px solid #e2e8f0; border-right: 1px solid #e2e8f0;">想做一个要稳定跑 10,000 小时的生产级 multi-agent 服务</td>
        <td class="px-4 py-3 align-top" style="border-top: 1px solid #e2e8f0;">代码驱动框架，更适合做部署、测试、监控和 SLA 保障</td>
      </tr>
      <tr style="background: rgba(248,250,252,0.92);">
        <td class="px-4 py-3 align-top" style="border-top: 1px solid #e2e8f0; border-right: 1px solid #e2e8f0;">只是想并行处理一次性任务，比如分头搜索网页</td>
        <td class="px-4 py-3 align-top" style="border-top: 1px solid #e2e8f0;">当前 CLI 产品内置的 subagents</td>
      </tr>
      <tr style="background: rgba(255,255,255,0.95);">
        <td class="px-4 py-3 align-top" style="border-top: 1px solid #e2e8f0; border-right: 1px solid #e2e8f0;">只想让 Codex 一次性调用 Claude，或反过来</td>
        <td class="px-4 py-3 align-top" style="border-top: 1px solid #e2e8f0;">skills 和 headless calls，比如 <code>claude -p &lt;prompt&gt;</code></td>
      </tr>
      <tr style="background: rgba(248,250,252,0.92);">
        <td class="px-4 py-3 align-top" style="border-top: 1px solid #e2e8f0; border-right: 1px solid #e2e8f0;">想快速试一个 agent loop，而且只关心最终结果</td>
        <td class="px-4 py-3 align-top" style="border-top: 1px solid #e2e8f0;">工具原生的 agent teams</td>
      </tr>
    </tbody>
  </table>
</div>

<div style="margin-top: 1rem; color: #334155; font-size: 0.95rem;">共性是：你要的是结果，或者生产服务，而不是一个可观测、可操作的 agent 运行环境。</div>

---
layout: section
---

# Houmao 核心概念

从角色定义、运行实例，到通信与协作控制。

---

# Agent 核心概念

Houmao 如何定义和启动 agent。

<div class="grid grid-cols-3 gap-4 mt-5 text-[14px] leading-snug">
  <div style="border: 1.5px solid #cbd5e1; border-radius: 12px; background: #f8fafc; padding: 1rem;">
    <div style="color: #172554; font-size: 1.05rem; font-weight: 700; margin-bottom: 0.5rem;">Specialist</div>
    <div><strong>定义</strong>：某类 agent 的可复用角色包。</div>
    <div class="mt-2"><strong>动机</strong>：不用反复重写同一套角色 prompt、skills、默认配置和 memo seed。</div>
    <div class="mt-2"><strong>可以放</strong>：角色 prompt、预安装 skills、CLI tool 配置、默认 memo 内容。</div>
  </div>
  <div style="border: 1.5px solid #cbd5e1; border-radius: 12px; background: #f8fafc; padding: 1rem;">
    <div style="color: #172554; font-size: 1.05rem; font-weight: 700; margin-bottom: 0.5rem;">Launch Profile</div>
    <div><strong>定义</strong>：记录启动时参数的记录，用来给 specialist 一个运行时身份。</div>
    <div class="mt-2"><strong>动机</strong>：把同一个 specialist 每次启动时要重复填写的运行参数保存下来，让它以明确身份进入运行态。</div>
    <div class="mt-2"><strong>可以放</strong>：agent name、workdir、mailbox posture、additional system prompt and memo。</div>
  </div>
  <div style="border: 1.5px solid #cbd5e1; border-radius: 12px; background: #f8fafc; padding: 1rem;">
    <div style="color: #172554; font-size: 1.05rem; font-weight: 700; margin-bottom: 0.5rem;">Agent Instance</div>
    <div><strong>定义</strong>：正在运行的 agent 实例，由 specialist 或 launch profile 创建出来的受 Houmao 管理的 CLI 进程。</div>
    <div class="mt-2"><strong>来源</strong>：由 launch profile 启动后产生。</div>
    <div class="mt-2"><strong>运行时状态</strong>：CLI 进程、tmux session、runtime home、registry/manifest、mailbox binding、gateway state。</div>
  </div>
</div>

<div class="grid grid-cols-3 gap-4 mt-4 text-[14px] leading-snug">
  <div style="border: 1.5px solid #bfdbfe; border-radius: 12px; background: #eff6ff; padding: 0.75rem 1rem;">
    类似 class，定义可复用的 agent 模板。
  </div>
  <div style="border: 1.5px solid #bfdbfe; border-radius: 12px; background: #eff6ff; padding: 0.75rem 1rem;">
    类似 constructor params，记录启动时参数。
  </div>
  <div style="border: 1.5px solid #bfdbfe; border-radius: 12px; background: #eff6ff; padding: 0.75rem 1rem;">
    类似 object instance，是启动后的运行实体。
  </div>
</div>

---

# Multi-Agent 协作

Houmao 同时支持 agent 之间的协作，以及 operator 与 agent team 之间的协作。

<div class="grid grid-cols-[1.05fr_0.95fr] gap-6 mt-5 items-start">
<div>

```mermaid
flowchart TB
  O[Operator] --> OA[Operator Agent]
  OA --> G[Agent Gateway]
  G --> A[Agent A]
  A <--> M[Mail System]
  B[Agent B] <--> M
  C[Agent C] <--> M
  M --> OA
```

</div>
<div class="text-[15px] leading-snug">

<div class="option-side-title" style="margin: 0 0 0.55rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.15rem; font-weight: 700; line-height: 1.2;">Agent 之间</div>

- 通过 mail system 交换有边界的请求和回复
- 每个 agent 保持自己的 context、tools 和 workspace
- 共享状态放在 messages 和 artifacts 里，而不是一个共享聊天窗口里

<div class="option-side-title" style="margin: 0.9rem 0 0.55rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.15rem; font-weight: 700; line-height: 1.2;">Operator 与 agents</div>

- operator 可以通过 gateway 直接 prompt、interrupt、inspect 或 recover
- operator 也可以通过 mail 查看协作状态、发送任务、归档结果
- 最终哪些输出进入 accepted work，仍然由 operator 决定

</div>
</div>

---
layout: section
---

# Agent Loop Pro Authoring

从 intention source 生成可验证、可执行的 execplan package。

---

# 为什么 Agent Loop 能工作？

<div class="text-[14px] leading-snug mt-4">

Agent Loop Pro 不是生成一个“总控大脑”，而是生成一组松耦合的运行约束：事件如何定义、agent 遇到事件时怎么做、状态如何可靠读写、协作记录放在哪里。

<div class="grid grid-cols-2 gap-4 mt-4">
  <div style="border: 1px solid #cbd5e1; border-radius: 8px; background: #f8fafc; padding: 0.7rem 0.8rem;">
    <div style="font-weight: 800; color: #0f172a; margin-bottom: 0.25rem;">1. on-event skill 定义行为</div>
    <div>mail schema 定义“发生了什么事件”；对应的 on-event skill 像 callback functions，规定 agent 收到这类 mail 后应该读什么、做什么、回什么。</div>
  </div>
  <div style="border: 1px solid #cbd5e1; border-radius: 8px; background: #f8fafc; padding: 0.7rem 0.8rem;">
    <div style="font-weight: 800; color: #0f172a; margin-bottom: 0.25rem;">2. houmao-memo.md 提供轻量记忆</div>
    <div>memo 记录任务相关细节、临时策略和 operator 给出的行为指令。它不是长期知识库，而是当前任务里让 agent 不忘关键上下文的轻量 memory。</div>
  </div>
  <div style="border: 1px solid #cbd5e1; border-radius: 8px; background: #f8fafc; padding: 0.7rem 0.8rem;">
    <div style="font-weight: 800; color: #0f172a; margin-bottom: 0.25rem;">3. harness 负责可靠读写</div>
    <div>agent 不直接猜状态文件怎么改，而是通过 harness 做 validate、query、render、apply、control。这样状态更新和 schema 校验有统一入口。</div>
  </div>
  <div style="border: 1px solid #cbd5e1; border-radius: 8px; background: #f8fafc; padding: 0.7rem 0.8rem;">
    <div style="font-weight: 800; color: #0f172a; margin-bottom: 0.25rem;">4. mailbox 是主通信通道</div>
    <div>mailbox 可以表达点对点、广播、汇总、转发、等待回复等通信模式；同时它也是任务记录的最后兜底，保留谁在什么时候交付了什么。</div>
  </div>
</div>

<div class="mt-4 rounded border border-slate-300 bg-white px-4 py-3 text-[13px] text-slate-700">
  <code>mail schema</code> 定义事件，<code>on-event skill</code> 定义响应，<code>houmao-memo.md</code> 保持局部记忆，<code>harness</code> 保证读写可靠，<code>mailbox</code> 串起协作和记录。
</div>

</div>

---

# Authoring 产物总览

<div class="text-[13px] leading-snug mt-4">

Agent Loop Pro authoring 的核心产物，是把可编辑意图逐步转成可校验、可启动的 loop package。

<div class="grid grid-cols-2 gap-3 mt-3">
  <div style="border: 1px solid #cbd5e1; border-radius: 8px; background: #f8fafc; padding: 0.55rem 0.65rem;">
    <div style="font-weight: 800; color: #0f172a; margin-bottom: 0.18rem;"><code>intention/</code></div>
    <div>operator 可编辑的意图来源：记录目标、项目背景、参与者、协作流程、通信方式、状态、workspace 和约束。</div>
  </div>
  <div style="border: 1px solid #cbd5e1; border-radius: 8px; background: #f8fafc; padding: 0.55rem 0.65rem;">
    <div style="font-weight: 800; color: #0f172a; margin-bottom: 0.18rem;"><code>execplan/specs/collab/</code></div>
    <div>协作过程的权威说明：描述拓扑、生命周期、交接方式、mail 路由和控制姿态。</div>
  </div>
  <div style="border: 1px solid #cbd5e1; border-radius: 8px; background: #f8fafc; padding: 0.55rem 0.65rem;">
    <div style="font-weight: 800; color: #0f172a; margin-bottom: 0.18rem;"><code>execplan/specs/**</code></div>
    <div>可验证的约束层：定义目标、参与者、通信 schema/renderers、状态表、workspace 策略和运行产物。</div>
  </div>
  <div style="border: 1px solid #cbd5e1; border-radius: 8px; background: #f8fafc; padding: 0.55rem 0.65rem;">
    <div style="font-weight: 800; color: #0f172a; margin-bottom: 0.18rem;"><code>execplan/harness/</code></div>
    <div>这个 loop 自带的命令入口：提供 validate、query、render、apply、control，让 agents 统一读写状态。</div>
  </div>
  <div style="border: 1px solid #cbd5e1; border-radius: 8px; background: #f8fafc; padding: 0.55rem 0.65rem;">
    <div style="font-weight: 800; color: #0f172a; margin-bottom: 0.18rem;"><code>execplan/skills/</code></div>
    <div>生成的 skills：把事件处理、角色 tick 和 operator 控制写成 agents 可加载的操作步骤。</div>
  </div>
  <div style="border: 1px solid #cbd5e1; border-radius: 8px; background: #f8fafc; padding: 0.55rem 0.65rem;">
    <div style="font-weight: 800; color: #0f172a; margin-bottom: 0.18rem;"><code>execplan/agents/</code></div>
    <div>agent 绑定层：把 participant 映射到具体 agent id、profile、notifier prompt、memo seed、skills 和 workspace 策略。</div>
  </div>
  <div style="border: 1px solid #cbd5e1; border-radius: 8px; background: #f8fafc; padding: 0.55rem 0.65rem;">
    <div style="font-weight: 800; color: #0f172a; margin-bottom: 0.18rem;"><code>execplan/docs/</code> + <code>manifest.toml</code></div>
    <div>给读者和 operator 的索引：说明 package 包含什么、如何运行、运行模型是什么、哪些 artifact 是权威来源。</div>
  </div>
  <div style="border: 1px solid #cbd5e1; border-radius: 8px; background: #f8fafc; padding: 0.55rem 0.65rem;">
    <div style="font-weight: 800; color: #0f172a; margin-bottom: 0.18rem;"><code>execplan/adrs/</code> + 校验结果</div>
    <div>决策记录和一致性检查：记录关键取舍，并验证 specs、harness、skills、agents 是否相互匹配。</div>
  </div>
</div>

</div>

---

# `init`

<div class="text-[15px] leading-snug mt-5">

- **定位**：为一个新 agent loop 创建可编辑的 source 区域。
- **输入**：loop 目录、operator 的初始目标、可选 project context。
- **边界**：只初始化 intention source，不生成 `execplan/`，也不启动 agent。

<div class="option-side-title" style="margin: 0.85rem 0 0.45rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.05rem; font-weight: 700; line-height: 1.2;">输出文件</div>

| 文件 | 作用 |
| --- | --- |
| `intention/loop-overview.md` | 只是 skeleton：预留目标、参与者、协作流程、handoff、open questions 等字段 |
| `intention/project-context.md` | 当前项目的背景事实：repo 结构、可用命令、约束、已有约定和 workspace 假设 |

</div>

---

# Example: init

<div class="text-[14px] leading-snug mt-4">

<div class="loop-example-grid">
  <div class="loop-example-panel">
    <div class="loop-example-label">You</div>
    <div class="loop-example-code">$houmao-agent-loop-pro init<br>teams/lead-code-synth-research</div>
  </div>
  <div class="loop-example-panel">
    <div class="loop-example-label">AI</div>
    <div class="loop-example-code">Initialized intention source.<br><br>Created:<br>- intention/README.md<br>- intention/loop-overview.md<br>- intention/project-context.md<br><br>No execplan/ or adrs/ generated.</div>
  </div>
</div>

</div>

---

# `create-intention`

<div class="text-[15px] leading-snug mt-5">

- **定位**：创建最小 intention source，用来承载 loop 的初始意图。
- **输入**：loop 目录、operator 对目标和参与者的描述。
- **边界**：不做 project context 探测，也不进入 execplan 生成阶段。
- **输出**：`intention/loop-overview.md`，最小 intention source。

<div class="option-side-title" style="margin: 0.85rem 0 0.45rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.05rem; font-weight: 700; line-height: 1.2;">`loop-overview.md` key sections</div>

| 分组 | 目的 |
| --- | --- |
| goal boundary | 说明这个 loop 想完成什么，以及当前还不处理什么 |
| participants | 记录预期参与者、责任分工，以及哪些角色还需要澄清 |
| workflow sketch | 勾勒初始协作流程、handoff 和 open questions，供后续 clarify/execplan 使用 |

</div>

---

# Example: create-intention

<div class="text-[14px] leading-snug mt-4">

<div class="loop-example-grid loop-example-grid-half">
  <div class="loop-example-stack">
    <div class="loop-example-panel">
      <div class="loop-example-label">You</div>
      <div class="loop-example-code">read the paper teams/lead-code-synth-research/source/mlsys26-tech-report.pdf, we want to implement such a multi agent system</div>
    </div>
    <div class="loop-example-panel">
      <div class="loop-example-label">AI</div>
      <div class="loop-example-code">Created loop intent from the paper.<br><br>Updated loop-overview.md.<br>Added focused intent files:<br>- paper-notes.md<br>- participants.md<br>- workflow.md<br>- constraints.md<br><br>No execplan/ generated.</div>
    </div>
  </div>
  <div class="loop-example-panel">
    <div class="loop-example-label">PDF Snapshot: Agent Structure</div>
    <img src="../assets/mlsys26-agent-structure.png" class="w-full rounded border border-slate-300 bg-white object-contain" />
  </div>
</div>

</div>

---

# `clarify-intent`

<div class="text-[15px] leading-snug mt-5">

- **定位**：在生成 execplan 前，补齐 intention 中影响设计的关键问题。
- **输入**：`intention/` 下的目标、参与者、协作方式和约束。
- **边界**：只澄清 source intent，不直接写运行时 contract。

<div class="option-side-title" style="margin: 0.85rem 0 0.45rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.05rem; font-weight: 700; line-height: 1.2;">更新文件组</div>

| 文件组 | 作用 |
| --- | --- |
| `<loop-dir>/adrs/*.md` | 记录已接受的 intent decision：问了什么、为什么重要、最终怎么决定 |
| `intention/loop-overview.md` | 更新目标、参与者、生命周期、拓扑和整体操作模型 |
| `intention/*.md` | 按主题补充 `participants.md`、`workflow.md`、`communication.md`、`state.md`、`workspace.md`、`constraints.md` 等 source docs |

</div>

---

# Example: clarify-intent

<div class="text-[14px] leading-snug mt-4">

<div class="loop-example-grid">
  <div class="loop-example-panel">
    <div class="loop-example-label">You</div>
    <div class="loop-example-code">$houmao-agent-loop-pro clarify intent</div>
  </div>
  <div class="loop-example-panel">
    <div class="loop-example-label">AI</div>
    <div class="loop-example-code">
      <div class="tmux-response-title">Question 1: First Scope</div>
      <div class="tmux-response-text">Which implementation scope should this Houmao loop target first?</div>
      <table class="tmux-table">
        <thead>
          <tr>
            <th class="tmux-col-narrow">Option</th>
            <th class="tmux-col-wide">Scope</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>A</td>
            <td>Recommended: Active Fused MoE only for the first implementation.</td>
          </tr>
          <tr>
            <td>B</td>
            <td>Build a reusable framework, but run the first concrete cycle on Fused MoE.</td>
          </tr>
          <tr>
            <td>C</td>
            <td>Support Fused MoE, DSA TopK, and DSA Sparse Attention from day one.</td>
          </tr>
        </tbody>
      </table>
      <div class="tmux-response-text">Reply with A, recommended, yes, or a short alternative.</div>
    </div>
  </div>
</div>

</div>

---

# `execplan-specs-process`

<div class="text-[13px] leading-tight mt-3">

- **定位**：先定义协作过程，作为后续 artifact 的 process authority。
- **输入**：intention 中的目标、参与者、事件、handoff 和 recovery 设想。
- **边界**：关注 phase、event、tick、handoff 和伪代码，不生成具体 agent 绑定。
- **输出**：`execplan/specs/collab/collab-overview.md`，第一个 generated authority。

<div class="option-side-title" style="margin: 0.55rem 0 0.3rem; padding-bottom: 0.16rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 0.95rem; font-weight: 700; line-height: 1.15;">`collab-overview.md` key sections</div>

| 分组 | 目的 |
| --- | --- |
| scope boundary | 说明这个 loop 解决什么问题、暂时不解决什么问题，避免后续 artifact 偷偷扩大范围 |
| topology model | 说明参与者之间是什么协作形状，谁拥有哪类工作，以及运行时按什么模式推进 |
| event flow | 说明一次工作如何从触发开始，经过哪些阶段、交接和分支，最后到达下一步状态 |
| mail routing | 说明消息如何成为事件、结果应该发给谁，以及哪些 mail family 会变成具体 contract |
| runtime control | 说明 agent 每次被唤醒该做什么，以及 operator 如何暂停、恢复、修复或结束 run |
| derivation aids | 用伪代码、时序图和未决问题，把抽象流程变成后续 contract 可以派生的依据 |

</div>

---

# Example: execplan-specs-process

<div class="text-[14px] leading-snug mt-4">

<div class="loop-example-grid loop-example-grid-side">
  <div class="loop-example-stack">
    <div class="loop-example-panel">
      <div class="loop-example-label">You</div>
      <div class="loop-example-code">execplan-specs-process</div>
    </div>
    <div class="loop-example-panel">
      <div class="loop-example-label">AI</div>
      <div class="loop-example-code">Generated process-stage files:<br><br>- execplan/specs/README.md<br>- execplan/specs/collab/README.md<br>- execplan/specs/collab/collab-overview.md<br><br>Next step:<br>execplan-specs-contract</div>
    </div>
  </div>
  <div class="loop-example-panel">
    <div class="loop-example-label">collab-overview.md preview</div>
    <div class="loop-example-md loop-example-md-compact">
      <h3>Generated Process Overview</h3>
      <p><strong>Selected topology mode:</strong> <code>generic-loop</code>.</p>
      <p>The loop is a directed graph with parallel Coder branches and repeated planning cycles. Normal work moves from Planner to two CUDA Coders, then to Synthesizer, then to Evaluator, then back to Planner through evaluation evidence.</p>
      <p><strong>Normal directed routes:</strong></p>
      <ul>
        <li>Human Operator to Planner: start, stop, pause, resume, redirect, invalidate, or force a new cycle.</li>
        <li>Planner to CUDA Coder 1 and CUDA Coder 2: optimization assignments with distinct directions.</li>
        <li>CUDA Coders to Synthesizer: routine <code>coder-result</code> mail containing candidate evidence.</li>
      </ul>
    </div>
  </div>
</div>

</div>

---

# `execplan-specs-contract`

<div class="text-[15px] leading-snug mt-5">

- **定位**：从 process spec 派生可验证的 contract 集合。
- **输入**：`collab-overview.md` 和 intention 中的约束。
- **边界**：定义结构和约束，不生成执行脚本和 skills。

<div class="option-side-title" style="margin: 0.85rem 0 0.45rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.05rem; font-weight: 700; line-height: 1.2;">contract 文件组</div>

| 文件组 | 作用 |
| --- | --- |
| `specs/objective/`、`specs/participants/` | 定义成功标准、policy、participant role templates 和 stable role instances |
| `specs/collab/topology/` | 定义 `tree-loop` 或 `generic-loop`、route graph、cycle posture、context posture |
| `specs/comms/` | 定义 mail templates、`schema_id`、JSON schemas、Markdown renderers 和 reply expectation |
| `specs/state/`、`specs/workspace/`、`specs/run/` | 定义 bookkeeping state、workspace policy、run artifacts 和结构化记录 schema |

</div>

---

# Example: execplan-specs-contract

<div class="text-[14px] leading-snug mt-4">

<div class="loop-example-grid loop-example-grid-half">
  <div class="loop-example-stack">
    <div class="loop-example-panel">
      <div class="loop-example-label">You</div>
      <div class="loop-example-code">execplan-specs-contract</div>
    </div>
    <div class="loop-example-panel">
      <div class="loop-example-label">AI</div>
      <div class="loop-example-code">Generated contract layer:<br><br>- objective/<br>- participants/<br>- collab/topology/<br>- comms/<br>- state/<br>- workspace/<br>- run/<br><br>Validated TOML, JSON and SQL.</div>
    </div>
  </div>
  <div class="loop-example-panel">
    <div class="loop-example-label">Generated Contract Tree</div>
    <pre class="loop-example-code loop-example-tree">execplan/specs/
|-- objective/       objective.toml, policy.toml
|-- participants/   participants.toml, role *.md
|-- collab/
|   |-- loop-policy.toml
|   `-- topology/   topology.toml, graph.md, context-posture.toml
|-- comms/
|   |-- templates.toml
|   |-- schemas/*.schema.json
|   `-- renderers/*.md.j2
|-- state/          schema.sql, invariants.toml, seed.toml
|-- workspace/      workspace.toml
`-- run/            control.toml, run-artifacts.toml</pre>
  </div>
</div>

</div>

---

# `execplan-harness`

<div class="text-[15px] leading-snug mt-5">

- **定位**：生成 loop package 自带的验证、查询、渲染、应用和控制入口。
- **输入**：process spec 和 contracts。
- **边界**：harness 服务于这个 loop，不替代 Houmao 平台级 lifecycle 命令。

<div class="option-side-title" style="margin: 0.85rem 0 0.45rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.05rem; font-weight: 700; line-height: 1.2;">harness 文件组</div>

| 文件组 | 作用 |
| --- | --- |
| `execplan/harness/commands.toml` | loop-local command registry：列出 validation、query、render、apply、control 等命令 |
| `execplan/harness/src/`、`bin/` | command implementation 和 wrapper，给 agents 或 operator 调用 |
| `execplan/harness/schemas/`、`refs/` | command envelope schema，以及指向 authoritative package artifacts 的相对引用 |
| `dependency-posture.toml`、`requirements.txt`、`vendor/` | 只在需要非标准库或 standalone/custom execution 时记录依赖姿态 |

</div>

---

# Example: execplan-harness

<div class="text-[14px] leading-snug mt-4">

<div class="loop-example-grid loop-example-grid-half">
  <div class="loop-example-stack">
    <div class="loop-example-panel">
      <div class="loop-example-label">You</div>
      <div class="loop-example-code">execplan-harness</div>
    </div>
    <div class="loop-example-panel">
      <div class="loop-example-label">AI</div>
      <div class="loop-example-code">Generated harness stage:<br><br>- commands.toml<br>- bin/lead-code-synth-research-harness<br>- src/..._harness.py<br>- command-envelope.schema.json<br>- dependency-posture.toml<br><br>Smoke tests passed.</div>
    </div>
  </div>
  <div class="loop-example-panel">
    <div class="loop-example-label">Generated Harness CLI</div>
    <div class="loop-example-code loop-example-tree">lead-code-synth-research-harness<br>|-- self-check<br>|-- topology&nbsp;&nbsp; validate / query<br>|-- context&nbsp;&nbsp;&nbsp; validate / query<br>|-- email&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; schema / validate / render / apply / query<br>|-- state&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; init / validate / query / export<br>|-- record&nbsp;&nbsp;&nbsp;&nbsp; validate / apply<br>`-- control&nbsp;&nbsp; status / get-mode / set-mode / pause / resume / stop<br><br>核心能力：<br>- 校验 topology、context、state 和 mail payload<br>- 渲染 mail，并把 lifecycle facts 写入 sqlite state<br>- 给 agents 提供统一 query/control 入口</div>
  </div>
</div>

</div>

---

# `execplan-skills`

<div class="text-[15px] leading-snug mt-5">

- **定位**：把 loop 行为编译成 agents 可以安装和调用的 generated skills。
- **输入**：process spec、contracts、事件定义和 operator control 需求。
- **边界**：每个 skill 都应该是 bounded turn，不依赖长期 in-chat wait。

<div class="option-side-title" style="margin: 0.85rem 0 0.45rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.05rem; font-weight: 700; line-height: 1.2;">skills 文件组</div>

| 文件组 | 作用 |
| --- | --- |
| `<loop-slug>-shared-harness/SKILL.md` | 统一说明 agents 如何使用 generated harness、contracts 和 structured outputs |
| `<loop-slug>-<role>-on-<message-family>/SKILL.md` | 处理一个具体 `schema_id` 或 event family，做一个 bounded action 后结束 |
| `<loop-slug>-<role>-tick/`、`<loop-slug>-operator-control/` | 调度/恢复/完成检查，以及 operator 的 status、pause、resume、stop、manual step 等控制 |

</div>

---

# Example: execplan-skills

<div class="text-[14px] leading-snug mt-4">

<div class="loop-example-grid loop-example-grid-side">
  <div class="loop-example-panel">
    <div class="loop-example-label">You</div>
    <div class="loop-example-code">go next</div>
  </div>
  <div class="loop-example-panel">
    <div class="loop-example-label">AI</div>
    <div class="loop-example-code">Routed to execplan-skills.<br><br>Generated 16 flat skill dirs:<br>- shared harness usage<br>- 9 on-event handlers<br>- 5 role tick handlers<br>- operator control<br><br>Next step:<br>execplan-agent-bindings</div>
  </div>
</div>

<div class="loop-example-md loop-example-md-compact">
  <h3>Generated Skills Preview</h3>
  <table class="generated-skills-table">
    <thead>
      <tr>
        <th>Skill</th>
        <th>Purpose</th>
      </tr>
    </thead>
    <tbody>
      <tr><td><code>shared-harness</code></td><td>让所有角色用同一个 harness 查询 control status、schema 和 state。</td></tr>
      <tr><td><code>on-planning-cycle-start</code></td><td>Planner 打开一个 cycle，并发出两个 Coder assignment。</td></tr>
      <tr><td><code>on-optimization-assignment</code></td><td>Coder 执行一次 bounded implementation attempt，然后发送结果或 blocker。</td></tr>
      <tr><td><code>on-coder-result</code></td><td>Synthesizer 汇总 Coder evidence，决定是否产出 synthesis-report。</td></tr>
      <tr><td><code>on-evaluation-report</code></td><td>Planner 只根据 Evaluator accepted evidence 更新 current-best。</td></tr>
    </tbody>
  </table>
</div>

</div>

---

# `execplan-agent-bindings`

<div class="text-[15px] leading-snug mt-5">

- **定位**：把 participant contract 绑定到可启动的 Houmao agent 配置。
- **输入**：participants、workspace contract、generated skills 和 notifier prompt 需求。
- **边界**：只生成绑定材料，不启动 live agent。

<div class="option-side-title" style="margin: 0.85rem 0 0.45rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.05rem; font-weight: 700; line-height: 1.2;">agent binding 文件组</div>

| 文件组 | 作用 |
| --- | --- |
| `execplan/agents/bindings.toml` | 把 participant instance 映射到 concrete agent id、skills、prompt source、workspace policy 和 notifier prompt |
| `execplan/agents/profiles/<agent-id>/config.toml` | 记录准备 Houmao profile 时需要的 concrete agent 配置意图 |
| `execplan/agents/profiles/<agent-id>/definition.md`、`memo-seed.md` | agent 的 role prompt source 和可选 memo seed |
| `execplan/agents/notifier-prompts/<agent-id>.md` | mail-driven participant 被 notifier 唤醒后，如何按 `schema_id` 选择 generated skill |

</div>

---

# Example: execplan-agent-bindings

<div class="text-[14px] leading-snug mt-4">

<div class="loop-example-grid loop-example-grid-half">
  <div class="loop-example-stack">
    <div class="loop-example-panel">
      <div class="loop-example-label">You</div>
      <div class="loop-example-code">next</div>
    </div>
    <div class="loop-example-panel">
      <div class="loop-example-label">AI</div>
      <div class="loop-example-code">Generated agent bindings:<br><br>- agents/bindings.toml<br>- six planned profile configs<br>- role definitions<br>- memo seeds<br>- notifier prompts<br><br>No live agents were launched.</div>
    </div>
  </div>
  <div class="loop-example-md loop-example-md-compact">
    <h3>Binding Result</h3>
    <table class="generated-skills-table">
      <thead>
        <tr>
          <th>Participant</th>
          <th>Agent / CLI</th>
        </tr>
      </thead>
      <tbody>
        <tr><td><code>planner</code></td><td><code>lcsr-planner</code> → Claude</td></tr>
        <tr><td><code>cuda-coder-1</code></td><td><code>lcsr-cuda-coder-1</code> → Codex</td></tr>
        <tr><td><code>cuda-coder-2</code></td><td><code>lcsr-cuda-coder-2</code> → Codex</td></tr>
        <tr><td><code>synthesizer</code></td><td><code>lcsr-synthesizer</code> → Codex</td></tr>
        <tr><td><code>researcher</code></td><td><code>lcsr-researcher</code> → Codex</td></tr>
        <tr><td><code>evaluator</code></td><td><code>lcsr-evaluator</code> → Claude</td></tr>
      </tbody>
    </table>
    <div class="loop-example-note">每一条 mapping 同时指向 profile config、definition、memo seed、notifier prompt 和 assigned skills。</div>
  </div>
</div>

</div>

---

# `execplan-finalize`

<div class="text-[15px] leading-snug mt-5">

- **定位**：整理 execplan package，让它可以被阅读、校验和执行。
- **输入**：已经生成的 specs、harness、skills 和 agent bindings。
- **边界**：docs 解释 package，但 source authority 仍然是 specs 和 contracts。

<div class="option-side-title" style="margin: 0.85rem 0 0.45rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.05rem; font-weight: 700; line-height: 1.2;">final package 文件组</div>

| 文件组 | 作用 |
| --- | --- |
| `execplan/manifest.toml` | final artifact index：路径、artifact kind、plan revision、generated-source posture、omissions |
| `execplan/docs/artifact-index.md` | 给人快速查 package 里有什么，每个 artifact 去哪里读 |
| `operator-guide.md`、`runtime-model.md`、`validation.md` | 总结如何操作、runtime 如何被 notifier/mail/skills 驱动、validation posture 是什么 |

</div>

---

# Example: execplan-finalize

<div class="text-[14px] leading-snug mt-4">

<div class="loop-example-grid">
  <div class="loop-example-panel">
    <div class="loop-example-label">You</div>
    <div class="loop-example-code">finalize execplan</div>
  </div>
  <div class="loop-example-panel">
    <div class="loop-example-label">AI</div>
    <div class="loop-example-code">Generated final support layer:<br><br>- manifest.toml<br>- docs/artifact-index.md<br>- docs/operator-guide.md<br>- docs/runtime-model.md<br>- docs/validation.md<br><br>Package is ready for validation.</div>
  </div>
</div>

</div>

---

# `validate-execplan`

<div class="text-[15px] leading-snug mt-5">

- **定位**：检查 execplan package 的结构、引用和 artifact 一致性。
- **输入**：完整或部分生成的 `execplan/`。
- **边界**：验证 package shape，不证明 live runtime 已经准备好。

<div class="option-side-title" style="margin: 0.85rem 0 0.45rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.05rem; font-weight: 700; line-height: 1.2;">检查对象</div>

| 文件组 | 检查什么 |
| --- | --- |
| `manifest.toml` | package 是否可索引、路径是否存在、omission 是否被记录 |
| `execplan/specs/**` | process authority、contracts、topology、comms、state、workspace、run 是否一致 |
| `harness/**`、`skills/**`、`agents/**` | command registry、generated skills、agent bindings 是否符合约定且互相引用正确 |
| validation report | 报告缺失文件、parse/link failures、stale markers 和是否可进入 execution preparation |

</div>

---

# Example: validate-execplan

<div class="text-[14px] leading-snug mt-4">

<div class="loop-example-grid">
  <div class="loop-example-panel">
    <div class="loop-example-label">You</div>
    <div class="loop-example-code">validate execplan</div>
  </div>
  <div class="loop-example-panel">
    <div class="loop-example-label">AI</div>
    <div class="loop-example-code">
      <div class="tmux-response-title">Validation summary</div>
      <table class="tmux-table">
        <thead>
          <tr>
            <th class="tmux-col-medium">Check</th>
            <th class="tmux-col-wide">Result</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>manifest paths</td>
            <td>ok</td>
          </tr>
          <tr>
            <td>TOML / JSON / SQL</td>
            <td>ok</td>
          </tr>
          <tr>
            <td>harness self-check</td>
            <td>ok</td>
          </tr>
          <tr>
            <td>binding/profile consistency</td>
            <td>ok</td>
          </tr>
          <tr>
            <td>live profile readiness</td>
            <td>missing credentials/profiles</td>
          </tr>
        </tbody>
      </table>
      <div class="tmux-response-text">Next: clarify CLI credentials, then prepare-agents.</div>
    </div>
  </div>
</div>

</div>

---

# `clarify-execplan`

<div class="text-[15px] leading-snug mt-5">

- **定位**：在 execplan 已生成后，处理 implementation-level 的歧义。
- **输入**：现有 `execplan/`、validation 结果和 operator 的修正意图。
- **边界**：只改 execplan 层的歧义，不重新定义原始目标，除非同步回 intention。

<div class="option-side-title" style="margin: 0.85rem 0 0.45rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.05rem; font-weight: 700; line-height: 1.2;">可能更新的文件组</div>

| 文件组 | 作用 |
| --- | --- |
| `execplan/adrs/*.md` | 记录 accepted execplan implementation decisions，以及影响哪些 generated artifacts |
| `execplan/specs/**`、`harness/**`、`skills/**`、`agents/**` | 修正 contracts、commands、skill trigger/procedure、agent binding 或 notifier prompt |
| stale-artifact notes | 标出受影响的下游 artifacts：哪些已更新，哪些需要 regeneration 或已经 stale |

</div>

---

# Example: clarify-execplan

<div class="text-[14px] leading-snug mt-4">

<div class="loop-example-grid">
  <div class="loop-example-panel">
    <div class="loop-example-label">You</div>
    <div class="loop-example-code">clarify the workspace execplan</div>
  </div>
  <div class="loop-example-panel">
    <div class="loop-example-label">AI</div>
    <div class="loop-example-code">
      <div class="tmux-response-title">Question: Workspace Materialization</div>
      <table class="tmux-table">
        <thead>
          <tr>
            <th class="tmux-col-narrow">Option</th>
            <th class="tmux-col-wide">Decision</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>A</td>
            <td>Recommended: in-repo Git worktrees, one private repo/ per <code>lcsr-*</code> agent.</td>
          </tr>
          <tr>
            <td>B</td>
            <td>Shared repo with per-agent states only.</td>
          </tr>
          <tr>
            <td>C</td>
            <td>External workspaces outside the repo.</td>
          </tr>
        </tbody>
      </table>
      <div class="tmux-response-text">After answer: record execplan ADR, update workspace contract and final docs.</div>
    </div>
  </div>
</div>

</div>

---

# `update-execplan`

<div class="text-[15px] leading-snug mt-5">

- **定位**：当 intention 或 contract 变化时，从最早受影响阶段向后刷新。
- **输入**：变更后的 source material，以及要保留或重生成的 artifact 范围。
- **边界**：避免盲目全量重写，重点是保持 artifact dependency 一致。

<div class="option-side-title" style="margin: 0.85rem 0 0.45rem; padding-bottom: 0.2rem; border-bottom: 1px solid #cbd5e1; color: #0f172a; font-size: 1.05rem; font-weight: 700; line-height: 1.2;">按影响范围刷新</div>

| 最早受影响文件组 | 后续动作 |
| --- | --- |
| `execplan/specs/collab/collab-overview.md` | process 变了，重跑 contracts、harness、skills、bindings、finalize |
| `execplan/specs/**` contracts | contracts 变了，重跑 harness、skills、bindings、finalize |
| `execplan/harness/**` 或 `execplan/skills/**` | 命令或 agent procedure 变了，重跑下游 skills/bindings/docs |
| `execplan/agents/**`、`docs/**`、`manifest.toml` | 只刷新 concrete bindings 或 final package material，并最后 `validate-execplan` |

</div>

---

# Example: update-execplan

<div class="text-[14px] leading-snug mt-4">

<div class="loop-example-grid loop-example-grid-wide-ai">
  <div class="loop-example-panel">
    <div class="loop-example-label">You</div>
    <div class="loop-example-code">$houmao-agent-loop-pro update-execplan teams/lead-code-synth-research<br><br>intention/workspace.md changed: use in-repo worktrees.</div>
  </div>
  <div class="loop-example-panel">
    <div class="loop-example-label">AI</div>
    <div class="loop-example-code">
      <div class="tmux-response-title">Impact plan</div>
      <table class="tmux-table tmux-impact-table">
        <thead>
          <tr>
            <th class="tmux-col-medium">Changed area</th>
            <th class="tmux-col-medium">Earliest stage</th>
            <th class="tmux-col-wide">Refresh</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>intention/workspace.md</td>
            <td>execplan-specs-contract</td>
            <td>workspace, harness refs, skills, bindings, docs</td>
          </tr>
          <tr>
            <td>collab-overview.md</td>
            <td>execplan-specs-process</td>
            <td>all downstream artifacts</td>
          </tr>
          <tr>
            <td>agents/bindings.toml</td>
            <td>execplan-agent-bindings</td>
            <td>profiles, notifier prompts, final docs</td>
          </tr>
        </tbody>
      </table>
      <div class="tmux-response-text">Run validate-execplan last.</div>
    </div>
  </div>
</div>

<div class="loop-example-note">Recording 中没有单独的 <code>update-execplan</code> run；这个 slide 展示同类 refresh 逻辑。相关 workspace clarification snapshots: <code>s008400</code> → <code>s008560</code>。</div>

</div>

---
layout: section
---

# Agent Loop Pro Execution

从 execplan package 准备、启动、运行和恢复 live Houmao agents。

---

# `prepare-agents`

<div class="text-[15px] leading-snug mt-5">

- **定位**：把 generated agent material 转成可启动的 Houmao agent 准备状态。
- **输入**：`execplan/agents/`、generated skills、notifier prompts 和 memo seeds。
- **输出**：specialists、launch profiles、已安装 skills 和准备报告。
- **边界**：只准备 agent 材料，不启动 CLI 进程。

<div class="loop-example-grid loop-example-grid-side">
  <div class="loop-example-panel">
    <div class="loop-example-label">You</div>
    <div class="loop-example-code">$houmao-agent-loop-pro prepare-agents teams/lead-code-synth-research</div>
  </div>
  <div class="loop-example-panel">
    <div class="loop-example-label">AI</div>
    <div class="loop-example-code">
      <div class="tmux-response-title">Prepared agents: ready.</div>
      <div class="tmux-response-text">Created six specialists/profiles. Registered generated + runtime skills, memo seeds, notifier appendices, and repo-root workdir.</div>
      <table class="tmux-table tmux-agent-status-table">
        <thead>
          <tr>
            <th>Agent</th>
            <th>Launch / credential</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          <tr><td><code>lcsr-planner</code></td><td>tui / <code>claude-kimi-cred</code></td><td>ready, not launched</td></tr>
          <tr><td><code>lcsr-cuda-coder-1</code></td><td>tui / <code>codex-pro</code></td><td>ready, not launched</td></tr>
          <tr><td><code>lcsr-cuda-coder-2</code></td><td>tui / <code>codex-pro</code></td><td>ready, not launched</td></tr>
          <tr><td><code>lcsr-synthesizer</code></td><td>tui / <code>codex-pro</code></td><td>ready, not launched</td></tr>
          <tr><td><code>lcsr-researcher</code></td><td>tui / <code>codex-pro</code></td><td>ready, not launched</td></tr>
          <tr><td><code>lcsr-evaluator</code></td><td>tui / <code>claude-kimi-cred</code></td><td>ready, not launched</td></tr>
        </tbody>
      </table>
    </div>
  </div>
</div>

</div>

---

# `prepare-workspace`

<div class="text-[15px] leading-snug mt-5">

- **定位**：按照 workspace contract 准备每个 agent 需要操作的工作区。
- **输入**：workspace contract、agent bindings 和 repo-local 约束。
- **输出**：workspace directories、state links、初始化文件和 workspace readiness report。
- **边界**：只处理 workspace 姿态，不代表 mail、gateway 或 agents 已就绪。

<div class="loop-example-grid loop-example-grid-side">
  <div class="loop-example-panel">
    <div class="loop-example-label">You</div>
    <div class="loop-example-code">$houmao-agent-loop-pro prepare-workspace teams/lead-code-synth-research</div>
  </div>
  <div class="loop-example-panel">
    <div class="loop-example-label">AI</div>
    <div class="loop-example-code">Materialized in-repo worktrees under <code>houmao-ws/lead-code-synth-research</code>.<br><br>Each agent gets a private <code>repo/</code> worktree and <code>states/</code> directory.<br><br>Shared owner-state and workspace docs are ready.</div>
  </div>
</div>

</div>

---

# `validate-loop`

<div class="text-[15px] leading-snug mt-5">

- **定位**：在 launch 前验证整个 loop 的 runtime readiness。
- **输入**：execplan package、prepared agents、workspace、mailbox、gateway 和 harness 状态。
- **输出**：pre-launch validation report，以及可以阻塞启动的问题清单。
- **边界**：这是运行前检查，不会替 operator 自动修复所有 runtime 问题。

<div class="loop-example-grid loop-example-grid-side">
  <div class="loop-example-panel">
    <div class="loop-example-label">You</div>
    <div class="loop-example-code">$houmao-agent-loop-pro validate-loop teams/lead-code-synth-research</div>
  </div>
  <div class="loop-example-panel">
    <div class="loop-example-label">AI</div>
    <div class="loop-example-code">Validation Result<br><br>Ready with warnings. No blockers found for <code>launch-agents</code>.<br><br>Checked: manifest, harness, mail schemas, profiles, skills and workspace readiness.<br><br>Warnings: mailbox accounts are launch-created; <code>NCU_ROOT_PW</code> is unset.</div>
  </div>
</div>

</div>

---

# `launch-agents`

<div class="text-[15px] leading-snug mt-5">

- **定位**：启动 execplan 定义的 Houmao managed agents。
- **输入**：prepared launch profiles、workspace facts、mailbox 和 gateway 配置。
- **输出**：live agent ids、CLI 进程信息、gateway attachment 和 launch report。
- **边界**：启动 agents，但不一定发送 first trigger。

<div class="loop-example-grid loop-example-grid-side">
  <div class="loop-example-panel">
    <div class="loop-example-label">You</div>
    <div class="loop-example-code">$houmao-agent-loop-pro launch-agents teams/lead-code-synth-research</div>
  </div>
  <div class="loop-example-panel">
    <div class="loop-example-label">AI</div>
    <div class="loop-example-code">Launched the managed agents and recorded live agent ids.<br><br>Gateway attachment and CLI process posture are captured for later inspection.<br><br>No first trigger is sent until start.</div>
  </div>
</div>

</div>

---

# Run / Runtime Control Commands

<div class="text-[14px] leading-snug mt-5">

从 `start` 开始，我们只把 execution commands 当作 runtime control surface 总览，不展开运行细节。

| command | 作用 |
| --- | --- |
| `start` | 正式开始一次 run：初始化 state，发送 first trigger mail 或 prompt，记录 run log 起点 |
| `status` | 只读查看 phase、open events、pending mail、agent 状态和最近 artifact 更新 |
| `pause` | 暂停自动推进或 notifier wakeup 姿态，保留 agents、workspace 和 run artifacts |
| `resume` | 从 paused state 恢复推进，并给出下一步触发计划 |
| `recover` | 处理中断、部分 handoff、失败 setup 或 runtime posture 不一致 |
| `stop` | 停止 loop runtime 和相关 managed agents，同时保留历史 run artifacts |

</div>

---
layout: image
image: ''
class: p-0
---

<div class="h-full w-full bg-black flex items-center justify-center">
  <video
    src="../assets/lcsr-tmux-viewer-window-20x.mp4"
    class="h-full w-full object-contain"
    autoplay
    muted
    loop
    playsinline
    controls
  />
</div>
