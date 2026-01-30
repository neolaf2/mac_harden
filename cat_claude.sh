#!/usr/bin/env bash
#
# ============================================================================
# CAT_CLAUDE - Pipe command output to Claude for analysis
# ============================================================================
#
# Usage:
#   ANY_COMMAND | cat_claude [output.md] [prompt]
#   cat_claude --cmd "command" [output.md] [prompt]
#
# Example:
#   opencode --help | cat_claude
#   ls -la | cat_claude ls_analysis.md
#   git diff | cat_claude review.md "review these changes"
#   cat_claude --cmd "opencode --help"
#
# Pipe-friendly:
#   opencode --help | cat_claude >> my_shell_analysis_log.md
#
# ============================================================================

set -euo pipefail

VERSION="1.0.0"

# Show version
if [[ "${1:-}" == "--version" || "${1:-}" == "-v" ]]; then
  echo "cat_claude version $VERSION"
  exit 0
fi

# Show help
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<EOF
cat_claude - Pipe command output to Claude for analysis

Usage:
  ANY_COMMAND | cat_claude [output.md] [prompt]
  cat_claude --cmd "command" [output.md] [prompt]

Options:
  --cmd "command"   Run command and analyze its output
  --version, -v     Show version
  --help, -h        Show this help

Examples:
  opencode --help | cat_claude
  ls -la | cat_claude ls_analysis.md
  git diff | cat_claude review.md "review these changes"
  cat_claude --cmd "docker ps -a"

Pipe-friendly (appends to log):
  opencode --help | cat_claude >> my_shell_analysis_log.md

Output:
  - Full markdown output goes to stdout (pipe-friendly)
  - A copy is saved to the .md file
  - Status messages go to stderr
EOF
  exit 0
fi

CMD=""

# Parse --cmd flag if present
if [[ "${1:-}" == "--cmd" ]]; then
  CMD="$2"
  shift 2
fi

TMP_INPUT=$(mktemp)
TMP_RESP=$(mktemp)

# Ensure cleanup on exit (including errors/interrupts)
trap 'rm -f "$TMP_INPUT" "$TMP_RESP"' EXIT

# If --cmd provided, run the command; otherwise read from stdin
if [[ -n "$CMD" ]]; then
  eval "$CMD" > "$TMP_INPUT" 2>&1
else
  # Check if stdin is a terminal (no pipe)
  if [[ -t 0 ]]; then
    echo "Error: No input piped. Usage: command | $0 [output.md] [prompt]" >&2
    echo "   or: $0 --cmd \"command\" [output.md] [prompt]" >&2
    echo "   Run '$0 --help' for more information." >&2
    exit 1
  fi

  # Try to detect command from parent process
  CMD=$(ps -o args= -p $PPID 2>/dev/null | head -1) || CMD=""
  # Clean up common shell wrappers
  CMD=$(echo "$CMD" | sed -E 's/^-?(bash|zsh|sh|fish)\s+(-c\s+)?//')

  cat > "$TMP_INPUT"
fi

# Check if input is empty
if [[ ! -s "$TMP_INPUT" ]]; then
  echo "Error: Input is empty" >&2
  exit 1
fi

# Generate default filename from command
generate_filename() {
  local cmd="$1"
  if [[ -z "$cmd" || "$cmd" == "-"* ]]; then
    echo "claude_analysis.md"
  else
    # Extract just the command part (before any pipe to this script)
    cmd=$(echo "$cmd" | sed 's/|.*//' | xargs)
    # Replace spaces and special chars with dashes, lowercase
    local base
    base=$(echo "${cmd}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g' | head -c 100)
    echo "${base}-analysis.md"
  fi
}

OUT="${1:-$(generate_filename "$CMD")}"
PROMPT="${2:-Analyze this output and explain what it shows}"

# Send captured input to Claude (status to stderr)
echo "Analyzing with Claude..." >&2
if ! claude -p "$PROMPT" < "$TMP_INPUT" > "$TMP_RESP" 2>&1; then
  echo "Error: Claude command failed" >&2
  cat "$TMP_RESP" >&2
  exit 1
fi

# Build markdown output
OUTPUT=$(cat <<EOF
# Command → Claude Analysis

**Command:** \`${CMD:-unknown}\`
**Generated:** $(date '+%Y-%m-%d %H:%M:%S')

## Prompt
\`\`\`text
$PROMPT
\`\`\`

## Input
\`\`\`
$(cat "$TMP_INPUT")
\`\`\`

## Analysis

$(cat "$TMP_RESP")

---

EOF
)

# Output to stdout (pipe-friendly)
echo "$OUTPUT"

# Save copy to file (status to stderr)
echo "$OUTPUT" > "$OUT"
echo "Saved to: $OUT" >&2
