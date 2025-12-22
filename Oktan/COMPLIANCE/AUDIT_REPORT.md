# iOS 26 Design Bible Compliance Audit Report

**App:** Oktan
**Audit Date:** December 2025
**Auditor:** Claude Code
**Bible Version:** ios26-design-bible

---

## Executive Summary

The Oktan app has **significant non-compliance** with the iOS 26 Design Bible. This audit identified **47+ violations** across 6 compliance layers. The app requires a substantial rewrite to achieve full compliance.

### Compliance Score: 35/100 (FAILING)

| Layer | Status | Issues |
|-------|--------|--------|
| Layer 1: No Numeric Inference | FAIL | 25+ violations |
| Layer 2: System Components | PARTIAL | Custom components used |
| Layer 3: Lifecycle/State | FAIL | No @SceneStorage usage |
| Layer 4: Accessibility | PARTIAL | Some support, gaps exist |
| Layer 5: App Store Review | PARTIAL | Some issues |
| Layer 6: AI Lockdown | FAIL | DesignSystem violates rules |

---

## Critical Violations

### 1. Numeric Inference Violations (FORBIDDEN)

#### DesignSystem.swift (ios/App/DesignSystem.swift) - **CRITICAL**
The legacy DesignSystem defines explicit numeric values that violate Article II:

```swift
// VIOLATIONS:
enum Spacing {
    static let xsmall: CGFloat = 4    // FORBIDDEN
    static let small: CGFloat = 8     // FORBIDDEN
    static let medium: CGFloat = 16   // FORBIDDEN
    static let large: CGFloat = 24    // FORBIDDEN
    static let xlarge: CGFloat = 32   // FORBIDDEN
}

enum CornerRadius {
    static let medium: CGFloat = 16   // FORBIDDEN
    static let large: CGFloat = 24    // FORBIDDEN
}
```

**Files Using These Values:**
- `ReportsView.swift` - 20+ usages
- `ChartComponents.swift` - 40+ usages
- `NotificationSettingsView.swift` - 5+ usages

#### Fixed Frame Heights (FORBIDDEN)
| File | Line | Violation |
|------|------|-----------|
| ChartComponents.swift | 108 | `.frame(height: 220)` |
| ChartComponents.swift | 128 | `.frame(height: 200)` |
| ChartComponents.swift | 197 | `.frame(height: 200)` |
| ChartComponents.swift | 213 | `.frame(height: 200)` |
| ChartComponents.swift | 255 | `.frame(height: 200)` |
| ChartComponents.swift | 280 | `.frame(height: 200)` |
| ChartComponents.swift | 341 | `.frame(height: 150)` |
| ChartComponents.swift | 357 | `.frame(height: 150)` |
| ReportsView.swift | 222 | `.frame(height: 180)` |
| ReportsView.swift | 246 | `.frame(width: 10, height: 10)` |
| ReportsView.swift | 270 | `.frame(width: 60, ...)` |
| ReportsView.swift | 349 | `.frame(height: 150)` |
| SplashView.swift | 104 | `.frame(width: config.size, height: config.size * 1.4)` |
| SplashView.swift | 114 | `.frame(width: config.size * 0.8, height: config.size * 0.8)` |
| CarSelectionView.swift | 149 | `.frame(height: 200)` |
| CarSelectionView.swift | 168 | `.frame(width: 80)` |
| ProfileView.swift | 39 | `.frame(width: 60, height: 60)` |

### 2. Custom Chrome Violations (FORBIDDEN)

#### RoundedRectangle with cornerRadius
| File | Line | Violation |
|------|------|-----------|
| ErrorHandler.swift | 239 | `RoundedRectangle(cornerRadius: 12)` |
| HomeView.swift | 208 | `RoundedRectangle(cornerRadius: 16)` |
| MetricCard.swift | 28 | `RoundedRectangle(cornerRadius: 12)` |

#### .cornerRadius() Modifier
| File | Line | Violation |
|------|------|-----------|
| ChartComponents.swift | 177 | `.cornerRadius(4)` |
| ChartComponents.swift | 242 | `.cornerRadius(8)` |
| ChartComponents.swift | 333 | `.cornerRadius(4)` |

#### LinearGradient (Custom Color)
| File | Line | Violation |
|------|------|-----------|
| HomeView.swift | 202 | `LinearGradient(colors: [.blue, .indigo], ...)` |
| ProfileView.swift | 33 | `LinearGradient(colors: [.blue, .indigo], ...)` |
| SettingsView.swift | 218 | `LinearGradient(colors: [.blue, .indigo], ...)` |
| SplashView.swift | 31 | `LinearGradient(colors: [Color.white, ...], ...)` |
| ReportsView.swift | 197 | `LinearGradient` |
| ChartComponents.swift | 327 | `LinearGradient` |

#### .shadow() Usage
| File | Line | Violation |
|------|------|-----------|
| DesignSystem.swift (ios) | 57 | `.shadow(color: ..., radius: 8, x: 0, y: 4)` |

### 3. Hex/RGB Color Violations (FORBIDDEN)

The `ios/App/DesignSystem.swift` file contains hex color definitions:

```swift
static let primaryBlue = Color(hex: "007AFF")      // FORBIDDEN
static let deepPurple = Color(hex: "5856D6")       // FORBIDDEN
static let successGreen = Color(hex: "34C759")     // FORBIDDEN
static let warningOrange = Color(hex: "FF9500")    // FORBIDDEN
static let errorRed = Color(hex: "FF3B30")         // FORBIDDEN
static let label = Color(hex: "1D1D1F")            // FORBIDDEN
static let secondaryLabel = Color(hex: "6E6E73")   // FORBIDDEN
static let background = Color(hex: "F5F5F7")       // FORBIDDEN
static let glassTint = Color(hex: "E8F4FD")        // FORBIDDEN
```

### 4. .tint() / Color Override Violations (FORBIDDEN)

| File | Line | Violation |
|------|------|-----------|
| OktanApp.swift | 185 | `.tint(.blue)` |
| ReportsView.swift | 310 | `.tint(DesignSystem.ColorPalette.primaryBlue)` |
| ReportsView.swift | 324 | `.tint(DesignSystem.ColorPalette.deepPurple)` |
| ReportsView.swift | 367 | `.tint(DesignSystem.ColorPalette.deepPurple)` |
| ErrorHandler.swift | 221 | `.tint(.white)` |

### 5. GeometryReader Usage (FORBIDDEN for layout)

| File | Line | Violation |
|------|------|-----------|
| ChartComponents.swift | 88 | `GeometryReader` - Chart overlay |
| ChartComponents.swift | 185 | `GeometryReader` - Chart overlay |
| SplashView.swift | 38 | `GeometryReader` - Animation layout |

### 6. ScrollView + VStack (FORBIDDEN for Forms)

| File | Line | Violation |
|------|------|-----------|
| ReportsView.swift | 35 | `ScrollView { VStack(spacing: ...) { ... } }` |

**Note:** This should use `List` or `Form` containers instead.

---

## Layer 3: Lifecycle & State Violations

### No @SceneStorage Usage (CRITICAL)

The app does not use `@SceneStorage` for state persistence. This violates Article VI.

**Required State Restoration:**

1. **Tab Selection** (`MainTabView`)
   - Current: `@State private var selectedTab = 0`
   - Required: `@SceneStorage("selectedTab") private var selectedTab = 0`

2. **Navigation Path** (All NavigationStack views)
   - No navigation path persistence implemented
   - Required: Store `NavigationPath` data in `@SceneStorage`

3. **Form State** (FuelEntryFormView)
   - Form data lost on background/foreground
   - Required: Persist draft entries

---

## Layer 4: Accessibility Gaps

### Positive Findings
- VoiceOver labels present on most interactive elements
- `accessibilityElement(children: .combine)` used appropriately
- `accessibilityHidden(true)` on decorative elements

### Missing Requirements
1. **Reduce Motion** - No check for `UIAccessibility.isReduceMotionEnabled`
2. **Reduce Transparency** - No check for `UIAccessibility.isReduceTransparencyEnabled`
3. **Largest Dynamic Type** - Not tested/documented
4. **Full Keyboard Access** - Not documented

---

## Layer 5: App Store Review Simulation Issues

### Custom Navigation Chrome
- `heroCard` in HomeView uses custom styling
- Custom gradient backgrounds on cards

### Non-System Alerts
- Some error handling uses custom overlays (ErrorHandler)

---

## ScreenShells Requirement

**Current State:** No ScreenShells implemented

**Required Shells:**
1. `ListShell` - For list-based screens (HomeView, TrackingView, SettingsView)
2. `DetailShell` - For detail views (pushed views with inline title)
3. `FormShell` - For form-based input (FuelEntryFormView, CarConfirmationView)
4. `SearchShell` - For searchable lists (CarSelectionView)

---

## Files Requiring Changes

### Critical Priority (Must Fix)
| File | Violations | Action |
|------|------------|--------|
| `ios/App/DesignSystem.swift` | Hex colors, numeric spacing, shadows, corner radius | DELETE or completely rewrite |
| `Oktan/App/DesignSystem.swift` | Incomplete | Expand with Bible-compliant patterns only |
| `ReportsView.swift` | 40+ DesignSystem usages, ScrollView | Complete rewrite |
| `ChartComponents.swift` | 60+ violations | Complete rewrite |
| `HomeView.swift` | LinearGradient, RoundedRectangle | Rewrite hero card |
| `OktanApp.swift` | .tint(), no SceneStorage | Add state restoration |
| `MetricCard.swift` | RoundedRectangle | Use system styling |

### High Priority
| File | Violations | Action |
|------|------------|--------|
| `ProfileView.swift` | LinearGradient, fixed frame | Rewrite avatar |
| `SettingsView.swift` | LinearGradient | Remove gradient |
| `SplashView.swift` | GeometryReader, LinearGradient | Rewrite animation |
| `CarSelectionView.swift` | Fixed frames | Remove fixed frames |
| `NotificationSettingsView.swift` | DesignSystem colors | Use system colors |
| `ErrorHandler.swift` | RoundedRectangle, .tint | Use system alerts |

### Medium Priority
| File | Violations | Action |
|------|------------|--------|
| `TrackingView.swift` | Minor | Add ScreenShell |
| `FuelEntryFormView.swift` | Minor | Add FormShell, state restoration |
| `CSVImportView.swift` | Minor | Audit for compliance |

---

## Compliance Documentation Missing

The following required documentation does not exist:

1. **SCREEN_INDEX.md** - Must list all screens with:
   - Entry points
   - Navigation type
   - State restoration status
   - Accessibility status

2. **TRACEABILITY_MATRIX.md** - Must map:
   - Each screen to its Shell type
   - System components used
   - UIKit bridging (if any)

3. **PR_DECLARATION.md** - Required for every PR with:
   - System components certification
   - Numeric inference statement
   - Accessibility evidence
   - Dynamic Type evidence
   - Lifecycle testing evidence

---

## Recommended Action Plan

### Phase 1: Foundation (Week 1)
1. Delete `ios/App/DesignSystem.swift`
2. Create Bible-compliant `DesignSystem.swift`
3. Create ScreenShells (`ListShell`, `DetailShell`, `FormShell`, `SearchShell`)
4. Create compliance documentation structure

### Phase 2: Navigation & State (Week 2)
1. Implement `@SceneStorage` for tab selection
2. Implement navigation path persistence
3. Create `RootScaffold` with proper tab management
4. Update all `NavigationStack` views with state restoration

### Phase 3: View Rewrites (Weeks 3-4)
1. Rewrite `ReportsView` using List containers
2. Rewrite `ChartComponents` without numeric inference
3. Rewrite `HomeView` hero card without custom styling
4. Rewrite all affected views

### Phase 4: Validation (Week 5)
1. Run CI compliance scripts
2. Manual accessibility testing (VoiceOver, Dynamic Type)
3. App Store Review simulation
4. Complete PR_DECLARATION.md

---

## Conclusion

The Oktan app requires significant work to achieve iOS 26 Design Bible compliance. The primary issues are:

1. **Legacy DesignSystem** with explicit numeric values and hex colors
2. **No state restoration** via @SceneStorage
3. **Custom chrome** (gradients, rounded rectangles, shadows)
4. **Missing ScreenShells** architecture
5. **Missing compliance documentation**

Full compliance is achievable but requires a disciplined approach to removing all numeric inference and custom styling in favor of system-provided defaults.
