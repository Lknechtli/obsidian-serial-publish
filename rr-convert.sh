#!/usr/bin/env bash
# rr-convert.sh — Convert Obsidian markdown to platform-compatible output
# Preprocesses \[\[...\]\] escape sequences so the Lua filter can distinguish
# them from wiki links.
#
# macOS / Linux. For Windows, use rr-convert.ps1 instead.
#
# Usage: ./rr-convert.sh input.md [-o output] [--mode rr|patreon]
#   --mode rr        Royal Road output (default): HTML with inline styles
#   --mode patreon   Patreon output: plaintext + blockquotes for paste

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
  echo "Usage: $0 input.md [-o output] [--mode rr|patreon]" >&2
  exit 1
fi

# Select filter and output format based on mode
case "$MODE" in
  rr)
    FILTER="$SCRIPT_DIR/rr-convert.lua"
    PANDOC_TO="html"
    ;;
  patreon)
    FILTER="$SCRIPT_DIR/patreon-convert.lua"
    PANDOC_TO="plain"
    ;;
  *)
    echo "Error: unknown mode '$MODE'. Use 'rr' or 'patreon'." >&2
    exit 1
    ;;
esac

# Pandoc format: use fenced_divs for callout support, disable yaml_metadata_block
# to prevent --- inside callouts (e.g. Obsidian callout section dividers) from
# triggering YAML parse errors when combined with \x01 control characters.
PANDOC_FROM='markdown+fenced_divs-yaml_metadata_block'

# Preprocess pipeline:
# 1. Strip YAML frontmatter (--- ... ---) to prevent --- inside callouts
#    from being misinterpreted as YAML boundaries
# 2. Replace \[ with \x01LB and \] with \x01RB so the Lua filter can
#    distinguish escaped brackets from wiki links
preprocess() {
  # Remove YAML frontmatter if present (leading --- ... ---)
  awk 'BEGIN{in_yaml=0; past_yaml=0} /^---$/{if(!past_yaml){if(!in_yaml){in_yaml=1;next}else{past_yaml=1;in_yaml=0;next}}} in_yaml{next} !in_yaml{print}' | \
  sed -e 's/\\\[/\x01LB/g' -e 's/\\\]/\x01RB/g'
}

if [ "$OUTPUT" = "-" ]; then
  cat "$INPUT" | preprocess \
    | pandoc --from "$PANDOC_FROM" --to "$PANDOC_TO" --lua-filter="$FILTER"
else
  cat "$INPUT" | preprocess \
    | pandoc --from "$PANDOC_FROM" --to "$PANDOC_TO" --lua-filter="$FILTER" \
    > "$OUTPUT"
fi
