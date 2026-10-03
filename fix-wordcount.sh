#!/bin/bash
# fix-wordcount.sh — correct the wordcount: YAML frontmatter value in place.
#
# Counts plain English words in the document body (everything after the
# YAML frontmatter), excluding markdown/HTML syntax and pure-punctuation
# tokens. See the counting rule below.
#
# Usage: fix-wordcount.sh <file> [more files...]
#
# Per file:
#   - no YAML frontmatter            -> skipped with a warning
#   - no wordcount: line in frontmatter -> skipped with a warning (never
#     adds the field to unrecognized files)
#   - wordcount already correct      -> file untouched (no mtime churn)
#
# Counting rule
#   1. Drop YAML frontmatter.
#   2. Strip syntax, keep visible text:
#        - HTML tags removed whole (inner text kept)
#        - Obsidian callout type tags removed ([!error], [!info], ...)
#        - line-leading > (blockquotes) and # (headings) markers
#        - table pipes |, emphasis markers * and _, backticks
#        - backslash escapes unescaped (\[ -> [)
#        - links: [text](url) -> text, [[wiki|link]] -> kept text
#   3. Tokenize on whitespace; strip leading/trailing punctuation from
#      each token (quotes, dashes, ellipses, brackets, commas, periods,
#      parens, +, ...).
#   4. Count a token only if it still contains at least one letter or
#      digit.
#
# Excluded: ---, .../…, standalone / - " tokens, [!error], data-glitch,
# and any other pure-syntax/punctuation token.
# Included: visible prose — stylized words (HONK, r-iiiii-p), numbers
# (3/3, +1), callout titles and stat-block lines (Chaos +1,
# Race: Canadian Goose | Alignment: Chaotic).
#
# Safe to run after smartify: quote/ellipsis normalization does not
# change token counts (... and … are both pure-punctuation tokens).

set -u

[ $# -ge 1 ] || { echo "usage: fix-wordcount.sh <file> [more files...]" >&2; exit 1; }

python3 - "$@" <<'PYEOF'
import re, string, sys

# ASCII punctuation plus the typographic chars smartify produces.
PUNCT = (string.punctuation
         + '\u2018\u2019\u201c\u201d'  # curly quotes
         + '\u2013\u2014\u2015'        # en/em/horizontal dashes
         + '\u2026'                    # ellipsis
         + '\u00b7\u2022')             # middle dot, bullet

def count_words(body):
    # 1. HTML tags gone whole (inner text kept)
    body = re.sub(r'<[^>]*>', '', body)
    # 2. Markdown links -> text; wiki links -> kept text
    body = re.sub(r'\[([^\]]*)\]\([^)]*\)', r'\1', body)
    body = re.sub(r'\[\[([^\]|]*)(?:\|[^\]]*)?\]\]', r'\1', body)
    # 3. Obsidian callout type tags: [!error], [!info], ...
    body = re.sub(r'\[[!a-z]+\]', '', body)
    # 4. Line-leading blockquote > and heading # markers
    body = re.sub(r'(?m)^[ \t]*(?:>[ \t]?)+', '', body)
    body = re.sub(r'(?m)^[ \t]*#{1,6}[ \t]+', '', body)
    # 5. Table pipes, emphasis markers, backticks
    body = body.replace('|', ' ')
    body = body.replace('*', '')
    body = body.replace('_', '')
    body = body.replace('`', '')
    # 6. Unescape backslash escapes (\[ -> [ etc.)
    body = re.sub(r'\\([\\`*_{}\[\]()#+\-.!<>~|/])', r'\1', body)
    # 7. Tokenize; count tokens that keep a letter or digit after
    #    stripping edge punctuation.
    n = 0
    for tok in body.split():
        t = tok.strip(PUNCT)
        if any(c.isalnum() for c in t):
            n += 1
    return n

for path in sys.argv[1:]:
    try:
        with open(path, encoding='utf-8') as f:
            text = f.read()
    except OSError as e:
        print(f'fix-wordcount: {path}: {e}', file=sys.stderr)
        continue

    m = re.match(r'\A---\n(.*?)\n---[ \t]*\n?', text, re.S)
    if not m:
        print(f'fix-wordcount: {path}: no YAML frontmatter, skipped', file=sys.stderr)
        continue
    fm, body = m.group(1), text[m.end():]

    wm = re.search(r'(?m)^([ \t]*wordcount[ \t]*:)(.*)$', fm)
    if not wm:
        print(f'fix-wordcount: {path}: no wordcount: line in frontmatter, skipped', file=sys.stderr)
        continue

    count = count_words(body)
    old = wm.group(2).strip()
    if old == str(count):
        print(f'fix-wordcount: {path}: ok ({count})')
        continue

    off = m.start(1)
    new_text = text[:off + wm.start()] + f'{wm.group(1)} {count}' + text[off + wm.end():]
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_text)
    print(f'fix-wordcount: {path}: {old} -> {count}')
PYEOF
