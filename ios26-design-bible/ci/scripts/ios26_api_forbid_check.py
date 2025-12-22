\
#!/usr/bin/env python3
import os, re, sys, json

ROOT = os.environ.get("SRC_ROOT", ".")
CONFIG_PATH = os.environ.get("BIBLE_CHECK_CONFIG", os.path.join(ROOT, "ci", "bible_check_config.json"))

DEFAULT_CONFIG = {
    "ignore_paths": [],
    "allow_forbidden_patterns_paths": [],
    "forbidden_swiftui_patterns": [],
    "forbidden_uikit_patterns": []
}

def load_config():
    cfg = DEFAULT_CONFIG.copy()
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            user = json.load(f)
        cfg.update(user or {})
    except Exception:
        pass
    return cfg

CFG = load_config()

EXTS = {".swift", ".m", ".mm", ".h"}

def is_ignored(rel):
    norm = rel.replace("\\", "/")
    return any(norm.startswith(p) or f"/{p}" in norm for p in CFG.get("ignore_paths", []))

def is_allowed(rel):
    norm = rel.replace("\\", "/")
    return any(norm.startswith(p) or f"/{p}" in norm for p in CFG.get("allow_forbidden_patterns_paths", []))

def iter_files():
    for dirpath, _, filenames in os.walk(ROOT):
        for fn in filenames:
            _, ext = os.path.splitext(fn)
            if ext in EXTS:
                full = os.path.join(dirpath, fn)
                rel = os.path.relpath(full, ROOT)
                if not is_ignored(rel):
                    yield full, rel

def compile_patterns(patterns):
    compiled = []
    for p in patterns:
        try:
            compiled.append((p, re.compile(p)))
        except re.error:
            # Skip invalid regex patterns rather than failing the build
            pass
    return compiled

SWIFTUI = compile_patterns(CFG.get("forbidden_swiftui_patterns", []))
UIKIT = compile_patterns(CFG.get("forbidden_uikit_patterns", []))

def main():
    violations = []
    for full, rel in iter_files():
        if is_allowed(rel):
            continue
        try:
            with open(full, "r", encoding="utf-8") as f:
                content = f.read()
        except Exception:
            continue

        if rel.endswith(".swift"):
            for raw, rx in SWIFTUI:
                if rx.search(content):
                    violations.append((f"Forbidden SwiftUI pattern: {raw}", rel))
        else:
            for raw, rx in UIKIT:
                if rx.search(content):
                    violations.append((f"Forbidden UIKit pattern: {raw}", rel))

    if violations:
        print("iOS 26 Bible Forbidden-API Check: FAILED")
        for name, rel in violations:
            print(f"- {name}: {rel}")
        print("\nIf this is a legitimate exception, add the file path prefix to allow_forbidden_patterns_paths in ci/bible_check_config.json (prefer Tests/ only).")
        sys.exit(1)

    print("iOS 26 Bible Forbidden-API Check: PASSED")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
