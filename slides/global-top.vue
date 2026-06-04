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
