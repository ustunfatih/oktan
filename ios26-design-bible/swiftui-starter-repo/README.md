# iOS 26 Design Bible — SwiftUI Starter Repo (Skeleton)

Date: 2025-12-22

This is a **Bible-compliant** SwiftUI starter structure designed to prevent drift:
- No numeric inference (Layer 1)
- SwiftUI rulebook enforcement (Appendix A)
- Lifecycle/state restoration (Layer 3)
- Accessibility contract (Layer 4)
- App Store review gates (Layer 5)
- AI lockdown contract (Layer 6)

## How to use
1. Create a new Xcode app (SwiftUI App lifecycle).
2. Copy the `Sources/` folder contents into your project (or mirror the structure).
3. Keep the `COMPLIANCE/` and `scripts/` folders in your repo and run checks in CI.

## Repo structure
- `Sources/App/` — App entry + scene storage state
- `Sources/Navigation/` — NavigationStack + tab scaffolding
- `Sources/Screens/` — Screen shells (List → Detail, Form, Search)
- `Sources/Components/` — Bible-safe component wrappers (system only)
- `COMPLIANCE/` — Contracts + checklists + review simulation script
- `scripts/` — CI checkers (forbidden patterns, compliance declarations)

## Non-negotiables
- **Do not add numeric padding, fixed frames, custom colors, custom animation curves, or custom nav bars.**
- If something isn’t explicitly allowed by the Bible, **omit it**.
