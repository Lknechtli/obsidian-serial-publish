# obsidian-serial-publish

Convert Obsidian markdown to platform-safe output for serial fiction publishing. Supports **Royal Road** (HTML) and **Patreon** (plaintext + blockquotes).

Uses a [Pandoc](https://pandoc.org) Lua filter for deterministic, reproducible conversion — no LLM guesswork.

## Dependencies

- **Pandoc** 3.x (with Lua support) — `brew install pandoc` on macOS, `apt install pandoc` on Debian/Ubuntu
- **sed** — included in every Unix/macOS system

## Usage

```bash
./rr-convert.sh input.md -o output.html        # Royal Road (default, HTML)
./rr-convert.sh input.md -o output.md --mode patreon  # Patreon (plaintext)
```

The script preprocesses `\[\[...\]\]` escape sequences so the Lua filter can distinguish literal brackets from Obsidian wiki links, then pipes through Pandoc with the filter.

### Modes

- **`--mode rr`** (default): Royal Road HTML output with inline styles, headings as `<div>` elements, callouts as styled `<table>` elements
- **`--mode patreon`**: Plaintext output with markdown-lite formatting (`**bold**`, `*italic*`, headings as `#`), callouts as blockquotes — suitable for pasting into Patreon's post editor

### Input / Output

- Takes any `.md` file as input
- Royal Road mode: writes clean HTML to `-o output.html` (or stdout if omitted)
- Patreon mode: writes plaintext to `-o output.md` (or stdout if omitted)
- Does not modify the original markdown file

### Wordcount fixer

`fix-wordcount.sh` corrects the `wordcount:` value in a file's YAML frontmatter to match the actual body text:

```bash
./fix-wordcount.sh chapter.md [more.md ...]
```

Counting rule: plain English words only. The YAML frontmatter is dropped, then HTML tags, Obsidian callout type tags (`[!error]`, `[!info]`, …), line-leading blockquote/heading markers, table pipes, emphasis markers, backticks, and link syntax are stripped (link text kept, backslash escapes unescaped). Tokens are split on whitespace, leading/trailing punctuation is stripped from each, and a token counts only if it still contains at least one letter or digit. So `---`, `…`, `[!error]`, and standalone `/`/`-` tokens are excluded, while visible prose is included — stylized words (`HONK`, `r-iiiii-p`), numbers (`3/3`, `+1`), and callout titles / stat-block lines (`Chaos +1`, `Race: Canadian Goose | Alignment: Chaotic`).

Files without frontmatter, or without a `wordcount:` line, are skipped with a warning (the field is never added). Files whose count is already correct are left untouched, so re-runs cause no mtime churn. Safe to run after `smartify` — quote/ellipsis normalization does not change token counts.

## Configuration

All Royal Road styling is controlled by `rr-convert.settings.lua`. Edit it to customize:

| Section | What it controls |
|---|---|
| `headings` | Font size, weight, margins for h1–h6 → div conversion |
| `data_spans` | How `<span data-foo="">` elements are transformed (e.g. glitch effect) |
| `callout_table` | Shared wrapper, table, shadow, border, and title prefix styles |
| `callouts` | Per-type color, symbol, heading/body/border styles |
| `horizontal_rule` | Full `<hr>` HTML string |
| `doc_wrapper_style` | Document-level wrapper div CSS |

The filter loads settings via the `RR_CONVERT_SETTINGS` environment variable (set automatically by `rr-convert.sh`).



## Using as an AI Skill

Drop this repo into your AI assistant's skill directory so it can convert chapters on demand:

```bash
# For "Oh My Pi" / opencode
cp -r obsidian-serial-publish ~/.config/opencode/skills/royal-road-converter

# The SKILL.md frontmatter registers it as a user-invocable skill
```

The SKILL.md documents every conversion rule the filter implements. When asked to convert markdown, the AI will run `rr-convert.sh` rather than generating HTML manually.

## Conversion Rules

Royal Road's HTML parser strips or mangles many elements. The filter handles:

- **Headings** → `<div>` with inline styles (RR converts `<hN>` to `<p>`)
- **Callouts** → styled `<table>` elements (RR strips `<pre>`)
- **Wiki links** (`[[text]]`) → stripped; literal brackets (`\[\[text\]\]`) → preserved
- **Forbidden tags** (`<script>`, `<style>`, `<iframe>`, etc.) → deleted
- **Stripped attributes** (`id`, `class`, `onclick`, etc.) → removed
- **Pixel dimensions** → converted to `em` units
- **Pure black/white colors** → replaced with RR-safe alternatives

See [SKILL.md](SKILL.md) for the complete rule set.

## License

MIT — see [LICENSE](LICENSE).
