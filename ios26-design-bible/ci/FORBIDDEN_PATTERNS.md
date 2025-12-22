# Forbidden Patterns (Bible Enforcement)

These patterns are banned because they encourage **non-native UI**, **numeric inference**, or **custom component reimplementation**.

## SwiftUI (examples)
- `.cornerRadius(...)` — numeric radius inference
- `.shadow(...)` — elevation/shadow ramps (Material-ism)
- `RoundedRectangle(cornerRadius: ...)` — custom chrome
- `.stroke(...)` — custom outlines (Material-ism)
- `.animation(...)` / `.transition(...)` — custom motion curves and authored transitions

## UIKit (examples)
- `UINavigationBarAppearance` — custom nav chrome
- `setBackgroundImage(...)` / `shadowImage = ...` — custom bar styling
- `layer.shadow*` / `layer.cornerRadius` — bespoke elevation/shape

## Exceptions
Exceptions should be **rare** and generally limited to:
- Tests
- CI tooling
- Non-UI infrastructure

If you absolutely must allow an exception, add a path prefix to:
`ci/bible_check_config.json` → `allow_forbidden_patterns_paths`

But beware: exceptions reduce review safety.
