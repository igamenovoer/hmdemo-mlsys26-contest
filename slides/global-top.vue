<script setup>
import { computed } from 'vue'
import { useNav } from '@slidev/client'

const nav = useNav()

const anchorSpecs = [
  { label: '概览', no: 1 },
  { label: 'Multi-Agent 动机', title: '为什么需要 Multi Agent System?' },
  { label: '方案比较', title: '方案一：代码驱动框架' },
  { label: '使用场景', title: '要不要用 Houmao？' },
  { label: '核心概念', title: 'Houmao 核心概念' },
  { label: 'Loop Authoring', title: 'Agent Loop Pro Authoring' },
  { label: 'Loop Execution', title: 'Agent Loop Pro Execution' },
  { label: 'Reference', title: 'Reference Material' },
  { label: 'Toy Example', title: 'Toy Example' },
  { label: 'CUDA Example', title: 'CUDA Kernel 优化' },
]

const currentPage = computed(() => nav.currentPage.value)
const total = computed(() => nav.total.value)

function normalize(value) {
  return String(value ?? '').replace(/\s+/g, ' ').trim()
}

const sections = computed(() => {
  const titleToPage = new Map(
    nav.slides.value
      .map(slide => [normalize(slide.meta?.slide?.title), slide.no])
      .filter(([title]) => title),
  )

  return anchorSpecs
    .map((spec) => {
      const no = spec.no ?? titleToPage.get(normalize(spec.title))
      return no ? { no, label: spec.label } : undefined
    })
    .filter(Boolean)
    .sort((a, b) => a.no - b.no)
})

const currentSection = computed(() => {
  return sections.value.reduce((active, section) => {
    return section.no <= currentPage.value ? section : active
  }, sections.value[0])
})
</script>

<template>
  <footer class="hm-section-footer" aria-label="Current slide section">
    <div class="hm-current-section">
      <span class="hm-current-label">当前章节</span>
      <span class="hm-current-title">{{ currentSection?.label }}</span>
    </div>

    <div class="hm-page-count">
      {{ currentPage }} / {{ total }}
    </div>
  </footer>
</template>

<style scoped>
.hm-section-footer {
  position: absolute;
  right: 0;
  bottom: 0;
  left: 0;
  z-index: 1000;
  display: grid;
  grid-template-columns: minmax(0, 1fr) 58px;
  gap: 10px;
  align-items: center;
  height: 30px;
  padding: 0 16px;
  border-top: 1px solid rgba(148, 163, 184, 0.5);
  background: rgba(248, 250, 252, 0.94);
  box-shadow: 0 -8px 22px rgba(15, 23, 42, 0.08);
  color: #334155;
  font-size: 10.5px;
  line-height: 1;
  pointer-events: none;
}

.hm-current-section {
  display: flex;
  min-width: 0;
  align-items: baseline;
  gap: 6px;
}

.hm-current-label {
  color: #64748b;
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 0;
  text-transform: uppercase;
}

.hm-current-title {
  overflow: hidden;
  color: #0f172a;
  font-size: 11px;
  font-weight: 800;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.hm-page-count {
  color: #475569;
  font-size: 10px;
  font-variant-numeric: tabular-nums;
  text-align: right;
  white-space: nowrap;
}
</style>

<style>
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

.loop-example-grid-side {
  grid-template-columns: minmax(0, 1fr) minmax(0, 2fr);
  gap: 0.85rem;
}

.loop-example-grid-side .loop-example-panel {
  padding: 0.62rem;
}

.loop-example-grid-side .loop-example-code {
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
</style>
