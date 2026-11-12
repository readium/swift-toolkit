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
    ![Alt text](Assets/timeline-segments.svg)

The SVG is written in the `Assets` folder next to the guide. For DocC, which
only resolves images by file name, `scripts/prepare-docc-catalog.py` strips the
`Assets/` prefix from the image links.

Each diagram is also rendered with a dark palette, as `name~dark.svg`, which
DocC displays in dark mode. GitHub always displays the light one.

Requires Node.js (npx) and Google Chrome. Set PUPPETEER_EXECUTABLE_PATH to use
another Chrome or Chromium binary.
"""

import json
import os
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass

MERMAID_CLI = "@mermaid-js/mermaid-cli@11.4.2"
DEFAULT_CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


@dataclass
class Palette:
    """
    Colors of the diagrams. In Gantt charts, an untagged task is drawn
    `strong`, an `active` task `light` and a `done` task `gray`. The `_alt`
    colors are the alternate shades of the bars touching each other.
    """

    suffix: str
    background: str
    text: str
    line: str
    grid: str
    section: str
    alt_section: str
    cluster: str
    cluster_border: str
    strong: str
    strong_alt: str
    strong_border: str
    strong_text: str
    light: str
    light_alt: str
    light_border: str
    gray: str
    gray_alt: str
    gray_border: str


LIGHT = Palette(
    suffix="",
    background="white",
    text="#1f2d3d",
    line="#555555",
    grid="#d0d7de",
    section="#f6f8fa",
    alt_section="#ffffff",
    cluster="#f6f8fa",
    cluster_border="#c0c8d0",
    strong="#3b6ea5",
    strong_alt="#2b5584",
    strong_border="#24476e",
    strong_text="#ffffff",
    light="#d6e6f7",
    light_alt="#a9c8ea",
    light_border="#3b6ea5",
    gray="#ececec",
    gray_alt="#d2d2d2",
    gray_border="#9e9e9e",
)

# Drawn on a transparent background, to blend with the dark page of DocC.
DARK = Palette(
    suffix="~dark",
    background="transparent",
    text="#e6edf3",
    line="#9aa4ad",
    grid="#3a3f45",
    section="#161b22",
    alt_section="#0d1117",
    cluster="#161b22",
    cluster_border="#3a3f45",
    strong="#4a80bd",
    strong_alt="#3a6aa0",
    strong_border="#8fb8e6",
    strong_text="#ffffff",
    light="#1f3a5c",
    light_alt="#2b4f7c",
    light_border="#6ea0d8",
    gray="#2b2f35",
    gray_alt="#3a3f46",
    gray_border="#6e7681",
)


def mermaid_config(palette):
    return {
        "theme": "base",
        "themeVariables": {
            "fontFamily": "-apple-system, 'Helvetica Neue', Helvetica, Arial, sans-serif",
            "background": palette.background,
            "textColor": palette.text,
            "primaryColor": palette.light,
            "primaryBorderColor": palette.light_border,
            "primaryTextColor": palette.text,
            "lineColor": palette.line,
            "clusterBkg": palette.cluster,
            "clusterBorder": palette.cluster_border,
            "titleColor": palette.text,
            "taskBkgColor": palette.strong,
            "taskBorderColor": palette.strong_border,
            "taskTextLightColor": palette.strong_text,
            "taskTextColor": palette.strong_text,
            "activeTaskBkgColor": palette.light,
            "activeTaskBorderColor": palette.light_border,
            "doneTaskBkgColor": palette.gray,
            "doneTaskBorderColor": palette.gray_border,
            "taskTextDarkColor": palette.text,
            "taskTextOutsideColor": palette.text,
            "sectionBkgColor": palette.section,
            "altSectionBkgColor": palette.alt_section,
            "sectionBkgColor2": palette.section,
            "gridColor": palette.grid,
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


def fix_size(svg, palette):
    """
    Replaces the fluid width of the SVG with its intrinsic size, otherwise
    DocC renders it as a thumbnail.
    """
    tag = re.search(r"<svg\b[^>]*>", svg).group(0)
    viewbox = re.search(r'viewBox="[-\d.]+ [-\d.]+ ([\d.]+) ([\d.]+)"', tag)
    if not viewbox:
        fail("no viewBox in the SVG")
    width, height = viewbox.groups()
    new_tag = re.sub(r'\s(width|height|style)="[^"]*"', "", tag)
    new_tag = new_tag.replace(
        "<svg",
        f'<svg width="{width}" height="{height}" style="background-color: {palette.background};"',
        1,
    )
    return svg.replace(tag, new_tag, 1)


def alternate_adjacent_bars(svg, svg_id, palette):
    """
    Alternates the shade of the Gantt bars touching each other on a row, so
    that their boundaries stand out.
    """
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
        f"#{svg_id} rect.task.alt{{fill:{palette.strong_alt};}}"
        f'#{svg_id} rect.task.alt[class*="active"]{{fill:{palette.light_alt};}}'
        f'#{svg_id} rect.task.alt[class*="done"]{{fill:{palette.gray_alt};}}'
    )
    return svg.replace("</style>", style + "</style>", 1)


def render(guide_path, source, image, work_dir, puppeteer_config):
    if not re.fullmatch(r"Assets/[^/]+\.svg", image):
        fail(f"{guide_path}: '{image}' must be an SVG in the Assets folder, such as 'Assets/name.svg'")

    name = os.path.basename(image)[: -len(".svg")]
    input_path = os.path.join(work_dir, f"{name}.mmd")
    with open(input_path, "w") as f:
        f.write(source + "\n")

    for palette in [LIGHT, DARK]:
        config_path = os.path.join(work_dir, f"mermaid{palette.suffix}.json")
        with open(config_path, "w") as f:
            json.dump(mermaid_config(palette), f)

        output_path = os.path.join(os.path.dirname(guide_path), "Assets", f"{name}{palette.suffix}.svg")
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        # A unique ID, as DocC references each SVG by its root ID.
        svg_id = name + palette.suffix.replace("~", "-")

        subprocess.run(
            [
                "npx", "--yes", "--package", MERMAID_CLI, "mmdc",
                "--puppeteerConfigFile", puppeteer_config,
                "--configFile", config_path,
                "--backgroundColor", palette.background,
                "--svgId", svg_id,
                "--input", input_path,
                "--output", output_path,
                "--quiet",
            ],
            check=True,
            # Gantt charts are laid out in local time, which would shift a time
            # axis starting at 00:00.
            env={**os.environ, "TZ": "UTC", "PUPPETEER_SKIP_DOWNLOAD": "1"},
        )

        with open(output_path) as f:
            svg = f.read()
        svg = fix_size(svg, palette)
        svg = alternate_adjacent_bars(svg, svg_id, palette)
        with open(output_path, "w") as f:
            f.write(svg)
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
                render(guide_path, block.group("source"), block.group("image"), work_dir, puppeteer_config)


if __name__ == "__main__":
    main()
