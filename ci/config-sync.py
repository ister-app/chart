#!/usr/bin/env python3
"""Keep values.yaml's server.config equal to the defaults of the pinned server.

server.config is rendered to a ConfigMap that wins over the server's built-in defaults, so a
default the server changes in a release would otherwise stay pinned at the old value here.

  ci/config-sync.py check [--server-dir DIR | --tag X.Y.Z]  exit 1 on drift
  ci/config-sync.py sync  [--server-dir DIR | --tag X.Y.Z] [--report F]  rewrite drifted values
  ci/config-sync.py commit-message --report F             commit text for what sync changed

The server's defaults come from its module YAML files (core, disk, transcoder, search — later
files win, as in the server's application.yaml) at the git tag of server.image.tag, fetched
from GitHub, or read from a server checkout with --server-dir. A `${ENV:default}` placeholder
reduces to its default; a key whose default depends on another property is "unresolvable" and
may not be pinned here at all.

Categories: changed (a pinned value differs: sync fixes it), removed (pinned key no longer in
the server: manual), unresolvable (manual), new (server key that is neither pinned nor one of
the chart's env vars: reported only — whether it is a tunable or chart-derived is a judgement
call, make it in values.yaml or CHART_MANAGED below).

sync edits values.yaml line by line, so comments, blank lines and quoting survive; a YAML
round-trip would drop them. python3 + PyYAML only, like ci/build-docs.sh: must run on any dev box.
"""

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request

import yaml

CHART_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VALUES = os.path.join(CHART_DIR, "values.yaml")
CHART_YAML = os.path.join(CHART_DIR, "Chart.yaml")
SERVER_REPO = "ister-app/server"
MODULES = ["core", "disk", "transcoder", "search"]  # import order: later wins
MODULE_PATH = "{module}/src/main/resources/{module}.{ext}"
EXTENSIONS = ["yaml", "properties"]  # .properties: server releases before 5.2.2

# Pinned keys whose default lives in server code, not in a module YAML file (disk.yaml only
# shows them in a comment). Not compared; when one turns up in the YAML the check says so.
CODE_DEFAULT_EXCEPTIONS = {
    "app.ister.server.blur-hash.chunk-size",
    "app.ister.server.segment-detect.chunk-size",
}

# Server keys the chart sets as env vars (templates/_helpers.tpl ister.serverCommonEnv and
# the two deployment templates), secrets, placeholder-derived values and image/runtime
# invariants. None of these belongs in server.config, so they are not "new" either. A new
# chart env var goes here too, or the check reports it as an unreviewed server key.
CHART_MANAGED = {
    # database (DB_* env)
    "spring.datasource.url", "spring.datasource.username", "spring.datasource.password",
    # broker (RABBITMQ_* env); publisher-returns/mandatory are what RabbitReliabilityConfig needs
    "spring.rabbitmq.host", "spring.rabbitmq.username", "spring.rabbitmq.password",
    "spring.rabbitmq.publisher-returns", "spring.rabbitmq.template.mandatory",
    # search (TYPESENSE_* env)
    "app.ister.typesense.enabled", "app.ister.typesense.host", "app.ister.typesense.port",
    "app.ister.typesense.protocol", "app.ister.typesense.api-key", "app.ister.typesense.collection",
    # OIDC (OIDC_URL / OIDC_AUDIENCE env)
    "spring.security.oauth2.resourceserver.jwt.issuer-uri", "springdoc.oAuthFlow.openIdConnectUrl",
    "app.ister.server.oidc.audience",
    # identity, URLs, languages (server.name/url/clusterName/languages values)
    "app.ister.server.name", "app.ister.server.url", "app.ister.cluster.name", "app.ister.languages",
    "app.ister.server.self-url", "app.ister.server.websocket.allowed-origins",
    # paths and binaries of the image (CACHE_DIR / TMP_DIR env, image layout)
    "app.ister.server.cache-dir", "app.ister.server.tmp-dir", "app.ister.server.ffmpeg-dir",
    "app.ister.server.mkvextract", "app.ister.s3.local-copy-dir",
    # hardware acceleration (hwaccel values), helper concurrency (server.helper / helpers[])
    "app.ister.transcoder.hls.hwaccel", "app.ister.transcoder.hls.hwaccel-device",
    "app.ister.helper.concurrency",
    # TMDB client: URL is server.externalServices, the header carries the secret
    "spring.cloud.openfeign.client.config.tmdb.url",
    "spring.cloud.openfeign.client.config.tmdb.defaultRequestHeaders.Authorization",
    # schema and migrations: Flyway runs as a Job (flyway.*), the server only validates
    "spring.flyway.enabled", "spring.flyway.locations", "spring.flyway.baseline-on-migrate",
    "spring.flyway.baseline-version", "spring.jpa.hibernate.ddl-auto",
    # ports the chart hardcodes / probes (server.managementPort)
    "management.server.port",
    # code invariants, not operator tunables
    "spring.jpa.open-in-view", "spring.jpa.properties.hibernate.bytecode.provider",
    "spring.jpa.properties.hibernate.auto_manage_bidirectional_associations",
    "spring.cloud.refresh.enabled", "spring.cloud.openfeign.client.refresh-enabled",
    "spring.cloud.openfeign.lazy-attributes-resolution", "spring.graphql.websocket.path",
    "logging.group.tomcat", "logging.level.tomcat",
    # misspelled, never matched a package; dropped by server 5.2.2
    "logging.level.app.ister.server.entitiy",
}

# Prefixes under which every key is chart-managed (lists the chart renders from values).
CHART_MANAGED_PREFIXES = (
    "app.ister.disk.", "app.ister.helper.", "app.ister.transcoder.disks", "app.ister.s3.connections",
)

PLACEHOLDER = re.compile(r"\$\{")


class Unresolvable(Exception):
    pass


# ----------------------------------------------------------------------------- helpers

def leaves(node, path=()):
    """Flatten a mapping to dotted keys. A YAML key written as "[a.b]" (a logger name) loses its
    brackets, so it spells the same as the flat a.b key of a .properties file."""
    for key, value in node.items():
        here = path + (str(key).strip("[]"),)
        if isinstance(value, dict):
            yield from leaves(value, here)
        else:
            yield ".".join(here), value


def parse_properties(text):
    """Flat {key: value} of a Java .properties file (servers before 5.2.2 shipped those)."""
    out, pending = {}, ""
    for raw in text.splitlines():
        line = pending + raw.strip()
        pending = ""
        if not line or line[0] in "#!":
            continue
        if line.endswith("\\"):
            pending = line[:-1]
            continue
        match = re.match(r"^([^=:\s]+)\s*[=:]?\s*(.*)$", line)
        if match:
            out[match.group(1)] = match.group(2)
    return out


def norm(value):
    """The string Spring binds: what the ConfigMap and the server's own file both end up as."""
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def reduce_placeholders(text):
    """'${NAME:default}' -> 'default'. Nested or default-less placeholders are unresolvable."""
    while True:
        start = text.find("${")
        if start < 0:
            return text
        depth, i = 0, start
        while i < len(text):
            if text.startswith("${", i):
                depth += 1
                i += 2
                continue
            if text[i] == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        else:
            raise Unresolvable(text)
        inner = text[start + 2:i]
        if "${" in inner or ":" not in inner:
            raise Unresolvable(text)
        text = text[:start] + inner.split(":", 1)[1] + text[i + 1:]


def read_module(module, tag, server_dir):
    """Text of a module's config file (.yaml, else .properties) and its extension; None if absent."""
    for ext in EXTENSIONS:
        rel = MODULE_PATH.format(module=module, ext=ext)
        if server_dir:
            path = os.path.join(server_dir, rel)
            if os.path.exists(path):
                with open(path, encoding="utf-8") as fh:
                    return fh.read(), ext
            continue
        url = f"https://raw.githubusercontent.com/{SERVER_REPO}/v{tag}/{rel}"
        try:
            with urllib.request.urlopen(url, timeout=30) as resp:
                return resp.read().decode("utf-8"), ext
        except urllib.error.HTTPError as err:
            if err.code != 404:
                sys.exit(f"{url}: HTTP {err.code}")
    return None, None


def server_defaults(tag, server_dir):
    """{key: normalised default} over all modules, plus the set of unresolvable keys."""
    merged, unresolvable = {}, set()
    for module in MODULES:
        text, ext = read_module(module, tag, server_dir)
        if text is None:
            if module == "core":
                sys.exit(f"server v{tag}: no core.yaml or core.properties found "
                         f"({'in ' + server_dir if server_dir else 'is the tag published?'})")
            continue
        if ext == "properties":
            flat = parse_properties(text)
        else:
            doc = yaml.safe_load(text) or {}
            if not isinstance(doc, dict):
                sys.exit(f"{module}.{ext}: not a mapping")
            flat = dict(leaves(doc))
        for key, value in flat.items():
            if isinstance(value, list):
                merged[key] = norm(value)
                continue
            try:
                merged[key] = reduce_placeholders(norm(value)) if isinstance(value, str) else norm(value)
                unresolvable.discard(key)
            except Unresolvable:
                merged.pop(key, None)
                unresolvable.add(key)
    return merged, unresolvable


def pinned_tag():
    with open(VALUES, encoding="utf-8") as fh:
        values = yaml.safe_load(fh)
    tag = str(values.get("server", {}).get("image", {}).get("tag") or "").strip()
    if not tag:
        with open(CHART_YAML, encoding="utf-8") as fh:
            tag = str(yaml.safe_load(fh).get("appVersion", "")).strip()
    return tag


def is_release_tag(tag):
    return re.fullmatch(r"\d+\.\d+\.\d+", tag) is not None


# ----------------------------------------------------------------------- values.yaml scan

KEY_LINE = re.compile(r'^(?P<indent> *)(?P<key>"[^"]*"|\'[^\']*\'|[^\s#:][^:]*?):(?: (?P<rest>.*))?$')


def scan_config_block(lines):
    """Map every leaf under server.config to its line index; also return the block's bounds."""
    in_server = False
    start = None
    for idx, line in enumerate(lines):
        if re.match(r"^server:\s*(#.*)?$", line):
            in_server = True
            continue
        if in_server and re.match(r"^\S", line) and not line.startswith("#"):
            in_server = False
        if in_server and re.match(r"^  config:\s*(#.*)?$", line):
            start = idx
            break
    if start is None:
        sys.exit("values.yaml: server.config block not found")

    leaf_lines, stack = {}, []  # stack: [(indent, key)]
    end = len(lines)
    for idx in range(start + 1, len(lines)):
        line = lines[idx]
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        indent = len(line) - len(line.lstrip(" "))
        if indent <= 2:
            end = idx
            break
        match = KEY_LINE.match(line)
        if not match:
            sys.exit(f"values.yaml:{idx + 1}: cannot parse inside server.config: {line.rstrip()}")
        key = match.group("key").strip("\"'")
        while stack and stack[-1][0] >= indent:
            stack.pop()
        stack.append((indent, key))
        rest = match.group("rest")
        if rest is not None and rest.strip() and not rest.lstrip().startswith("#"):
            path = ".".join(k.strip("[]") for _, k in stack)
            leaf_lines[path] = idx
    return leaf_lines, start, end


def split_value(rest):
    """'"a b" # c' -> ('"a b"', ' # c'); '20 # c' -> ('20', ' # c')."""
    rest = rest.rstrip("\n")
    if rest.startswith('"'):
        close = rest.find('"', 1)
        while close > 0 and rest[close - 1] == "\\":
            close = rest.find('"', close + 1)
        return rest[: close + 1], rest[close + 1:]
    if rest.startswith("'"):
        close = rest.find("'", 1)
        return rest[: close + 1], rest[close + 1:]
    comment = rest.find(" #")
    if comment >= 0:
        return rest[:comment].rstrip(), rest[comment:]
    return rest.rstrip(), ""


def render_scalar(new, old_token):
    """Write `new` the way the old token was written: bare when it was bare and stays
    unambiguous YAML, double-quoted otherwise."""
    if not old_token.startswith(('"', "'")):
        try:
            if norm(yaml.safe_load(new)) == new and not re.match(r"^[\[\]{}&*!|>'\"%@`,]", new) \
                    and " #" not in new and ": " not in new and new.strip() == new:
                return new
        except yaml.YAMLError:
            pass
    return json.dumps(new, ensure_ascii=False)


# ------------------------------------------------------------------------------ compare

def compare(chart, server, unresolvable):
    report = {"changed": [], "removed": [], "unresolvable": [], "new": [], "stale_exceptions": []}
    for key, value in sorted(chart.items()):
        if key in CODE_DEFAULT_EXCEPTIONS:
            if key in server:
                report["stale_exceptions"].append(key)
            continue
        if key in unresolvable:
            report["unresolvable"].append(key)
        elif key not in server:
            report["removed"].append(key)
        elif server[key] != value:
            report["changed"].append({"key": key, "chart": value, "server": server[key]})
    for key, value in sorted(server.items()):
        if key in chart or key in CHART_MANAGED or key.startswith(CHART_MANAGED_PREFIXES):
            continue
        report["new"].append({"key": key, "value": value})
    return report


def chart_config(values_text):
    values = yaml.safe_load(values_text)
    config = values.get("server", {}).get("config") or {}
    out = {}
    for key, value in leaves(config):
        if isinstance(value, list):
            sys.exit(f"server.config.{key}: lists are not supported here")
        out[key] = norm(value)
    return out


def annotate(kind, message, line=None):
    if os.environ.get("GITHUB_ACTIONS"):
        where = f" file=values.yaml,line={line}" if line else ""
        print(f"::{kind}{where}::{message}")
    else:
        print(f"{kind}: {message}" + (f" (values.yaml:{line})" if line else ""))


def print_report(report, tag, leaf_lines):
    for item in report["changed"]:
        annotate("error", f"server.config.{item['key']} is {item['chart']}, server v{tag} default is "
                 f"{item['server']}", leaf_lines.get(item["key"], 0) + 1)
    for key in report["removed"]:
        annotate("error", f"server.config.{key} does not exist in server v{tag}", leaf_lines.get(key, 0) + 1)
    for key in report["unresolvable"]:
        annotate("error", f"server.config.{key}: the server derives this value from another property; "
                 f"it must not be pinned", leaf_lines.get(key, 0) + 1)
    for key in report["stale_exceptions"]:
        annotate("warning", f"{key} is now in the server YAML; drop it from CODE_DEFAULT_EXCEPTIONS")
    for item in report["new"]:
        annotate("warning", f"server v{tag} has {item['key']} = {item['value']}, which server.config does "
                 f"not pin and the chart does not set (tunable -> values.yaml, chart-derived -> CHART_MANAGED)")


def blocking(report):
    return bool(report["changed"] or report["removed"] or report["unresolvable"])


def report_text(report, tag):
    out = [f"Server v{tag} defaults, compared with server.config:"]
    if report["changed"]:
        out.append(f"changed ({len(report['changed'])}):")
        out += [f"  {i['key']}: {i['chart']} -> {i['server']}" for i in report["changed"]]
    if report["removed"]:
        out.append(f"removed from the server ({len(report['removed'])}):")
        out += [f"  {k}" for k in report["removed"]]
    if report["unresolvable"]:
        out.append(f"derived in the server, must not be pinned ({len(report['unresolvable'])}):")
        out += [f"  {k}" for k in report["unresolvable"]]
    if report["new"]:
        out.append(f"new in server, not mirrored ({len(report['new'])}):")
        out += [f"  {i['key']} = {i['value']}" for i in report["new"]]
    if len(out) == 1:
        out.append("no differences")
    return "\n".join(out)


# ----------------------------------------------------------------------------- commands

def load(args):
    tag = args.tag or pinned_tag()
    if not args.server_dir and not is_release_tag(tag):
        annotate("notice", f"server.image.tag {tag!r} is not a release tag; nothing to compare against")
        return None
    server, unresolvable = server_defaults(tag, args.server_dir)
    with open(VALUES, encoding="utf-8") as fh:
        text = fh.read()
    leaf_lines, start, end = scan_config_block(text.splitlines(keepends=True))
    report = compare(chart_config(text), server, unresolvable)
    report["tag"] = tag
    return tag, server, text, leaf_lines, start, end, report


def cmd_check(args):
    loaded = load(args)
    if loaded is None:
        return 0
    tag, _, _, leaf_lines, _, _, report = loaded
    print_report(report, tag, leaf_lines)
    print(report_text(report, tag))
    return 1 if blocking(report) else 0


def cmd_sync(args):
    loaded = load(args)
    if loaded is None:
        return 0
    tag, server, text, leaf_lines, start, end, report = loaded
    if args.report:
        with open(args.report, "w", encoding="utf-8") as fh:
            json.dump(report, fh, indent=2)
    print_report(report, tag, leaf_lines)
    if report["removed"] or report["unresolvable"]:
        print("sync only rewrites changed values; fix the keys above by hand", file=sys.stderr)
        return 1
    if not report["changed"]:
        print(report_text(report, tag))
        return 0

    lines = text.splitlines(keepends=True)
    for item in report["changed"]:
        idx = leaf_lines[item["key"]]
        match = KEY_LINE.match(lines[idx])
        token, tail = split_value(match.group("rest"))
        newline = "\n" if lines[idx].endswith("\n") else ""
        lines[idx] = f"{match.group('indent')}{match.group('key')}: {render_scalar(item['server'], token)}{tail}{newline}"
    # The header comment names the server version the values come from.
    for idx in range(0, start):
        lines[idx] = re.sub(r"\(server \d+\.\d+\.\d+\)", f"(server {tag})", lines[idx])
    new_text = "".join(lines)

    again = compare(chart_config(new_text), server, set())
    if again["changed"]:
        sys.exit("sync did not converge: " + ", ".join(i["key"] for i in again["changed"]))
    with open(VALUES, "w", encoding="utf-8") as fh:
        fh.write(new_text)
    print(report_text(report, tag))
    print(f"values.yaml: {len(report['changed'])} value(s) updated to server v{tag}")
    return 0


def cmd_commit_message(args):
    with open(args.report, encoding="utf-8") as fh:
        report = json.load(fh)
    tag = report["tag"]
    body = [f"fix(server): sync server.config with server v{tag}", "",
            "Defaults the server changed in this release, mirrored into server.config so the",
            "ConfigMap no longer pins the old value. Generated by ci/config-sync.py.", "",
            report_text(report, tag), ""]
    body += [f"Config-Changed: {i['key']} {i['chart']} -> {i['server']}" for i in report["changed"]]
    body += [f"Config-New: {i['key']} = {i['value']}" for i in report["new"]]
    print("\n".join(body))
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    for name, func in (("check", cmd_check), ("sync", cmd_sync)):
        p = sub.add_parser(name)
        p.add_argument("--server-dir", help="read the module YAML files from this server checkout instead of GitHub")
        p.add_argument("--tag", help="compare against this server release instead of server.image.tag")
        p.add_argument("--report", help="write the comparison as JSON here")
        p.set_defaults(func=func)
    p = sub.add_parser("commit-message")
    p.add_argument("--report", required=True)
    p.set_defaults(func=cmd_commit_message)
    args = parser.parse_args()
    sys.exit(args.func(args))


if __name__ == "__main__":
    main()
