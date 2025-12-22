# Task 100 — Add Notifications Screen

## Goal
Add a new Notifications screen that is fully compliant with the iOS 26 Design Bible.

## Requirements
- Create `NotificationsScreen.swift` using `ListShell(title: "Notifications")` as the outer container.
- Display a sectioned list of notifications.
- Tapping a row pushes `NotificationDetailScreen` via `NavigationLink`.
- No numeric padding or fixed frames.
- No custom colors/shadows/corner radii.
- Use system text + list patterns.

## Compliance updates (Required)
- Update `swiftui-starter-repo/COMPLIANCE/SCREEN_INDEX.md`
- Update `swiftui-starter-repo/COMPLIANCE/TRACEABILITY_MATRIX.md`
- Update `swiftui-starter-repo/COMPLIANCE/PR_DECLARATION.md`

## Definition of Done
- CI scripts pass.
- Navigation works with swipe back.
- VoiceOver traversal reads rows correctly.
- Dynamic Type largest size has no clipping.
