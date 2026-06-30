# Royal Road Scrubber — Examples

Demonstrates every conversion the `rr-convert.lua` Pandoc Lua filter performs on Obsidian markdown.

---

## Headings (h1–h6 → styled divs)

Royal Road mangles `<h1>`–`<h6>` into `<p>` tags. The converter converts them to `<div>` elements with inline styles.

# Level 1 Heading
## Level 2 Heading
### Level 3 Heading
#### Level 4 Heading
##### Level 5 Heading
###### Level 6 Heading

---

## Paragraphs

This is the first paragraph.

This is the second paragraph.

---

## Bold, Italic, and Strikethrough

This is **bold**, _italic_, and ~~strikethrough~~ text.

---

## Chromatic Aberration (data-glitch)

Use `<span data-glitch="">` for a chromatic aberration text-shadow effect.

<span data-glitch="">This text has a glitch effect</span>

The glitch effect also works inside callouts:

> [!error] Profile: Quincy Adams | Level 1
> Race: Canadian Goose  |  Alignment: <span data-glitch="">Chaotic</span>
>
> ---
>
> <span data-glitch="">[Touch of Chaos]</span>
> Passive — You radiate an unsettling aura.

---

## Paragraph Spacing (demo)

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt.

Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur?

---

## Links (preserved)

Regular URLs pass through as `<a>` tags — Royal Road supports them natively.

Read more at [Example Site](https://example.com) for details.

---

## Wiki Links (removed entirely)

Obsidian `[[wiki links]]` have no Royal Road equivalent and are deleted.

See [[Character Sheet]] and [[World Map]] for reference.

---

## Literal Brackets

Use backslash-escaped brackets to output literal `[[Text]]` in the final HTML.

The spell is \[\[Fireball\]\] and the place is \[\[Castle Ruins\]\].

Escaped brackets inside quoted text also resolve correctly: "I was an \[Overlord]."

---

## Inline Code

Use the `pandoc` command with `--lua-filter` flag.

---

## Fenced Code Blocks

```python
def hello():
    print("Hello, Royal Road!")
```

---

## Escaped Brackets in Code Blocks

Backslash-escaped brackets inside fenced code blocks remain as literal text.

```
\[test\]
```
---

## Unordered Lists

- Apples
- Bananas
- Cherries

---

## Ordered Lists

1. First step
2. Second step
3. Third step

---

## Task Lists

Task list checkboxes are converted to symbols: ☐ for unchecked, ☑ for checked.

- [ ] Unchecked item
- [x] Checked item with lowercase x
- [X] Also checked with uppercase X
- Regular list item without checkbox

---

## Horizontal Rules

---

## Images

![Dragon illustration](https://www.royalroad.com/dist/img/nocover-new-min.png)

---

## Callouts

Obsidian callout syntax becomes styled `<table>` elements. Royal Road strips `<pre>` tags, so tables are used instead.

### Info Callout

> [!info] About This Chapter
> This chapter introduces the main characters.
> Pay attention to the timeline.
> \[Time Lock: 0:06:00]

### Tip Callout

> [!tip] Writing Advice
> Show, don't tell. Let actions reveal character.

### Warning Callout

> [!warning] Spoiler Ahead
> The following section reveals the antagonist's identity.

### Error Callout

The error callout has special handling: multi-layer chromatic aberration box-shadow and bold body text.

> [!error] Critical Plot Hole
> The timeline contradicts itself in chapter three.

### Note Callout

> [!note] Author's Note
> Thanks for reading! Leave a review if you enjoyed.

### Task Callout

> [!task] Beta Reader Checklist
> - [ ] Check for continuity errors in the magic system
> - [x] Verify character names are consistent
> - [ ] Review chapter pacing

### Quote Callout

> [!quote] Epigraph
> "The only way out of the labyrinth is through."

### Example Callout

> [!example] Sample Dialogue
> "You shall not pass!" shouted the wizard.

### Multi-Section Callout

A `---` separator inside a callout splits the body into separate table rows, each with its own cell.

> [!info] Spell Reference
> **Fireball** — 3rd-level evocation
> Range: 150 feet
> Casting Time: 1 action
>
> ---
>
> **Description**
> A bright streak flashes from your pointing finger to a point you choose within range and then blossoms with a low roar into an explosion of flame.
>
> ---
>
> **Saving Throw**
> Dexterity save or take 8d6 fire damage. Half damage on a success.

### Multi-Column Callout

A `|` separator inside a callout line splits the content into multiple table columns.

> [!tip] Character Stats
> **Name** | **Class** | **Level**
> Kael | Wizard | 5
> Mira | Rogue | 3
### Mixed Column Counts

Rows with fewer columns than the max are padded with empty cells.

> [!tip] Spell Comparison
> **Spell** | **School** | **Level**
> Fireball | Evocation | 3
> Shield | Abjuration | 2
> Simple spell with no columns

### Hidden Callouts (New)

These callouts collapse into a title bar and require a click to expand.

> [!info-hidden] Hidden Simple
> This content should be hidden until clicked. It's a simple paragraph.

> [!warning-hidden] Hidden Table
> Here is a table inside a hidden callout:
>
> | Column A | Column B |
> |----------|----------|
> | Value 1  | Value 2  |
> | Value 3  | Value 4  |

> [!tip-hidden] Hidden Multi-column
> This is a hidden callout with a multi-column section:
> Item 1 | Item 2
> Item 3 | Item 4

---

## Unknown Callout Types

Unknown types default to `info` styling. Numeric suffixes are stripped (e.g., `tip-1` → `tip`).

> [!custom] Custom Label
> This falls back to info styling.

---

## Full Chapter Example

# Chapter 1: The Beginning

## The Awakening

Kael opened his eyes to a world he didn't recognize. The sky was **purple**, and the trees were _burning_.

> [!info] Author's Note
> This chapter was inspired by a dream.

> [!warning] Content Warning
> This chapter contains descriptions of violence.

### The Journey Begins

He picked up his sword and walked toward the [[Castle Ruins]]. The path was marked by [[Stone Markers]] that glowed faintly.

1. Find the sword
2. Cross the bridge
3. Enter the castle

For more lore, see [the wiki](https://example.com/wiki).

---

> [!error] Plot Note
> Remember: Kael doesn't know about the prophecy yet.
