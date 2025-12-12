# Oktan App Roadmap

## Completed ✅

### Phase 1-2: Core Features
- [x] Fuel entry tracking with manual input
- [x] Odometer tracking with distance calculation
- [x] Drive mode support (Eco, Normal, Sport)
- [x] Reports with efficiency and cost analytics
- [x] Car selection with AI-generated images
- [x] CSV export functionality
- [x] Splash animation

### Phase 3: Localization & Authentication
- [x] Sign in with Apple integration
- [x] English & Turkish localization
- [x] Language switching in Settings

---

## Phase 4: Technical Foundation 🔧
**Priority: HIGH** | **Status: IN PROGRESS**

Strengthen the codebase before adding major features.

### 4.1 Unit Tests ✅
- [x] FuelEntryTests (27 tests) - distance, cost, efficiency, edge cases
- [x] FuelRepositoryTests (30+ tests) - CRUD, validation, summary, CSV export
- [x] AppSettingsTests (25+ tests) - unit conversions, formatting, currencies
- [x] CarRepositoryTests (20+ tests) - CRUD, CarDatabase validation
- [x] CalculationAccuracyTests (25+ tests) - formula verification, real data

> **Note:** Test files are in `/OktanTests/`. See `OktanTests/TESTING_SETUP.md` for instructions on adding the test target in Xcode.

### 4.2 SwiftData Migration ✅
- [x] Migrate FuelEntry from JSON to SwiftData
- [x] Migrate Car from JSON to SwiftData  
- [x] Unified FuelRepository with dual storage backend (JSON/SwiftData)
- [x] DataMigrationService for one-time migration
- [x] Feature flag for gradual rollout (`useSwiftData`)
- [x] Backward compatibility via CarRepositoryProtocol

> **SwiftData Files:**
> - `FuelEntrySD.swift` - SwiftData model for fuel entries
> - `CarSD.swift` - SwiftData model for cars
> - `FuelRepositorySD.swift` - SwiftData repository (alternative)
> - `CarRepositorySD.swift` - SwiftData car repository
> - `DataContainer.swift` - Schema and container configuration
> - `DataMigrationService.swift` - Handles JSON → SwiftData migration

### 4.3 Error Handling ✅
- [x] Create centralized error types (OktanError enum)
- [x] Add user-friendly error alerts with ErrorHandler
- [x] Handle network errors gracefully (URL error conversion)
- [x] Add retry mechanisms for recoverable errors
- [x] ErrorBannerView and ErrorStateView UI components
- [x] Unit tests for error handling

> **Error Handling Files:**
> - `OktanError.swift` - Comprehensive error enum with localized descriptions
> - `ErrorHandler.swift` - Error service with alerts, retry, and UI components
> - `ErrorHandlingTests.swift` - Unit tests

### 4.4 Accessibility ✅
- [x] Full VoiceOver audit and improvements
- [x] Dynamic Type support (max accessibility3)
- [x] ≥44pt touch targets for all buttons
- [x] Comprehensive accessibility labels and hints
- [x] Accessibility identifiers for UI testing
- [x] Speakable number/currency/date formatters
- [x] Decorative elements hidden from VoiceOver

> **Accessibility Files:**
> - `Accessibility.swift` - View extensions, helpers, and identifiers
>
> **Key Improvements:**
> - HomeView: Hero card, stat cards, entry rows
> - TrackingView: Add button, entry list, edit/delete buttons
> - FuelEntryFormView: All form fields with labels and hints
> - Error states: Error messages announced to VoiceOver

---

## Phase 5: Charts Enhancements 📊 ✅
**Priority: HIGH** | **Status: COMPLETE**

### 5.1 Data Accuracy Audit ✅
- [x] Audit L/100km calculations (verified in ChartDataServiceTests)
- [x] Audit cost per km calculations (verified in ChartDataServiceTests)
- [x] Audit rolling averages (3-point moving average implemented)
- [x] Add unit tests for all calculations (ChartDataServiceTests.swift)
- [x] Handle edge cases (missing odometer, partial refills gracefully handled)

### 5.2 Enhanced Charts ✅
- [x] Monthly efficiency comparison chart (MonthlyCostChart)
- [x] Cost trend over time (weekly/monthly aggregation)
- [x] Drive mode efficiency comparison (DriveModeComparisonChart)
- [x] Rolling average trend line
- [x] Fill-up frequency insights (FillupFrequencyChart)

### 5.3 Chart Improvements ✅
- [x] Interactive chart tooltips (touch selection with details)
- [x] EfficiencyTrendChart with rolling average overlay
- [x] InsightsCard with auto-generated insights
- [x] Better empty state handling (custom placeholders)
- [x] Tabbed interface (Overview, Trends, Patterns)
- [x] Month-over-month comparison card
- [x] Period comparison with trend indicators

> **Charts Files:**
> - `ChartDataService.swift` - Data aggregation and calculation service
> - `ChartComponents.swift` - Reusable interactive chart components
> - `ReportsView.swift` - Enhanced tabbed reports interface
> - `ChartDataServiceTests.swift` - Comprehensive unit tests

---

## Phase 6: Data Import 📥 ✅
**Priority: MEDIUM** | **Status: COMPLETE**

### 6.1 CSV Import ✅
- [x] Import from CSV files with file picker
- [x] Smart field mapping with auto-suggestions
- [x] Duplicate detection (by date)
- [x] Preview validation before import
- [x] Step-by-step import wizard UI
- [x] Multiple date format support
- [x] Comma/period decimal separator options
- [x] Currency symbol stripping
- [x] Unit tests for import service

### 6.2 Migration Support ✅
- [x] Turkish and English header recognition
- [x] Common fuel app export format compatibility
- [x] Guided import with progress indicator

> **Import Files:**
> - `CSVImportService.swift` - Parsing, mapping, and import logic
> - `CSVImportView.swift` - Step-by-step import wizard
> - `CSVImportServiceTests.swift` - Comprehensive unit tests

---

## Phase 7: Notifications & Reminders 🔔
**Priority: MEDIUM** | **Status: PENDING**

---

## Phase 7: Notifications & Reminders 🔔 ✅
**Priority: MEDIUM** | **Status: COMPLETE**

### 7.1 Reminder System ✅
- [x] User-configurable frequency (Daily, 3 days, Weekly, Biweekly, Monthly)
- [x] Specific day/time selection for reminders
- [x] Local notification scheduling
- [x] Permission handling with UI feedback
- [x] Dedicated Notification Settings UI
- [x] Persistent settings via UserDefaults

### 7.2 Smart Notifications ✅
- [x] "We miss you" inactivity reminder
- [x] Configurable inactivity threshold (7, 14, 21, 30 days)

> **Notification Files:**
> - `NotificationService.swift` - Core service logic
> - `NotificationSettingsView.swift` - Configuration UI
> - `SettingsView.swift` - Integration point

---

## Phase 8: iCloud Sync ☁️ (PAID FEATURE) ✅
**Priority: HIGH** | **Status: COMPLETE**

### 8.1 In-App Purchase ✅
- [x] StoreKit 2 integration (Mocked via PremiumManager)
- [x] "Oktan Pro" subscription or one-time purchase
- [x] Restore purchases functionality
- [x] Paywall UI design

### 8.2 CloudKit Integration ✅
- [x] CloudKit container setup (Entitlements added)
- [x] Sync FuelEntry records (SwiftData implicit)
- [x] Sync Car data (SwiftData implicit)
- [x] Conflict resolution strategy (Default)
- [x] Offline-first architecture (Fallback to local)

### 8.3 Pro Features ✅
- [x] iCloud sync
- [x] Gated behind paywall (Charts)
- [x] "Go Pro" prompt (Paywall)

---

## Phase 9: iOS Widgets 📱
**Priority: MEDIUM** | **Status: PENDING**

### 9.1 Widget Types (2-3)
- [ ] **Quick Stats Widget** (Small)
  - Last fill-up date
  - Recent efficiency
- [ ] **Efficiency Widget** (Medium)
  - Current efficiency trend
  - Last 5 fill-ups average
- [ ] **Summary Widget** (Large)
  - Total distance/cost this month
  - Efficiency chart mini-view

### 9.2 Implementation
- [ ] Widget extension target
- [ ] Shared data with main app
- [ ] Widget configuration (if applicable)

---

## Phase 10: Dark Mode 🌙
**Priority: LOW** | **Status: PENDING**

### 10.1 Design System Updates
- [ ] Dark color palette in DesignSystem.swift
- [ ] Adaptive colors throughout
- [ ] Glass card dark variants
- [ ] Chart color adjustments

### 10.2 Testing
- [ ] All screens in dark mode
- [ ] Screenshot comparison
- [ ] Edge cases (transitions, modals)

---

## Phase 11: App Store Preparation 🚀
**Priority: FINAL** | **Status: PENDING**

### 11.1 Assets
- [ ] App icon (all sizes)
- [ ] App Store screenshots (6.7", 6.5", 5.5")
- [ ] App preview video (optional)

### 11.2 Metadata
- [ ] App name & subtitle
- [ ] Description (EN & TR)
- [ ] Keywords
- [ ] Category selection
- [ ] Privacy policy URL
- [ ] Support URL

### 11.3 Technical
- [ ] Archive & upload to App Store Connect
- [ ] TestFlight beta testing
- [ ] App Review preparation

---

## Future Considerations 🔮

### Maybe Later
- Apple Watch companion app
- CarPlay integration
- Fuel price lookup by location
- Multiple cars support

---

## Version Planning

| Version | Phases | Target |
|---------|--------|--------|
| 1.1 | Phase 4 (Technical) | TBD |
| 1.2 | Phase 5 (Charts) | TBD |
| 1.3 | Phase 6-7 (Import, Reminders) | TBD |
| 2.0 | Phase 8 (iCloud Pro) | TBD |
| 2.1 | Phase 9 (Widgets) | TBD |
| 2.2 | Phase 10 (Dark Mode) | TBD |
| 3.0 | Phase 11 (App Store) | TBD |
