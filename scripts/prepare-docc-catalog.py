#!/usr/bin/env python3
"""
Adapts a copy of the `docs` folder to DocC, which resolves links differently
from GitHub.

Usage: python3 -I scripts/prepare-docc-catalog.py CATALOG_DIR REPOSITORY_URL

The guides are written for GitHub, with relative links. In the Markdown files
of CATALOG_DIR, a copy of the `docs` folder, this script rewrites:

- the image links to their bare file name, as DocC only resolves images by
  file name: `![Alt](Assets/image.svg)` becomes `![Alt](image.svg)`;
- the links to other guides of the catalog into DocC links:
  `[Text](../Guides/My%20Guide.md#a-heading)` becomes
  `[Text](doc:My-Guide#A-heading)`;
- the links to files of the repository outside the `docs` folder into links
  to REPOSITORY_URL, such as `https://github.com/org/repo/blob/1.0.0`:
  `[Text](../README.md)` becomes `[Text](https://github.com/org/repo/blob/1.0.0/README.md)`;
- the GitHub alerts into DocC asides: `> [!NOTE]` followed by `> Text` becomes
  `> Note: Text`;
- the headings, without their backticks, which DocC displays as is:
  ## The `Navigator` API becomes ## The Navigator API.

It prints a warning for each link it cannot rewrite.
"""

import argparse
import os
import re
import sys
from urllib.parse import unquote

LINK = re.compile(r"(?P<image>!?)\[(?P<text>[^\]]*)\]\((?P<target>[^)\s]+)\)")
HEADING = re.compile(r"^#{1,6}\s+(?P<title>.+?)\s*#*\s*$")
FENCE = re.compile(r"^\s*(```|~~~)")
ALERT = re.compile(r"^\s*>\s*\[!(?P<kind>[A-Z]+)\]\s*$")
QUOTE = re.compile(r"^(?P<prefix>\s*>\s?)(?P<text>.*)$")

# DocC aside of each GitHub alert. DocC has no caution aside.
ALERT_KINDS = {
    "NOTE": "Note",
    "TIP": "Tip",
    "IMPORTANT": "Important",
    "WARNING": "Warning",
    "CAUTION": "Warning",
}

warnings = 0


def warn(path, message):
    global warnings
    warnings += 1
    print(f"warning: {path}: {message}", file=sys.stderr)


def is_external(target):
    return re.match(r"^[a-z][a-z0-9+.-]*:", target) is not None or target.startswith("#")


def plain_text(markdown):
    """Text of a heading, without its inline Markdown."""
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", markdown)
    return re.sub(r"[`*_]", "", text).strip()


def github_anchor(title):
    """Anchor of a heading on GitHub."""
    anchor = plain_text(title).lower()
    anchor = re.sub(r"[^\w\- ]", "", anchor)
    return anchor.replace(" ", "-")


def docc_anchor(title):
    """Anchor of a heading in DocC."""
    anchor = "-".join(plain_text(title).split())
    return re.sub(r"[^\w\-]", "", anchor)


def headings(path):
    """DocC anchors of the headings of a Markdown file, by GitHub anchor."""
    anchors = {}
    in_code = False
    with open(path) as f:
        for line in f:
            if FENCE.match(line):
                in_code = not in_code
                continue
            match = None if in_code else HEADING.match(line)
            if match:
                title = match.group("title")
                anchors.setdefault(github_anchor(title), docc_anchor(title))
    return anchors


def rewrite_link(match, path, catalog, repository_url):
    target = match.group("target")
    if is_external(target):
        return match.group(0)

    if match.group("image"):
        return f"![{match.group('text')}]({os.path.basename(target)})"

    file, _, anchor = target.partition("#")
    target_path = os.path.normpath(os.path.join(os.path.dirname(path), unquote(file)))
    if not target_path.startswith(catalog + os.sep):
        # The catalog is a copy of the `docs` folder of the repository.
        repository_path = os.path.normpath(os.path.join("docs", os.path.relpath(target_path, catalog)))
        if repository_path.startswith(".."):
            warn(path, f"'{target}' is outside the repository")
            return match.group(0)
        url = f"{repository_url.rstrip('/')}/{repository_path}" + (f"#{anchor}" if anchor else "")
        return f"[{match.group('text')}]({url})"

    if not file.endswith(".md"):
        return match.group(0)
    if not os.path.exists(target_path):
        warn(path, f"'{target}' is not a page of the documentation")
        return match.group(0)

    name = os.path.basename(target_path)[: -len(".md")]
    link = "doc:" + "-".join(name.split())
    if anchor:
        docc = headings(target_path).get(anchor)
        if docc:
            link += f"#{docc}"
        else:
            warn(path, f"no heading matches '#{anchor}' in {os.path.relpath(target_path, catalog)}")
    return f"[{match.group('text')}]({link})"


def rewrite_alerts(lines, path):
    """
    Rewrites the GitHub alerts into DocC asides:

        > [!IMPORTANT]          > Important: Text
        > Text           →
    """
    result = []
    kind = None
    for line in lines:
        alert = ALERT.match(line)
        if alert:
            kind = ALERT_KINDS.get(alert.group("kind"))
            if kind is None:
                warn(path, f"unknown alert '[!{alert.group('kind')}]'")
                result.append(line)
            continue
        if kind:
            quote = QUOTE.match(line)
            if quote and quote.group("text").strip():
                line = f"{quote.group('prefix')}{kind}: {quote.group('text')}"
                kind = None
            elif not quote:
                warn(path, "an alert has no text")
                kind = None
        result.append(line)
    return result


def rewrite(path, catalog, repository_url):
    with open(path) as f:
        lines = f.read().split("\n")
    in_code = False
    prose = []
    output = []

    def flush():
        output.extend(rewrite_alerts(prose, path))
        prose.clear()

    for line in lines:
        if FENCE.match(line):
            in_code = not in_code
            if in_code:
                flush()
            output.append(line)
        elif in_code:
            output.append(line)
        else:
            # DocC displays the backticks of a heading instead of code.
            if HEADING.match(line):
                line = line.replace("`", "")
            prose.append(LINK.sub(lambda m: rewrite_link(m, path, catalog, repository_url), line))
    flush()
    with open(path, "w") as f:
        f.write("\n".join(output))


def main():
    parser = argparse.ArgumentParser(description="Adapts a copy of the docs folder to DocC.")
    parser.add_argument("catalog", help="DocC catalog, a copy of the docs folder")
    parser.add_argument("repository_url", help="URL of the repository at the documented version")
    args = parser.parse_args()
    catalog = os.path.normpath(os.path.abspath(args.catalog))

    for root, _, files in os.walk(catalog):
        for file in files:
            if file.endswith(".md"):
                rewrite(os.path.join(root, file), catalog, args.repository_url)

    if warnings:
        print(f"{warnings} link(s) could not be adapted to DocC", file=sys.stderr)


if __name__ == "__main__":
    main()
