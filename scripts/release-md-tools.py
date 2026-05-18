#!/usr/bin/env python3
"""
Markdown editing tools for the Readium Swift Toolkit release workflow.

Subcommands:
    close-changelog OLD_VERSION VERSION CHANGELOG_PATH
        Comments out ## [Unreleased], inserts ## [VERSION] - DATE, appends compare link.

    close-migration-guide VERSION GUIDE_PATH
        Comments out ## Unreleased and inserts ## VERSION (no-op if section absent).

    extract-changelog VERSION CHANGELOG_PATH
        Prints the body of the ## [VERSION] section to stdout.

    update-readme VERSION OLD_VERSION README_PATH
        Bumps CocoaPods pod lines and inserts a new Minimum Requirements row when needed.
"""

import sys
from datetime import date
from pathlib import Path



"""
Comments out ## [Unreleased], inserts ## [VERSION] - DATE, appends compare link.
"""
def close_changelog(old_version, version, changelog_path):
    text = Path(changelog_path).read_text()
    lines = text.splitlines(keepends=True)

    today = date.today().strftime("%Y-%m-%d")
    replaced = False
    result = []

    for line in lines:
        if not replaced and line.strip() == "## [Unreleased]":
            result.append("<!-- ## [Unreleased] -->\n")
            result.append("\n")
            result.append(f"## [{version}] - {today}\n")
            replaced = True
        else:
            result.append(line)

    if not replaced:
        print("ERROR: '## [Unreleased]' heading not found — changelog not modified.", file=sys.stderr)
        sys.exit(1)

    content = "".join(result)
    if not content.endswith("\n"):
        content += "\n"
    compare_link = f"[{version}]: https://github.com/readium/swift-toolkit/compare/{old_version}...{version}\n"
    content += compare_link

    Path(changelog_path).write_text(content)

"""
Comments out ## Unreleased and inserts ## VERSION (no-op if section absent).
"""
def close_migration_guide(version, guide_path):
    text = Path(guide_path).read_text()
    lines = text.splitlines(keepends=True)

    replaced = False
    result = []
    for line in lines:
        if not replaced and line.strip() == "## Unreleased":
            result.append("<!-- ## Unreleased -->\n")
            result.append("\n")
            result.append(f"## {version}\n")
            replaced = True
        else:
            result.append(line)

    if not replaced:
        print("No uncommented '## Unreleased' heading found — Migration Guide not modified.")
        return

    Path(guide_path).write_text("".join(result))

"""
Prints the body of the ## [VERSION] section to stdout.
"""
def extract_changelog(version, changelog_path):
    lines = Path(changelog_path).read_text().splitlines()

    target_heading = f"## [{version}]"
    capturing = False
    captured = []

    for line in lines:
        if not capturing:
            if line.strip().startswith(target_heading):
                capturing = True
            continue
        if line.startswith("## ["):
            break
        captured.append(line)

    if not capturing:
        print(f"ERROR: Section '## [{version}]' not found in changelog.", file=sys.stderr)
        sys.exit(1)

    while captured and not captured[0].strip():
        captured.pop(0)
    while captured and not captured[-1].strip():
        captured.pop()

    print("\n".join(captured))

"""
Bumps CocoaPods pod lines and inserts a new Minimum Requirements row when needed.
"""
def update_readme(version, old_version, readme_path):
    text = Path(readme_path).read_text()
    lines = text.splitlines(keepends=True)
    result = []

    in_requirements = False
    header_seen = False
    separator_seen = False
    develop_cells = None
    first_release_seen = False

    for line in lines:
        # CocoaPods pod lines
        line = line.replace(f"'~> {old_version}'", f"'~> {version}'")
        stripped = line.rstrip("\n")

        # Requirements table detection
        if "### Minimum Requirements" in stripped:
            in_requirements = True
        elif in_requirements:
            if stripped.startswith("| Readium") and "iOS" in stripped:
                header_seen = True
            elif header_seen and not separator_seen and stripped.startswith("|---"):
                separator_seen = True
            elif separator_seen and stripped.startswith("|"):
                cells = _parse_table_row(stripped)
                if cells and cells[0] == "`develop`":
                    develop_cells = cells[1:]
                elif not first_release_seen and develop_cells is not None:
                    if cells[1:] != develop_cells:
                        result.append(f"| {version} | {' | '.join(develop_cells)} |\n")
                    first_release_seen = True
                    develop_cells = None
            elif separator_seen and not stripped.startswith("|"):
                in_requirements = False

        result.append(line)

    Path(readme_path).write_text("".join(result))

def _parse_table_row(line):
    parts = line.strip().strip("|").split("|")
    return [p.strip() for p in parts]

USAGE = """\
Usage:
  release-md-tools.py close-changelog OLD_VERSION VERSION CHANGELOG_PATH
  release-md-tools.py close-migration-guide VERSION GUIDE_PATH
  release-md-tools.py extract-changelog VERSION CHANGELOG_PATH
  release-md-tools.py update-readme VERSION OLD_VERSION README_PATH\
"""

SUBCOMMANDS = {
    "close-changelog":       (close_changelog,       3, "OLD_VERSION VERSION CHANGELOG_PATH"),
    "close-migration-guide": (close_migration_guide, 2, "VERSION GUIDE_PATH"),
    "extract-changelog":     (extract_changelog,     2, "VERSION CHANGELOG_PATH"),
    "update-readme":         (update_readme,         3, "VERSION OLD_VERSION README_PATH"),
}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in SUBCOMMANDS:
        print(USAGE, file=sys.stderr)
        sys.exit(1)

    cmd = sys.argv[1]
    fn, nargs, signature = SUBCOMMANDS[cmd]
    args = sys.argv[2:]

    if len(args) != nargs:
        print(f"Usage: release-md-tools.py {cmd} {signature}", file=sys.stderr)
        sys.exit(1)

    fn(*args)
