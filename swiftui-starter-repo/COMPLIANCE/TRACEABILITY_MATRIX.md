# Screen ↔ Component Traceability Matrix (Required)

Purpose: make audits deterministic. Every screen must declare which approved components/primitives it uses.

## Format (one block per screen)

- Screen: <Name>
- Type: ListShell | DetailShell | FormShell | SearchShell
- Navigation: Tab | Push | Sheet | Alert | Menu
- System components used:
  - <e.g., List, Section, NavigationLink, Text, Button, TextField, Toggle, DatePicker, Picker, Menu, ProgressView>
- UIKit/SwiftUI bridging: None | UIViewRepresentable | etc. (must be justified)
- Accessibility: Labels/traits notes + any custom focus management (should be none)
- State: What must persist (SceneStorage / model)
- Notes: Any exceptions + justification

## Entries (Oktan target)

- Screen: SplashView
  Type: DetailShell
  Navigation: none
  System components used:
    - Image
    - Text
    - ProgressView
  UIKit/SwiftUI bridging: None
  Accessibility: static text and icon
  State: none
  Notes: No motion or custom chrome

- Screen: HomeView
  Type: ListShell
  Navigation: Tab, Sheet
  System components used:
    - NavigationStack
    - TabView
    - List
    - Section
    - Text
    - Image
    - Button
    - ProgressView
  UIKit/SwiftUI bridging: None
  Accessibility: labeled buttons; summary labels
  State: selected tab via SceneStorage; car selection in repo
  Notes: Uses system materials for cards

- Screen: TrackingView
  Type: ListShell
  Navigation: Tab, Sheet, Alert
  System components used:
    - NavigationStack
    - TabView
    - List
    - Section
    - Text
    - Button
    - ProgressView
  UIKit/SwiftUI bridging: None
  Accessibility: row summaries and labeled actions
  State: entries from repo; modal state in view
  Notes: Swipe actions are system

- Screen: FuelEntryFormView
  Type: FormShell
  Navigation: Sheet
  System components used:
    - NavigationStack
    - Form
    - Section
    - Text
    - TextField
    - Toggle
    - DatePicker
    - Picker
    - Button
  UIKit/SwiftUI bridging: None
  Accessibility: labeled fields; errors visible
  State: form inputs in state
  Notes: None

- Screen: CarSelectionView
  Type: FormShell
  Navigation: Sheet, Push
  System components used:
    - NavigationStack
    - Form
    - Section
    - Text
    - TextField
    - Picker
    - Button
    - ProgressView
    - Image
  UIKit/SwiftUI bridging: None
  Accessibility: labeled fields and buttons
  State: selected make/model/year during flow
  Notes: Uses system aspect fit for images

- Screen: ReportsView
  Type: ListShell
  Navigation: Tab, Sheet, Alert, Menu
  System components used:
    - NavigationStack
    - TabView
    - List
    - Section
    - Text
    - Button
    - Menu
    - Image
    - ProgressView
  UIKit/SwiftUI bridging: None
  Accessibility: chart labels + export button labels
  State: selected tab segment
  Notes: Uses Swift Charts (system framework); update allowlist if enforced strictly

- Screen: ProfileView
  Type: ListShell
  Navigation: Tab, Alert
  System components used:
    - NavigationStack
    - TabView
    - List
    - Section
    - Text
    - Button
    - Image
    - ProgressView
  UIKit/SwiftUI bridging: None
  Accessibility: labeled buttons; confirmation dialog
  State: auth state in model
  Notes: None

- Screen: SettingsView
  Type: ListShell
  Navigation: Tab, Push, Sheet
  System components used:
    - NavigationStack
    - TabView
    - List
    - Section
    - Text
    - Button
    - Toggle
    - NavigationLink
    - Image
  UIKit/SwiftUI bridging: None
  Accessibility: labeled toggles and actions
  State: settings in model
  Notes: None

- Screen: NotificationSettingsView
  Type: ListShell
  Navigation: Push
  System components used:
    - NavigationStack
    - List
    - Section
    - Text
    - Toggle
    - Button
  UIKit/SwiftUI bridging: None
  Accessibility: labeled toggles
  State: reminder settings in model
  Notes: None

- Screen: CSVImportView
  Type: ListShell
  Navigation: Push
  System components used:
    - NavigationStack
    - List
    - Section
    - Text
    - Button
  UIKit/SwiftUI bridging: None
  Accessibility: labeled buttons and messages
  State: import state in model
  Notes: None

- Screen: PaywallView
  Type: DetailShell
  Navigation: Sheet
  System components used:
    - NavigationStack
    - List
    - Section
    - Text
    - Button
    - Image
    - ProgressView
  UIKit/SwiftUI bridging: None
  Accessibility: labeled purchase actions
  State: paywall presentation state
  Notes: None

## Reference entries (ios26-design-bible sample screens)

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
  Accessibility: system list rows; labels are visible
  State: selected tab + home navigation path per scene
  Notes: Reference-only screen in ios26-design-bible package

- Screen: DetailScreen
  Type: DetailShell
  Navigation: Push
  System components used:
    - List
    - Section
    - Text
  UIKit/SwiftUI bridging: None
  Accessibility: text-only; system list structure
  State: part of nav path
  Notes: Reference-only screen in ios26-design-bible package

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
  Accessibility: error uses accessibilityLabel; labels are visible
  State: inputs persist during session
  Notes: Reference-only screen in ios26-design-bible package

- Screen: SearchScreen
  Type: SearchShell
  Navigation: Tab
  System components used:
    - List
    - Section
    - Text
    - ProgressView
  UIKit/SwiftUI bridging: None
  Accessibility: searchable list; empty state exposed
  State: query may restore
  Notes: Reference-only screen in ios26-design-bible package

- Screen: SettingsScreen
  Type: ListShell
  Navigation: Tab
  System components used:
    - List
    - Section
    - Toggle
    - Text
  UIKit/SwiftUI bridging: None
  Accessibility: toggle labeled
  State: toggle state per model
  Notes: Reference-only screen in ios26-design-bible package
