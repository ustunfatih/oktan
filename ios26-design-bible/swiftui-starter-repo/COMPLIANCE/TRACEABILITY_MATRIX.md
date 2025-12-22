# Screen ↔ Component Traceability Matrix (Required)

Purpose: make audits deterministic. Every screen must declare which **approved components/primitives** it uses.
CI will fail if:
- A `*Screen.swift` exists without a matrix entry
- A matrix entry is missing required fields
- A screen claims components that are not in the approved allowlist (unless explicitly exempted)

## Format (one block per screen)

- Screen: <NameScreen>
- Type: ListShell | DetailShell | FormShell | SearchShell
- Navigation: Tab | Push | Sheet | Alert | Menu
- System components used:
  - <e.g., List, Section, NavigationLink, Text, Button, TextField, Toggle, DatePicker, Picker, Menu, ProgressView>
- UIKit/SwiftUI bridging: None | UIViewRepresentable | etc. (must be justified)
- Accessibility: Labels/traits notes + any custom focus management (should be none)
- State: What must persist (SceneStorage / model)
- Notes: Any exceptions + justification

## Approved component allowlist reference
Source of truth is `ci/bible_check_config.json`:
- `component_rules.allowlist_swiftui_primitives`

## Entries

- Screen: HomeListScreen
  Type: ListShell
  Navigation: Tab, Push
  System components used:
    - NavigationStack
    - TabView
    - List
    - Section
    - NavigationLink
    - Text
  UIKit/SwiftUI bridging: None
  Accessibility: System list rows; no icon-only actions; labels visible
  State: Selected tab + home navigation path per scene
  Notes: None

- Screen: DetailScreen
  Type: DetailShell
  Navigation: Push
  System components used:
    - List
    - Section
    - Text
  UIKit/SwiftUI bridging: None
  Accessibility: Text-only; headings via Section titles
  State: Part of navigation path
  Notes: None

- Screen: FormScreen
  Type: FormShell
  Navigation: Push
  System components used:
    - Form
    - Section
    - TextField
    - SecureField
    - Button
    - Text
  UIKit/SwiftUI bridging: None
  Accessibility: Error uses accessibilityLabel; labels are visible
  State: Inputs remain during session; safe recovery on interruption
  Notes: None

- Screen: SearchScreen
  Type: SearchShell
  Navigation: Tab
  System components used:
    - List
    - Section
    - Text
    - ProgressView
  UIKit/SwiftUI bridging: None
  Accessibility: Search is system-searchable; empty state is text
  State: Query may restore; results derived
  Notes: None

- Screen: SettingsScreen
  Type: ListShell
  Navigation: Tab
  System components used:
    - List
    - Section
    - Toggle
    - Text
  UIKit/SwiftUI bridging: None
  Accessibility: Toggle labeled
  State: Toggle state per model
  Notes: None
