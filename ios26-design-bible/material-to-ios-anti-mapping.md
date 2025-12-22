# Material → iOS 26 Anti-Mapping Appendix
*(What NOT to port, and the compliant iOS alternative)*

Purpose: prevent cross-platform leakage. Many “Material-isms” are actively non-native on iOS and can trigger review or UX failures.

## 1) Elevation / Shadows as hierarchy
- Material pattern: elevation levels, shadow-based surfaces
- iOS 26 reality: hierarchy is semantic + spatial + system materials
- DO:
  - Use system sheets, navigation stacks, grouped lists
  - Use system materials (where applicable)
- DO NOT:
  - Invent elevation tokens or shadow ramps

## 2) Outlined/Filled Text Fields as brand expression
- Material pattern: outlined/filled text fields, persistent borders and helper rows
- iOS 26 reality: lightweight fields, often list/form-based; labels must be clear
- DO:
  - Use Form/List + TextField with correct keyboard/content types
  - Use deferred validation
- DO NOT:
  - Add custom outlines or helper/label behaviors that mimic Material

## 3) Snackbars as primary feedback
- Material pattern: snackbars for errors and confirmations
- iOS 26 reality: avoid toast spam; use inline feedback, state change, or system alerts when critical
- DO:
  - Inline errors near fields
  - Use alerts only for critical decisions
- DO NOT:
  - Use snackbar-like toasts as default error UX

## 4) Bottom navigation vs Tab Bar
- Material pattern: bottom navigation as a primary IA hub with dynamic badges/actions
- iOS 26 reality: Tab Bar is for peer top-level destinations; state per tab
- DO:
  - Use TabView/UITabBarController, stable ordering
- DO NOT:
  - Dynamically reorder tabs or hide labels

## 5) Custom app bars
- Material pattern: heavily customized top app bar
- iOS 26 reality: system navigation bar rules + large/inline titles
- DO:
  - Use NavigationStack + toolbar placements
- DO NOT:
  - Reimplement nav chrome or back behavior

## 6) Global tokens and fixed spacing scales
- Material pattern: tokenized 4/8 dp spacing
- iOS 26 reality: system determines spacing per context; avoid numeric inference
- DO:
  - Use default spacing and `.padding()` without numbers
- DO NOT:
  - Create a dp scale in iOS

## 7) FAB as a primary pattern
- Material pattern: floating action button as primary action
- iOS 26 reality: primary actions live in nav bar, toolbar, or prominent button in content
- DO:
  - Place primary actions in toolbar or as prominent button in layout
- DO NOT:
  - Add FABs unless Apple pattern explicitly applies (rare and context-specific)

## 8) “Design parity” as a goal
- Material pattern: maximize parity across platforms
- iOS 26 reality: native behavior is the goal
- DO:
  - Share IA and data models, not UI mechanics
- DO NOT:
  - Port interaction metaphors
