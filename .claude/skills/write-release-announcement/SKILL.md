---
name: write-release-announcement
description: >
  Write a blog post and Discord announcement for a new Readium Swift Toolkit release.
  Use this skill whenever the user wants to announce a new version, write a blog post,
  or draft a Discord post.
---

## Overview

This skill writes two release announcement documents to the project root:

1. **`BLOG-{VERSION}.md`** — a blog post (no length limit) in the established Readium style
2. **`DISCORD-{VERSION}.md`** — a Discord message (≤ 2000 characters)

## Step 1 — Identify the version

Run this command to get the most recent release tag:

```bash
git tag --sort=-version:refname | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | head -1
```

This is `VERSION` for the rest of the workflow.

## Step 2 — Extract the changelog

```bash
python3 scripts/release-md-tools.py extract-changelog VERSION CHANGELOG.md
```

Read the output carefully. The changelog is organized by module (Shared, Navigator, Streamer, LCP) and change type (Added, Changed, Deprecated, Fixed, Removed). Your job is to translate these raw technical entries into user-facing **themes** that matter to developers integrating the toolkit.

Good themes cut across modules and focus on *what the developer can now do* or *what changed in their workflow*, not on internal architecture. Examples of good theme names:
- "Improved reading for comics and image-based publications" (not "Navigator: Divina support")
- "Secure LCP Repositories with Keychain" (not "LCP: new repository classes")
- "Performance improvements for PDF" (not "Streamer: async PDF opening")

Aim for 3–6 themes. Always surface breaking changes as their own theme or subsection — developers must not miss them.

## Step 3 — Ask the user which themes to feature

Use the tool to ask user questions with multi-selection. Present your proposed themes as options. The user's selection determines the structure of both documents.

If the changelog has breaking changes, always include a "Technical updates and breaking changes" option (or similar).

## Step 4 — Ask about anything extra

Ask the user: "Is there anything else you'd like to mention in the announcements that isn't in the changelog?" (e.g. a new documentation site, an upcoming major version, a community shoutout).

This is a free-text follow-up — use the tool to ask the user with a single open question.

## Step 5 — Write the blog post

Read `references/example-3.7.0.md` and `references/example-3.8.0.md` before writing. Each file contains the raw changelog, the finished blog post, and the finished Discord message for one release — study how the changelog entries were grouped, reworded, and condensed at each step.

### Blog post rules

- **No title heading.** Start directly with a lead paragraph.
- **Lead paragraph:** One sentence opening ("We are happy/pleased to announce...") followed by a brief statement of the release's main themes. Keep it to 2–3 sentences max.
- **One h2 section per selected theme.** Section titles are phrased for a developer audience but avoid jargon dumps. They should read like article headlines.
- **Prose, not bullet dumps.** Explain *why* a feature matters, not just that it exists. Use bullet lists only when a section genuinely has 3+ parallel items (like a list of new preferences or a list of benefits).
- **Code identifiers** always in backticks: `EPUBNavigatorViewController`, `LCPKeychainLicenseRepository`, etc.
- **Breaking changes and deprecations** should be clearly flagged. State clearly what developers must do.
- **Migration guide links:** You can mention the migration guide in the blog post, but don't link to it.
- **Tone:** Friendly, informative, developer-focused. Not marketing fluff. The audience builds reading apps.
- **Don't add relative links:** They won't be available on the blog website. Only external links are allowed.

## Step 6 — Write the Discord announcement

The reference examples in `references/example-3.7.0.md` and `references/example-3.8.0.md` also contain the Discord announcements.

### Discord rules

- **Hard limit: 2000 characters** (Discord will truncate beyond this).
- Choose the right format based on release complexity:
  - **Many distinct themes** → use the 3.7.0 style: GitHub release link as header, sections with bullet points, end with blog URL.
  - **Fewer themes or a focused release** → use the 3.8.0 style: short prose intro, any extra note, then just the blog URL.
- The blog URL pattern is: `https://blog.readium.org/release-note-swift-toolkit-version-{VERSION_DASHES}/` where `3.9.0` becomes `3-9-0`.
- The GitHub release URL pattern is: `https://github.com/readium/swift-toolkit/releases/tag/{VERSION}`
- End with just the bare blog URL on its own line (no markdown link — Discord auto-embeds it).
- If there are breaking changes, include a brief warning so developers don't miss them.

## Step 7 — Save the files

Write the blog post to `BLOG-{VERSION}.md` and the Discord message to `DISCORD-{VERSION}.md` in the project root.

## Reference files

- `references/example-3.7.0.md` — full example for a feature-rich release: raw changelog → blog post → Discord
- `references/example-3.8.0.md` — full example for a focused release: raw changelog → blog post → Discord
