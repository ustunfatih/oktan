# CI Compliance Checker (Concept + Implementable Scripts)

This folder turns the iOS 26 Design Bible into a **merge gate**.

## What we enforce automatically
- No numeric padding in SwiftUI: `.padding(<number>)` (configurable allowlist)
- No fixed frames for controls: `.frame(width:..., height:...)`
- No GeometryReader for layout tuning
- No hex/RGB colors in SwiftUI
- No custom animation curves (spring parameters, timingCurve)
- UIKit: no frame-based layout and no direct `CGRect(...)` for UI layout
- No disabling interactive pop gesture

## PR Compliance Declaration (NEW)
Every PR must modify:
- `swiftui-starter-repo/COMPLIANCE/PR_DECLARATION.md`

This makes humans and AI agents **self-certify** against Layers 1–6.
The checker verifies the file changed and contains required sections.

## Configuration
Edit `ci/bible_check_config.json`:
- `ignore_paths`: directories to ignore
- `allow_numeric_padding_paths`: allow numeric padding only in these paths (e.g., Tests)
- `require_pr_declaration`: enable/disable PR gate
- `pr_declaration_path`: location of declaration file

## Limits
Some checks remain manual (Layer 5 review simulation):
- Full VoiceOver grouping correctness
- Native-feel heuristics
- Some lifecycle edge-cases


## Component allowlist (NEW)
Runs `ios26_component_allowlist_check.py` to prevent ScrollView+VStack form impostors, Divider-in-List separators, and gesture-buttons.
See `ci/COMPONENT_ALLOWLIST.md`.


## Optional: SwiftLint
See `lint/` for a baseline `.swiftlint.yml` that mirrors key Bible constraints.


## Optional: Golden-path UI tests
See `tests/` for XCUITest templates to automate parts of Layer 5.


## Final gate: Traceability matrix
Every screen must be listed in `swiftui-starter-repo/COMPLIANCE/TRACEABILITY_MATRIX.md` with system components used. CI enforces this.
