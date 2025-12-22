# PR Compliance Declaration (Required)

Framework: SwiftUI

## Scope
- Screens touched: HomeView, TrackingView, FuelEntryFormView, ReportsView, ProfileView, SettingsView, SplashView, CarSelectionView
- Components touched: MetricCard, ShareSheet, ErrorHandler
- New flows added: None

## System Components Only
- [ ] Yes (required)

## Numeric Inference
- [ ] None (required)
If any numeric values were added, list them and justify with Apple-exposed APIs (otherwise PR must fail):

## Accessibility Contract (Layer 4)
### Accessibility Evidence (Required)
- VoiceOver Evidence: Tested? No (pending). Device + iOS version + notes: TBD
- Switch Control / Full Keyboard Access: Tested? No (pending). Notes: TBD

### Dynamic Type Evidence (Required)
- Largest text size tested? No (pending)
- Screens verified (list them): TBD

### Reduce Motion / Transparency Evidence (Required)
- Reduce Motion: Verified? No (pending)
- Reduce Transparency: Verified? No (pending)

## Lifecycle & State (Layer 3)
- [ ] Background/foreground tested (pending)
- [ ] Navigation state preserved (pending)
- [ ] Modal state preserved or safely recovered (pending)

## App Store Review Simulation (Layer 5)
- [ ] Swipe-to-go-back works (pending)
- [ ] No custom alerts/nav bars (pending)
- [ ] Destructive actions confirmed (pending)

## Compliance Declaration
I certify this PR complies with the iOS 26 Design Bible Layers 1–6.
