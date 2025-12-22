# Task 300 — Add Delete Account Flow

## Goal
Add a destructive action using system patterns only.

## Requirements
- Add a "Danger Zone" section in `SettingsScreen`.
- Add "Delete Account" row or button.
- Confirmation uses a system Alert with:
  - Cancel role
  - Destructive role
- No custom toast/snackbar.
- No custom sheet chrome.

## Compliance updates (Required)
- Update `PR_DECLARATION.md`
- Update traceability if components/screens changed

## Definition of Done
- CI passes
- Alert is system-native
- VoiceOver reads the destructive nature clearly
