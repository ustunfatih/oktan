# Lint Rule Pack

This is an optional but recommended lint layer. CI already enforces core rules via Python checkers.

## SwiftLint
- Use `.swiftlint.yml` as a baseline.
- Add to your repo root and run in CI (or local pre-commit).

Key benefits:
- Faster feedback on style + some unsafe patterns.
- Complements (does not replace) Bible compliance checks.
