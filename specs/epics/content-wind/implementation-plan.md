# content-wind — implementation plan

Three milestones, each one reviewed pull request (CW0 is the repository's
first commit), each green before it merges.

## CW0 — the spec (CW-1)

The repository is born: `intent.yaml` with the placeholder workspace
`ws_CHANGE_ME`, `ci.yml` (byte for byte turso-starter's), the shared
TypeScript and ESLint configuration, the wiring renderer, the spec index,
this doc set and the task contracts.

## CW1 — Content Wind on Workers and D1 (CW-2)

- The template in `apps/web`: `app/`, `content/`, `public/`,
  `content.config.ts`, `eslint.config.mjs` and its LICENSE as they are;
  `nuxt.config.ts` with Nuxt Content on the D1 binding `DB`, the bundled
  icons, the origin, and Nitro's `cloudflare_module` preset with
  `deployConfig: false` and every page prerendered.
- `site.ts` (`SITE_NAME`) and `app.vue` writing it into the titles and the
  Open Graph site name; `app.config.ts` linking the site's own repository.
- `package.json`: upstream's dependencies at their locked versions, Vercel
  Analytics dropped, wrangler and vue-tsc added, `typecheck` and `lint`.
- `wrangler.template.jsonc` + `wiring.fixture.json`, `component.yaml`
  (deploy contract, `NUXT_SITE_URL` per environment, the smoke).
- The D1 root, from docus's (turso-starter's).
- `tests/web`: the site's name, the Workers and D1 configuration, the
  bundled icons, every page's title, layout and internal links.

## CW2 — a baseline (CW-3)

docus's machinery: `blueprint.yaml`, `repo-blueprint.yaml` (three brokered
keys), `.baseline/`, the rename engine (with the upstream's repository
masked and the navbar's link renamed), the bootstrap helpers, the record
renderer (probing `/` and Nuxt Content's query route), `docs/phases/`, the
context pack, and `testing/` — the leak, placement and wiring gates over
D1, and the e2e tier that builds the stage lane in its job tree and serves
the built Worker over an empty local D1: the pages and their payloads, the
query route answering from the table Nuxt Content filled and refusing
anything else, the 404.
