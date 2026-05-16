# Royal Road Scrubber — Examples

Live examples of every conversion the `rr-scrubber.lua` Pandoc Lua filter performs.

## Files

- **`examples-input.md`** — Source markdown with all example constructs
- **`examples-output.html`** — Generated HTML from running the pandoc filter

## Usage

```bash
./rr-scrubber.sh input.md -o output.html
```

The script preprocesses `\[\[...\]\]` escape sequences so the Lua filter can distinguish them from wiki links. Under the hood it runs `sed` to swap `\[` / `\]` for control characters, then pipes through pandoc with `rr-scrubber.lua`.

## What's Demonstrated

### Headings (h1–h6 → styled divs)

Royal Road mangles `<h1>`–`<h6>` into `<p>` tags. The scrubber converts them to `<div>` elements with inline styles.

| Markdown | Heading Level |
|----------|--------------|
| `# Heading` | h1 → `font-size:2.0em` |
| `## Heading` | h2 → `font-size:1.6em` |
| `### Heading` | h3 → `font-size:1.3em` |
| `#### Heading` | h4 → `font-size:1.1em` |
| `##### Heading` | h5 → `font-size:1.0em` |
| `###### Heading` | h6 → `font-size:0.9em` + uppercase |

### Paragraphs

Each paragraph is wrapped in a `<div>` with `margin-bottom:1em`.

### Text Formatting

| Markdown | HTML Output |
|----------|-------------|
| `**bold**` | `<strong>bold</strong>` |
| `_italic_` | `<em>italic</em>` |
| `~~strikethrough~~` | `<del>strikethrough</del>` |
| `` `code` `` | `<code>code</code>` |

### Links

| Input | Behavior |
|-------|----------|
| `[text](url)` | Preserved as `<a href="url">text</a>` — Royal Road supports links natively |
| `[[Wiki Link]]` | Stripped — only visible text remains |
| `\[\[Literal\]\]` | Escaped brackets → literal `[[Literal]]` in output |

### Lists

Standard unordered (`- item`) and ordered (`1. item`) lists pass through as `<ul>`/`<ol>`.

### Horizontal Rules

`---` becomes a styled `<hr>` with chromatic aberration box-shadow.

### Images

`![alt](src)` becomes a `<figure>` with `<figcaption>` containing the alt text. The image itself does **not** embed — only the alt text is preserved.

### Callouts

Obsidian callout syntax (`> [!type] Title`) becomes styled `<table>` elements. Royal Road strips `<pre>` tags, so tables are used instead.

| Callout Type | Color | Symbol | Special |
|--------------|-------|--------|---------|
| `info` | `#1e90ff` (blue) | ℹ | — |
| `tip` | `#4caf50` (green) | ▶ | — |
| `warning` | `#ff5722` (deep orange) | ⚠ | — |
| `error` | `#f44336` (red) | ✖ | Chromatic aberration + bold body |
| `note` | `#8bc34a` (light green) | ✎ | — |
| `task` | `#9c27b0` (purple) | ☑ | — |
| `quote` | `#607d8b` (slate) | ❝ | — |
| `example` | `#ba68c8` (purple) | ☷ | — |
| unknown | `#1e90ff` (info) | ℹ | Falls back to info |

Each callout renders as:
- Outer wrapper div with `max-width:60ch` centered on page
- Table with dark background (`#1a1a2e`), monospace font, rounded corners
- Title row with colored background, traffic-light dots, and Unicode symbol
- Body row(s) with indented content
- Table border matching the callout color

### Multi-Section Callouts

A `---` separator inside a callout splits the body into separate table rows. Each section becomes its own `<tr><td>` cell, with a `border-bottom` separator between them (no border on the last section).

```markdown
> [!info] Spell Reference
> **Fireball** — 3rd-level evocation
>
> ---
>
> **Description**
> A bright streak flashes from your pointing finger.
>
> ---
>
> **Saving Throw**
> Dexterity save or take 8d6 fire damage.
```

Produces a table with 4 rows: title + 3 body sections.

### Full Chapter Example

The bottom of `examples-input.md` has a complete chapter combining headings, paragraphs, bold/italic text, callouts, lists, links, wiki links, and horizontal rules — showing how everything works together.
