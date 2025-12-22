# Screen Index (Required Registry)

Every screen must be registered here.

## Format (one block per screen)

- Screen: <Name>
- Purpose: <What user can do here>
- Entry point: <Where navigation starts from>
- Navigation: <push/sheet/tab>
- State restoration: <what must persist>
- Accessibility: <VO labels, focus order notes>
- Dynamic Type: <notes; max size verified?>
- Reduce Motion/Transparency: <notes>

## Registered screens (Oktan target)
- Screen: SplashView
  Purpose: App startup state while data loads
  Entry point: App launch
  Navigation: none
  State restoration: none
  Accessibility: icon + title text; no hidden controls
  Dynamic Type: default; verify largest size
  Reduce Motion/Transparency: system defaults (no custom motion)

- Screen: HomeView
  Purpose: Show summary and quick actions for car + recent activity
  Entry point: Home tab root
  Navigation: sheet (CarSelectionView, FuelEntryFormView)
  State restoration: selected tab; car selection state from repo
  Accessibility: labeled buttons and summary; VO labels on hero card
  Dynamic Type: list wraps; verify largest size
  Reduce Motion/Transparency: system defaults

- Screen: TrackingView
  Purpose: Review fuel entries and add/edit fill-ups
  Entry point: Tracking tab root
  Navigation: sheet (FuelEntryFormView), swipe actions
  State restoration: selected tab; list derived from repo
  Accessibility: labeled toolbar button; VO value summary for rows
  Dynamic Type: list wraps; verify largest size
  Reduce Motion/Transparency: system defaults

- Screen: FuelEntryFormView
  Purpose: Add or edit a fuel entry
  Entry point: TrackingView sheet
  Navigation: sheet
  State restoration: input values during session
  Accessibility: labeled fields, error message announced
  Dynamic Type: Form scrolls; verify largest size
  Reduce Motion/Transparency: system defaults

- Screen: CarSelectionView
  Purpose: Select make/model/year and confirm car setup
  Entry point: HomeView sheet
  Navigation: sheet + internal navigation links
  State restoration: current selection during flow
  Accessibility: labeled fields; system controls only
  Dynamic Type: Form scrolls; verify largest size
  Reduce Motion/Transparency: system defaults

- Screen: ReportsView
  Purpose: Show metrics, charts, and export options
  Entry point: Reports tab root
  Navigation: sheet (ShareSheet, PaywallView), alert
  State restoration: selected tab segment
  Accessibility: chart labels; export actions labeled
  Dynamic Type: list wraps; verify largest size
  Reduce Motion/Transparency: system defaults

- Screen: ProfileView
  Purpose: Authentication state + account benefits
  Entry point: Profile tab root
  Navigation: none
  State restoration: auth state from model
  Accessibility: buttons labeled; sign-out confirmation dialog
  Dynamic Type: list wraps; verify largest size
  Reduce Motion/Transparency: system defaults

- Screen: SettingsView
  Purpose: Preferences, data management, and about
  Entry point: Settings tab root
  Navigation: push (NotificationSettingsView, CSVImportView), sheet (AboutView)
  State restoration: settings state from model
  Accessibility: toggles labeled; destructive confirmations
  Dynamic Type: list wraps; verify largest size
  Reduce Motion/Transparency: system defaults

- Screen: NotificationSettingsView
  Purpose: Configure reminders
  Entry point: SettingsView push
  Navigation: push
  State restoration: reminder state from model
  Accessibility: toggle labels visible
  Dynamic Type: list wraps; verify largest size
  Reduce Motion/Transparency: system defaults

- Screen: CSVImportView
  Purpose: Import fuel entries from CSV
  Entry point: SettingsView push
  Navigation: push
  State restoration: import state during session
  Accessibility: labeled buttons; error text visible
  Dynamic Type: list wraps; verify largest size
  Reduce Motion/Transparency: system defaults

- Screen: PaywallView
  Purpose: Upsell premium features
  Entry point: ReportsView sheet
  Navigation: sheet
  State restoration: paywall presentation state
  Accessibility: labels on purchase actions
  Dynamic Type: list wraps; verify largest size
  Reduce Motion/Transparency: system defaults
