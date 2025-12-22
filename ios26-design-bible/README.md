# iOS 26 Design Bible (Full Package)

This is the **canonical, consolidated** iOS 26 design enforcement package:
- `swiftui-starter-repo/` — SwiftUI scaffolding + compliance docs
- `ci/` — hard gates that fail non-compliant changes
- `ai-prompt-pack/` — agent prompts per component
- `agent-run/` — system prompt + runner templates for Codex / Claude Code
- `lint/` — optional SwiftLint rules
- `tests/` — optional XCUITest templates

Start here:
1) Read `README_CONSTITUTION.md`
2) Give your agent `agent-run/SYSTEM_PROMPT.md`
3) Make changes
4) Update compliance docs
5) Ensure CI passes


Team workflow:
- Create tasks in `tasks/` and run agents against a single task file.
