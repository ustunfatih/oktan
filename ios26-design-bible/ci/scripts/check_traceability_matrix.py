#!/usr/bin/env python3
import os, re, sys, json

ROOT = os.environ.get("SRC_ROOT", ".")
CONFIG_PATH = os.environ.get("BIBLE_CHECK_CONFIG", os.path.join(ROOT, "ci", "bible_check_config.json"))
MATRIX_PATH = os.path.join(ROOT, "swiftui-starter-repo", "COMPLIANCE", "TRACEABILITY_MATRIX.md")

def load_config():
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}

CFG = load_config()
ALLOW = set((CFG.get("component_rules", {}) or {}).get("allowlist_swiftui_primitives", []))

def iter_screens():
    for dirpath, _, filenames in os.walk(ROOT):
        for fn in filenames:
            if fn.endswith("Screen.swift"):
                full = os.path.join(dirpath, fn)
                rel = os.path.relpath(full, ROOT).replace("\\", "/")
                if any(rel.startswith(p) for p in CFG.get("component_rules", {}).get("allowlist_exempt_paths", [])):
                    continue
                yield fn[:-6], rel  # NameScreen, path

def parse_matrix(text):
    blocks = {}
    parts = re.split(r"\\n(?=- Screen:\\s*)", "\\n" + text)
    for part in parts:
        m = re.search(r"- Screen:\\s*([A-Za-z0-9_]+)", part)
        if not m:
            continue
        name = m.group(1).strip()
        comps = []
        m2 = re.search(r"System components used:\\s*(.*?)\\n\\s*(?:UIKit/SwiftUI bridging:|Accessibility:|State:|Notes:|$)", part, flags=re.S)
        if m2:
            section = m2.group(1)
            for line in section.splitlines():
                line = line.strip()
                if line.startswith("- "):
                    comps.append(line[2:].strip())
        blocks[name] = comps
    return blocks

def main():
    if not os.path.exists(MATRIX_PATH):
        print("Traceability matrix check: FAILED")
        print(f"- Missing {os.path.relpath(MATRIX_PATH, ROOT)}")
        sys.exit(1)

    text = open(MATRIX_PATH, "r", encoding="utf-8").read()
    blocks = parse_matrix(text)

    missing = []
    invalid = []
    unknown_components = []

    for name, rel in iter_screens():
        if name not in blocks:
            missing.append(rel)
            continue
        comps = blocks[name]
        if not comps:
            invalid.append((name, rel, "No components listed under 'System components used'"))
            continue
        if ALLOW:
            bad = [c for c in comps if c not in ALLOW]
            if bad:
                unknown_components.append((name, rel, bad))

    if missing:
        print("Traceability matrix check: FAILED")
        print("- The following screens have no entry in TRACEABILITY_MATRIX.md:")
        for rel in missing:
            print(f"  - {rel}")
        sys.exit(1)

    if invalid:
        print("Traceability matrix check: FAILED")
        for name, rel, msg in invalid:
            print(f"- {name} ({rel}): {msg}")
        sys.exit(1)

    if unknown_components:
        print("Traceability matrix check: FAILED")
        print("- Screens list components not in allowlist. Update matrix OR allowlist intentionally.")
        for name, rel, bad in unknown_components:
            print(f"  - {name} ({rel}): {', '.join(bad)}")
        sys.exit(1)

    print("Traceability matrix check: PASSED")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
