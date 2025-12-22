# Task Templates (Copy/Paste)

## Add a new List-based screen
Implement `NotificationsScreen.swift`:
- Outer container: ListShell(title: "Notifications")
- Sectioned list of items
- Push to `NotificationDetailScreen` via NavigationLink
Constraints: no numeric padding/frames; no custom colors/shadows/radii
Update COMPLIANCE docs (PR_DECLARATION, SCREEN_INDEX, TRACEABILITY).

## Add a Form-based screen
Implement `ProfileEditScreen.swift`:
- Outer container: FormShell(title: "Edit Profile")
- Fields: name, email, phone
- Save button: borderedProminent
- Deferred validation + inline errors (not color-only)
Update COMPLIANCE docs.

## Add a destructive flow
Add "Delete account" in Settings "Danger Zone":
- Confirmation via system alert with cancel + destructive roles
- No custom toast/snackbar
Update COMPLIANCE docs.
