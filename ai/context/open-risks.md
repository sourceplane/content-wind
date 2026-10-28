# content-wind — open risks

What is not yet proven or not yet decided. The full write-up of every risk,
including the accepted and resolved ones, is
`specs/epics/content-wind/risks-and-open-questions.md`; this page lists only what
is still live, so it should be short.

| ID | Risk | State | What closes it |
|---|---|---|---|
| CW-A | `baseline-v1` is not yet proven live; it is proven offline in Baseline CI (the offline bootstrap, the stage lane's own steps, the built Worker served by `wrangler dev` over an empty local D1: the pages, their payloads, Nuxt Content's query route answering from the table it created, the 404) | OPEN | One console bootstrap from `baseline-v1` |
| CW-E | Nuxt Content's query route is its own, unauthenticated, as upstream: it runs only the SELECTs its query builder writes, on the site's public content, and refuses anything else | WATCH | The e2e tier's refusal checks on every Nuxt Content bump |

Accepted, and worth knowing before you change them: CW-B (Nuxt Content
fills D1 on the first query), CW-C (an icon named only at runtime falls back
to a CDN fetch), CW-D (the build fetches its font from Google Fonts),
CW-F (stack-tectonic 0.19.0).
