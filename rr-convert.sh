#!/usr/bin/env bash
# rr-convert.sh — Convert Obsidian markdown to Royal Road or Ghost-compatible HTML
# Preprocesses \[\[...\]\] escape sequences so the Lua filter can distinguish
# them from wiki links.
#
# macOS / Linux. For Windows, use rr-convert.ps1 instead.
#
# Usage: ./rr-convert.sh input.md [-o output.html] [--mode rr|ghost]
#   --mode rr     Royal Road output (default): inline styles, headings → divs
#   --mode ghost  Ghost CMS output: semantic HTML, styled by theme CSS

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export RR_CONVERT_SETTINGS="$SCRIPT_DIR/rr-convert.settings.lua"

MODE="rr"
INPUT=""
OUTPUT="-"

# Parse arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    -o)
      OUTPUT="$2"
      shift 2
      ;;
    *)
      if [ -z "$INPUT" ]; then
        INPUT="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$INPUT" ]; then
  echo "Usage: $0 input.md [-o output.html] [--mode rr|ghost]" >&2
  exit 1
fi

# Select filter based on mode
case "$MODE" in
  rr)
    FILTER="$SCRIPT_DIR/rr-convert.lua"
    ;;
  ghost)
    FILTER="$SCRIPT_DIR/ghost-convert.lua"
    ;;
  *)
    echo "Error: unknown mode '$MODE'. Use 'rr' or 'ghost'." >&2
    exit 1
    ;;
esac

# Preprocess: replace \[ with \x01LB and \] with \x01RB
# This lets the Lua filter distinguish escaped brackets from wiki links
if [ "$OUTPUT" = "-" ]; then
  sed -e 's/\\\[/\x01LB/g' -e 's/\\\]/\x01RB/g' "$INPUT" \
    | pandoc --from 'markdown+fenced_divs' --to html --lua-filter="$FILTER"
else
  sed -e 's/\\\[/\x01LB/g' -e 's/\\\]/\x01RB/g' "$INPUT" \
    | pandoc --from 'markdown+fenced_divs' --to html --lua-filter="$FILTER" \
    > "$OUTPUT"
fi
