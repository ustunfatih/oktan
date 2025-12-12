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

## Phase 6: Data Import 📥
**Priority: MEDIUM** | **Status: PENDING**

### 6.1 CSV Import
- [ ] Import from CSV files
- [ ] Field mapping UI
- [ ] Duplicate detection
- [ ] Validation with preview

### 6.2 Migration from Other Apps
- [ ] Research common fuel tracking app export formats
- [ ] Implement parsers for popular formats
- [ ] Guided import wizard

---

## Phase 7: Notifications & Reminders 🔔
**Priority: MEDIUM** | **Status: PENDING**

### 7.1 Reminder System
- [ ] User-configurable reminder frequency
  - Every X days
  - Weekly on specific day
  - Monthly
  - Never
- [ ] Local notifications
- [ ] Reminder settings in Settings tab

### 7.2 Smart Notifications (Optional)
- [ ] "You haven't logged in X days" reminder
- [ ] Fuel price trends (if API available)

---

## Phase 8: iCloud Sync ☁️ (PAID FEATURE)
**Priority: HIGH** | **Status: PENDING**

### 8.1 In-App Purchase
- [ ] StoreKit 2 integration
- [ ] "Oktan Pro" subscription or one-time purchase
- [ ] Restore purchases functionality
- [ ] Paywall UI design

### 8.2 CloudKit Integration
- [ ] CloudKit container setup
- [ ] Sync FuelEntry records
- [ ] Sync Car data
- [ ] Conflict resolution strategy
- [ ] Offline-first architecture

### 8.3 Pro Features
- [ ] iCloud sync
- [ ] Gated behind paywall
- [ ] "Go Pro" prompt in Profile tab

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
