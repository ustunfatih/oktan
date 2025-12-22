# GitHub Actions snippet (optional)

If your workflow includes SwiftLint, add a step like:

- name: SwiftLint
  run: |
    swiftlint lint --config lint/.swiftlint.yml
