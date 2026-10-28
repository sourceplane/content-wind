# content-wind — where this repository stands

The entry page for anyone (or any agent) picking this repository up. It is
this repository's own state and does not ship to a site built from it; the
two pages that do are [operations.md](operations.md) and
[deployment.md](deployment.md).

## What it is

Vercel's Content Wind template (atinux/content-wind at `f0e56c9`) — a
personal website written in Markdown, built with Nuxt Content, Tailwind CSS
and Iconify — on Cloudflare Workers + Static Assets through Nitro's
`cloudflare_module` preset, every page prerendered and Nuxt Content's
queries on a D1 database Terraform provisions per environment (docus's
seam), packaged as an Orun baseline: `orun new --blueprint
repo-blueprint.yaml` builds a new site in its own repository and takes it to
live on stage and prod in one landing (`01-product`: cloudflare-d1 → web per
environment), then records what went live (`02-docs`). Workers Free is
enough.

## Release

| | |
|---|---|
| Latest tag | `baseline-v1` — CW0 to CW2: the repository, Content Wind on Workers and D1, and the baseline (blueprint, phases, tests) |
| Proven live | Not yet: proven offline in Baseline CI only (risk CW-A) |

## Where to read

| Question | Page |
|---|---|
| What shipped, and every departure from upstream | `specs/epics/content-wind/IMPLEMENTATION-STATUS.md` |
| Why it is built this way | [decisions.md](decisions.md), then `specs/epics/content-wind/design.md` |
| What could still go wrong | [open-risks.md](open-risks.md), then `specs/epics/content-wind/risks-and-open-questions.md` |
| How to instantiate it | `BOOTSTRAP.md`, `docs/phases/` |
| What the components are | each component's `docs/` (generated; `python3 tooling/catalog/gen-component-docs.py`) |

## Next

1. Bootstrap one site from `baseline-v1` and record the timings against the
   6-minute estimate (closes CW-A); then the registry row goes public with
   the measured minutes.
