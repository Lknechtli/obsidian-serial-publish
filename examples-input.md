# Royal Road Scrubber — Examples

Demonstrates every conversion the `rr-scrubber.lua` Pandoc Lua filter performs on Obsidian markdown.

---

## Headings (h1–h6 → styled divs)

Royal Road mangles `<h1>`–`<h6>` into `<p>` tags. The scrubber converts them to `<div>` elements with inline styles.

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

## Horizontal Rules

---

## Images

![Dragon illustration](https://example.com/dragon.png)

---

## Callouts

Obsidian callout syntax becomes styled `<table>` elements. Royal Road strips `<pre>` tags, so tables are used instead.

### Info Callout

> [!info] About This Chapter
> This chapter introduces the main characters.
> Pay attention to the timeline.

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
> Check for continuity errors in the magic system.

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
