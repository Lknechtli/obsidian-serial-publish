#!/usr/bin/env bash
# rr-scrubber.sh — Convert Obsidian markdown to Royal Road-compatible HTML
# Preprocesses \[\[...\]\] escape sequences so the Lua filter can distinguish
# them from wiki links.
#
# Usage: ./rr-scrubber.sh input.md [-o output.html]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FILTER="$SCRIPT_DIR/rr-scrubber.lua"

if [ $# -lt 1 ]; then
  echo "Usage: $0 input.md [-o output.html]" >&2
  exit 1
fi

INPUT="$1"
shift

OUTPUT="-"
if [ $# -ge 2 ] && [ "$1" = "-o" ]; then
  OUTPUT="$2"
  shift 2
fi

# Preprocess: replace \[ with \x01LB and \] with \x01RB
# This lets the Lua filter distinguish escaped brackets from wiki links
sed -e 's/\\\[/\x01LB/g' -e 's/\\\]/\x01RB/g' "$INPUT" \
  | pandoc --from 'markdown+fenced_divs' --to html --lua-filter="$FILTER" "$@" \
  > "$OUTPUT"
