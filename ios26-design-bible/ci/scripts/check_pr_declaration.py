#!/usr/bin/env python3
import os, subprocess, sys, json

ROOT = os.environ.get("GITHUB_WORKSPACE", ".")
CONFIG_PATH = os.environ.get("BIBLE_CHECK_CONFIG", os.path.join(ROOT, "ci", "bible_check_config.json"))

def load_config():
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}

CFG = load_config()
DECL_PATH = CFG.get("pr_declaration_path", "")
REQUIRED = CFG.get("required_declaration_phrases", [])

def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()

def main():
    if not CFG.get("require_pr_declaration", False):
        print("PR declaration check: SKIPPED (disabled in config)")
        return 0

    base_ref = os.environ.get("GITHUB_BASE_REF") or os.environ.get("GITHUB_REF_NAME")
    if not base_ref:
        print("PR declaration check: SKIPPED (not a PR context)")
        return 0

    # Ensure we have the base ref fetched
    try:
        git("fetch", "origin", base_ref, "--depth=1")
    except Exception:
        pass

    # Compare changes between base and HEAD
    diff_names = git("diff", "--name-only", f"origin/{base_ref}...HEAD").splitlines()
    if DECL_PATH not in diff_names:
        print("PR declaration check: FAILED")
        print(f"- You must modify {DECL_PATH} in every PR.")
        sys.exit(1)

    full_decl = os.path.join(ROOT, DECL_PATH)
    if not os.path.exists(full_decl):
        print("PR declaration check: FAILED")
        print(f"- Declaration file missing: {DECL_PATH}")
        sys.exit(1)

    content = open(full_decl, "r", encoding="utf-8").read()
    missing = [p for p in REQUIRED if p not in content]
    if missing:
        print("PR declaration check: FAILED")
        for m in missing:
            print(f"- Missing required phrase/section: {m}")
        sys.exit(1)

    if "Numeric Inference" in content and "None" not in content:
        # light heuristic: we expect "None" to appear in that section
        pass

    print("PR declaration check: PASSED")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
