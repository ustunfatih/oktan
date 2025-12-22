#!/usr/bin/env python3
import os, re, sys, json

ROOT = os.environ.get("SRC_ROOT", ".")
CONFIG_PATH = os.environ.get("BIBLE_CHECK_CONFIG", os.path.join(ROOT, "ci", "bible_check_config.json"))

DEFAULT_CONFIG = {
    "ignore_paths": [],
    "allow_numeric_padding_paths": [],
    "require_pr_declaration": False,
    "pr_declaration_path": "",
    "required_declaration_phrases": []
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

# Patterns (conservative; false positives are acceptable for a Bible)
RULES = [
    ("SwiftUI numeric padding", re.compile(r"\.padding\(\s*\d")),
    ("SwiftUI fixed frame size", re.compile(r"\.frame\(.*(width\s*:\s*\d|height\s*:\s*\d)")),
    ("SwiftUI GeometryReader", re.compile(r"\bGeometryReader\b")),
    ("SwiftUI hex color", re.compile(r"Color\(\s*#|Color\(\s*\"#|#(?:[0-9a-fA-F]{3}){1,2}\b")),
    ("Custom spring params", re.compile(r"\.spring\(\s*response\s*:|\.interpolatingSpring\(|\.timingCurve\(")),
    ("UIKit frame layout", re.compile(r"\bview\.frame\s*=|\bCGRect\(")),
    ("UIKit disables pop gesture", re.compile(r"interactivePopGestureRecognizer\?\.isEnabled\s*=\s*false")),
]

EXTS = {".swift", ".m", ".mm", ".h"}

def is_ignored(path):
    norm = path.replace("\\", "/")
    return any(norm.startswith(p) or f"/{p}" in norm for p in CFG.get("ignore_paths", []))

def is_allowed_numeric_padding(path):
    norm = path.replace("\\", "/")
    return any(norm.startswith(p) or f"/{p}" in norm for p in CFG.get("allow_numeric_padding_paths", []))

def iter_files():
    for dirpath, _, filenames in os.walk(ROOT):
        for fn in filenames:
            _, ext = os.path.splitext(fn)
            if ext in EXTS:
                full = os.path.join(dirpath, fn)
                rel = os.path.relpath(full, ROOT)
                if not is_ignored(rel):
                    yield full, rel

def main():
    violations = []
    for full, rel in iter_files():
        try:
            with open(full, "r", encoding="utf-8") as f:
                content = f.read()
        except Exception:
            continue
        for name, rx in RULES:
            if name == "SwiftUI numeric padding" and is_allowed_numeric_padding(rel):
                continue
            if rx.search(content):
                violations.append((name, rel))
    if violations:
        print("iOS 26 Bible Compliance Check: FAILED")
        for name, rel in violations:
            print(f"- {name}: {rel}")
        sys.exit(1)
    print("iOS 26 Bible Compliance Check: PASSED")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
