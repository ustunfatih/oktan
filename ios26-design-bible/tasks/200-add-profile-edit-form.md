# Task 200 — Add Profile Edit Form

## Goal
Add an Edit Profile form that is system-native and accessible.

## Requirements
- Create `ProfileEditScreen.swift` using `FormShell(title: "Edit Profile")`.
- Fields:
  - Name (TextField)
  - Email (TextField, email keyboard, no autocap)
  - Phone (TextField, phone keyboard)
- Save button uses `.buttonStyle(.borderedProminent)`.
- Validation is deferred; inline error text appears when Save is tapped.
- Do not rely on color alone for errors.

## Compliance updates (Required)
- Update `SCREEN_INDEX.md`
- Update `TRACEABILITY_MATRIX.md`
- Update `PR_DECLARATION.md` with evidence sections

## Definition of Done
- CI passes
- Dynamic Type largest works
- VoiceOver announces error text
