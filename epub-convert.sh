#!/usr/bin/env bash
# epub-convert.sh — Convert Obsidian markdown to EPUB
# Preprocesses \[\[...\]\] escape sequences so the Lua filter can distinguish
# them from wiki links, then runs pandoc with the epub-convert.lua filter.
#
# Usage: ./epub-convert.sh input.md [-o output.epub] [-s style] [extra pandoc args...]
# Styles: default (clean light theme), heavy (dark RR-style callouts)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FILTER="$SCRIPT_DIR/epub-convert.lua"
CSS="$SCRIPT_DIR/epub-styles.css"

if [ $# -lt 1 ]; then
  echo "Usage: $0 input.md [-o output.epub] [-s default|heavy] [pandoc args...]" >&2
  exit 1
fi

INPUT="$1"
shift

OUTPUT="-"
if [ $# -ge 2 ] && [ "$1" = "-o" ]; then
  OUTPUT="$2"
  shift 2
fi

if [ $# -ge 2 ] && [ "$1" = "-s" ]; then
  case "$2" in
    heavy) CSS="$SCRIPT_DIR/epub-styles-heavy.css" ;;
    default|*) CSS="$SCRIPT_DIR/epub-styles.css" ;;
  esac
  shift 2
fi

# Preprocess: replace \[ with \x01LB and \] with \x01RB
# This lets the Lua filter distinguish escaped brackets from wiki links
sed -e 's/\\\[/\x01LB/g' -e 's/\\\]/\x01RB/g' "$INPUT" \
  | pandoc \
      --from 'markdown+fenced_divs' \
      --to epub \
      --lua-filter="$FILTER" \
      --css="$CSS" \
      "$@" \
  > "$OUTPUT"
