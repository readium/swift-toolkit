#!/usr/bin/env python3
"""
Renders the Mermaid diagrams of the user guides to SVG.

Usage: python3 -I .claude/skills/write-guide/scripts/render-diagrams.py docs/Guides/Timeline.md [...]

Each diagram is kept in the guide as an HTML comment holding a Mermaid code
block, immediately followed by the image it renders to:

    <!--
    ```mermaid
    gantt
        ...
    ```
    -->
    ![Alt text](timeline-segments.svg)

The SVG is written next to the guide, and referenced by its bare file name, so
that it resolves both on GitHub and in the DocC catalog.

Requires Node.js (npx) and Google Chrome. Set PUPPETEER_EXECUTABLE_PATH to use
another Chrome or Chromium binary.
"""

import json
import os
import re
import subprocess
import sys
import tempfile

MERMAID_CLI = "@mermaid-js/mermaid-cli@11.4.2"
DEFAULT_CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Palette shared by the diagrams. In Gantt charts, an untagged task is drawn
# dark, an `active` task light and a `done` task gray.
DARK = "#3b6ea5"
DARK_ALT = "#2b5584"
DARK_BORDER = "#24476e"
LIGHT = "#d6e6f7"
LIGHT_ALT = "#a9c8ea"
GRAY = "#ececec"
GRAY_ALT = "#d2d2d2"
GRAY_BORDER = "#9e9e9e"
TEXT = "#1f2d3d"

CONFIG = {
    "theme": "base",
    "themeVariables": {
        "fontFamily": "-apple-system, 'Helvetica Neue', Helvetica, Arial, sans-serif",
        "primaryColor": LIGHT,
        "primaryBorderColor": DARK,
        "primaryTextColor": TEXT,
        "lineColor": "#555555",
        "clusterBkg": "#f6f8fa",
        "clusterBorder": "#c0c8d0",
        "taskBkgColor": DARK,
        "taskBorderColor": DARK_BORDER,
        "taskTextLightColor": "#ffffff",
        "taskTextColor": "#ffffff",
        "activeTaskBkgColor": LIGHT,
        "activeTaskBorderColor": DARK,
        "doneTaskBkgColor": GRAY,
        "doneTaskBorderColor": GRAY_BORDER,
        "taskTextDarkColor": TEXT,
        "taskTextOutsideColor": TEXT,
        "sectionBkgColor": "#f6f8fa",
        "altSectionBkgColor": "#ffffff",
        "sectionBkgColor2": "#f6f8fa",
        "gridColor": "#d0d7de",
        "titleColor": TEXT,
    },
    "htmlLabels": False,
    "flowchart": {"htmlLabels": False},
    "gantt": {
        "useWidth": 1100,
        "barHeight": 24,
        "fontSize": 14,
        "sectionFontSize": 14,
        "leftPadding": 170,
    },
}

BLOCK = re.compile(
    r"<!--[ \t]*\n```mermaid\n(?P<source>.*?)\n```[ \t]*\n-->[ \t]*\n"
    r"!\[(?P<alt>[^\]]*)\]\((?P<image>[^)\s]+)\)",
    re.DOTALL,
)


def fail(message):
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def fix_size(svg_path):
    """
    Replaces the fluid width of the SVG with its intrinsic size, otherwise
    DocC renders it as a thumbnail.
    """
    with open(svg_path) as f:
        svg = f.read()
    tag = re.search(r"<svg\b[^>]*>", svg).group(0)
    viewbox = re.search(r'viewBox="[-\d.]+ [-\d.]+ ([\d.]+) ([\d.]+)"', tag)
    if not viewbox:
        fail(f"no viewBox in {svg_path}")
    width, height = viewbox.groups()
    new_tag = re.sub(r'\s(width|height|style)="[^"]*"', "", tag)
    new_tag = new_tag.replace(
        "<svg",
        f'<svg width="{width}" height="{height}" style="background-color: white;"',
        1,
    )
    with open(svg_path, "w") as f:
        f.write(svg.replace(tag, new_tag, 1))


def alternate_adjacent_bars(svg_path, svg_id):
    """
    Alternates the shade of the Gantt bars touching each other on a row, so
    that their boundaries stand out.
    """
    with open(svg_path) as f:
        svg = f.read()

    bar = re.compile(r'<rect\b[^>]*class="task [^"]*"[^>]*/>')
    rows = {}
    for match in bar.finditer(svg):
        tag = match.group(0)
        if "milestone" in tag:
            continue
        attrs = dict(re.findall(r'\b(x|y|width)="([-\d.]+)"', tag))
        rows.setdefault(attrs["y"], []).append((float(attrs["x"]), float(attrs["width"]), tag))

    alternates = set()
    for bars in rows.values():
        bars.sort()
        is_alt = False
        previous_end = None
        for x, width, tag in bars:
            touches = previous_end is not None and abs(previous_end - x) < 1
            is_alt = not is_alt if touches else False
            if is_alt:
                alternates.add(tag)
            previous_end = x + width

    for tag in alternates:
        svg = svg.replace(tag, tag.replace('class="task ', 'class="task alt ', 1), 1)

    style = (
        f"#{svg_id} rect.task.alt{{fill:{DARK_ALT};}}"
        f'#{svg_id} rect.task.alt[class*="active"]{{fill:{LIGHT_ALT};}}'
        f'#{svg_id} rect.task.alt[class*="done"]{{fill:{GRAY_ALT};}}'
    )
    svg = svg.replace("</style>", style + "</style>", 1)
    with open(svg_path, "w") as f:
        f.write(svg)


def render(guide_path, source, image, work_dir, puppeteer_config, mermaid_config):
    if "/" in image or not image.endswith(".svg"):
        fail(f"{guide_path}: '{image}' must be the bare name of an SVG next to the guide")

    name = image[: -len(".svg")]
    input_path = os.path.join(work_dir, f"{name}.mmd")
    output_path = os.path.join(os.path.dirname(guide_path), image)
    with open(input_path, "w") as f:
        f.write(source + "\n")

    subprocess.run(
        [
            "npx", "--yes", "--package", MERMAID_CLI, "mmdc",
            "--puppeteerConfigFile", puppeteer_config,
            "--configFile", mermaid_config,
            "--backgroundColor", "white",
            # A unique ID, as DocC references each SVG by its root ID.
            "--svgId", name,
            "--input", input_path,
            "--output", output_path,
            "--quiet",
        ],
        check=True,
        # Gantt charts are laid out in local time, which would shift a time
        # axis starting at 00:00.
        env={**os.environ, "TZ": "UTC", "PUPPETEER_SKIP_DOWNLOAD": "1"},
    )
    fix_size(output_path)
    alternate_adjacent_bars(output_path, name)
    print(f"Rendered {output_path}")


def main():
    guides = sys.argv[1:]
    if not guides:
        fail("usage: render-diagrams.py GUIDE.md [GUIDE.md...]")

    chrome = os.environ.get("PUPPETEER_EXECUTABLE_PATH", DEFAULT_CHROME)
    if not os.path.exists(chrome):
        fail(f"Chrome not found at {chrome}, set PUPPETEER_EXECUTABLE_PATH")

    with tempfile.TemporaryDirectory() as work_dir:
        puppeteer_config = os.path.join(work_dir, "puppeteer.json")
        with open(puppeteer_config, "w") as f:
            json.dump({"executablePath": chrome, "headless": "new"}, f)
        mermaid_config = os.path.join(work_dir, "mermaid.json")
        with open(mermaid_config, "w") as f:
            json.dump(CONFIG, f)

        for guide_path in guides:
            with open(guide_path) as f:
                guide = f.read()
            blocks = list(BLOCK.finditer(guide))
            # A Mermaid block that doesn't match is likely broken by a `-->`
            # closing the HTML comment early.
            if len(blocks) != guide.count("```mermaid"):
                fail(
                    f"{guide_path}: a Mermaid block is not in the expected format. "
                    "Check that it does not contain `-->` (use `==>` in flowcharts)."
                )
            for block in blocks:
                if not block.group("alt").strip():
                    fail(f"{guide_path}: '{block.group('image')}' needs an alt text")
                render(guide_path, block.group("source"), block.group("image"), work_dir, puppeteer_config, mermaid_config)


if __name__ == "__main__":
    main()
