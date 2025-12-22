# PR Declaration Template

**PR Title:** [Brief description]
**PR Number:** #XXX
**Author:** [Name]
**Date:** [YYYY-MM-DD]

---

## Framework

- [ ] SwiftUI
- [ ] UIKit
- [ ] Mixed (justify below)

**UIKit Justification (if applicable):**
> [Explain why UIKit is necessary]

---

## Scope

**Screens/Components Touched:**
- [ ] [ScreenName] - [Brief description of changes]
- [ ] [ScreenName] - [Brief description of changes]

**New Files Created:**
- [ ] [FileName] - [Purpose]

**Files Modified:**
- [ ] [FileName] - [Summary of changes]

---

## System Components Only

- [ ] I certify that this PR uses ONLY approved system components from the allowlist
- [ ] No custom navigation chrome (NavigationStack/TabView with system defaults only)
- [ ] No custom form containers (Form/List with system styling only)
- [ ] No custom control implementations

**Components Used:**
> List all SwiftUI/UIKit components used in this PR

---

## Numeric Inference

- [ ] **NO numeric values inferred** - This PR contains no hardcoded spacing, padding, corner radius, shadow, or animation curve values
- [ ] **Exception documented** - This PR contains numeric values with justification below

**Numeric Values Justification (if any):**
> [Explain any numeric values and why they are necessary]

**Search Verification:**
```
rg '\.(padding|frame|cornerRadius|shadow)\([0-9]' [files changed]
rg 'spacing:\s*[0-9]' [files changed]
```

---

## Accessibility Contract

### VoiceOver Evidence

- [ ] Tested on physical device with VoiceOver enabled
- [ ] All interactive elements have accessibility labels
- [ ] All containers use appropriate `accessibilityElement(children:)` grouping
- [ ] Decorative elements marked with `accessibilityHidden(true)`

**Device:** [iPhone model]
**iOS Version:** [XX.X]

**Testing Notes:**
> [Describe VoiceOver traversal path and any issues found/fixed]

### Switch Control / Full Keyboard Access

- [ ] Tested with Switch Control enabled
- [ ] Tested with Full Keyboard Access enabled
- [ ] All interactive elements are reachable and activatable

**Testing Notes:**
> [Describe any issues found/fixed]

---

## Dynamic Type Evidence

- [ ] Tested with **Largest Accessibility Size** enabled
- [ ] No text clipping observed
- [ ] No layout breakage observed
- [ ] All text uses semantic font styles (.body, .headline, etc.)

**Screenshot(s) at Largest Size:**
> [Attach or describe]

---

## Reduce Motion / Transparency Evidence

### Reduce Motion

- [ ] Tested with **Reduce Motion** enabled
- [ ] All animations respect `UIAccessibility.isReduceMotionEnabled`
- [ ] Essential animations still functional with reduced intensity

**Testing Notes:**
> [Describe behavior with Reduce Motion enabled]

### Reduce Transparency

- [ ] Tested with **Reduce Transparency** enabled
- [ ] UI remains usable and readable
- [ ] No critical information hidden by transparency effects

**Testing Notes:**
> [Describe behavior with Reduce Transparency enabled]

---

## Lifecycle & State

### Background/Foreground

- [ ] Tested app backgrounding and foregrounding
- [ ] State preserved correctly when returning from background
- [ ] No data loss on backgrounding

**Testing Steps:**
1. [Step 1]
2. [Step 2]
3. [Expected result]

### Navigation State

- [ ] Navigation path persisted via `@SceneStorage` (if applicable)
- [ ] Tab selection persisted via `@SceneStorage` (if applicable)
- [ ] Form draft data persisted (if applicable)

**State Storage:**
> [List all @SceneStorage properties used]

### Modal State

- [ ] Sheets dismiss correctly
- [ ] Alerts respond to both Cancel and Confirm
- [ ] Confirmation dialogs work as expected

---

## App Store Review Simulation

- [ ] Swipe-to-go-back works on all pushed screens
- [ ] No custom alerts (using system .alert modifier)
- [ ] Destructive actions have `.destructive` role
- [ ] No hidden/deceptive UI patterns
- [ ] Privacy-sensitive features have appropriate permissions

**Simulation Notes:**
> [Describe manual App Store review simulation results]

---

## Shell Usage

**Screens in this PR use the following shells:**

| Screen | Shell Type | Title Display Mode |
|--------|------------|-------------------|
| [ScreenName] | ListShell / DetailShell / FormShell / SearchShell | .large / .inline |

---

## CI Check Results

```
[ ] ios26_bible_check.py - PASS / FAIL
[ ] ios26_api_forbid_check.py - PASS / FAIL
[ ] ios26_component_allowlist_check.py - PASS / FAIL
[ ] check_screen_registry.py - PASS / FAIL
[ ] check_shell_usage.py - PASS / FAIL
[ ] check_traceability_matrix.py - PASS / FAIL
```

**CI Output:**
> [Paste relevant CI output or link to CI run]

---

## Compliance Certification

- [ ] I certify this PR complies with the iOS 26 Design Bible Layers 1-6
- [ ] I have read and understood the Constitution (README_CONSTITUTION.md)
- [ ] I have updated SCREEN_INDEX.md (if screens changed)
- [ ] I have updated TRACEABILITY_MATRIX.md (if screens changed)
- [ ] All CI checks pass

**Signed:** [Your Name]
**Date:** [YYYY-MM-DD]

---

## Reviewer Checklist

For the reviewer to complete:

- [ ] Numeric inference check passed
- [ ] System components only verified
- [ ] Accessibility requirements met
- [ ] State restoration implemented correctly
- [ ] SCREEN_INDEX.md updated (if applicable)
- [ ] TRACEABILITY_MATRIX.md updated (if applicable)
- [ ] CI checks all green

**Reviewer:** [Name]
**Date:** [YYYY-MM-DD]
