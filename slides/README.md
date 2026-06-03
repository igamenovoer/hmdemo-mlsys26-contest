# Slides

This directory collects Slidev decks and design notes for presenting this demo package.

## Layout

- `pages/`: Slidev Markdown decks. Start new decks here, one `.md` file per talk or walkthrough.
- `design/`: Design notes for deck goals, audience, narrative arc, visual direction, and open questions.

## Current Decks

- `pages/demo-package-intro.md`: A short introduction to this MLSys 2026 FlashInfer contest demo package and the Houmao-assisted CUDA optimization workflow it demonstrates.

## Installation

Use Bun for Slidev dependencies. From the repository root, run:

```bash
cd slides
bun install
```

If your shell has proxy variables set and you want the repo-supported install path that clears them for Bun, use:

```bash
pixi run slides-install
```

This writes `slides/bun.lock` and installs local dependencies under `slides/node_modules/`.

## Running a Deck

From the repository root, run the default deck through Pixi:

```bash
pixi run slides
```

Or run it directly from `slides/` with Bun:

```bash
bun run dev
```

Build or export the deck with:

```bash
pixi run slides-build
pixi run slides-export
```

Use the matching design note in `slides/design/` when editing a deck so the story, audience, and visuals stay aligned.
