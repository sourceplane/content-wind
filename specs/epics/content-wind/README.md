# content-wind — Vercel's Content Wind template on Cloudflare

**Content Wind on Cloudflare alone — Nitro's Workers preset for Vercel's
Nuxt hosting, every page prerendered as a static asset, Nuxt Content's
queries on a D1 database the Worker binds — and the baseline that makes a
copy of it somebody else's personal website in one landing.**

| | |
|---|---|
| Status | In progress — CW0 on main |
| Upstream | [atinux/content-wind](https://github.com/Atinux/content-wind) (MIT), at `f0e56c9` (2026-10-23): Nuxt 4.6, Nuxt Content 3.16, Tailwind CSS 4, Nuxt Icon 2 |
| Reference | [docus](https://github.com/sourceplane/docus) — the same Nuxt Content → D1 seam; [turso-starter](https://github.com/sourceplane/turso-starter) — D1 and its wiring |
| Key | `CW` |

## Read in this order

1. [design.md](design.md) — the template, how each Vercel piece maps to
   Cloudflare, the repository and the build, and the alternative rejected.
2. [implementation-plan.md](implementation-plan.md) — the milestones.
3. [risks-and-open-questions.md](risks-and-open-questions.md) — what is not
   proven, and what was accepted.
4. [IMPLEMENTATION-STATUS.md](IMPLEMENTATION-STATUS.md) — what shipped, and
   every departure from the upstream template.

## Milestones

| Milestone | What it lands | Task |
|---|---|---|
| CW0 — the spec | the repository, its intent, CI, tooling and spec index; this doc set | CW-1 |
| CW1 — Content Wind on Workers and D1 | the template in `apps/web` on Nitro's Workers preset with Nuxt Content on D1, the D1 root, the tests | CW-2 |
| CW2 — a baseline | the console card, the build document, the context pack and the baseline's tests | CW-3 |
