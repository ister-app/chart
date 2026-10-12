#!/usr/bin/env bash
# Build the release notes for a chart release.
#
#   ci/release-notes.sh <chart-version> [<previous-tag>]
#
# Writes RELEASE_NOTES.md (fed to `gh release create --notes-file`) and prepends the same
# block to CHANGELOG.md. Runs fine outside CI, so the formatting can be checked locally.
#
# `gh release create --generate-notes` is not enough here: it lists PR titles only, so
# commits pushed straight to main go missing, and it cannot say which image versions the
# chart actually deploys — which, with server/player/migrations on independent version
# lines, is the first thing anyone reading a chart release wants to know.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:?usage: release-notes.sh <chart-version> [<previous-tag>]}"
VERSION="${VERSION#v}"

# The previous tag, or the root commit when this is the first release.
PREV="${2:-$(git describe --tags --abbrev=0 2>/dev/null || true)}"
RANGE="${PREV:+$PREV..}HEAD"

REPO="${GITHUB_REPOSITORY:-$(git remote get-url origin 2>/dev/null |
  sed -E 's#^.*[:/]([^/]+/[^/]+?)(\.git)?$#\1#' || echo ister-app/chart)}"

# python3 rather than yq: yq is preinstalled on GitHub's runners but not on every dev box,
# and the whole point of this script is that you can run it locally to check the formatting.
yaml() {
  python3 -c '
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
for key in sys.argv[2].split("."):
    doc = doc[key]
print(doc)
' "$1" "$2"
}
img() { yaml values.yaml "$1"; }

# migrations has no tag of its own: it rides .Chart.AppVersion (== server version), the same
# fallback ister.image does when flyway.image.tag is empty. Mirror it here so the table shows
# the version actually deployed rather than a blank cell.
mig_tag="$(img flyway.image.tag)"
[ -n "$mig_tag" ] || mig_tag="$(img server.image.tag)"

{
  echo "## ister-chart v${VERSION}"
  echo
  echo "| Component | Image | Version |"
  echo "|---|---|---|"
  echo "| server | \`$(img server.image.repository)\` | $(img server.image.tag) |"
  echo "| website | \`$(img website.image.repository)\` | $(img website.image.tag) |"
  echo "| migrations | \`$(img flyway.image.repository)\` | ${mig_tag} |"
  echo "| database | \`$(img database.internal.image.repository)\` | $(img database.internal.image.tag) |"
  echo "| typesense | \`$(img typesense.image.repository)\` | $(img typesense.image.tag) |"
  echo "| rabbitmq | \`$(img rabbitmq.image.repository)\` | $(img rabbitmq.image.tag) |"
  echo

  # Group the commits by conventional-commit type. The release commit itself is dropped:
  # it is the bump this file documents, so listing it is circular.
  #
  # `%h %s` rather than a delimiter — a commit subject may legitimately contain any
  # separator character, but never a space before the first one.
  # grep -P, not -E: the "not deps" scopes below need a lookahead.
  section() {
    local title="$1" pattern="$2" body
    body="$(git log --no-merges --pretty='%h %s' "$RANGE" |
      grep -v ' chore(release)' |
      grep -P " ${pattern}" |
      while read -r sha subject; do
        echo "- ${subject} ([\`${sha}\`](https://github.com/${REPO}/commit/${sha}))"
      done || true)"
    [ -n "$body" ] || return 0
    echo "### ${title}"
    echo
    echo "$body"
    echo
  }

  section "Breaking changes"   '[a-z]+(\(.+\))?!:'
  section "Features"           'feat(\(.+\))?:'
  section "Fixes"              'fix(\((?!deps\)).+\))?:'
  section "Dependency updates" '(fix|chore)\(deps\):'
  section "Other"              '(chore|docs|ci|build|refactor|test|perf)(\((?!deps\)).+\))?:'

  # server.config pins the server's defaults (ci/config-sync.py). Operators run with these
  # values, so list what moved since the previous tag — whether the nightly sync or a hand
  # edit changed it — plus the server keys the sync found and nobody has mirrored yet
  # (Config-New trailers on the sync commits).
  if [ -n "$PREV" ]; then
    prev_values="$(mktemp)"
    git show "$PREV:values.yaml" > "$prev_values" 2>/dev/null || : > "$prev_values"
    settings="$(python3 - "$prev_values" values.yaml <<'PY'
import sys, yaml

def leaves(node, path=()):
    for key, value in node.items():
        here = path + (str(key).strip("[]"),)
        if isinstance(value, dict):
            yield from leaves(value, here)
        else:
            yield ".".join(here), value

def config(path):
    doc = yaml.safe_load(open(path)) or {}
    return dict(leaves(doc.get("server", {}).get("config") or {}))

def show(v):
    return "true" if v is True else "false" if v is False else str(v)

prev, cur = config(sys.argv[1]), config(sys.argv[2])
for key in sorted(set(prev) | set(cur)):
    if key not in prev:
        print(f"- added: `{key}` = `{show(cur[key])}`")
    elif key not in cur:
        print(f"- removed: `{key}` (was `{show(prev[key])}`)")
    elif show(prev[key]) != show(cur[key]):
        print(f"- changed: `{key}` `{show(prev[key])}` → `{show(cur[key])}`")
PY
    )"
    rm -f "$prev_values"
    unmirrored="$(git log --no-merges --format='%(trailers:key=Config-New,valueonly)' "$RANGE" |
      sed '/^$/d' | sort -u | sed 's/^/- `/; s/ = /` = `/; s/$/`/')"
    if [ -n "$settings" ] || [ -n "$unmirrored" ]; then
      echo "### Server settings (server.config)"
      echo
      if [ -n "$settings" ]; then
        echo "$settings"
        echo
      fi
      if [ -n "$unmirrored" ]; then
        echo "Server defaults not yet mirrored in \`server.config\` (set them there or via env):"
        echo
        echo "$unmirrored"
        echo
      fi
    fi
  fi

  echo "### Install"
  echo
  echo '```sh'
  echo "helm install ister oci://ghcr.io/ister-app/charts/ister --version ${VERSION}"
  echo '```'
  echo
  if [ -n "$PREV" ]; then
    echo "**Full changelog**: https://github.com/${REPO}/compare/${PREV}...v${VERSION}"
  fi
} > RELEASE_NOTES.md

# Prepend to the changelog, keeping the file's heading on top.
{
  echo "# Changelog"
  echo
  cat RELEASE_NOTES.md
  if [ -f CHANGELOG.md ]; then
    echo
    tail -n +2 CHANGELOG.md | sed '/./,$!d'
  fi
} > CHANGELOG.md.new
mv CHANGELOG.md.new CHANGELOG.md

echo "wrote RELEASE_NOTES.md and CHANGELOG.md for v${VERSION} (range: ${RANGE})" >&2
