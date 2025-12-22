\
#!/usr/bin/env python3
import os, re, sys, json

ROOT = os.environ.get("SRC_ROOT", ".")
CONFIG_PATH = os.environ.get("BIBLE_CHECK_CONFIG", os.path.join(ROOT, "ci", "bible_check_config.json"))

def load_config():
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}

CFG = load_config()
SCREEN_INDEX = os.path.join(ROOT, "swiftui-starter-repo", "COMPLIANCE", "SCREEN_INDEX.md")

def iter_swift():
    for dirpath, _, filenames in os.walk(ROOT):
        for fn in filenames:
            if fn.endswith("Screen.swift"):
                full = os.path.join(dirpath, fn)
                rel = os.path.relpath(full, ROOT).replace("\\", "/")
                # ignore tests/previews if configured
                if any(rel.startswith(p) for p in CFG.get("component_rules", {}).get("allowlist_exempt_paths", [])):
                    continue
                yield fn, rel

def main():
    if not os.path.exists(SCREEN_INDEX):
        print("Screen registry check: FAILED")
        print(f"- Missing {os.path.relpath(SCREEN_INDEX, ROOT)}")
        return 1

    index_text = open(SCREEN_INDEX, "r", encoding="utf-8").read()
    missing = []
    for fn, rel in iter_swift():
        name = fn[:-5]  # strip .swift
        if name not in index_text:
            missing.append(rel)

    if missing:
        print("Screen registry check: FAILED")
        print("- The following *Screen.swift files are not registered in SCREEN_INDEX.md:")
        for m in missing:
            print(f"  - {m}")
        sys.exit(1)

    print("Screen registry check: PASSED")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
