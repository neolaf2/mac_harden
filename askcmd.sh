#!/usr/bin/env bash
#
# ============================================================================
# ASKCMD - Natural language to Unix command (quiet mode)
# ============================================================================
#
# Usage:
#   askcmd "find all .env files in this directory"
#   askcmd "list files modified in the last hour"
#
# Output:
#   - Prints ONLY the command to stdout
#   - Full conversation logged to ~/.askcmd/history/
#
# ============================================================================

set -euo pipefail

VERSION="1.0.0"

# Show version
if [[ "${1:-}" == "--version" || "${1:-}" == "-v" ]]; then
  echo "askcmd version $VERSION"
  exit 0
fi

# Show help
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat << 'HELPEOF'
askcmd - Natural language to Unix command (quiet mode)

Usage:
  askcmd "description of what you want to do"

Options:
  --version, -v     Show version
  --help, -h        Show this help
  --history         Show recent command history
  --log             Show path to latest log file

Examples:
  askcmd "find all .env files under the current directory"
  askcmd "list all python files modified in the last 24 hours"
  askcmd "show disk usage sorted by size"
  askcmd "kill all processes matching nginx"
  askcmd "compress all jpg files in this folder"

Output:
  - Prints ONLY the executable command to stdout
  - Full reasoning is logged to ~/.askcmd/history/YYYY-MM/

Tips:
  - Pipe to pbcopy: askcmd "..." | pbcopy
  - Execute directly: $(askcmd "...")
  - Review before running dangerous commands!
HELPEOF
  exit 0
fi

# Show history
if [[ "${1:-}" == "--history" ]]; then
  LOG_DIR="$HOME/.askcmd/history"
  if [[ -d "$LOG_DIR" ]]; then
    find "$LOG_DIR" -name "*.md" -type f -mtime -7 | sort -r | head -20 | while read -r f; do
      echo "---"
      echo "File: $f"
      grep -A1 "Query:" "$f" 2>/dev/null | tail -1 || true
      grep -A1 "Response" "$f" 2>/dev/null | tail -1 || true
    done
  else
    echo "No history found"
  fi
  exit 0
fi

# Show latest log path
if [[ "${1:-}" == "--log" ]]; then
  LOG_DIR="$HOME/.askcmd/history"
  if [[ -d "$LOG_DIR" ]]; then
    find "$LOG_DIR" -name "*.md" -type f | sort -r | head -1
  else
    echo "No logs found"
  fi
  exit 0
fi

# Require query
QUERY="$*"
if [[ -z "$QUERY" ]]; then
  echo "Usage: askcmd \"description\"" >&2
  echo "Run 'askcmd --help' for more information." >&2
  exit 1
fi

# Log directory (time-based)
LOG_DIR="$HOME/.askcmd/history/$(date +%Y-%m)"
mkdir -p "$LOG_DIR"

TS=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/$TS.md"

PROMPT='You are a Unix command-line expert.

Task:
- Convert the user request into a SINGLE correct Unix shell command.
- Output ONLY the command.
- NO explanations.
- NO markdown.
- NO backticks.
- NO commentary.
- NO line breaks unless absolutely necessary for the command.

Assume:
- macOS or Linux (prefer POSIX-compatible commands)
- Current directory unless stated otherwise
- Safe defaults (no destructive flags unless explicitly requested)

If multiple commands are required, chain with && or use subshells.

User request:'

# Run Claude
if ! RESPONSE=$(claude -p "$PROMPT $QUERY" 2>/dev/null); then
  echo "Error: Claude command failed" >&2
  exit 1
fi

# Clean up response (remove any accidental markdown or whitespace)
RESPONSE=$(echo "$RESPONSE" | sed 's/^```[a-z]*//; s/```$//; s/^[[:space:]]*//; s/[[:space:]]*$//' | head -1)

# Save full trace (hidden from shell)
{
  echo "# askcmd session"
  echo ""
  echo "**Time:** $(date)"
  echo "**Query:** $QUERY"
  echo ""
  echo "## Prompt"
  echo ""
  echo "$PROMPT"
  echo ""
  echo "## Claude Response"
  echo ""
  echo "$RESPONSE"
} > "$LOG_FILE"

# Output ONLY the command to stdout
echo "$RESPONSE"
