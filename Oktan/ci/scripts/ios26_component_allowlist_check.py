\
#!/usr/bin/env python3
import os, re, sys, json
from collections import defaultdict

ROOT = os.environ.get("SRC_ROOT", ".")
CONFIG_PATH = os.environ.get("BIBLE_CHECK_CONFIG", os.path.join(ROOT, "ci", "bible_check_config.json"))

DEFAULT = {
    "ignore_paths": [],
    "component_rules": {
        "forbid_scrollview_vstack_forms": True,
        "forbid_custom_list_separators": True,
        "forbid_gesture_buttons": True,
        "allowlist_swiftui_primitives": [],
        "allowlist_enforcement_mode": "warn",
        "allowlist_exempt_paths": []
    }
}

def load_config():
    cfg = DEFAULT.copy()
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            user = json.load(f)
        cfg.update(user or {})
        # deep merge component_rules
        cr = DEFAULT["component_rules"].copy()
        cr.update((user or {}).get("component_rules", {}) if isinstance(user, dict) else {})
        cfg["component_rules"] = cr
    except Exception:
        pass
    return cfg

CFG = load_config()
CR = CFG["component_rules"]

EXTS = {".swift"}

def norm(p): return p.replace("\\", "/")

def is_ignored(rel):
    r = norm(rel)
    return any(r.startswith(p) or f"/{p}" in r for p in CFG.get("ignore_paths", []))

def is_exempt(rel):
    r = norm(rel)
    return any(r.startswith(p) or f"/{p}" in r for p in CR.get("allowlist_exempt_paths", []))

def iter_swift():
    for dirpath, _, filenames in os.walk(ROOT):
        for fn in filenames:
            if os.path.splitext(fn)[1] in EXTS:
                full = os.path.join(dirpath, fn)
                rel = os.path.relpath(full, ROOT)
                if not is_ignored(rel):
                    yield full, rel

# Heuristic patterns
RX_SCROLLVIEW = re.compile(r"\bScrollView\b")
RX_VSTACK = re.compile(r"\bVStack\b")
RX_FORM = re.compile(r"\bForm\s*\{")
RX_LIST = re.compile(r"\bList\s*\{")
RX_DIVIDER = re.compile(r"\bDivider\s*\(")
RX_ON_TAP = re.compile(r"\.onTapGesture\b")
RX_BUTTON = re.compile(r"\bButton\s*\(")

# Extract SwiftUI type identifiers (very rough; sufficient for CI guardrails)
RX_TYPE = re.compile(r"\b([A-Z][A-Za-z0-9_]*)\b")

def main():
    allow = set(CR.get("allowlist_swiftui_primitives", []))
    mode = (CR.get("allowlist_enforcement_mode") or "warn").lower()

    findings = []
    allowlist_hits = defaultdict(set)

    for full, rel in iter_swift():
        if is_exempt(rel):
            continue
        try:
            text = open(full, "r", encoding="utf-8").read()
        except Exception:
            continue

        # Rule: forbid ScrollView + VStack used as forms (heuristic)
        if CR.get("forbid_scrollview_vstack_forms", True):
            # If file contains ScrollView + VStack and also contains TextField/SecureField/Toggle, flag it
            if RX_SCROLLVIEW.search(text) and RX_VSTACK.search(text) and re.search(r"\b(TextField|SecureField|Toggle|DatePicker|Picker)\b", text):
                # But if it also contains Form or List, it's probably fine
                if not (RX_FORM.search(text) or RX_LIST.search(text)):
                    findings.append(("Forbidden form layout: ScrollView+VStack used with form controls (use Form/List)", rel))

        # Rule: forbid custom list separators (Divider in list-ish contexts)
        if CR.get("forbid_custom_list_separators", True):
            if RX_DIVIDER.search(text) and RX_LIST.search(text):
                findings.append(("Forbidden custom separators: Divider inside List (use system separators)", rel))

        # Rule: forbid gesture-based buttons (onTapGesture without Button)
        if CR.get("forbid_gesture_buttons", True):
            if RX_ON_TAP.search(text) and not RX_BUTTON.search(text):
                findings.append(("Forbidden gesture-button: onTapGesture used without Button (use Button)", rel))

        # Allowlist: report unexpected primitives/types (warn by default)
        if allow:
            # Collect types that look like SwiftUI primitives by being capitalized and common
            types = set(RX_TYPE.findall(text))
            # Focus on known SwiftUI-ish names by intersecting allowlist complement in a small heuristic set
            suspects = sorted([t for t in types if t in {
                "ScrollView","LazyVStack","LazyHStack","HStack","VStack","ZStack",
                "GeometryReader","Spacer","Divider","Rectangle","RoundedRectangle",
                "Canvas","TimelineView","UIViewRepresentable","NSViewRepresentable"
            } and t not in allow])
            if suspects:
                allowlist_hits[rel].update(suspects)

    # Print allowlist warnings
    if allowlist_hits:
        print("iOS 26 Bible Component Allowlist: WARNINGS")
        for rel, items in allowlist_hits.items():
            print(f"- {rel}: unexpected primitives -> {', '.join(sorted(items))}")
        if mode == "fail":
            print("\nAllowlist enforcement mode is FAIL. Update component_rules.allowlist_swiftui_primitives or exempt paths if truly needed.")
            sys.exit(1)

    # Print hard rule findings
    if findings:
        print("iOS 26 Bible Component Rules: FAILED")
        for msg, rel in findings:
            print(f"- {msg}: {rel}")
        sys.exit(1)

    if not allowlist_hits:
        print("iOS 26 Bible Component Allowlist: PASSED")
    else:
        print("iOS 26 Bible Component Allowlist: PASSED with warnings")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
