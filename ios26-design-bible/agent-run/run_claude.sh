#!/usr/bin/env bash
set -euo pipefail

# TEMPLATE — edit for your Claude Code CLI.
# Usage: ./agent-run/run_claude.sh tasks/<task>.md

TASK_FILE="${1:-}"
if [[ -z "${TASK_FILE}" ]]; then
  echo "Usage: ./agent-run/run_claude.sh tasks/<task>.md"
  exit 1
fi

TASK="$(cat "${TASK_FILE}")"

echo "=== Claude Code run (template) ==="
echo "System prompt: agent-run/SYSTEM_PROMPT.md"
echo "Task file: ${TASK_FILE}"

# Replace this line with your actual Claude invocation:
echo "(placeholder) claude --system agent-run/SYSTEM_PROMPT.md --message "${TASK}""
