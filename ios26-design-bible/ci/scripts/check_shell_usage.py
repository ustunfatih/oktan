\
#!/usr/bin/env python3
import os, re, sys

ROOT = os.environ.get("SRC_ROOT", ".")

SHELLS = ["ListShell(", "DetailShell(", "FormShell(", "SearchShell("]

def iter_screen_files():
    for dirpath, _, filenames in os.walk(ROOT):
        for fn in filenames:
            if fn.endswith("Screen.swift"):
                full = os.path.join(dirpath, fn)
                rel = os.path.relpath(full, ROOT).replace("\\", "/")
                yield full, rel

def main():
    missing = []
    for full, rel in iter_screen_files():
        try:
            text = open(full, "r", encoding="utf-8").read()
        except Exception:
            continue
        # allow screen to be a wrapper that returns another view (still should use shells)
        if not any(s in text for s in SHELLS):
            missing.append(rel)

    if missing:
        print("Shell enforcement: FAILED")
        print("- Screens must compose an approved Shell as outer container: ListShell/DetailShell/FormShell/SearchShell")
        for m in missing:
            print(f"  - {m}")
        sys.exit(1)

    print("Shell enforcement: PASSED")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
