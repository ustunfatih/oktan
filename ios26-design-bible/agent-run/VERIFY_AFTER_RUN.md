# Verify After Agent Run (Non-negotiable)

Run CI scripts:
- ci/scripts/ios26_bible_check.py
- ci/scripts/ios26_api_forbid_check.py
- ci/scripts/ios26_component_allowlist_check.py
- ci/scripts/check_screen_registry.py
- ci/scripts/check_shell_usage.py
- ci/scripts/check_traceability_matrix.py

Manual checks (Layer 5):
- Swipe-to-go-back everywhere
- Dynamic Type (largest): no clipping
- VoiceOver traversal: labels correct
- Reduce Motion/Transparency: usable

Docs updated:
- PR_DECLARATION.md (must change every PR)
- SCREEN_INDEX.md (if screens changed)
- TRACEABILITY_MATRIX.md (if screens changed)
