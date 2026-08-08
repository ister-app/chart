#!/usr/bin/env bash
# Build the docs zip for a chart release.
#
#   ci/build-docs.sh [<chart-version>]
#
# Copies doc/ into a build dir, fills the VALUES:BEGIN/VALUES:END markers with a
# reference table generated from values.yaml, and packages the result as
# ister-chart-docs-<version>.zip in the repo root. The committed chapters keep the
# markers empty — the table exists only inside the zip, so it can never go stale
# against values.yaml. Runs fine outside CI.
set -euo pipefail

cd "$(dirname "$0")/.."
root="$PWD"

version="${1:-$(grep -oP '^version:\s*\K\S+' Chart.yaml)}"
version="${version#v}"
zip_name="ister-chart-docs-${version}.zip"

build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT
cp -r doc "$build_dir/doc"

echo "=== generating the values reference from values.yaml"
# python3 rather than yq, for the same reason as release-notes.sh: this must run on
# any dev box. Leaves are dict-less values; lists count as leaves so the example-heavy
# ones (libraries, mediaVolumes, extraEnv) show up as one row, not an explosion.
python3 - values.yaml > "$build_dir/values-table.md" <<'PY'
import json, sys, yaml

values = yaml.safe_load(open(sys.argv[1]))

def rows(node, path):
    for key, value in node.items():
        here = path + [key]
        if isinstance(value, dict) and value:
            yield from rows(value, here)
        else:
            yield ".".join(here), json.dumps(value)

print("| Key | Default |")
print("|---|---|")
for key, default in rows(values, []):
    print(f"| `{key}` | `{default}` |")
PY

echo "=== filling the markers"
python3 - "$build_dir/doc" "$build_dir/values-table.md" <<'PY'
import pathlib, sys

doc_dir = pathlib.Path(sys.argv[1])
table = pathlib.Path(sys.argv[2]).read_text().rstrip("\n")
BEGIN, END = "<!-- VALUES:BEGIN", "<!-- VALUES:END -->"

filled = 0
for chapter in sorted(doc_dir.rglob("*.md")):
    text = chapter.read_text()
    if BEGIN not in text and END not in text:
        continue
    # One well-formed pair per chapter, or the build fails rather than shipping a
    # half-substituted document.
    if text.count(BEGIN) != 1 or text.count(END) != 1:
        sys.exit(f"{chapter}: expected exactly one VALUES:BEGIN/VALUES:END pair")
    head, rest = text.split(BEGIN, 1)
    begin_line, rest = rest.split("\n", 1)
    _, tail = rest.split(END, 1)
    chapter.write_text(f"{head}{BEGIN}{begin_line}\n{table}\n{END}{tail}")
    filled += 1

if filled == 0:
    sys.exit("no chapter carries the VALUES markers — nothing to fill")
print(f"filled the values table into {filled} chapter(s)", file=sys.stderr)
PY

# inject_last_update <file-to-edit> <git-tracked-path>
# Bake Docusaurus `last_update` frontmatter from the source file's git history,
# so the documentation site (which has no history for synced files) can show
# "Last updated on ... by ...". Merges into an existing frontmatter block or
# creates one. Skips silently when the file has no history (untracked file).
inject_last_update() {
  local file="$1" src="$2" stamp date author
  stamp="$(git log -1 --format='%aI%x09%an' -- "$src")"
  [ -n "$stamp" ] || return 0
  date="${stamp%%$'\t'*}"
  author="${stamp#*$'\t'}"
  if [ "$(head -1 "$file")" = "---" ]; then
    sed -i "1a last_update:\n  date: $date\n  author: \"$author\"" "$file"
  else
    printf -- '---\nlast_update:\n  date: %s\n  author: "%s"\n---\n\n%s\n' \
      "$date" "$author" "$(cat "$file")" > "$file"
  fi
}

echo "=== injecting last_update frontmatter"
if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
  # PR builds check out shallowly; per-file dates would all be the tip commit.
  # The zip a PR build produces is never published, so skip rather than lie.
  echo "shallow checkout — skipping last_update injection"
else
  while IFS= read -r f; do
    inject_last_update "$f" "${f#"$build_dir/"}"
  done < <(find "$build_dir/doc" -name '*.md')
fi

echo "=== packaging $zip_name"
rm -f "$root/$zip_name"
(cd "$build_dir" && zip -qr "$root/$zip_name" doc -x '*/.gitkeep')
unzip -l "$root/$zip_name"
