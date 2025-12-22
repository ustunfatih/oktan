# iOS 26 Design Bible Compliance Roadmap

## Goal
Ensure the Oktan codebase fully complies with the iOS 26 Design Bible rules, including documentation, accessibility evidence, and CI enforcement.

## Phase 1 — Baseline Compliance (Completed)
- [x] Remove numeric inference (fixed frames, explicit spacing/radii, custom gradients)
- [x] Replace custom chrome (tint overrides, rounded rectangles)
- [x] Replace non-system layouts (ScrollView+VStack forms)
- [x] Simplify splash and reports flows to system-first views
- [x] Add project-level Bible config at `ci/bible_check_config.json`

## Phase 2 — Documentation & Registry (Completed)
- [x] Add PR declaration template at `swiftui-starter-repo/COMPLIANCE/PR_DECLARATION.md`
- [x] Add screen registry at `swiftui-starter-repo/COMPLIANCE/SCREEN_INDEX.md`
- [x] Add traceability matrix at `swiftui-starter-repo/COMPLIANCE/TRACEABILITY_MATRIX.md`

## Phase 3 — Accessibility Evidence (Next)
- [ ] Run VoiceOver on core screens: Home, Tracking, Reports, Settings, Profile
- [ ] Verify Dynamic Type at largest size on each screen
- [ ] Verify Reduce Motion and Reduce Transparency behaviors
- [ ] Update `PR_DECLARATION.md` with evidence and notes

## Phase 4 — State & Lifecycle Integrity (Next)
- [ ] Confirm tab state persistence after background/foreground
- [ ] Verify modal restoration (FuelEntryForm, CarSelection, Paywall)
- [ ] Consider persisting navigation paths with SceneStorage where needed

## Phase 5 — CI & Enforcement Hardening (Optional)
- [ ] Promote component allowlist from warn → fail (after confirming primitives list)
- [ ] Add `Chart` and `ContentUnavailableView` to allowlist if enforcing
- [ ] Add CI job invoking scripts under `ios26-design-bible/ci/scripts`

## Phase 6 — Cleanup & Consistency (Optional)
- [ ] Align README to indicate active target and compliance process
- [ ] Migrate ScreenShells / *Screen.swift naming for stricter enforcement
- [ ] Validate widgets against Bible rules (if included in app review)
