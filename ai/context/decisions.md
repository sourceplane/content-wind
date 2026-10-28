# content-wind — decisions

The choices that shape this repository, one line each, with where the full
reasoning lives. Superseded decisions stay listed, marked, so the history
reads in order.

| # | Decision | Why | Source |
|---|---|---|---|
| 1 | Content Wind at `f0e56c9`, its app, content and look unchanged, its dependencies pinned at the versions its lockfile resolves | The template Vercel lists, built the same every time | `specs/epics/content-wind/design.md` |
| 2 | Nitro's `cloudflare_module` preset, every page prerendered (crawled from `/`), `deployConfig: false` | Vercel's Nuxt hosting becomes one Worker + Static Assets; the committed `wrangler.jsonc` is the config (docus's shape) | design.md |
| 3 | A Worker, not a static `nuxt generate` | A page the build did not prerender, the 404 and Nuxt Content's query route need one; it is the seam docus uses, so the two Nuxt Content starters stay one shape | design.md, "The alternative rejected" |
| 4 | Nuxt Content's database is the D1 binding `DB`; no migrations | Nuxt Content creates and fills its tables from the bundled dump on the first query; the database holds nothing the repository does not | risk CW-B |
| 5 | Every icon the site names is bundled into the client | On an edge preset Nuxt Icon's server fetches whole icon collections from a CDN while it renders; the tests check the list covers every name | `apps/web/nuxt.config.ts`, `tests/web` |
| 6 | `html_handling: drop-trailing-slash` | Nuxt links pages without one; `/about` is served from `about/index.html` and `/about/` sent there | `apps/web/wrangler.template.jsonc` |
| 7 | `NUXT_SITE_URL` per environment: its `SITE_URL`, else its workers.dev URL, baked into the pages' Open Graph image and page URLs | Open Graph wants absolute URLs; upstream gave a relative image | `apps/web/component.yaml`, `apps/web/app/app.vue` |
| 8 | The site's name is `SITE_NAME` in `apps/web/site.ts`, written into every page's title (`<page> · <name>`) and the Open Graph site name | Upstream names the site nowhere but in its home page's heading; the seam must be one line | `apps/web/app/app.vue` |
| 9 | The identity's Pascal form is `ContentWind` (nothing spells it); the template's own `Atinux/content-wind` links and its theme comment are masked from the rename | The slug is the template's own name, and its demo content links its repository | `tooling/rebrand/rebrand.mjs` |
| 10 | The navbar's GitHub link is the site's own repository; the author's X, Mastodon and Bluesky handles are not carried | A product must not link its visitors to the template author's accounts | `apps/web/app/app.config.ts` |
| 11 | The smoke fetches `/` and asks Nuxt Content's query route to count the pages | The page is a static asset; only the Worker, querying D1, answers the route; the count does not depend on any page the owner keeps | IMPLEMENTATION-STATUS |
| 12 | Three brokered keys in one reconcile: `workers-deploy`, `d1-edit`, the account id | The deploy token cannot touch D1 | `repo-blueprint.yaml` |
| 13 | One landing (`01-product`) then the record (`02-docs`), each checked in the build box | turso-starter's shape: the plan carries the order (database, then Worker) | `docs/phases/README.md` |
| 14 | `ci.yml` plans nothing while `intent.yaml` names `ws_CHANGE_ME`; stack-tectonic 0.19.0 | As every sibling: a bootstrap cannot set a repository variable; the job-scoped install is the verified one | `.github/workflows/ci.yml`, `intent.yaml` |
| 15 | Component docs are generated from the manifests and checked in CI; orun is pinned only where it runs | A hand-written copy drifts silently | `tooling/catalog/gen-component-docs.py` |
| 16 | `subdomain` is read from the Cloudflare connection, never asked; the console asks for no domain | Both belong to the account or the owner, not to the build | `blueprint.yaml` |
