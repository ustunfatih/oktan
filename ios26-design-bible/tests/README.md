# Golden-Path UI Tests (XCUITest Skeleton)

Goal: automate parts of Layer 5 (review simulation) in UI tests.

This folder provides a **template** you can copy into an Xcode test target.

## What to automate
- Launch and tab switching
- Navigate list -> detail
- Background/foreground (limited in XCUITest)
- Basic accessibility existence checks (labels present)
- Dynamic Type (best tested via manual + snapshots; automation varies)

## Note
XCUITest cannot fully validate "native feel", but it can prevent regressions.
