#!/usr/bin/env bash
# THE REBRAND WRITES EACH VALUE ONCE, AND WHAT IT WROTE STAYS WRITTEN.
#
# Drives the real tooling/rebrand/rebrand.mjs over one-file trees and compares
# the file. Each case is a shape this baseline's identity actually takes in the
# tree — the source link, the site-name seam, the worker name in the component
# and the wrangler config, the D1 database names and the terraform `repo` they
# are built from, the placeholder domain, a secret ref, the navbar's GitHub
# link, and the upstream's own `content-wind` (its repository, linked from the
# demo content, and the theme's comment) that must survive — and the
# survival cases run through three passes, so a value an earlier rebrand
# wrote (a re-run phase re-runs the rebrand over everything placed) comes
# out of every later one unchanged.
#
# The identity is PINNED (fixtures/baseline-identity.content-wind.json)
# rather than read from .baseline/identity.json: what this tests is the engine,
# and its fixtures spell the identity out literally.
#
# Needs: node, git. No network.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
rebrand="$here/../tooling/rebrand/rebrand.mjs"
identity="$here/fixtures/baseline-identity.content-wind.json"

fail=0
# check NAME VALUES-JSON FILE CONTENT WANT [PASSES]
check() {
  local name="$1" values="$2" file="$3" content="$4" want="$5" passes="${6:-1}"
  local tmp got out i
  tmp="$(mktemp -d)"
  git -C "$tmp" init -q
  mkdir -p "$tmp/$(dirname "$file")" "$tmp/.rebrand"
  printf '%s\n' "$content" > "$tmp/$file"
  printf '%s\n' "$values" > "$tmp/.rebrand/values.json"
  for ((i = 1; i <= passes; i++)); do
    git -C "$tmp" add -A
    if ! out="$(cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --values .rebrand/values.json --allow-dirty 2>&1)"; then
      echo "   ✕  $name: rebrand pass $i failed:" >&2
      printf '%s\n' "$out" | sed 's/^/        /' >&2
      fail=1
      rm -rf "$tmp"
      return
    fi
  done
  got="$(cat "$tmp/$file")"
  rm -rf "$tmp"
  if [ "$got" = "$want" ]; then
    echo "   ok  $name"
  else
    echo "   ✕  $name:" >&2
    echo "        got:  $got" >&2
    echo "        want: $want" >&2
    fail=1
  fi
}

acme='{"reponame":"acme-site","productname":"Acme Site","productdomain":"acme.dev","githuborg":"acme-inc","subdomain":"acme","orunWorkspace":"ws_79BDXAZQ"}'

echo "── rebrand: the site's own identity"
check "the source link names the product's owner and repository" \
  "$acme" README.md \
  'Source: https://github.com/sourceplane/content-wind' \
  'Source: https://github.com/acme-inc/acme-site'
check "the site-name seam takes the product's name" \
  "$acme" apps/web/site.ts 'export const SITE_NAME = "Content Wind"' \
  'export const SITE_NAME = "Acme Site"'
check "…and stays a valid string for a name with an apostrophe and an ampersand" \
  '{"reponame":"sams-site","productname":"Sam'"'"'s Site & Notes","productdomain":"sam.dev"}' \
  apps/web/site.ts 'export const SITE_NAME = "Content Wind"' \
  'export const SITE_NAME = "Sam'"'"'s Site & Notes"'
check "the navbar links the product's own repository" \
  "$acme" apps/web/app/app.config.ts "    github: 'sourceplane/content-wind'," \
  "    github: 'acme-inc/acme-site',"
check "the template's own name in its demo content is content, and is left alone" \
  "$acme" apps/web/content/1.index.md '# Content Wind' \
  '# Content Wind'
check "the template's repository in its demo content keeps its name" \
  "$acme" apps/web/content/1.index.md 'href: https://stackblitz.com/github/Atinux/content-wind/?file=content%2F1.index.md' \
  'href: https://stackblitz.com/github/Atinux/content-wind/?file=content%2F1.index.md'
check "…in the init command, any case" \
  "$acme" apps/web/content/1.index.md 'npx nuxi init -t github:atinux/content-wind my-website' \
  'npx nuxi init -t github:atinux/content-wind my-website'
check "…and in the deploy buttons' encoded URLs" \
  "$acme" apps/web/content/1.index.md '[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https%3A%2F%2Fgithub.com%2Fatinux%2Fcontent-wind)' \
  '[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https%3A%2F%2Fgithub.com%2Fatinux%2Fcontent-wind)'
check "the content config's comment about the theme is the template's" \
  "$acme" apps/web/content.config.ts '     * This is collection for content-wind theme' \
  '     * This is collection for content-wind theme'
check "the worker name is re-prefixed, the environment suffix kept" \
  "$acme" apps/web/component.yaml 'workerName: content-wind-web' \
  'workerName: acme-site-web'
check "the wrangler config's worker name, template and render alike" \
  "$acme" apps/web/wrangler.template.jsonc '  "name": "content-wind-web",' \
  '  "name": "acme-site-web",'
check "the environment URLs: worker name and subdomain" \
  "$acme" intent.yaml '    url: https://content-wind-web-stage.your-workers-subdomain.workers.dev' \
  '    url: https://acme-site-web-stage.acme.workers.dev'
check "the D1 root's terraform repo — every database name is built on it" \
  "$acme" infra/terraform/cloudflare-d1/terraform/main.tf '  default = "content-wind"' \
  '  default = "acme-site"'
check "the per-environment terraform repo parameter" \
  "$acme" intent.yaml '        repo: content-wind' \
  '        repo: acme-site'
check "the D1 root's own repo parameter" \
  "$acme" infra/terraform/cloudflare-d1/component.yaml '    repo: content-wind' \
  '    repo: acme-site'
check "a fixture's database name follows the same rule" \
  "$acme" apps/web/wiring.fixture.json '    "d1_database_name": "stg-content-wind-stage"' \
  '    "d1_database_name": "stg-acme-site-stage"'
check "the placeholder domain is the product's domain, not a renamed slug" \
  "$acme" intent.yaml '      BASE_DOMAIN: content-wind.example.com' \
  '      BASE_DOMAIN: acme.dev'
check "no domain given: the reserved placeholder, for an owner to replace later" \
  '{"reponame":"acme-site","productname":"Acme Site","githuborg":"acme-inc","subdomain":"acme"}' \
  intent.yaml '      BASE_DOMAIN: content-wind.example.com' \
  '      BASE_DOMAIN: acme-site.example.com'
check "an empty domain is no domain" \
  '{"reponame":"acme-site","productname":"Acme Site","productdomain":""}' \
  intent.yaml '      BASE_DOMAIN: content-wind.example.com' \
  '      BASE_DOMAIN: acme-site.example.com'
check "the repo slug" \
  "$acme" package.json '  "name": "content-wind",' \
  '  "name": "acme-site",'
check "a wiring secret ref names the product's workspace and project" \
  "$acme" apps/web/component.yaml \
  '    WIRING_CLOUDFLARE_D1_STAGE: "secret://content-wind/content-wind/stage/WIRING_CLOUDFLARE_D1"' \
  '    WIRING_CLOUDFLARE_D1_STAGE: "secret://ws_79BDXAZQ/acme-site/stage/WIRING_CLOUDFLARE_D1"'
check "a templated provider secret ref too (the D1 token the root binds)" \
  "$acme" infra/terraform/cloudflare-d1/component.yaml \
  '    CLOUDFLARE_API_TOKEN: "secret://content-wind/content-wind/{{ .environment }}/CLOUDFLARE_D1_TOKEN"' \
  '    CLOUDFLARE_API_TOKEN: "secret://ws_79BDXAZQ/acme-site/{{ .environment }}/CLOUDFLARE_D1_TOKEN"'
check "org-owned identity is not renamed" \
  "$acme" intent.yaml 'apiVersion: sourceplane.io/v1 # mail ops@sourceplane.ai' \
  'apiVersion: sourceplane.io/v1 # mail ops@sourceplane.ai'
check "without githuborg the source link keeps the baseline's owner" \
  '{"reponame":"acme-site","productname":"Acme Site","productdomain":"acme.dev"}' \
  README.md 'Source: https://github.com/sourceplane/content-wind' \
  'Source: https://github.com/sourceplane/acme-site'

echo "── rebrand: a written value is not rewritten, in any later pass"
contains='{"reponame":"content-wind-2","productname":"Content Wind 2","productdomain":"content-wind.example.com.au","githuborg":"sourceplane","subdomain":"your-workers-subdomain-2"}'
check "a repo slug containing the baseline's slug survives three passes" \
  "$contains" package.json '  "name": "content-wind",' \
  '  "name": "content-wind-2",' 3
check "a worker name built on it survives three passes" \
  "$contains" apps/web/component.yaml 'workerName: content-wind-web' \
  'workerName: content-wind-2-web' 3
check "a database name built on it survives three passes" \
  "$contains" apps/web/wiring.fixture.json '"d1_database_name": "prod-content-wind-prod"' \
  '"d1_database_name": "prod-content-wind-2-prod"' 3
check "a domain containing the baseline's domain survives three passes" \
  "$contains" intent.yaml 'BASE_DOMAIN: content-wind.example.com' \
  'BASE_DOMAIN: content-wind.example.com.au' 3
check "a subdomain containing the placeholder survives three passes" \
  "$contains" apps/web/component.yaml 'workersDevSubdomain: your-workers-subdomain' \
  'workersDevSubdomain: your-workers-subdomain-2' 3
check "a site name containing the baseline's name survives three passes" \
  "$contains" apps/web/site.ts 'export const SITE_NAME = "Content Wind"' \
  'export const SITE_NAME = "Content Wind 2"' 3

# --verify runs in every phase. Without the product's values it cannot tell
# the product's own identity from a leftover; with them it can. A real
# leftover must fail it either way.
verify() { # NAME VALUES FILE CONTENT WANT(pass|fail) [--values]
  local name="$1" values="$2" file="$3" content="$4" want="$5" withvalues="${6:-}" tmp got
  tmp="$(mktemp -d)"
  git -C "$tmp" init -q
  mkdir -p "$tmp/$(dirname "$file")" "$tmp/.rebrand"
  printf '%s\n' "$content" > "$tmp/$file"
  printf '%s\n' "$values" > "$tmp/.rebrand/values.json"
  git -C "$tmp" add -A
  if (cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --verify ${withvalues:+--values .rebrand/values.json} >/dev/null 2>&1); then got=pass; else got=fail; fi
  rm -rf "$tmp"
  if [ "$got" = "$want" ]; then echo "   ok  $name"; else echo "   ✕  $name: --verify ${got}ed, want $want" >&2; fail=1; fi
}
echo "── rebrand --verify: the product's own identity is not residue"
verify "given the values, a slug containing the baseline's passes" \
  "$contains" package.json '"name": "content-wind-2"' pass --values
verify "without them it cannot know, and fails" \
  "$contains" package.json '"name": "content-wind-2"' fail
verify "given the values, a real leftover still fails" \
  "$acme" package.json '"name": "content-wind"' fail --values
verify "a leftover worker name fails" \
  "$acme" apps/web/wrangler.jsonc '"name": "content-wind-web",' fail --values
verify "a leftover database name fails" \
  "$acme" apps/web/wiring.fixture.json '"d1_database_name": "stg-content-wind-stage"' fail --values
verify "a leftover runner parameter fails" \
  "$acme" infra/terraform/cloudflare-d1/component.yaml '    repo: content-wind' fail --values
verify "a leftover code identifier fails (no rule renames it — so nothing may spell it)" \
  "$acme" apps/web/app/x.ts 'export class ContentWind {}' fail --values
verify "a clean product passes" \
  "$acme" package.json '"name": "acme-site"' pass --values

echo "── rebrand: a residue it cannot rename fails the rebrand itself"
tmp="$(mktemp -d)"; git -C "$tmp" init -q; mkdir -p "$tmp/.rebrand" "$tmp/apps/web"
printf '%s\n' "$acme" > "$tmp/.rebrand/values.json"
printf 'const x = "CONTENT_WIND_TOKEN"\n' > "$tmp/apps/web/x.ts"
git -C "$tmp" add -A
if (cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --values .rebrand/values.json --allow-dirty >/dev/null 2>&1); then
  echo "   ✕  an unrenamable env-var prefix passed the rebrand" >&2; fail=1
else
  echo "   ok  an unrenamable env-var prefix fails the rebrand, naming the file"
fi
rm -rf "$tmp"

[ "$fail" -eq 0 ] || exit 1
echo "rebrand.test.sh: ok"
