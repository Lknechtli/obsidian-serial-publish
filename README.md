# obsidian-serial-publish

Convert Obsidian markdown to platform-safe HTML for serial fiction publishing. Currently supports **Royal Road**; more platforms planned.

Uses a [Pandoc](https://pandoc.org) Lua filter for deterministic, reproducible conversion — no LLM guesswork.

## Dependencies

- **Pandoc** 3.x (with Lua support) — `brew install pandoc` on macOS, `apt install pandoc` on Debian/Ubuntu
- **sed** — included in every Unix/macOS system

## Usage

```bash
./rr-convert.sh input.md -o output.html
```

The script preprocesses `\[\[...\]\]` escape sequences so the Lua filter can distinguish literal brackets from Obsidian wiki links, then pipes through Pandoc with the filter.

### Input / Output

- Takes any `.md` file as input
- Writes clean HTML to `-o output.html` (or stdout if omitted)
- Does not modify the original markdown file

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

**Ghost mode styling:** The Ghost converter (`--mode ghost`) produces clean semantic HTML with class-based output — no inline styles. All visual styling is handled by your Ghost theme's CSS (e.g. `rr-theme.css` in the theme's `assets/css/ghost/` directory). The settings file is still used for callout type definitions (colors, symbols), but layout and typography come from the theme.

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
