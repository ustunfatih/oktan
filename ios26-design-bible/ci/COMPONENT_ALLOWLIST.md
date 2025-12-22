# Component Allowlist & Anti-Impostor Rules

This checker targets the most common “looks fine but fails iOS-ness” patterns AI agents produce.

## Hard-fail rules
1) **ScrollView + VStack used as a Form**
- If a file contains ScrollView + VStack + form controls (TextField/SecureField/Toggle/etc.)
- And does NOT contain Form or List
→ FAIL (use Form or List)

2) **Custom separators inside List**
- Divider inside List
→ FAIL (use system separators)

3) **Gesture-based buttons**
- onTapGesture used without Button
→ FAIL (use Button)

## Allowlist warnings (optional fail mode)
We also warn (or fail) if disallowed primitives appear:
- GeometryReader, ScrollView, LazyVStack, custom representables, etc.

Configure in `ci/bible_check_config.json`:
- `component_rules.allowlist_swiftui_primitives`
- `component_rules.allowlist_enforcement_mode` = warn | fail
- `component_rules.allowlist_exempt_paths`

The goal is not to ban advanced SwiftUI forever.
The goal is to keep **system-first, native behavior** as the default.
