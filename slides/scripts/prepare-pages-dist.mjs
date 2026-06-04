import fs from 'node:fs'
import crypto from 'node:crypto'
import path from 'node:path'

const base = '/hmdemo-mlsys26-contest/'
const dist = path.resolve('dist')
const indexPath = path.join(dist, 'index.html')

const normalizer = `<script>(function(){var base='${base}';var legacy='#'+base;function normalize(){if(location.hash.indexOf(legacy)===0){location.replace(base+'#/'+location.hash.slice(legacy.length)+location.search);return true}if(location.pathname.indexOf(base)===0&&location.pathname!==base&&!location.hash){var rest=location.pathname.slice(base.length);if(rest.charAt(rest.length-1)==='/')rest=rest.slice(0,-1);if(rest){location.replace(base+'#/'+rest+location.search);return true}}return false}normalize();addEventListener('hashchange',normalize)})();</script>`

const indexAsset = fs.readdirSync(path.join(dist, 'assets'))
  .find(file => /^index-.*\.js$/.test(file))

if (!indexAsset)
  throw new Error('Could not find built Slidev index asset')

const bundle = fs.readFileSync(path.join(dist, 'assets', indexAsset), 'utf8')
const routePathNeedle = `return\`${base}\${`
const patchedBundle = bundle.replace(routePathNeedle, 'return`/${')

if (patchedBundle === bundle)
  throw new Error('Could not patch Slidev getSlidePath base prefix')

const assetHash = crypto.createHash('sha256').update(patchedBundle).digest('base64url').slice(0, 8)
const patchedIndexAsset = indexAsset.replace(/index-[^.]+\.js$/, `index-${assetHash}.js`)

if (patchedIndexAsset !== indexAsset)
  fs.renameSync(path.join(dist, 'assets', indexAsset), path.join(dist, 'assets', patchedIndexAsset))

fs.writeFileSync(path.join(dist, 'assets', patchedIndexAsset), patchedBundle)
rewriteAssetReferences(path.join(dist, 'assets'), indexAsset, patchedIndexAsset)

const indexHtml = fs.readFileSync(indexPath, 'utf8')
  .replaceAll(indexAsset, patchedIndexAsset)
const patchedHtml = indexHtml.includes("var legacy='#'+base")
  ? indexHtml
  : indexHtml.replace('</head>', `${normalizer}</head>`)

fs.writeFileSync(indexPath, patchedHtml)
fs.writeFileSync(path.join(dist, '404.html'), patchedHtml)

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

for (const route of routes) {
  const routePath = path.join(dist, ...route.split('/'))
  fs.mkdirSync(routePath, { recursive: true })
  fs.writeFileSync(path.join(routePath, 'index.html'), redirectHtml(route))
}

fs.writeFileSync(path.join(dist, '.nojekyll'), '')

function redirectHtml(route) {
  const target = `${base}#/${route}`
  return `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Redirecting...</title><script>location.replace(${JSON.stringify(target)}+location.search)</script><meta http-equiv="refresh" content="0;url=${target}"></head><body><a href="${target}">Continue to slides</a></body></html>`
}

function rewriteAssetReferences(dir, from, to) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const filePath = path.join(dir, entry.name)
    if (entry.isDirectory()) {
      rewriteAssetReferences(filePath, from, to)
      continue
    }
    if (!entry.name.endsWith('.js'))
      continue
    const content = fs.readFileSync(filePath, 'utf8')
    if (content.includes(from))
      fs.writeFileSync(filePath, content.replaceAll(from, to))
  }
}
