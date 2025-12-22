# Task 900 — Tighten Allowlist Mode to FAIL

## Goal
Make the component allowlist enforcement strict.

## Requirements
- Update `ci/bible_check_config.json`
- Set: `component_rules.allowlist_enforcement_mode` to `fail`
- Keep exemptions limited to `Tests/` and `Previews/` only.
- Document rationale in `ci/COMPONENT_ALLOWLIST.md` (short addendum).

## Definition of Done
- CI passes in main branch
- Future PRs fail if disallowed primitives appear
