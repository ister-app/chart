# Ister chart documentation

This directory holds the administrator documentation for the ister Helm chart, laid out
the same way as the player repo's `doc/`.

## Contents

- `admin/en/` — the administrator guide in English (installation, architecture, values)
- `admin/nl/` — de beheerdershandleiding in het Nederlands (same chapters, translated)

## The generated values reference

Each chapter that ends in a values reference carries an empty pair of HTML-comment
markers, `VALUES:BEGIN` and `VALUES:END` (spelled out only in the chapters themselves —
reproducing them here would get this README a table too).

The markers stay empty in git. `ci/build-docs.sh` fills them with a table generated from
`values.yaml` when it builds the zip, so the shipped reference always matches the
release it accompanies. Never hand-edit between the markers.

## Building the docs zip locally

```sh
ci/build-docs.sh            # version taken from Chart.yaml
ci/build-docs.sh 0.0.0-local
```

This writes `ister-chart-docs-<version>.zip` in the repo root (git-ignored) and leaves
the committed chapters untouched. The release workflow runs the same script and attaches
the zip to every GitHub Release.
