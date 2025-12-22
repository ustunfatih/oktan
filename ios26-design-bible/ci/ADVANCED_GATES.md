# Advanced Gates (Options 1–6 Implemented)

## Option 1 — Screen Registry Gate
- File: `swiftui-starter-repo/COMPLIANCE/SCREEN_INDEX.md`
- CI: `ci/scripts/check_screen_registry.py`
- Rule: every `*Screen.swift` must be listed in the index.

## Option 2 — Shell-Template Enforcement
- Shells: `swiftui-starter-repo/Sources/Shells/ScreenShells.swift`
- CI: `ci/scripts/check_shell_usage.py`
- Rule: every `*Screen.swift` must compose one of the approved shells.

## Option 3 — No Custom Chrome Gate
- Enforced via `ci/scripts/ios26_api_forbid_check.py`
- Config: `ci/bible_check_config.json` forbidden patterns expanded.

## Option 4 — Accessibility Proof Gate
- PR Template includes Evidence sections
- CI enforces required sections/phrases in PR declaration.

## Option 5 — Lint Rule Pack
- Folder: `lint/`
- Provides SwiftLint config mirroring key Bible rules (optional).

## Option 6 — Golden-path UI Test Harness
- Folder: `tests/`
- Provides XCUITest template to automate parts of Layer 5 (optional).


## Final Step — Screen ↔ Component Traceability Matrix
- Matrix: `swiftui-starter-repo/COMPLIANCE/TRACEABILITY_MATRIX.md`
- CI: `ci/scripts/check_traceability_matrix.py`
- Rule: every `*Screen.swift` must declare system components used; must match allowlist.
