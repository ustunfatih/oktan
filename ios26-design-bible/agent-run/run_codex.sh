#!/usr/bin/env bash
set -euo pipefail

# TEMPLATE — edit for your Codex CLI.
# Usage: ./agent-run/run_codex.sh tasks/<task>.md

TASK_FILE="${1:-}"
if [[ -z "${TASK_FILE}" ]]; then
  echo "Usage: ./agent-run/run_codex.sh tasks/<task>.md"
  exit 1
fi

TASK="$(cat "${TASK_FILE}")"

echo "=== Codex run (template) ==="
echo "System prompt: agent-run/SYSTEM_PROMPT.md"
echo "Task file: ${TASK_FILE}"

# Replace this line with your actual Codex invocation:
echo "(placeholder) codex --instructions agent-run/SYSTEM_PROMPT.md --message "${TASK}""
