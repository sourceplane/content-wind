#!/usr/bin/env bash
# TIER 2 — the product a bootstrap produces builds, deploys (dry) and serves.
#
# placement.test.sh proves the tree a bootstrap ends with is the right tree.
# This proves it WORKS, by doing to it what its own pipelines will:
#
#   1. at the 01-product landing (the commit its one pull request merges),
#      install with the lockfile the product ships, render the wrangler
#      fixture and check the committed config IS that render, typecheck,
#      lint, test, build. The landing's own PR runs `plan` alone (an
#      `orun/BASE-*` branch), so THIS is where a product those steps refuse
#      is caught: before the tag, not after a build has merged it;
#   2. the stage web lane's own steps, rendered by `orun plan` in the product
#      and run IN THE TREE THE RUNNER STAGES for the job
#      (testing/lib/stage-job.py), with the dependency layout the pinned
#      composition produces and with the job's secrets in its environment as
#      the platform resolves them (the component's secretEnv), from a pull
#      request's plan (the verify profile: the deploy profile has no dry run)
#      — `verify-app-structure` (which checks the wrangler config exists
#      BEFORE anything is built), `build-app` (the component's buildCommand:
#      the live wiring render, then the Nuxt build for the stage origin),
#      `verify-build-output` and `deploy-dry-run` (`wrangler deploy --dry-run
#      --name <reponame>-web-stage`): the database id in the built config
#      asserted to be the stage document's, not the fixture's, the pages
#      prerendered for the stage origin, and the Worker small enough for
#      Workers Free;
#   3. serve the built Worker with `wrangler dev` (an EMPTY local D1 behind
#      the same binding): the prerendered pages alone, served without the
#      Worker, fail the component's OWN `smokeCommand`; the Worker passes it,
#      verbatim — the check the real deploy ends with — Nuxt Content having
#      created and filled its tables in D1 on that first query; then every
#      route the site promises: the pages titled for the product, their Open
#      Graph URLs on the stage origin, the navbar linking the product's own
#      repository, the client's payloads, Nuxt Content's query route answering
#      from D1 and refusing anything but its own SELECTs, the local D1 holding
#      the pages, the favicon, a 404 the Worker renders.
#
# What it cannot do is the platform's half: create the repository, mint the
# brokered Cloudflare tokens, apply the database and deploy for real, and
# probe workers.dev. The D1 root is verified to `terraform validate` and its
# plan is part of every pull request's lanes; the apply needs an account.
#
# Needs: orun, node, pnpm, python3 (+PyYAML), git, curl, and the network for
# `pnpm install` and the build's fonts (or a warm store). A few minutes: two
# installs and two builds.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$here/lib/bootstrap.sh"

for bin in orun node pnpm python3 git curl; do
  command -v "$bin" >/dev/null || { echo "e2e.test.sh needs $bin on PATH" >&2; exit 1; }
done

scratch="$(mktemp -d)"
dev_pid=""
static_pid=""
# wrangler dev runs under pnpm, node and two workerd processes; a TERM to the
# first does not reach the rest, and waiting on it then never returns. So it is
# started as its own process group (setsid) and the whole group is stopped.
stop_group() {
  kill -TERM -- "-$1" 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$1" 2>/dev/null || break; sleep 0.5; done
  kill -KILL -- "-$1" 2>/dev/null || true
}
cleanup() {
  [ -z "$dev_pid" ] || stop_group "$dev_pid"
  [ -z "$static_pid" ] || stop_group "$static_pid"
  rm -rf "$scratch"
}
trap cleanup EXIT
values="$here/fixtures/acme.json"
repo="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['reponame'])" "$values")"
export CI=1 WRANGLER_SEND_METRICS=false NUXT_TELEMETRY_DISABLED=1 TURBO_TELEMETRY_DISABLED=1

# The landing's own checks, step for step: what a pull request in the product
# verifies through its lanes, run here at once on the whole tree.
LANDING_CHECKS=(
  "pnpm install --frozen-lockfile"
  "pnpm run wire:fixture"
  "git diff --exit-code"
  "pnpm typecheck"
  "pnpm lint"
  "pnpm test"
  "pnpm build"
)
checks() { # DIR LOG
  local dir="$1" log="$2" cmd
  for cmd in "${LANDING_CHECKS[@]}"; do
    echo "   \$ $cmd" | tee -a "$log"
    if ! (cd "$dir" && bash -c "$cmd") >> "$log" 2>&1; then
      echo "FAIL: \`$cmd\` failed in $dir" >&2; tail -40 "$log" >&2; return 1
    fi
  done
}

# A job's steps out of a plan, by component and environment: each step's
# script (named by its id, or by a fixed name for the composition steps this
# file runs), the job's path, its env and the names of its secrets.
extract() { # PLAN COMPONENT ENV OUTDIR
  python3 - "$@" <<'PY'
import json, pathlib, re, sys
plan, comp, env, out = json.load(open(sys.argv[1])), sys.argv[2], sys.argv[3], pathlib.Path(sys.argv[4])
out.mkdir(parents=True, exist_ok=True)
job = next(j for j in plan["jobs"] if j["component"] == comp and j["environment"] == env)
for s in job["steps"]:
    run = s.get("run") or ""
    if not run:
        continue
    sid = s["id"]
    (out / f"{re.sub(r'[^A-Za-z0-9_-]', '_', sid)}.sh").write_text(run)
    if s["id"] in ("install-workspace-dependencies", "install-dependencies"):
        (out / "install.sh").write_text(run)
        (out / "install.wd").write_text(s.get("working-directory") or ".")
        (out / "install.scope").write_text(s.get("scope") or "job")
(out / "path").write_text(job.get("path") or ".")
(out / "env").write_text("".join(f"export {k}={json.dumps(v)}\n" for k, v in (job.get("env") or {}).items()))
(out / "secrets").write_text("\n".join(r["asEnv"] for r in job.get("secretRefs") or []))
PY
}

# A job's private tree, staged as orun stages it. The source checkout carries
# no build output (nothing was built in it), and its dependencies are what the
# pinned composition says: a lane-scoped install ran once in the source tree
# and is linked in, or the job installs its own.
stage_job() { # STEPS-DIR WORK-DIR LOG
  local steps="$1" work="$2" log="$3"
  [ -f "$steps/install.sh" ] || { echo "FAIL: the lane has no install step" >&2; return 1; }
  if [ "$(cat "$steps/install.scope")" = lane ]; then
    (cd "$tree" && bash -e "$steps/install.sh") > "$log" 2>&1 \
      || { echo "FAIL: the lane's install step" >&2; tail -30 "$log" >&2; return 1; }
    python3 "$here/lib/stage-job.py" "$tree" "$work" --shared-deps
    [ -L "$work/node_modules" ] || { echo "FAIL: the staged tree's node_modules is not the lane's symlink" >&2; return 1; }
    echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: lane — node_modules → the source tree's"
  else
    python3 "$here/lib/stage-job.py" "$tree" "$work"
    echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: job — installing inside it"
    (cd "$work/$(cat "$steps/path")/$(cat "$steps/install.wd")" && bash -e "$steps/install.sh") > "$log" 2>&1 \
      || { echo "FAIL: the lane's install step" >&2; tail -30 "$log" >&2; return 1; }
    [ -d "$work/node_modules" ] && [ ! -L "$work/node_modules" ] \
      || { echo "FAIL: the job's install did not land inside its own tree" >&2; return 1; }
  fi
}

# One step, in the runner's per-job environment: the job's env (intent
# environment `env:`), its resolved secrets (exported by the caller) and
# ORUN_ENVIRONMENT; the step runs in the component's directory.
run_step() { # STEPS-DIR WORK-DIR STEP LOG
  local steps="$1" work="$2" step="$3" log="$4"
  [ -f "$steps/$step.sh" ] || { echo "FAIL: the stage lane has no $step step" >&2; return 1; }
  echo "   ▸ $step"
  if ! (cd "$work/$(cat "$steps/path")" && source "$steps/env" && export ORUN_ENVIRONMENT=stage \
        && bash -e "$steps/$step.sh") > "$log" 2>&1; then
    echo "FAIL: the lane's $step step" >&2; tail -40 "$log" >&2; return 1
  fi
}

echo "── the offline bootstrap (testing/lib/bootstrap.sh)"
tree="$scratch/$repo"
bootstrap_offline "$root" "$tree" "$values" "$scratch/logs" > "$scratch/bootstrap.log" 2>&1 || {
  echo "FAIL: the offline bootstrap stopped" >&2; tail -40 "$scratch/bootstrap.log" >&2; exit 1; }
echo "   2 phases placed and landed"
s01="$(git -C "$tree" rev-parse HEAD~1)"

# ── 1. the product's one pull request ──────────────────────────────────────
echo "── 01-product's landing: install, the fixture render, typecheck, lint, test, build"
git -C "$tree" worktree add -q "$scratch/at-01" "$s01"
checks "$scratch/at-01" "$scratch/checks-01.log"
# The landing's build is done; its tree is not needed again, and the disk is shared.
git -C "$tree" worktree remove --force "$scratch/at-01"

# ── 2. the stage web lane's steps, in the job's own tree ──────────────────
# A pull request that changes the site: the lanes `orun plan` gives it.
git -C "$tree" checkout -q -b e2e-pr
echo "<!-- a change to the site's component -->" >> "$tree/apps/web/README.md"
git -C "$tree" -c user.email=e2e@example.invalid -c user.name=e2e commit -qam "a pull request"
(cd "$tree" && orun plan --intent intent.yaml --trigger github-pull-request --changed \
   --base main --head HEAD --env stage --output "$scratch/plan.json") > "$scratch/plan.log" 2>&1 \
  || { echo "FAIL: orun plan (pull request)" >&2; tail -15 "$scratch/plan.log" >&2; exit 1; }
extract "$scratch/plan.json" web stage "$scratch/web"

# What the platform resolves into the job before its first step: the wiring
# document the D1 root lease-published (the component's secretEnv), with a
# database id no fixture carries, so the built config proves which document
# it came from.
d1_id="5ca1ab1e-0000-4000-8000-00000000a001"
export WIRING_CLOUDFLARE_D1_STAGE='{"d1_database_id":"'"$d1_id"'","d1_database_name":"stg-'"$repo"'-stage"}'
export WIRING_CLOUDFLARE_D1_PROD='{"d1_database_id":"5ca1ab1e-0000-4000-8000-00000000a003","d1_database_name":"prod-'"$repo"'-prod"}'

echo "── the stage web lane: verify-app-structure, build-app, verify-build-output, deploy-dry-run"
for key in WIRING_CLOUDFLARE_D1_STAGE WIRING_CLOUDFLARE_D1_PROD; do
  grep -qx "$key" "$scratch/web/secrets" || { echo "FAIL: the stage web lane does not resolve $key" >&2; exit 1; }
done
work="$tree/.orun/runs/e2e/web.stage.verify-deploy/work"
stage_job "$scratch/web" "$work" "$scratch/install-web.log"
[ ! -e "$work/apps/web/.output" ] || { echo "FAIL: the staged tree carries build output" >&2; exit 1; }
for step in verify-app-structure build-app verify-build-output deploy-dry-run; do
  run_step "$scratch/web" "$work" "$step" "$scratch/$step.log"
done
grep -q "\"$d1_id\"" "$work/apps/web/wrangler.jsonc" \
  || { echo "FAIL: the lane's build did not render the stage database id from its wiring document" >&2; exit 1; }
# wrangler's dry run names a D1 binding's database by name, not id.
grep -Eq "env\.DB \(stg-$repo-stage\) +D1 Database" "$scratch/deploy-dry-run.log" \
  || { echo "FAIL: the dry run does not bind DB to the stage database" >&2; tail -20 "$scratch/deploy-dry-run.log" >&2; exit 1; }
python3 - "$work/apps/web/.output/public" "$scratch/deploy-dry-run.log" "$values" <<'PY'
import json, re, sys
public, log, values = sys.argv[1], open(sys.argv[2]).read(), json.load(open(sys.argv[3]))
origin = f"https://{values['reponame']}-web-stage.{values['subdomain']}.workers.dev"
problems = []
# The pages are prerendered by the build, for the origin the lane built for:
# their Open Graph image and URL are absolute on it.
for page, path in (("index.html", "/"), ("about/index.html", "/about")):
    try:
        text = open(f"{public}/{page}").read()
    except OSError:
        problems.append(f"the build did not prerender {page}")
        continue
    for prop, want in (("og:image", f"{origin}/cover.jpg"), ("og:url", origin + path)):
        m = re.search(rf'<meta property="{prop}" content="([^"]*)"', text)
        if not m or m.group(1).rstrip("/") != want.rstrip("/"):
            problems.append(f"the prerendered {page}'s {prop} is {m and m.group(1)!r}, not {want}")
# …with the payloads client-side navigation reads, and the dump Nuxt Content
# fills D1 from on the first query.
for f in ("_payload.json", "about/_payload.json", "dump.content.sql"):
    try:
        open(f"{public}/{f}").close()
    except OSError:
        problems.append(f"the build did not write {f}")
# Workers Free takes a Worker up to 3 MiB gzipped.
m = re.search(r"Total Upload: [\d.]+ KiB / gzip: ([\d.]+) KiB", log)
if not m:
    problems.append("the dry run reports no upload size")
elif float(m.group(1)) >= 3072:
    problems.append(f"the Worker is {m.group(1)} KiB gzipped — over Workers Free's 3 MiB")
for p in problems:
    print(f"  ✕ {p}", file=sys.stderr)
if problems:
    sys.exit(1)
print(f"   prerendered for {origin}; the Worker is {m.group(1)} KiB gzipped (Workers Free: 3 MiB)")
PY
echo "   the built config binds DB to the stage document's database ($d1_id); the dry run accepts it"

# ── 3. serve it, and smoke it as the deploy does ───────────────────────────
smoke="$(python3 -c "import yaml,sys;print(yaml.safe_load(open(sys.argv[1]))['spec']['parameters']['smokeCommand'])" "$tree/apps/web/component.yaml")"
free_port() { python3 -c "import socket;s=socket.socket();s.bind(('127.0.0.1',0));print(s.getsockname()[1]);s.close()"; }

echo "── the prerendered pages alone, without the Worker: the deploy's smoke refuses them"
sport="$(free_port)"
(exec setsid python3 -m http.server "$sport" --bind 127.0.0.1 --directory "$work/apps/web/.output/public") \
  > "$scratch/static.log" 2>&1 < /dev/null &
static_pid=$!
for _ in $(seq 1 50); do curl -s -o /dev/null "http://127.0.0.1:$sport/" && break; sleep 0.1; done
curl -s "http://127.0.0.1:$sport/" | grep -q 'id="__nuxt"' \
  || { echo "FAIL: the static server does not serve the prerendered home" >&2; exit 1; }
if DEPLOYED_URL="http://127.0.0.1:$sport" bash -c "$smoke"; then
  echo "FAIL: the deploy's smoke passed the prerendered pages with no Worker behind them" >&2; exit 1
fi
stop_group "$static_pid"; static_pid=""
echo "   the home page is there, Nuxt Content's query route is not: refused"

echo "── wrangler dev over the built Worker (an empty local D1 behind DB)"
rm -rf "$work/apps/web/.wrangler/state"
port="$(free_port)"
(cd "$work/apps/web" && exec setsid pnpm exec wrangler dev --config wrangler.jsonc --ip 127.0.0.1 --port "$port" \
   --name "$repo-web-stage" --show-interactive-dev-session=false) > "$scratch/dev.log" 2>&1 < /dev/null &
dev_pid=$!
url="http://127.0.0.1:$port"
for _ in $(seq 1 90); do
  curl -s -o /dev/null "$url/favicon.ico" && break
  kill -0 "$dev_pid" 2>/dev/null || { echo "FAIL: wrangler dev exited" >&2; tail -30 "$scratch/dev.log" >&2; exit 1; }
  sleep 1
done
curl -s -o /dev/null "$url/favicon.ico" || { echo "FAIL: wrangler dev never answered" >&2; tail -30 "$scratch/dev.log" >&2; exit 1; }

echo "   ▸ the component's own smokeCommand, DEPLOYED_URL=$url"
DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the deploy's smoke refused the site" >&2; tail -30 "$scratch/dev.log" >&2; exit 1; }

echo "   ▸ every route the site promises, Nuxt Content answering from D1"
python3 - "$url" "$values" "$work/apps/web" <<'PY'
import glob, html, json, re, sqlite3, sys, urllib.error, urllib.request
base, values, app = sys.argv[1], json.load(open(sys.argv[2])), sys.argv[3]
name, repo, org = values["productname"], values["reponame"], values["githuborg"]
origin = f"https://{repo}-web-stage.{values['subdomain']}.workers.dev"
problems = []
def bad(m): problems.append(m)
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None
opener = urllib.request.build_opener(NoRedirect)
def req(path, method="GET", body=None, headers=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(base + path, method=method, data=data, headers=headers or {})
    try:
        with opener.open(r, timeout=60) as resp:
            return resp.status, resp.headers, resp.read().decode(errors="replace")
    except urllib.error.HTTPError as e:
        return e.code, e.headers, e.read().decode(errors="replace")
def title(page):
    m = re.search(r"<title>(.*?)</title>", page, re.S)
    return html.unescape(m.group(1)) if m else None
def meta(page, prop):
    m = re.search(rf'<meta property="{prop}" content="([^"]*)"', page)
    return html.unescape(m.group(1)) if m else None
def query(sql):
    s, h, body = req("/__nuxt_content/content/query", "POST", {"sql": sql}, {"content-type": "application/json"})
    return s, body

# The pages: prerendered, titled for the product (decoded: the name carries an
# apostrophe and an ampersand), their Open Graph URLs on the origin the lane
# built for, the navbar linking the product's own repository.
for path, want in (("/", name), ("/about", f"About · {name}")):
    s, h, page = req(path)
    ctype = h.get("content-type", "")
    if s != 200 or not ctype.startswith("text/html"):
        bad(f"{path} answered {s} {ctype}")
        continue
    if title(page) != want:
        bad(f"{path} is titled {title(page)!r}, not {want!r}")
    if meta(page, "og:site_name") != name:
        bad(f"{path}'s og:site_name is {meta(page, 'og:site_name')!r}, not {name!r}")
    if meta(page, "og:image") != f"{origin}/cover.jpg":
        bad(f"{path}'s og:image is {meta(page, 'og:image')!r}, not {origin}/cover.jpg")
    if (meta(page, "og:url") or "").rstrip("/") != (origin + path).rstrip("/"):
        bad(f"{path}'s og:url is {meta(page, 'og:url')!r}, not {origin + path}")
    if f'href="https://github.com/{org}/{repo}"' not in page:
        bad(f"{path}'s navbar does not link https://github.com/{org}/{repo}")
    if "content-wind-web" in page or "github.com/sourceplane/" in page:
        bad(f"{path} still carries the baseline's Worker name or repository")
# Nuxt's links carry no trailing slash; the slashed form is sent to them.
s, h, _ = req("/about/")
if s not in (307, 308) or (h.get("location") or "").rstrip("/") not in ("/about", f"{base}/about"):
    bad(f"/about/ answered {s} → {h.get('location')!r}, not a redirect to /about")
# Client-side navigation reads each page's payload, prerendered beside it.
for f in ("/_payload.json", "/about/_payload.json"):
    s, h, _ = req(f)
    if s != 200:
        bad(f"{f} answered {s}")

# THE ROUTE ONLY THE WORKER ANSWERS: Nuxt Content's query route, reading the
# pages from D1 through the binding the wiring rendered — the very SQL
# queryCollection('content') sends.
s, body = query("SELECT * FROM _content_content WHERE (\"path\" = '/about') ORDER BY stem ASC LIMIT 1")
try:
    rows = json.loads(body) if s == 200 else []
except ValueError:
    rows = []
if len(rows) != 1 or rows[0].get("title") != "About" or rows[0].get("path") != "/about":
    bad(f"the query route answered {s} {body[:160]!r} for /about, not its page")
s, body = query("SELECT COUNT(*) as count FROM _content_content ORDER BY stem ASC")
count = (json.loads(body) or [{}])[0].get("count") if s == 200 else None
if count != 2:
    bad(f"the query route counts {count!r} pages ({s} {body[:80]!r}), not the site's 2")
# …and refuses anything but those SELECTs: no write, no other table.
for sql in ("DELETE FROM _content_content", "SELECT * FROM _content_info",
            "SELECT * FROM _content_content; DROP TABLE _content_content"):
    s, body = query(sql)
    if s == 200:
        bad(f"the query route ran {sql!r}: {body[:80]!r}")
s, body = query("SELECT COUNT(*) as count FROM _content_content ORDER BY stem ASC")
if s != 200 or (json.loads(body) or [{}])[0].get("count") != 2:
    bad(f"after the refused queries the route counts {body[:80]!r}, not the 2 pages")
# Those answers came from the local D1 the binding names: Nuxt Content created
# and filled its tables there, from the build's dump, on the first query.
dbs = glob.glob(f"{app}/.wrangler/state/v3/d1/*/*.sqlite")
stored = 0
for path in dbs:
    con = sqlite3.connect(path)
    tables = {r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    if "_content_content" in tables:
        stored = con.execute("SELECT count(*) FROM _content_content").fetchone()[0]
if stored != 2:
    bad(f"the local D1 ({len(dbs)} database file(s)) holds {stored} page row(s) — Nuxt Content did not fill it")

# A page no file matches is the Worker's: it asks D1 and renders the 404.
for path, want, ctype in (("/favicon.ico", 200, "image/"), ("/no-such-page", 404, "text/html")):
    s, h, page = req(path, headers={"accept": "text/html,*/*;q=0.8"})
    ct = h.get("content-type", "")
    if s != want or not ct.startswith(ctype):
        bad(f"{path} answered {s} {ct}, want {want} {ctype}")
    elif want == 404 and 'id="__nuxt"' not in page:
        bad(f"{path}'s 404 is not the site's own page")

if problems:
    for p in problems:
        print(f"  ✕ {p}", file=sys.stderr)
    sys.exit(1)
print(f"   the pages titled for {name!r}, their Open Graph URLs on {origin}, the navbar on {org}/{repo};")
print(f"   the payloads; the query route answering /about and counting {count} pages from the {stored} rows")
print("   Nuxt Content wrote into the empty D1, and refusing writes and other tables; the favicon and the Worker's 404")
PY

echo "e2e.test.sh: ok"
