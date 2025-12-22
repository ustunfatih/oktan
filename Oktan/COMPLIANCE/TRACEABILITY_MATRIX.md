# Traceability Matrix

This document maps each screen to its system components, shell type, and compliance status per the iOS 26 Design Bible.

---

## Component Allowlist

### Approved SwiftUI Primitives

```
NavigationStack, TabView, List, Form, Section, NavigationLink,
Text, Image, Button, Toggle, TextField, SecureField,
DatePicker, Picker, Menu, ProgressView, Label, Divider,
ContentUnavailableView, LabeledContent, Link
```

### Approved Modifiers

```
.navigationTitle(), .navigationBarTitleDisplayMode(),
.listStyle(), .toolbar(), .sheet(), .alert(),
.confirmationDialog(), .searchable(), .swipeActions(),
.accessibilityLabel(), .accessibilityValue(), .accessibilityHint(),
.accessibilityIdentifier(), .accessibilityElement(),
.accessibilityHidden(), .font(), .foregroundStyle(),
.buttonStyle(.borderedProminent), .buttonStyle(.bordered),
.disabled(), .keyboardType(), .textContentType(),
.textInputAutocapitalization(), .autocorrectionDisabled(),
.padding() (NO numeric argument), .background(.ultraThinMaterial)
```

### FORBIDDEN Components/Modifiers

```
.padding(N), .frame(width:), .frame(height:),
.cornerRadius(), .shadow(), RoundedRectangle(cornerRadius:),
LinearGradient, GeometryReader (for layout), ScrollView + VStack (for forms),
.tint(), .accentColor(), Color(hex:), Color(red:green:blue:),
UINavigationBarAppearance, UIAppearance, .toolbarBackground()
```

---

## Screen-to-Component Matrix

### Tab Screens

| Screen | Shell Type | Navigation | System Components | UIKit Bridge | Compliance |
|--------|------------|------------|-------------------|--------------|------------|
| HomeScreen | ListShell | Tab | List, Section, Button, Text, Image, Label, NavigationStack, NavigationLink | None | NON-COMPLIANT |
| TrackingScreen | ListShell | Tab | List, Section, ForEach, Button, Label, NavigationStack, .sheet, .swipeActions | None | PARTIAL |
| ReportsScreen | ListShell | Tab | Picker, ScrollView, VStack, Chart, ProgressView, NavigationStack, Menu, .sheet | None | NON-COMPLIANT |
| ProfileScreen | ListShell | Tab | List, Section, Button, Label, Text, Image, NavigationStack, .confirmationDialog | AuthenticationServices | PARTIAL |
| SettingsScreen | ListShell | Tab | List, Section, Picker, Toggle, Button, Link, NavigationStack, NavigationLink, .sheet, .alert | None | PARTIAL |

### Detail/Pushed Screens

| Screen | Shell Type | Navigation | System Components | UIKit Bridge | Compliance |
|--------|------------|------------|-------------------|--------------|------------|
| NotificationSettingsScreen | ListShell | Push | List, Section, Picker, Toggle, Button, .alert | UserNotifications | PARTIAL |
| DataManagementScreen | ListShell | Push | List, Section, Button, .sheet, .confirmationDialog | None | COMPLIANT |
| AboutScreen | ListShell | Sheet | List, Section, Text, Image, Label, .toolbar | None | PARTIAL |

### Modal/Sheet Screens

| Screen | Shell Type | Navigation | System Components | UIKit Bridge | Compliance |
|--------|------------|------------|-------------------|--------------|------------|
| FuelEntryFormScreen | FormShell | Sheet | Form, Section, TextField, DatePicker, Picker, Toggle, Button, .toolbar | UINotificationFeedbackGenerator | PARTIAL |
| CarSelectionScreen | SearchShell | Sheet | List, NavigationStack, NavigationLink, .searchable, .toolbar | None | PARTIAL |
| CarModelSelectionScreen | ListShell | Push | List, NavigationLink | None | COMPLIANT |
| CarYearSelectionScreen | ListShell | Push | List, NavigationLink | None | COMPLIANT |
| CarConfirmationScreen | FormShell | Push | Form, Section, TextField, Button, ProgressView, LabeledContent | UINotificationFeedbackGenerator | NON-COMPLIANT |
| CSVImportScreen | FormShell | Sheet | Form, List, Section, Picker, Toggle, Button, ProgressView, .fileImporter, .toolbar | UniformTypeIdentifiers | PARTIAL |
| PaywallScreen | N/A | Sheet | RevenueCatUI.PaywallView | RevenueCat | EXEMPT |
| SplashScreen | N/A | Overlay | ZStack, GeometryReader, Text, Image | None | NON-COMPLIANT |

---

## Violation Details Per Screen

### HomeScreen

**Current Components:**
```swift
NavigationStack, List, Section, VStack, HStack, Spacer,
Image, Text, Button, Label, Divider,
ContentUnavailableView, ForEach
```

**VIOLATIONS:**
| Component/Modifier | Line | Issue |
|--------------------|------|-------|
| LinearGradient | 202 | Custom gradient |
| RoundedRectangle(cornerRadius: 16) | 208 | Numeric corner radius |
| .padding() | 125, 200 | OK (no numeric) |
| .background(.ultraThinMaterial) | 126 | OK |
| .foregroundStyle(.white.opacity(0.8)) | 159 | Custom opacity |
| .font(.system(size: 48)) | 133 | Fixed font size |
| .font(.system(size: 36)) | 162 | Fixed font size |

**Required Changes:**
1. Remove LinearGradient hero card -> Use Section with semantic styling
2. Remove RoundedRectangle -> Use system card styling
3. Remove fixed font sizes -> Use semantic fonts
4. Wrap in ListShell

---

### TrackingScreen

**Current Components:**
```swift
NavigationStack, List, Section, Text, ForEach,
VStack, HStack, Spacer, Label, Button,
ContentUnavailableView, .swipeActions, .sheet,
.confirmationDialog, .toolbar
```

**VIOLATIONS:**
| Component/Modifier | Line | Issue |
|--------------------|------|-------|
| None critical | - | Shell wrapper missing |

**Required Changes:**
1. Wrap content in ListShell(title: "Tracking")
2. Add @SceneStorage for state

---

### ReportsScreen

**Current Components:**
```swift
NavigationStack, Picker, ScrollView, VStack,
Chart (BarMark, LineMark, AreaMark, PointMark, RuleMark),
LazyVGrid, Text, Image, Button, Menu,
ProgressView, HStack, Spacer, ForEach
```

**VIOLATIONS:**
| Component/Modifier | Line | Issue |
|--------------------|------|-------|
| ScrollView + VStack | 35 | Should be List |
| DesignSystem.Spacing.large | 32-46 | Numeric spacing |
| DesignSystem.Spacing.medium | Multiple | Numeric spacing |
| DesignSystem.ColorPalette.* | Multiple | Hex colors |
| .frame(height: 180) | 222 | Fixed height |
| .frame(width: 10, height: 10) | 246 | Fixed size |
| .frame(width: 60) | 270 | Fixed width |
| .frame(height: 150) | 349 | Fixed height |
| .tint() | 310, 324, 367 | Color override |
| .glassCard() | Multiple | Custom modifier |
| GeometryReader | 88, 185 | Layout violation |

**Required Changes:**
1. Replace ScrollView with List
2. Remove all DesignSystem.Spacing references
3. Remove all DesignSystem.ColorPalette references
4. Remove all fixed .frame() calls
5. Remove .tint() calls
6. Remove .glassCard() modifier
7. Use system colors (Color.primary, .secondary, etc.)

---

### ProfileScreen

**Current Components:**
```swift
NavigationStack, List, Section, VStack, HStack,
Text, Image, Label, Button, ProgressView,
.confirmationDialog
```

**VIOLATIONS:**
| Component/Modifier | Line | Issue |
|--------------------|------|-------|
| LinearGradient | 33 | Avatar gradient |
| Circle().fill() | 32 | OK |
| .frame(width: 60, height: 60) | 39 | Fixed size |

**Required Changes:**
1. Remove LinearGradient -> Use system color
2. Remove fixed frame -> Use dynamic sizing

---

### SettingsScreen

**Current Components:**
```swift
NavigationStack, List, Section, Picker, Toggle,
Button, Link, Label, Text, HStack,
NavigationLink, .sheet, .alert
```

**VIOLATIONS:**
| Component/Modifier | Line | Issue |
|--------------------|------|-------|
| LinearGradient (AboutView) | 218 | App icon gradient |

**Required Changes:**
1. Remove LinearGradient in AboutView

---

### ChartComponents.swift

**VIOLATIONS (CRITICAL - 60+ issues):**

| Pattern | Count | Issue |
|---------|-------|-------|
| DesignSystem.Spacing.* | 25+ | Numeric spacing |
| DesignSystem.ColorPalette.* | 35+ | Hex colors |
| .frame(height: N) | 8 | Fixed heights |
| .cornerRadius(N) | 3 | Numeric radius |
| LinearGradient | 1 | Custom gradient |
| GeometryReader | 2 | Layout |
| .glassCard() | 6 | Custom modifier |

**Required Changes:**
1. Complete rewrite removing all numeric values
2. Use List with Section for organization
3. Use system colors only
4. Remove .glassCard() custom modifier

---

### MetricCard.swift

**Current Components:**
```swift
VStack, Label, Text, .background(), .clipShape()
```

**VIOLATIONS:**
| Component/Modifier | Line | Issue |
|--------------------|------|-------|
| VStack(..., spacing: 8) | 11 | Numeric spacing |
| .padding() | 26 | OK |
| Color(uiColor: .secondarySystemGroupedBackground) | 27 | OK |
| RoundedRectangle(cornerRadius: 12) | 28 | Numeric radius |

**Required Changes:**
1. Remove VStack spacing -> Use default
2. Remove RoundedRectangle -> Use .background(.fill)

---

## Shell Assignment Summary

| Shell Type | Screens |
|------------|---------|
| **ListShell** | HomeScreen, TrackingScreen, ReportsScreen, ProfileScreen, SettingsScreen, NotificationSettingsScreen, DataManagementScreen, AboutScreen, CarModelSelectionScreen, CarYearSelectionScreen |
| **FormShell** | FuelEntryFormScreen, CarConfirmationScreen, CSVImportScreen |
| **SearchShell** | CarSelectionScreen |
| **DetailShell** | (none currently - for pushed detail views) |
| **N/A** | PaywallScreen (RevenueCat), SplashScreen (special) |

---

## UIKit Bridging Justification

| Screen | UIKit Component | Justification |
|--------|-----------------|---------------|
| ProfileScreen | AuthenticationServices | Sign in with Apple requires ASAuthorizationController |
| FuelEntryFormScreen | UINotificationFeedbackGenerator | Haptic feedback on save |
| CarConfirmationScreen | UINotificationFeedbackGenerator | Haptic feedback on save |
| NotificationSettingsScreen | UserNotifications | Local notification scheduling |
| CSVImportScreen | UniformTypeIdentifiers | File type identification |

All UIKit bridging is for system APIs that have no SwiftUI equivalent. No custom UIKit views are implemented.

---

## Compliance Summary

| Status | Count | Screens |
|--------|-------|---------|
| COMPLIANT | 2 | CarModelSelectionScreen, CarYearSelectionScreen |
| PARTIAL | 8 | TrackingScreen, SettingsScreen, NotificationSettingsScreen, DataManagementScreen, FuelEntryFormScreen, CarSelectionScreen, CSVImportScreen, ProfileScreen |
| NON-COMPLIANT | 5 | HomeScreen, ReportsScreen, CarConfirmationScreen, SplashScreen, AboutScreen (in SettingsView) |
| EXEMPT | 1 | PaywallScreen (third-party) |

**Total: 16 screens audited**
