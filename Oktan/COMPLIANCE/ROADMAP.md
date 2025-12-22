# iOS 26 Design Bible Compliance Roadmap

## Overview

This roadmap outlines the steps required to bring the Oktan app into full compliance with the iOS 26 Design Bible. The work is organized into phases with clear deliverables and dependencies.

**Current Compliance Score:** 35/100 (FAILING)
**Target Compliance Score:** 100/100 (PASSING)

---

## Phase 1: Foundation (Priority: CRITICAL)

### 1.1 Delete Legacy DesignSystem
**Status:** NOT STARTED
**Estimated Effort:** 30 minutes

**Tasks:**
- [ ] Delete `ios/App/DesignSystem.swift` (legacy file with violations)
- [ ] Verify no imports reference this file

**Files Affected:**
- `ios/App/DesignSystem.swift` (DELETE)

---

### 1.2 Create Bible-Compliant DesignSystem
**Status:** NOT STARTED
**Estimated Effort:** 1 hour

**Tasks:**
- [ ] Rewrite `Oktan/App/DesignSystem.swift` with Bible-compliant patterns
- [ ] Define ONLY system color references (no hex)
- [ ] Remove all numeric spacing constants
- [ ] Remove all corner radius constants
- [ ] Remove all shadow definitions

**Deliverable:**
```swift
// Oktan/App/DesignSystem.swift
import SwiftUI

/// Bible-compliant color references using ONLY system colors.
enum BibleColors {
    static let primary = Color.primary
    static let secondary = Color.secondary
    static let destructive = Color.red
    static let success = Color.green
    static let warning = Color.orange
    static let accent = Color.accentColor
}

// NO spacing, corner radius, or shadow definitions allowed
```

---

### 1.3 Create ScreenShells
**Status:** NOT STARTED
**Estimated Effort:** 1.5 hours

**Tasks:**
- [ ] Create `Oktan/Navigation/Shells/ScreenShells.swift`
- [ ] Implement `ListShell` - For list-based screens
- [ ] Implement `DetailShell` - For pushed detail views
- [ ] Implement `FormShell` - For form-based input
- [ ] Implement `SearchShell` - For searchable lists

**Deliverable:**
```swift
// Oktan/Navigation/Shells/ScreenShells.swift
import SwiftUI

struct ListShell<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        List { content() }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
    }
}

struct DetailShell<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        List { content() }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct FormShell<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        Form { content() }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct SearchShell<Content: View>: View {
    let title: String
    @Binding var query: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        List { content() }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query)
    }
}
```

---

## Phase 2: Navigation & State (Priority: HIGH)

### 2.1 Implement RootScaffold with State Restoration
**Status:** NOT STARTED
**Estimated Effort:** 2 hours

**Tasks:**
- [ ] Create `Oktan/Navigation/RootScaffold.swift`
- [ ] Replace `MainTabView` with `RootScaffold`
- [ ] Add `@SceneStorage("selectedTab")` for tab persistence
- [ ] Remove `.tint(.blue)` from TabView

**Deliverable:**
```swift
// Oktan/Navigation/RootScaffold.swift
import SwiftUI

struct RootScaffold: View {
    @SceneStorage("selectedTab") private var selectedTab: String = "home"

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeNav()
                .tabItem { Label("Home", systemImage: "house") }
                .tag("home")

            TrackingNav()
                .tabItem { Label("Tracking", systemImage: "fuelpump") }
                .tag("tracking")

            ReportsNav()
                .tabItem { Label("Reports", systemImage: "chart.bar") }
                .tag("reports")

            ProfileNav()
                .tabItem { Label("Profile", systemImage: "person") }
                .tag("profile")

            SettingsNav()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag("settings")
        }
    }
}
```

---

### 2.2 Create Navigation Wrappers with Path Persistence
**Status:** NOT STARTED
**Estimated Effort:** 2 hours

**Tasks:**
- [ ] Create `HomeNav.swift` with `@SceneStorage` path persistence
- [ ] Create `TrackingNav.swift` with path persistence
- [ ] Create `ReportsNav.swift` with path persistence
- [ ] Create `ProfileNav.swift` with path persistence
- [ ] Create `SettingsNav.swift` with path persistence

**Deliverable per Nav:**
```swift
// Oktan/Navigation/HomeNav.swift
import SwiftUI

struct HomeNav: View {
    @SceneStorage("homeNavPath") private var homePathData: Data?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreen()
                .onAppear { restorePathIfPossible() }
                .onChange(of: path) { savePathIfPossible() }
        }
    }

    private func restorePathIfPossible() {
        // Restore navigation path from SceneStorage
    }

    private func savePathIfPossible() {
        // Save navigation path to SceneStorage
    }
}
```

---

### 2.3 Update OktanApp.swift
**Status:** NOT STARTED
**Estimated Effort:** 1 hour

**Tasks:**
- [ ] Replace `MainTabView` with `RootScaffold`
- [ ] Remove `.tint(.blue)` override
- [ ] Verify environment object propagation

---

## Phase 3: View Rewrites (Priority: HIGH)

### 3.1 Rewrite HomeView
**Status:** NOT STARTED
**Estimated Effort:** 2 hours

**Tasks:**
- [ ] Wrap content in `ListShell(title: "Home")`
- [ ] Replace hero card LinearGradient with system styling
- [ ] Remove RoundedRectangle with cornerRadius
- [ ] Remove fixed font sizes
- [ ] Use system colors only
- [ ] Extract to `HomeScreen.swift`

**Violations to Fix:**
| Line | Issue | Fix |
|------|-------|-----|
| 202 | LinearGradient | Remove, use Section |
| 208 | RoundedRectangle(cornerRadius: 16) | Remove |
| 133 | .font(.system(size: 48)) | Use .largeTitle |
| 162 | .font(.system(size: 36)) | Use .title |

---

### 3.2 Rewrite ReportsView (CRITICAL)
**Status:** NOT STARTED
**Estimated Effort:** 4 hours

**Tasks:**
- [ ] Replace ScrollView + VStack with List
- [ ] Remove ALL DesignSystem.Spacing references (25+)
- [ ] Remove ALL DesignSystem.ColorPalette references (30+)
- [ ] Remove all fixed .frame() calls
- [ ] Remove .tint() calls
- [ ] Remove .glassCard() modifier
- [ ] Wrap in `ListShell(title: "Reports")`

**This is the most complex rewrite due to the chart components.**

---

### 3.3 Rewrite ChartComponents.swift (CRITICAL)
**Status:** NOT STARTED
**Estimated Effort:** 4 hours

**Tasks:**
- [ ] Remove ALL DesignSystem.Spacing references
- [ ] Remove ALL DesignSystem.ColorPalette references
- [ ] Remove all fixed .frame(height:) calls
- [ ] Remove all .cornerRadius() calls
- [ ] Remove LinearGradient
- [ ] Remove GeometryReader (use chartOverlay alternatives)
- [ ] Remove .glassCard() modifier
- [ ] Use system colors for chart elements

---

### 3.4 Rewrite ProfileView
**Status:** NOT STARTED
**Estimated Effort:** 1 hour

**Tasks:**
- [ ] Remove LinearGradient avatar background
- [ ] Remove fixed .frame(width: 60, height: 60)
- [ ] Use system Circle with accent color
- [ ] Wrap in ListShell

---

### 3.5 Rewrite SettingsView
**Status:** NOT STARTED
**Estimated Effort:** 30 minutes

**Tasks:**
- [ ] Remove LinearGradient in AboutView
- [ ] Wrap in ListShell (already uses List)

---

### 3.6 Rewrite MetricCard
**Status:** NOT STARTED
**Estimated Effort:** 30 minutes

**Tasks:**
- [ ] Remove VStack spacing: 8
- [ ] Remove RoundedRectangle(cornerRadius: 12)
- [ ] Use .background(.fill) or .ultraThinMaterial

---

### 3.7 Rewrite SplashView
**Status:** NOT STARTED
**Estimated Effort:** 2 hours

**Tasks:**
- [ ] Remove GeometryReader dependency for layout
- [ ] Remove LinearGradient background
- [ ] Simplify animation without numeric values
- [ ] Consider using system transition effects

---

### 3.8 Fix ErrorHandler Custom UI
**Status:** NOT STARTED
**Estimated Effort:** 1 hour

**Tasks:**
- [ ] Remove RoundedRectangle(cornerRadius: 12)
- [ ] Remove .tint(.white)
- [ ] Use system alert/banner patterns

---

### 3.9 Fix CarConfirmationView
**Status:** NOT STARTED
**Estimated Effort:** 30 minutes

**Tasks:**
- [ ] Remove .frame(height: 200)
- [ ] Remove .frame(width: 80)
- [ ] Wrap in FormShell

---

### 3.10 Apply Shells to All Screens
**Status:** NOT STARTED
**Estimated Effort:** 2 hours

**Tasks:**
- [ ] TrackingView -> ListShell
- [ ] FuelEntryFormView -> FormShell
- [ ] CarSelectionView -> SearchShell
- [ ] NotificationSettingsView -> ListShell
- [ ] CSVImportView -> FormShell
- [ ] DataManagementView -> ListShell

---

## Phase 4: Accessibility & Testing (Priority: MEDIUM)

### 4.1 Add Reduce Motion Support
**Status:** NOT STARTED
**Estimated Effort:** 1 hour

**Tasks:**
- [ ] Add `@Environment(\.accessibilityReduceMotion)` checks
- [ ] Wrap animations in reduce motion conditionals
- [ ] Test with Reduce Motion enabled

---

### 4.2 Add Reduce Transparency Support
**Status:** NOT STARTED
**Estimated Effort:** 30 minutes

**Tasks:**
- [ ] Add `@Environment(\.accessibilityReduceTransparency)` checks
- [ ] Provide solid backgrounds when enabled

---

### 4.3 Dynamic Type Testing
**Status:** NOT STARTED
**Estimated Effort:** 2 hours

**Tasks:**
- [ ] Test each screen at Largest Accessibility Size
- [ ] Fix any clipping issues
- [ ] Document results in SCREEN_INDEX.md

---

### 4.4 VoiceOver Testing
**Status:** NOT STARTED
**Estimated Effort:** 2 hours

**Tasks:**
- [ ] Test each screen with VoiceOver enabled
- [ ] Verify all interactive elements are labeled
- [ ] Fix any navigation issues
- [ ] Document results in SCREEN_INDEX.md

---

## Phase 5: CI Integration (Priority: MEDIUM)

### 5.1 Copy CI Scripts
**Status:** NOT STARTED
**Estimated Effort:** 30 minutes

**Tasks:**
- [ ] Create `Oktan/ci/` directory
- [ ] Copy `ios26_bible_check.py`
- [ ] Copy `ios26_api_forbid_check.py`
- [ ] Copy `ios26_component_allowlist_check.py`
- [ ] Copy `check_pr_declaration.py`
- [ ] Copy `check_screen_registry.py`
- [ ] Copy `check_shell_usage.py`
- [ ] Copy `check_traceability_matrix.py`
- [ ] Copy `bible_check_config.json`

---

### 5.2 Configure GitHub Actions
**Status:** NOT STARTED
**Estimated Effort:** 1 hour

**Tasks:**
- [ ] Create `.github/workflows/ios26-bible-check.yml`
- [ ] Configure to run on PRs
- [ ] Test workflow

---

### 5.3 Run Initial CI Check
**Status:** NOT STARTED
**Estimated Effort:** 30 minutes

**Tasks:**
- [ ] Run all CI scripts locally
- [ ] Fix any remaining violations
- [ ] Verify all checks pass

---

## Phase 6: Documentation & Finalization (Priority: LOW)

### 6.1 Update SCREEN_INDEX.md
**Status:** PARTIALLY COMPLETE
**Estimated Effort:** 1 hour

**Tasks:**
- [ ] Update compliance status after fixes
- [ ] Document Dynamic Type testing results
- [ ] Document VoiceOver testing results
- [ ] Mark state restoration as implemented

---

### 6.2 Update TRACEABILITY_MATRIX.md
**Status:** PARTIALLY COMPLETE
**Estimated Effort:** 1 hour

**Tasks:**
- [ ] Update shell assignments
- [ ] Update compliance status
- [ ] Document any UIKit bridging

---

### 6.3 Create Initial PR with All Changes
**Status:** NOT STARTED
**Estimated Effort:** 1 hour

**Tasks:**
- [ ] Complete PR_DECLARATION.md for changes
- [ ] Run all CI checks
- [ ] Submit PR for review

---

## Timeline Summary

| Phase | Estimated Hours | Priority |
|-------|-----------------|----------|
| Phase 1: Foundation | 3 hours | CRITICAL |
| Phase 2: Navigation & State | 5 hours | HIGH |
| Phase 3: View Rewrites | 17 hours | HIGH |
| Phase 4: Accessibility | 5.5 hours | MEDIUM |
| Phase 5: CI Integration | 2 hours | MEDIUM |
| Phase 6: Documentation | 3 hours | LOW |
| **TOTAL** | **35.5 hours** | |

---

## Dependencies

```
Phase 1.2 (DesignSystem) -> Phase 3 (View Rewrites)
Phase 1.3 (ScreenShells) -> Phase 3 (View Rewrites)
Phase 2.1 (RootScaffold) -> Phase 2.2 (Nav Wrappers)
Phase 3 (View Rewrites) -> Phase 4 (Accessibility Testing)
Phase 3 (View Rewrites) -> Phase 5 (CI Integration)
Phase 4 + 5 -> Phase 6 (Documentation)
```

---

## Success Criteria

1. **All CI scripts pass** without violations
2. **@SceneStorage** implemented for tab and navigation state
3. **All screens use ScreenShells** (ListShell, DetailShell, FormShell, SearchShell)
4. **No numeric inference** (spacing, padding, radius, shadows)
5. **System colors only** (no hex, no RGB)
6. **Accessibility tested** (VoiceOver, Dynamic Type, Reduce Motion)
7. **Documentation complete** (SCREEN_INDEX, TRACEABILITY_MATRIX, PR_DECLARATION)

---

## Quick Start

To begin compliance work:

1. Start with **Phase 1.2** - Create Bible-compliant DesignSystem
2. Then **Phase 1.3** - Create ScreenShells
3. Then **Phase 2.1** - Create RootScaffold
4. Then **Phase 3.1-3.10** - Rewrite views one at a time

Each task can be completed independently after dependencies are met.
