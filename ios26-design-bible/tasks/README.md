# Tasks (Team-friendly)

This folder contains **one markdown file per change request**.
Agents should be run against a single task file for repeatability.

Naming convention:
- `000-...` for conventions/meta
- `100-...` for new screens
- `200-...` for forms/validation
- `300-...` for navigation/flows
- `900-...` for enforcement changes

Workflow:
1) Create a new task file or duplicate an existing one.
2) Run `./agent-run/run_codex.sh tasks/<file>.md` or `./agent-run/run_claude.sh tasks/<file>.md`
3) Ensure CI passes.
4) Update compliance docs (PR_DECLARATION + registry + traceability).
