# PR Compliance Declaration (Required)

Framework: SwiftUI / UIKit (choose one or both)

## Scope
- Screens touched:
- Components touched:
- New flows added:

## System Components Only
- [ ] Yes (required)

## Numeric Inference
- [ ] None (required)
If any numeric values were added, list them and justify with Apple-exposed APIs (otherwise PR must fail):

## Accessibility Contract (Layer 4)
### Accessibility Evidence (Required)
- VoiceOver: Tested? (Yes/No) Device + iOS version + notes
- Switch Control / Full Keyboard Access: Tested? (Yes/No) notes

### Dynamic Type Evidence (Required)
- Largest text size tested? (Yes/No)
- Screens verified (list them):

### Reduce Motion / Transparency Evidence (Required)
- Reduce Motion: Verified? (Yes/No)
- Reduce Transparency: Verified? (Yes/No)

## Lifecycle & State (Layer 3)
- [ ] Background/foreground tested
- [ ] Navigation state preserved
- [ ] Modal state preserved or safely recovered

## App Store Review Simulation (Layer 5)
- [ ] Swipe-to-go-back works
- [ ] No custom alerts/nav bars
- [ ] Destructive actions confirmed

## Compliance Declaration
I certify this PR complies with the iOS 26 Design Bible Layers 1–6.
