# AGENTS.md

## Scope

These instructions apply to the entire repository. A more deeply nested `AGENTS.md` may add or override rules for its subtree.

## Product contract

Mac Gadgets is a native SwiftUI macOS utility collection. Text and files must remain on the user's Mac unless a future feature explicitly states otherwise. Do not add analytics, telemetry, uploads, remote processing, or network dependencies as an incidental implementation detail.

The deployment target is macOS 14. The project is currently built with Swift 6.2 and the macOS 26 SDK, so newer APIs must retain an availability-gated fallback when the app still supports macOS 14.

## Repository map

- `Sources/MacGadgets/Features`: one SwiftUI screen per utility.
- `Sources/MacGadgets/Services`: testable file and data transformations; keep non-UI logic here.
- `Sources/MacGadgets/Shared`: reusable views, file panels, theme, and compatibility helpers.
- `Sources/MacGadgets/Models/ToolKind.swift`: sidebar metadata and pinyin sorting information.
- `Tests/MacGadgetsTests`: service, ordering, and file round-trip coverage.
- `Packaging`: bundle metadata and the 1024 x 1024 app-icon master.
- `scripts/build-app.sh`: reproducible local `.app` packaging and ad-hoc signing.
- `dist`: generated output. Never edit files inside it by hand.

## Implementation conventions

- Keep views focused on state, layout, and user interaction. Move reusable transformations and file operations into services.
- Reuse shared components such as `ToolHeader`, `ToolControlBar`, `EditorPane`, file-drop helpers, and the modifiers in `AppTheme.swift` before introducing parallel styles.
- Add new tools to `ToolKind` with a stable title, subtitle, SF Symbol, and pinyin sort key. Preserve pinyin grouping and search behavior.
- Use system controls, keyboard shortcuts, drag and drop, accessibility labels, and semantic colors where possible.
- Keep user-visible Chinese concise and consistent with the existing app. Do not expose raw implementation errors when a useful recovery message can be shown.
- Never silently overwrite an output file. Continue to use save panels or explicit user-selected destinations.
- Preserve unrelated working-tree changes. Do not commit or push unless the user asks.

## Branch workflow

- `master` is the canonical development and GitHub default branch.
- Keep `main` only as a compatibility branch unless the user explicitly asks to remove it. Do not create independent `main`-only work; synchronize it with `master` when both branches need to be published.
- Before changing the remote default branch or synchronizing branches, fetch the remote, inspect the commit graph, and verify that the intended merge does not discard remote-only commits.

## Visual system

- On macOS 26, use the native Liquid Glass APIs through `appGlassSurface` and `appPrimaryActionStyle`; do not imitate glass with custom blur stacks.
- Keep compatibility branches for older macOS versions and a solid-surface branch for Reduce Transparency.
- Reserve glass for navigation, search, action hierarchy, and compact controls. Editors, previews, tables, and other content-heavy surfaces remain solid for readability.
- Support system, light, and dark appearances. Check contrast and disabled, focused, selected, success, and error states after visual changes.
- The app-icon artwork source is `Packaging/AppIcon.png`. Keep it square, 1024 x 1024, centered, and readable at 32 px. Do not bake an outer rounded-rectangle frame into the artwork; `scripts/prepare-app-icon.swift` applies the legacy ICNS safe-area scale, continuous mask, transparent margin, and shadow during packaging.

## Build and verification

Run checks proportional to the change. The normal full verification sequence is:

```bash
git diff --check
swift test
./scripts/build-app.sh
codesign --verify --deep --strict "dist/Mac Gadgets.app"
```

For UI changes, also launch the packaged app and inspect at least light and dark appearance. For packaging or icon changes, verify `Contents/Info.plist`, the packaged resources, and the result shown by Finder rather than trusting source files alone.

`scripts/build-app.sh` prepares the icon artwork, creates all ten conventional macOS icon renditions, builds `AppIcon.icns`, embeds it, and applies an ad-hoc signature. Distribution still requires an Apple Developer identity and notarization.

## Proactive experience capture

Treat this file as a maintained project playbook, not a static setup note. After every non-trivial task, actively review what was learned and update this file during the same task when the insight is both verified and likely to help future work.

Capture:

- Project-specific invariants that are easy to violate.
- Root causes and durable fixes for recurring failures.
- Compatibility constraints and required fallbacks.
- Reliable verification commands or visual checks.
- Conventions that became clear only after inspecting or testing the code.

Do not capture:

- Chronological progress logs, one-off task details, or obvious facts visible from a single filename.
- Guesses that were not validated by code, tests, documentation, or direct UI inspection.
- Secrets, credentials, personal data, machine-specific absolute paths, or transient environment state.
- Duplicate rules. Merge new knowledge into the most relevant existing section.

When maintaining this file:

1. State the reusable rule and, when useful, the reason or verification method.
2. Reconcile contradictions instead of appending a competing instruction.
3. Update or remove stale guidance when the architecture changes.
4. Keep instructions compact and actionable; prune repetition as the file grows.
5. Mention material `AGENTS.md` updates in the final handoff.

## Current verified lessons

- Building against the macOS 26 SDK does not remove the macOS 14 deployment promise; all Liquid Glass references must remain inside `#available(macOS 26.0, *)` branches.
- A successful Swift build does not validate the final bundle. Icon inclusion, `Info.plist`, and code signing are verified only after running the packaging script.
- Finder can cache application presentation, so recreate the bundle at the same path and inspect the packaged `.app` after icon changes.
- A traditional flattened `.icns` in this manually packaged SwiftPM app does not receive the automatic mask used by an Icon Composer layered icon. Apply the safe-area scale and transparent continuous-corner mask before generating the iconset.
- Finder can observe a manually assembled bundle before its resources are complete and cache a generic icon. Touch the top-level `.app` after signing so a watched Finder window reloads the finished bundle.
- Small app icons punish detail. Always inspect the master at 128 px and 32 px before accepting a design.
- Content surfaces and translucent control surfaces have different jobs. Applying glass to editors or large result panes reduces legibility and weakens the interaction hierarchy.
