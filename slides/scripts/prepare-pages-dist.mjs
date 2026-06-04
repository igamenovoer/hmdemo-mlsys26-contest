import fs from 'node:fs'
import path from 'node:path'

const base = '/hmdemo-mlsys26-contest/'
const dist = path.resolve('dist')
const indexPath = path.join(dist, 'index.html')

const normalizer = `<script>(function(){var base='${base}';var legacy='#'+base;if(location.hash.indexOf(legacy)===0){location.replace(base+'#/'+location.hash.slice(legacy.length)+location.search);return}if(location.pathname.indexOf(base)===0&&location.pathname!==base&&!location.hash){var rest=location.pathname.slice(base.length);if(rest.charAt(rest.length-1)==='/')rest=rest.slice(0,-1);if(rest)location.replace(base+'#/'+rest+location.search)}})();</script>`

const indexHtml = fs.readFileSync(indexPath, 'utf8')
const patchedHtml = indexHtml.includes("var legacy='#'+base")
  ? indexHtml
  : indexHtml.replace('</head>', `${normalizer}</head>`)

fs.writeFileSync(indexPath, patchedHtml)
fs.writeFileSync(path.join(dist, '404.html'), patchedHtml)

const indexAsset = fs.readdirSync(path.join(dist, 'assets'))
  .find(file => /^index-.*\.js$/.test(file))

if (!indexAsset)
  throw new Error('Could not find built Slidev index asset')

const bundle = fs.readFileSync(path.join(dist, 'assets', indexAsset), 'utf8')
const slideNumbers = [...bundle.matchAll(/\bno:(\d+)\b/g)].map(match => Number(match[1]))
const slideCount = Math.max(...slideNumbers)

if (!Number.isFinite(slideCount) || slideCount <= 0)
  throw new Error('Could not determine Slidev slide count')

const routes = [
  'entry',
  'overview',
  'notes',
  'notes-edit',
  'presenter',
]

for (let no = 1; no <= slideCount; no++) {
  routes.push(String(no))
  routes.push(`presenter/${no}`)
  routes.push(`export/${no}`)
}

function redirectHtml(route) {
  const target = `${base}#/${route}`
  return `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Redirecting...</title><script>location.replace(${JSON.stringify(target)}+location.search)</script><meta http-equiv="refresh" content="0;url=${target}"></head><body><a href="${target}">Continue to slides</a></body></html>`
}

for (const route of routes) {
  const routePath = path.join(dist, ...route.split('/'))
  fs.mkdirSync(routePath, { recursive: true })
  fs.writeFileSync(path.join(routePath, 'index.html'), redirectHtml(route))
}

fs.writeFileSync(path.join(dist, '.nojekyll'), '')
