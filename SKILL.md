--- 
name: royal-road-converter
description: Convert Obsidian markdown to Royal Road-compatible HTML. Uses a Pandoc Lua filter (rr-convert.lua) applied via --lua-filter for deterministic, testable conversion. Strips forbidden tags, converts headings to divs with inline styles, renders callouts as styled tables, preserves regular links, strips wiki links, unescapes brackets, and removes properties RR would break.
user_invocable: true
---

# Royal Road Converter — Pandoc Lua Filter

**Recommended approach:** Use the bundled `rr-convert.sh` script for deterministic, testable conversion:

    ./rr-convert.sh input.md -o output.html

This handles `\[\[...\]\]` escape preprocessing and runs the `rr-convert.lua` Lua filter with pandoc. The script swaps escaped brackets to control characters before pandoc parses them, so the filter can distinguish literal brackets from wiki links.

**Note:** The SKILL.md below documents the conversion rules that the Lua filter implements. For new conversions, always prefer running the lua filter over instructing an LLM to manually apply these rules.

Royal Road has a restrictive HTML/CSS parser ("the wizard") that strips or mangles certain elements during publishing. When given an Obsidian markdown file, produce HTML output that passes Royal Road's parser intact by applying these rules in order.

## Output File

When given a markdown file, write the converted HTML to a new `.html` file:
- Take the input path (e.g., `Chapter 1/Draft 2.md`)
- Replace extension to produce `Chapter 1/Draft 2.html`
- Do **not** overwrite or modify the original markdown file
- Output only HTML — no preamble, explanation text, or code fences around the output

## Conversion Order (apply sequentially)

1. **Strip** forbidden HTML tags and their contents
2. **Remove** ID/class/event attributes from remaining tags
3. **Convert** heading tags (`<hN>` to `<div>`) 
4. **Fix** CSS properties that RR would break or strip
5. **Remove** absolute positioning declarations

---

## 1. STRIP — Forbidden Elements (delete entirely)

Royal Road's parser deletes these. Do not include them in output.

### Tags and Contents to Delete
Delete the opening tag, all inner HTML, and closing tag for:
`<script>`, `<style>`, `<iframe>`, `<object>`, `<embed>`, `<form>`, `<input>`, `<button>`, `<textarea>`, `<svg>`, `<canvas>`, `<video>`, `<audio>`

### Attributes to Remove from Any Tag
- `id="..."` — remove the entire attribute
- `class="..."` — remove the entire attribute  
- Any `on[a-z]+=` event handler (`onclick=`, `onload=`, etc.) — remove the entire attribute

**Note:** When removing class attributes, preserve semantic meaning by adding inline styles (see heading conversion below).

---

## 2. CONVERT — Safe Replacements

Royal Road's parser breaks these properties unless you pre-convert them. Apply these transformations during markdown-to-HTML conversion.

### Background Colors — RR Color Inverter
RR randomly inverts pure black (`#000`, `#000000`, `"black"`) and pure white (`#fff`, `#ffffff`, `"white"`) on publish/preview only (not edit mode). RR recommends `#212529` for black and `#f8f9fa` or `#fafafa` for white.

**Rule:** When converting background-color or color values:
- `#000`, `#000000`, `black` to `#212529`
- `#fff`, `#ffffff`, `white` to `#fafafa` (or `#f8f9fa`)

To prevent RR from stripping solid background colors, wrap them in a gradient:
```css
background-color: #000;
/* Convert to */
background-image: linear-gradient(135deg, #212529, #212529);
background-color: #212529 !important;
```

### Border-Radius — Must Have !important
RR strips border-radius unless `!important` is present.

**Rule:** Append `!important` to any `border-radius:` declaration.
```css
/* Before */
border-radius: 8px;
/* After */
border-radius: 8px !important;
```

### Font-Size / Line-Height — px to em Conversion
RR strips pixel-based font sizes and line heights. Convert to em units.

**Rule:** `font-size: Npx` to `(N divided by 10)em`, rounded to one decimal place, clamped between 0.3em and 2.4em. Same for `line-height`.
```css
/* Before */
font-size: 16px; line-height: 24px;
/* After */
font-size: 1.6em; line-height: 2.4em;
```

### Heading Tags — `<hN>` to `<div>` with Inline Styling
RR mangles `<h1>` through `<h6>` into `<p>` tags during parsing. Convert to `<div>` elements with inline styles that replicate heading semantics.

**Rule:** Replace every `<hN` and `</hN>` (N is 1 through 6) with `<div` / `</div>`. Add inline styles for font-size, font-weight, and margins appropriate to the heading level:

| Level | Inline style template |
|-------|----------------------|
| h1    | `font-size:2.0em;font-weight:bold;margin:1.5em 0 0.8em;` |
| h2    | `font-size:1.6em;font-weight:bold;margin:1.3em 0 0.7em;` |
| h3    | `font-size:1.3em;font-weight:bold;margin:1.1em 0 0.5em;` |
| h4    | `font-size:1.1em;font-weight:bold;margin:0.9em 0 0.4em;` |
| h5    | `font-size:1.0em;font-weight:bold;margin:0.7em 0 0.3em;` |
| h6    | `font-size:0.9em;font-weight:bold;text-transform:uppercase;margin:0.6em 0 0.2em;` |

Preserve the original element's text content and any inline style attributes (merge if needed). Do not preserve class or id attributes — they get stripped by RR anyway.

**Example:**
```html
<!-- Markdown: ## Chapter Title -->
<h2>Chapter Title</h2>
<!-- Becomes -->
<div style="font-size:1.6em;font-weight:bold;margin:1.3em 0 0.7em;">Chapter Title</div>
```

### Background Shorthand — Convert to background-image:
RR strips `background:` shorthand declarations that contain gradients but preserves `background-image:` declarations.

**Rule:** When encountering `background:` with a gradient value, convert to `background-image:` only:
```css
/* Before */
background: linear-gradient(135deg, #1a1a2e, #16213e) center/cover no-repeat;
/* After */
background-image: linear-gradient(135deg, #1a1a2e, #16213e);
```

Strip any shorthand sub-properties (color, position, size, repeat). Keep only the gradient.

### Absolute Positioning — Remove Entirely
RR strips `position: absolute` and will break your layout. There is no safe equivalent value RR accepts.

**Rule:** Delete all `position: absolute;` declarations along with their positioning properties (`top`, `left`, `right`, `bottom`). For overlapping elements, rebuild using CSS Grid or structural margins/borders instead.
```css
/* Before */
position: absolute; top: 10px; left: 20px; z-index: 5;
/* After — delete entirely */
```

### Pixel Dimensions (width/height) — Convert to em or %
RR strips `width:` and `height:` values expressed in pixels.

**Rule:** 
- Convert `width: Npx` to `(N divided by 10)em` (same clamp as font-size: min 0.3em, max 2.4em)
- Or better: remove fixed px dimensions entirely and use flexbox/grid for layout instead
- Percentages are preserved by RR but pixels are not

---

## 3. REMOVE — Properties to Delete (RR strips these; no safe equivalent)

Do not include these in output — they waste bytes and serve zero purpose since RR deletes them regardless.

| Property | Pattern | Action |
|----------|---------|--------|
| Clip-path: polygon | `clip-path: polygon(...)` | **Delete** from CSS block |
| Position absolute | `position: absolute` | **Delete** entire declaration + related positioning props (top, left, right, bottom) |

---

## 4. MARKDOWN TO HTML SPECIFIC RULES

When the input is Obsidian markdown, apply these conversions before applying converter rules above.

### Headings
```markdown
# H1        -> <div style="font-size:2.0em;font-weight:bold;margin:1.5em 0 0.8em;">Heading</div>
## H2       -> <div style="font-size:1.6em;font-weight:bold;margin:1.3em 0 0.7em;">Heading</div>
### H3      -> <div style="font-size:1.3em;font-weight:bold;margin:1.1em 0 0.5em;">Heading</div>
#### H4     -> <div style="font-size:1.1em;font-weight:bold;margin:0.9em 0 0.4em;">Heading</div>
##### H5    -> <div style="font-size:1.0em;font-weight:bold;margin:0.7em 0 0.3em;">Heading</div>
###### H6   -> <div style="font-size:0.9em;font-weight:bold;text-transform:uppercase;margin:0.6em 0 0.2em;">Heading</div>
```

### Paragraphs — Wrap in `<p>` Tags with Spacing

Each block of text between blank lines (or after a heading) is a paragraph. Wrap each one:

```markdown
Some paragraph text   ->   <p style="margin-bottom:1em;">Some paragraph text</p>
```

Do **not** collapse consecutive paragraphs into a single `<p>` — RR may strip content if not separated properly.

### Bold & Emphasis (inside `<p>`)

| Markdown | HTML Output | Notes |
|----------|-------------|-------|
| `**bold**` or `__bold__` | `<b>text</b>` | RR-safe |
| `_italic_` or `*italic*` | `<i>text</i>` | RR-safe |
| `~~strikethrough~~` | `<strike>text</strike>` | RR-safe |

### Code Blocks

```markdown
Inline: `code`        -> <code>code</code> (safe)
Fenced block:          -> <div class="sourceCode"><code>...content...</code></div>
                        -> No <pre> wrapper (RR strips <pre> tags)
```

### Links

- `[text](url)` -> preserved as `<a href="url">text</a>` (Royal Road supports links natively)
- `[[Page Name]]` -> stripped entirely (Obsidian wiki-links have no RR equivalent)
- `\[\[Text\]\]` -> unescaped to literal `[[Text]]` in output (requires `rr-convert.sh` preprocessing)

### Escaped Brackets — Unescape in Output

Backslash-escaped brackets are literal text in Obsidian and should output with brackets intact:
- `\[\[Text\]\]` -> `[[Text]]` (requires `rr-convert.sh` which preprocesses escapes before pandoc)

**Rule:** Use `./rr-convert.sh input.md -o output.html` rather than raw pandoc, so that `\[\[...\]\]` sequences are distinguished from wiki links during preprocessing.

### Lists

| Markdown | HTML Output | Notes |
|----------|-------------|-------|
| `- item` / `* item` | `<li>item</li>` inside `<ul>` | RR-safe |
| `1. item` | `<li>item</li>` inside `<ol>` | RR-safe |

### Horizontal Rules & Images

| Markdown | HTML Output | Notes |
|----------|-------------|-------|
| `---` | `<hr style="border:0;border-top:2px solid #333;margin:2em 0;">` | RR-safe |
| `![alt](src)` | `<img src="src" alt="alt">` | Ensure trusted domain; use em or % for width/height — never px |

### Callouts — Styled Tables (RR-safe, no `<pre>` tags)

Obsidian callout syntax (`> [!type]`) becomes styled `<table>` elements wrapped in a max-width container. Royal Road strips `<pre>` tags, so tables are used instead.

**Supported callout types:**

| Callout Type | Color (hex) | Symbol | Notes |
|--------------|-------------|--------|-------|
| `info`       | `#1e90ff`   | ℹ      | Blue        |
| `tip`        | `#4caf50`   | ▶      | Green       |
| `warning`    | `#ff5722`   | ⚠      | Deep orange/red |
| `error`      | `#f44336`   | ✖      | Red + chromatic aberration |
| `note`       | `#8bc34a`   | ✎      | Light green  |
| `task`       | `#9c27b0`   | ☑      | Purple      |
| `quote`      | `#607d8b`   | ❝      | Slate blue  |

**Structure:** Each callout renders as:
- Outer wrapper: `<div style="max-width:90ch!important;margin:auto;">` — caps width at ~90 characters, centers on page
- Table with dark background (`#1a1a2e`) and monospace font
- **Title row**: colored bold text with Unicode symbol prefix; `border-bottom:2px solid <color>` separator (or 0 if no body)
- **Body row**: content with `<br />` preserving line breaks; all cell borders at 0
- Outer table border: `4px solid <color>` on the table element itself

**All critical CSS properties use `!important`** to override Royal Road defaults.

**Special handling for `[!error]`:**
- Chromatic aberration via multi-layer box-shadow (red/cyan offsets in multiple directions)
- **All body text is bold** — wrapped in `<b>` tags

**Example ([!info]):**
```markdown
> [!info] Note
> This is an informational note.

<!-- becomes -->
<div style="max-width:90ch!important;margin:auto;">
<table style="background:#1a1a2e!important;color:#ddd!important;width:100%!important;font-family:monospace!important;font-size:0.9em!important;white-space:pre-wrap!important;border-radius:8px !important;box-shadow:-4px 4px 0 #1e90ff66!important;border:4px solid #1e90ff!important;">
<tr><td colspan="2" style="color:#1e90ff!important;font-weight:bold!important;padding:0.5em 1em!important;border-top:0!important;border-right:0!important;border-left:0!important;border-bottom:2px solid #1e90ff!important;">ℹ Note</td></tr>
<tr><td colspan="2" style="padding:0.5em 1em!important;border-top:0!important;border-right:0!important;border-left:0!important;border-bottom:0!important;"><span style="display:block!important;padding-left:1em!important;text-indent:-1em!important;">This is an informational note.</span></td></tr>
</tbody></table>
</div>
```

**Example ([!error]):**
```markdown
> [!error] Critical Failure
> The system encountered a fatal error.

<!-- becomes -->
<div style="max-width:90ch!important;margin:auto;">
<table style="background:#1a1a2e!important;color:#ddd!important;width:100%!important;font-family:monospace!important;font-size:0.9em!important;white-space:pre-wrap!important;border-radius:8px !important;box-shadow:-4px 4px 0 #f4433666!important,-2px -1px 0 #ff0000!important,2px 1px 0 #00ffff!important,-3px 2px 0 rgba(255,0,0,0.4)!important,3px -2px 0 rgba(0,255,255,0.4)!important;border:4px solid #f44336!important;">
<tr><td colspan="2" style="color:#f44336!important;font-weight:bold!important;padding:0.5em 1em!important;border-top:0!important;border-right:0!important;border-left:0!important;border-bottom:2px solid #f44336!important;">✖ Critical Failure</td></tr>
<tr><td colspan="2" style="padding:0.5em 1em!important;border-top:0!important;border-right:0!important;border-left:0!important;border-bottom:0!important;"><span style="display:block!important;padding-left:1em!important;text-indent:-1em!important;"><b>The system encountered a fatal error.</b></span></td></tr>
</tbody></table>
</div>
```

**Note:** Type variants with numeric suffixes (e.g., `task-1`) are normalized to their base type (`task`). Unknown types default to `info`.

---

## 5. SAFE ELEMENTS & PROPERTIES (no conversion needed)

### HTML Elements That Survive Unchanged
`<div>`, `<span>`, `<p>`, `<br>`, `<hr>`, `<ul>`, `<ol>`, `<li>`, `<a href="">`, `<b>`, `<i>`, `<u>`, `<strike>`, `<sub>`, `<sup>`, `<code>`, `<figure>`, `<figcaption>`, `<blockquote>`

### HTML Elements That Are Stripped
`<pre>` — RR strips `<pre>` tags. Use `<code>` without `<pre>` wrapper.
`<font>` — RR converts `<font color="...">` to `<span style="color:...">`. Use `<span>` directly.

### CSS Properties That Survive (with correct values)
- `color:` — safe as long as value is not pure #000/#fff (use conversions above)
- `background-image:` — gradients via this property survive; shorthand does not
- `border:` / `border-top:` etc. — safe
- `padding:`, `margin:` — use em or %, avoid px
- `display: flex | grid | block | inline-block` — all safe
- `text-shadow:` — safe
- `font-weight: bold` — safe

---

## EXAMPLE: Full Conversion Walkthrough

**Input markdown:**
```markdown
# My Chapter

## Introduction

This is **bold** and _italic_ text with a black background.

![Image](https://example.com/image.png)

> [!info] Note
> This is an informational note about the chapter.

> [!error] Warning
> The system failed to initialize.

[Read more](https://example.com)
```

**Output HTML (RR-safe):**
```html
<div style="font-size:2.0em;font-weight:bold;margin:1.5em 0 0.8em;">My Chapter</div>

<div style="font-size:1.6em;font-weight:bold;margin:1.3em 0 0.7em;">Introduction</div>

<p>This is <b>bold</b> and <i>italic</i> text with a black background.</p>

<img src="https://example.com/image.png" alt="Image">

<div style="max-width:90ch!important;margin:auto;">
<table style="background:#1a1a2e!important;color:#ddd!important;width:100%!important;font-family:monospace!important;font-size:0.9em!important;white-space:pre-wrap!important;border-radius:8px !important;box-shadow:-4px 4px 0 #1e90ff66!important;border:4px solid #1e90ff!important;">
<tr><td colspan="2" style="color:#1e90ff!important;font-weight:bold!important;padding:0.5em 1em!important;border-top:0!important;border-right:0!important;border-left:0!important;border-bottom:2px solid #1e90ff!important;">ℹ Note</td></tr>
<tr><td colspan="2" style="padding:0.5em 1em!important;border-top:0!important;border-right:0!important;border-left:0!important;border-bottom:0!important;"><span style="display:block!important;padding-left:1em!important;text-indent:-1em!important;">This is an informational note about the chapter.</span></td></tr>
</tbody></table>
</div>

<div style="max-width:90ch!important;margin:auto;">
<table style="background:#1a1a2e!important;color:#ddd!important;width:100%!important;font-family:monospace!important;font-size:0.9em!important;white-space:pre-wrap!important;border-radius:8px !important;box-shadow:-4px 4px 0 #f4433666!important,-2px -1px 0 #ff0000!important,2px 1px 0 #00ffff!important,-3px 2px 0 rgba(255,0,0,0.4)!important,3px -2px 0 rgba(0,255,255,0.4)!important;border:4px solid #f44336!important;">
<tr><td colspan="2" style="color:#f44336!important;font-weight:bold!important;padding:0.5em 1em!important;border-top:0!important;border-right:0!important;border-left:0!important;border-bottom:2px solid #f44336!important;">✖ Warning</td></tr>
<tr><td colspan="2" style="padding:0.5em 1em!important;border-top:0!important;border-right:0!important;border-left:0!important;border-bottom:0!important;"><span style="display:block!important;padding-left:1em!important;text-indent:-1em!important;"><b>The system failed to initialize.</b></span></td></tr>
</tbody></table>
</div>
```

(Links `[text](url)` are preserved as `<a>` tags. Wiki links `[[wiki]]` are removed entirely, leaving surrounding text intact.)

---

## SUMMARY CHECKLIST (Lua Filter Output)

For every markdown-to-RR-HTML conversion via the Lua filter, verify:
- [ ] No `<script>`, `<style>`, `<iframe>`, `<svg>`, etc. tags remain
- [ ] All headings are `<div>` with inline styles (not `<hN>`)
- [ ] Links `[text](url)` preserved as `<a href="">` tags
- [ ] Wiki links `[[wiki]]` are removed entirely
- [ ] Escaped brackets `\[\[...\]\]` rendered as literal `[[...]]` (use `rr-convert.sh`)
- [ ] Callouts rendered as styled tables in max-width wrapper divs
- [ ] `[!error]` callouts have single combined box-shadow (chromatic aberration + base) and bold body text
- [ ] Callout titles use `<span style="color:...">` for traffic light dots (not `<font>`)
- [ ] Code blocks use `<code>` without `<pre>` wrapper
- [ ] All `box-shadow` properties are single declarations (RR only keeps the first)

**Note:** CSS-level conversions (color inverter, border-radius `!important`, px→em, background shorthand → `background-image`, absolute positioning removal) apply only when the input already contains inline styles. The Lua filter handles markdown AST transformations; CSS property rewriting would need a separate post-processor if your source uses style attributes extensively.
