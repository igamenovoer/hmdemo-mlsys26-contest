# How to Publish the Slidev Deck on GitHub Pages

This deck is published from the `slides/` directory to GitHub Pages at `https://igamenovoer.github.io/hmdemo-mlsys26-contest/`.

## Official Slidev Rule

The Slidev hosting guide says GitHub Pages builds should use `slidev build` with a repository base path. For this repository, the base path is `/hmdemo-mlsys26-contest/`, so the official shape is:

```bash
cd slides
bunx slidev build slides.md --base /hmdemo-mlsys26-contest/
```

Reference: https://sli.dev/guide/hosting

The leading and trailing slashes matter. Without `--base /hmdemo-mlsys26-contest/`, generated assets and routes point at the GitHub Pages domain root instead of the repository site root.

## Current Repository Workflow

The current GitHub Actions workflow intentionally builds in hash-router mode because we want public slide URLs like `https://igamenovoer.github.io/hmdemo-mlsys26-contest/#/16`:

```bash
cd slides
bunx slidev build slides.md --base /hmdemo-mlsys26-contest/ --router-mode hash
node scripts/prepare-pages-dist.mjs
```

This is not the pure official GitHub Pages recipe. It is a compatibility variant for hash URLs.

## Why the Route Bug Happened

Slidev combines `--base /hmdemo-mlsys26-contest/` with its route helper. In hash-router mode, keyboard navigation can generate a hash route like `#/hmdemo-mlsys26-contest/17`, but the deck expects `#/17`. That mismatch makes Slidev show its internal 404 route.

Refreshing appeared to fix the page because our normalizer redirected the malformed hash back to the canonical hash route. The real fix is to prevent the bad hash from being generated during navigation.

## What `prepare-pages-dist.mjs` Does

`scripts/prepare-pages-dist.mjs` patches the built `dist/` output after Slidev runs:

- It rewrites Slidev's generated slide path helper so hash navigation produces `#/17`, not `#/hmdemo-mlsys26-contest/17`.
- It injects a normalizer into `index.html` and `404.html` so legacy malformed hashes and direct known paths redirect to canonical hash URLs.
- It creates route entry pages such as `dist/16/index.html` that redirect to `#/16`, avoiding a GitHub Pages 404 for known slide paths.
- It renames the patched main JavaScript asset with a content hash and rewrites chunk references so browsers do not keep using stale cached route code.
- It writes `.nojekyll` so GitHub Pages serves the Vite asset directory normally.

Because the script patches generated JavaScript, the asset rename step is important. If the patched bundle keeps Slidev's original hashed filename, browsers may reuse an old cached bundle and keep sending ArrowRight to the bad route.

## GitHub Actions Deployment

The workflow lives at `.github/workflows/pages.yml`. It checks out the repo, installs Bun dependencies in `slides/`, builds the deck, runs the post-build patch, uploads `slides/dist`, and deploys it with `actions/deploy-pages`.

The important build lines are:

```yaml
- run: bunx slidev build slides.md --base /hmdemo-mlsys26-contest/ --router-mode hash
- run: node scripts/prepare-pages-dist.mjs
```

## Local Verification

Run a clean build:

```bash
cd slides
rm -rf dist
bunx slidev build slides.md --base /hmdemo-mlsys26-contest/ --router-mode hash
node scripts/prepare-pages-dist.mjs
```

Serve it under the same repository base path GitHub Pages uses:

```bash
cd ..
rm -rf tmp/pages-check
mkdir -p tmp/pages-check
ln -s "$PWD/slides/dist" tmp/pages-check/hmdemo-mlsys26-contest
python3 -m http.server 4177 --bind 127.0.0.1 --directory tmp/pages-check
```

Open `http://127.0.0.1:4177/hmdemo-mlsys26-contest/#/16`, press ArrowRight, and confirm the browser lands on `http://127.0.0.1:4177/hmdemo-mlsys26-contest/#/17` without showing a 404.

## Live Verification

After a successful Pages deploy, test the production URL:

```text
https://igamenovoer.github.io/hmdemo-mlsys26-contest/#/16
```

Press ArrowRight. The expected URL is:

```text
https://igamenovoer.github.io/hmdemo-mlsys26-contest/#/17
```

The URL must not become:

```text
https://igamenovoer.github.io/hmdemo-mlsys26-contest/#/hmdemo-mlsys26-contest/17
```

If the live site still shows the old behavior right after deployment, first check whether GitHub Pages or the browser is serving cached HTML or JavaScript. The patched bundle should have a new `assets/index-*.js` filename after each route-helper patch.

## Simpler Alternative

If we stop requiring hash URLs, remove `--router-mode hash` and follow the official Slidev GitHub Pages recipe:

```bash
cd slides
bunx slidev build slides.md --base /hmdemo-mlsys26-contest/
```

That produces history-style URLs such as `/hmdemo-mlsys26-contest/16`. GitHub Pages cannot rewrite arbitrary SPA deep links by itself, so direct slide paths may still need generated route entry pages or a fallback `404.html`.
