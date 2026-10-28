# content-wind

Vercel's [Content Wind](https://github.com/Atinux/content-wind) template — a
personal website written in Markdown, built with Nuxt Content, Tailwind CSS
and Iconify: pages with layouts, navigation generated from them, meta tags,
light and dark mode, icons and highlighted code — running on **Cloudflare
Workers + Static Assets** through Nitro's `cloudflare_module` preset, every
page prerendered and Nuxt Content's queries on a **Cloudflare D1** database
Terraform provisions per environment, deployed by
[Orun](https://github.com/sourceplane/orun) to stage and prod on every merge.
Packaging it as an Orun baseline is the next milestone (CW2).

The port is Content Wind as upstream ships it (`atinux/content-wind` at
`f0e56c9`), its app, content and look unchanged: Vercel's Nuxt hosting
becomes Nitro's Workers preset, Nuxt Content's SQLite becomes the D1 binding
— which Nuxt Content creates its tables in and fills from the build's dump
on the first query, so there are no migrations — and the site's origin is
set per environment. It is the same Nuxt Content → D1 seam as
[docus](https://github.com/sourceplane/docus). See
[`specs/epics/content-wind`](specs/epics/content-wind/README.md) for the
design, the milestones and the as-built status.

## What is here (the product)

| Surface | Where |
|---|---|
| The pages (Markdown) and their images | `apps/web/content`, `apps/web/public` |
| The app: the navbar, the layouts, the catch-all page, the components Markdown uses | `apps/web/app` |
| The site's name | `apps/web/site.ts` |
| The navbar's links and the cover image | `apps/web/app/app.config.ts` |
| Nuxt Content on D1, the bundled icons, the Workers build | `apps/web/nuxt.config.ts` |
| Workers bindings and deploy contract | `apps/web/wrangler.template.jsonc` + `wiring.fixture.json` (→ the committed `wrangler.jsonc`), `component.yaml` |
| The D1 database (stage, prod) | `infra/terraform/cloudflare-d1` |
| The wrangler renderer | `tooling/wire` |
| Tests | `tests/web` (the site's name, its Workers and D1 configuration, its icons, every page's title, layout and internal links) |

## Getting started

```bash
pnpm install
pnpm run wire:fixture   # render apps/web/wrangler.jsonc from the offline fixture
pnpm typecheck
pnpm lint
pnpm test
pnpm build              # nuxt build → apps/web/.output (the Worker, and every page prerendered)
```

```bash
pnpm --filter @app/web dev       # http://localhost:3000 — the content in a local SQLite file
pnpm --filter @app/web preview   # wrangler dev over the built Worker, a local D1 behind DB
```

## How it maps to Vercel

| Vercel-side | Here |
|---|---|
| Zero-config Nuxt hosting | Nitro's `cloudflare_module` preset: one Worker (`.output/server/index.mjs`) + Static Assets (`.output/public`), `deployConfig: false` |
| Pages rendered per request | Every page prerendered by `nuxt build` (crawled from `/`) with its client payload, served as static assets; the Worker answers the rest |
| Nuxt Content's SQLite | The D1 `DB` binding (`content.database: { type: 'd1' }`); the id and name are rendered into `wrangler.jsonc` per environment from the Terraform root's wiring document. Nuxt Content creates and fills its tables from the build's dump on the first query |
| Nuxt Icon (served per request) | Every icon the site names bundled into the client; the server would otherwise fetch whole icon collections from a CDN while it renders |
| The site's origin (`VERCEL_URL`) | `NUXT_SITE_URL` per environment: its `SITE_URL` in `intent.yaml`, else its workers.dev URL — the pages' Open Graph image and page URLs |
| Vercel Analytics (`@vercel/analytics/nuxt`) | Not carried: Cloudflare's Web Analytics is the account owner's to turn on |
| Deploy on push | Orun applies the database and deploys `<repo>-web-{stage,prod}` on merge to `main` |
| "Deploy with Vercel" (clone the template) | `orun new --blueprint repo-blueprint.yaml` — a new repository, branded, deployed |

## How the database reaches the Worker

```
infra/terraform/cloudflare-d1 ──apply──► orun secret WIRING_CLOUDFLARE_D1 (stage, prod)
                                               ▼
apps/web  dependsOn cloudflare-d1 (enforced on main) · secretEnv WIRING_CLOUDFLARE_D1_<ENV>
  build:  tooling/wire/live.mjs → wrangler.jsonc with the environment's database id
          (dev, verify-only, renders the fixture) → nuxt build (NUXT_SITE_URL per environment)
  first query after the deploy: Nuxt Content creates its tables in D1 from the bundled dump
```

`wrangler.jsonc` is committed as the fixture render of
`wrangler.template.jsonc`, because the deploy lane's `verify-app-structure`
step checks the config exists before it builds; `testing/e2e.test.sh` fails
if the two disagree.

## CI

| Workflow | What it runs | Ships to a product |
|---|---|---|
| `ci.yml` | the Orun pipeline, and the only workflow a product carries: `orun plan --changed`, then one job per lane. A pull request runs the verify lanes (the site type-checked and its tests run, the site built and dry-deployed per environment), except the bootstrap's own landings (`orun/BASE-*`), where `plan` alone is the check; a merge applies the D1 database, then deploys stage → prod. It plans nothing while `intent.yaml` names the placeholder workspace `ws_CHANGE_ME`, as this repository does. A manual run (Orunbase's Deploy button, or Run workflow on `main`) plans the environment and components it names under the push-to-main trigger, so they deploy as a merge deploys them | yes |
