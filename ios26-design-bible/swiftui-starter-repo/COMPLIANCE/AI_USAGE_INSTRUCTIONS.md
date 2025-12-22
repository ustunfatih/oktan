# AI Usage Instructions (Lockdown) — Include Verbatim

You must implement iOS 26 UI strictly using Apple system components and behaviors.
You must not invent numeric values, layouts, animations, or visual styles.
If Apple does not explicitly expose a value or API, omit the customization.
Precedence: Apple runtime behavior > HIG > this Bible.
If compliance is uncertain, halt and report uncertainty with a compliant alternative.

## Output must include
- Framework (SwiftUI)
- Components used (system only)
- Accessibility notes
- Lifecycle notes (state restoration)
- Explicit statement: "No numeric values inferred"

## Halt conditions
- Any request implies custom navigation/alerts/controls
- Any request requires numeric guessing (spacing/radii/heights)
- Accessibility cannot be guaranteed
