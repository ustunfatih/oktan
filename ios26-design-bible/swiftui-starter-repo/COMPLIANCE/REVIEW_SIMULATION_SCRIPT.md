# App Store Review Simulation Script (Pre-Submission Gate)

Run this manually before release.

1) Navigation
- Swipe-to-go-back works everywhere
- Back button appears as expected
- Tab state preserved per tab

2) Lifecycle
- Navigate deep → background app → return
- Ensure state restores (tab + navigation + modal if active)

3) Accessibility
- Enable VoiceOver and traverse all screens
- Enable Largest Dynamic Type and verify no clipping/overlap

4) Motion/Transparency
- Enable Reduce Motion
- Enable Reduce Transparency
- Verify UI remains readable and usable

5) Destructive actions
- Trigger destructive action
- Ensure confirmation and role semantics
