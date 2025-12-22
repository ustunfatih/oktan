# iOS 26 Design Bible — Constitution
Version: 1.0
Date: 2025-12-22

## Preamble
This repository exists to produce iOS-native interfaces that are accessible, resilient, and resistant to drift.
Humans and AI agents must obey the same rules.

## Article I — Supremacy
1) Apple runtime behavior is supreme.
2) Apple documentation/HIG is authoritative when runtime details are unclear.
3) This Bible governs implementation only where it does not conflict with (1) or (2).

## Article II — No Numeric Inference
No contributor may invent numeric values for spacing, radii, sizing, or animation curves.
If a number is unavoidable due to an Apple API, it must be minimized and justified in the PR declaration.

## Article III — No Custom Chrome
Navigation and tab chrome must remain system.
Appearance proxies and bespoke nav bars are forbidden.

## Article IV — Control Authenticity
Controls must be real:
- No fake buttons via gestures
- No fake forms via ScrollView+VStack
- No custom list separators

## Article V — Accessibility
Every change must remain usable under:
- VoiceOver
- Largest Dynamic Type
- Reduce Motion
- Reduce Transparency
Evidence is required in the PR declaration.

## Article VI — Lifecycle Integrity
State and navigation must be coherent across background/foreground and restoration scenarios.

## Article VII — Documentation as Law
- Every screen must be registered in COMPLIANCE/SCREEN_INDEX.md
- Every screen must declare components in COMPLIANCE/TRACEABILITY_MATRIX.md
- Every PR must modify COMPLIANCE/PR_DECLARATION.md

## Article VIII — Enforcement
CI scripts are the constitutional court. If CI fails, the change is rejected.

## Article IX — Amendments
Any amendment must reduce ambiguity and ideally add enforcement or documentation updates.
