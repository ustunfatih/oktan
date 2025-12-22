# Screen Index

This document lists all screens in the Oktan app with their compliance status per the iOS 26 Design Bible.

---

## Screen Registry

### Tab Screens (Root Level)

| Screen | File | Shell | Entry Point | Navigation | State Restoration | Accessibility | Dynamic Type | Compliance |
|--------|------|-------|-------------|------------|-------------------|---------------|--------------|------------|
| HomeScreen | `Views/Home/HomeView.swift` | ListShell | Tab 0 | Tab | MISSING | Partial | Untested | NON-COMPLIANT |
| TrackingScreen | `Views/Tracking/TrackingView.swift` | ListShell | Tab 1 | Tab | MISSING | Good | Untested | NON-COMPLIANT |
| ReportsScreen | `Views/Reports/ReportsView.swift` | ListShell | Tab 2 | Tab | MISSING | Partial | Untested | NON-COMPLIANT |
| ProfileScreen | `Views/Profile/ProfileView.swift` | ListShell | Tab 3 | Tab | MISSING | Good | Untested | NON-COMPLIANT |
| SettingsScreen | `Views/Settings/SettingsView.swift` | ListShell | Tab 4 | Tab | MISSING | Good | Untested | NON-COMPLIANT |

### Pushed Screens (Detail)

| Screen | File | Shell | Entry Point | Navigation | State Restoration | Accessibility | Dynamic Type | Compliance |
|--------|------|-------|-------------|------------|-------------------|---------------|--------------|------------|
| NotificationSettingsScreen | `Views/Settings/NotificationSettingsView.swift` | ListShell | Settings > Reminders | Push | MISSING | Good | Untested | PARTIAL |
| DataManagementScreen | `Views/Settings/SettingsView.swift` | ListShell | Settings > Data | Push | MISSING | Good | Untested | PARTIAL |
| AboutScreen | `Views/Settings/SettingsView.swift` | ListShell | Settings > About | Sheet | N/A | Partial | Untested | PARTIAL |

### Sheet Screens (Modal)

| Screen | File | Shell | Entry Point | Navigation | State Restoration | Accessibility | Dynamic Type | Compliance |
|--------|------|-------|-------------|------------|-------------------|---------------|--------------|------------|
| FuelEntryFormScreen | `Views/Tracking/FuelEntryFormView.swift` | FormShell | Home/Tracking + Button | Sheet | MISSING | Good | Untested | PARTIAL |
| CarSelectionScreen | `Views/Home/CarSelectionView.swift` | SearchShell | Home > Change Car | Sheet | MISSING | Partial | Untested | NON-COMPLIANT |
| CarModelSelectionScreen | `Views/Home/CarSelectionView.swift` | ListShell | CarSelection > Make | Push | MISSING | Partial | Untested | NON-COMPLIANT |
| CarYearSelectionScreen | `Views/Home/CarSelectionView.swift` | ListShell | CarModel > Model | Push | MISSING | Partial | Untested | NON-COMPLIANT |
| CarConfirmationScreen | `Views/Home/CarSelectionView.swift` | FormShell | CarYear > Year | Push | MISSING | Partial | Untested | NON-COMPLIANT |
| CSVImportScreen | `Views/Settings/CSVImportView.swift` | FormShell | Settings > Import | Sheet | MISSING | Partial | Untested | PARTIAL |
| PaywallScreen | `Views/Premium/PaywallView.swift` | N/A (RevenueCat) | Various | Sheet | N/A | RevenueCat | RevenueCat | N/A |
| SplashScreen | `Views/Splash/SplashView.swift` | N/A (Special) | App Launch | Overlay | N/A | Missing | N/A | NON-COMPLIANT |

---

## Screen Details

### HomeScreen

**Purpose:** Dashboard showing car, fuel summary, efficiency metrics, and recent activity.

**Entry Point:** Tab 0 ("Home")

**Navigation Type:** Tab

**State Restoration:**
- [ ] Tab selection persisted
- [ ] Car selection refreshes on appear
- [ ] No draft state to persist

**Accessibility Notes:**
- Hero card has combined accessibility element with summary
- Recent entries have proper labels
- Add button has identifier

**Dynamic Type Status:** UNTESTED

**Reduce Motion/Transparency:** NOT IMPLEMENTED

**Violations:**
- LinearGradient hero card
- RoundedRectangle with cornerRadius: 16
- Custom color `.blue`, `.indigo`
- `.padding()` without numeric values (OK)

---

### TrackingScreen

**Purpose:** List of all fuel entries with add/edit/delete functionality.

**Entry Point:** Tab 1 ("Tracking")

**Navigation Type:** Tab

**State Restoration:**
- [ ] Tab selection persisted
- [ ] Entry list loads from repository

**Accessibility Notes:**
- Good VoiceOver labels on entry rows
- Swipe actions have labels
- Add button has accessibility identifier

**Dynamic Type Status:** UNTESTED

**Violations:**
- Minor - needs Shell wrapper

---

### ReportsScreen

**Purpose:** Analytics dashboard with charts and insights.

**Entry Point:** Tab 2 ("Reports")

**Navigation Type:** Tab

**State Restoration:**
- [ ] Selected report tab not persisted

**Accessibility Notes:**
- Charts have accessibility labels
- Export button has identifier
- Locked content announces properly

**Dynamic Type Status:** UNTESTED

**Violations:**
- 40+ DesignSystem.Spacing usages (numeric inference)
- 30+ DesignSystem.ColorPalette usages (hex colors)
- ScrollView + VStack instead of List
- Multiple .frame(height:) violations
- .tint() usage

---

### ProfileScreen

**Purpose:** User authentication and account management.

**Entry Point:** Tab 3 ("Profile")

**Navigation Type:** Tab

**State Restoration:**
- [ ] Authentication state from AuthManager

**Accessibility Notes:**
- Sign in button accessible
- User info properly labeled
- Sign out confirmation uses system dialog

**Dynamic Type Status:** UNTESTED

**Violations:**
- LinearGradient avatar background
- .frame(width: 60, height: 60) fixed size

---

### SettingsScreen

**Purpose:** App preferences and configuration.

**Entry Point:** Tab 4 ("Settings")

**Navigation Type:** Tab

**State Restoration:**
- [ ] Settings persisted in UserDefaults (OK)

**Accessibility Notes:**
- Standard Form/List structure
- Pickers accessible
- Links properly labeled

**Dynamic Type Status:** UNTESTED

**Violations:**
- LinearGradient in AboutView

---

### FuelEntryFormScreen

**Purpose:** Add or edit fuel entry data.

**Entry Point:** Sheet from Home/Tracking

**Navigation Type:** Sheet (.medium, .large detents)

**State Restoration:**
- [ ] Draft entry NOT persisted (data loss risk)

**Accessibility Notes:**
- All fields have accessibility labels
- Accessibility identifiers for testing
- Error messages announced

**Dynamic Type Status:** UNTESTED

**Violations:**
- Needs FormShell wrapper
- Draft state should persist

---

### CarSelectionScreen

**Purpose:** Multi-step car selection flow.

**Entry Point:** Sheet from HomeView

**Navigation Type:** Sheet with internal NavigationStack

**State Restoration:**
- [ ] Navigation path NOT persisted

**Accessibility Notes:**
- Search field accessible
- List items have labels
- Tank capacity announced

**Dynamic Type Status:** UNTESTED

**Violations:**
- .frame(height: 200) in confirmation
- .frame(width: 80) in tank input
- Needs SearchShell wrapper

---

## Required Actions Per Screen

### Immediate (Must Have Shell)

1. **HomeScreen** -> Wrap in `ListShell(title: "Home")`
2. **TrackingScreen** -> Wrap in `ListShell(title: "Tracking")`
3. **ReportsScreen** -> Replace ScrollView with `ListShell(title: "Reports")`
4. **ProfileScreen** -> Already uses List (wrap in ListShell)
5. **SettingsScreen** -> Already uses List (wrap in ListShell)
6. **FuelEntryFormScreen** -> Wrap in `FormShell(title: "Add Fill-up")`
7. **CarSelectionScreen** -> Wrap in `SearchShell(title: "Select Make")`

### State Restoration Required

1. **MainTabView** -> `@SceneStorage("selectedTab")`
2. **CarSelectionView** -> Persist navigation path
3. **FuelEntryFormView** -> Persist draft data
4. **ReportsView** -> Persist selected report tab

---

## Compliance Checklist

For each screen to be compliant:

- [ ] Uses approved Shell (ListShell, DetailShell, FormShell, SearchShell)
- [ ] No numeric padding/spacing values
- [ ] No fixed frame dimensions
- [ ] No custom corner radius
- [ ] No custom shadows
- [ ] No hex/RGB colors
- [ ] Uses system colors only
- [ ] State restoration implemented
- [ ] VoiceOver tested and working
- [ ] Largest Dynamic Type tested - no clipping
- [ ] Reduce Motion respected
- [ ] Reduce Transparency respected
- [ ] Swipe-to-go-back works (for pushed screens)
