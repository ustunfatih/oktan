# Screen Index (Required Registry)

Every screen must be registered here. CI will fail if new or modified `*Screen.swift` files are not reflected.

## Format (one block per screen)

- Screen: <NameScreen>
- Purpose: <What user can do here>
- Entry point: <Where navigation starts from>
- Navigation: <push/sheet/tab>
- State restoration: <what must persist>
- Accessibility: <VO labels, focus order notes>
- Dynamic Type: <notes; max size verified?>
- Reduce Motion/Transparency: <notes>

## Registered screens
- Screen: HomeListScreen
  Purpose: Demonstration list->detail and list->form flows
  Entry point: Home tab root
  Navigation: push via NavigationLink destinations
  State restoration: tab selection and navigation path per scene
  Accessibility: system list rows; labels are visible; VO traversal ok
  Dynamic Type: list wraps; verified required in PR
  Reduce Motion/Transparency: system defaults

- Screen: DetailScreen
  Purpose: Demonstration detail content
  Entry point: From Home list
  Navigation: push
  State restoration: part of nav path
  Accessibility: text-only; system list structure
  Dynamic Type: wraps
  Reduce Motion/Transparency: system defaults

- Screen: FormScreen
  Purpose: Demonstration sign-in style form
  Entry point: From Home list
  Navigation: push
  State restoration: form input should persist during session; safe recovery on interruption
  Accessibility: error announced via accessibilityLabel
  Dynamic Type: Form scrolls; no clipping expected
  Reduce Motion/Transparency: system defaults

- Screen: SearchScreen
  Purpose: Demonstration system search flow
  Entry point: Search tab root
  Navigation: none (list updates)
  State restoration: query may be restored if desired; results derive from query
  Accessibility: searchable + list; “No results” state exposed
  Dynamic Type: list wraps
  Reduce Motion/Transparency: system defaults

- Screen: SettingsScreen
  Purpose: Demonstration settings list with toggle
  Entry point: Settings tab root
  Navigation: none
  State restoration: toggle state persists per your model
  Accessibility: Toggle labeled
  Dynamic Type: list wraps
  Reduce Motion/Transparency: system defaults
