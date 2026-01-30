#!/usr/bin/env bash
#
# ============================================================================
# CAT_CLAUDE - Pipe command output to Claude for analysis
# ============================================================================
#
# Usage:
#   ANY_COMMAND | cat_claude [prompt]
#   cat_claude --cmd "command" [prompt]
#
# Example:
#   opencode --help | cat_claude
#   git diff | cat_claude "review these changes"
#   cat_claude --cmd "opencode --help"
#
# Pipe-friendly:
#   opencode --help | cat_claude >> my_shell_analysis_log.md
#
# History:
#   All analyses saved to ~/.mac_harden/stm/cat_claude/YYYY-MM/
#
# Environment:
#   CAT_CLAUDE_PROMPT - Override default prompt
#
# ============================================================================

set -euo pipefail

VERSION="1.2.0"

# Default prompt (can be overridden via env var or argument)
DEFAULT_PROMPT="Analyze this output and explain what it shows. Ignore ASCII art, banners, and trivial or non-essential decorative elements. Focus on the substantive content and functionality."

# Show version
if [[ "${1:-}" == "--version" || "${1:-}" == "-v" ]]; then
  echo "cat_claude version $VERSION"
  exit 0
fi

# Show help
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat << HELPEOF
cat_claude - Pipe command output to Claude for analysis

Usage:
  ANY_COMMAND | cat_claude [prompt]
  cat_claude --cmd "command" [prompt]

Options:
  --cmd "command"   Run command and analyze its output
  --history         Show recent analysis history
  --log             Show path to latest log file
  --version, -v     Show version
  --help, -h        Show this help

Environment:
  CAT_CLAUDE_PROMPT   Override default prompt for all invocations
                      Example: export CAT_CLAUDE_PROMPT="summarize briefly"

Examples:
  opencode --help | cat_claude
  git diff | cat_claude "review these changes for bugs"
  cat_claude --cmd "docker ps -a"

Pipe-friendly (appends to local log):
  opencode --help | cat_claude >> my_shell_analysis_log.md

Output:
  - Full markdown output goes to stdout (pipe-friendly)
  - A copy is saved to ~/.mac_harden/stm/cat_claude/YYYY-MM/
  - Status messages go to stderr

Default prompt:
  $DEFAULT_PROMPT
HELPEOF
  exit 0
fi

# Show history
if [[ "${1:-}" == "--history" ]]; then
  HIST_DIR="$HOME/.mac_harden/stm/cat_claude"
  if [[ -d "$HIST_DIR" ]]; then
    find "$HIST_DIR" -name "*.md" -type f -mtime -7 | sort -r | head -20 | while read -r f; do
      echo "---"
      echo "File: $f"
      grep "^\*\*Command:\*\*" "$f" 2>/dev/null | head -1 || true
      grep "^\*\*Generated:\*\*" "$f" 2>/dev/null | head -1 || true
    done
  else
    echo "No history found"
  fi
  exit 0
fi

# Show latest log path
if [[ "${1:-}" == "--log" ]]; then
  HIST_DIR="$HOME/.mac_harden/stm/cat_claude"
  if [[ -d "$HIST_DIR" ]]; then
    find "$HIST_DIR" -name "*.md" -type f | sort -r | head -1
  else
    echo "No logs found"
  fi
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

# History directory (time-based)
HIST_DIR="$HOME/.mac_harden/stm/cat_claude/$(date +%Y-%m)"
mkdir -p "$HIST_DIR"

# Generate filename from command
generate_filename() {
  local cmd="$1"
  local ts
  ts=$(date +"%Y%m%d_%H%M%S")
  if [[ -z "$cmd" || "$cmd" == "-"* ]]; then
    echo "${ts}_analysis.md"
  else
    # Extract just the command part (before any pipe to this script)
    cmd=$(echo "$cmd" | sed 's/|.*//' | xargs)
    # Replace spaces and special chars with dashes, lowercase
    local base
    base=$(echo "${cmd}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g' | head -c 60)
    echo "${ts}_${base}.md"
  fi
}

HIST_FILE="$HIST_DIR/$(generate_filename "$CMD")"
PROMPT="${1:-${CAT_CLAUDE_PROMPT:-$DEFAULT_PROMPT}}"

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

# Save copy to history (status to stderr)
echo "$OUTPUT" > "$HIST_FILE"
echo "Saved to: $HIST_FILE" >&2
