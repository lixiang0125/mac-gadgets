# Mac Gadgets

[中文](README.md) | [English](README.en.md)

A native SwiftUI utility suite for macOS with Chinese and English interfaces. All text and files are processed locally and are never uploaded.

## Download the Latest Version

<!-- release-download:start -->
[Download Mac Gadgets v0.2.1 DMG](release/Mac-Gadgets-0.2.1.dmg)
<!-- release-download:end -->

See [CHANGELOG.md](CHANGELOG.md) for version history.

Open the DMG and drag `Mac Gadgets.app` into the Applications folder to install it.

## Included Tools

- Clipboard History: automatically keeps the latest 100 text items while the app is running, moves duplicates to the top, and supports button or double-click copying.
- Chinese Script Conversion: converts text directly and supports opening and saving TXT files.
- Merge PDF Files: add PDFs in batches, arrange their order, and merge them.
- Images and PDF: create a PDF from ordered images or export every PDF page as a PNG.
- Stitch Images: scale proportionally to the widest image for vertical stitching or the tallest image for horizontal stitching, with adjustable ordering; the list and preview use a 3:7 layout, previews fit the window with zoom controls, and clicking a thumbnail opens the source image in a preview dialog.
- Format JSON: validate, indent, and optionally sort keys in the same editor, with line numbers, nested object/array folding, and Fold All / Unfold All. Copying and saving preserve the full content; editing automatically unfolds it.
- Compare JSON: format and align two JSON documents, highlighting added, removed, and changed lines.

The sidebar sorts tools by the pinyin of their Chinese names and groups them by initial. Search supports Chinese, English descriptions, and pinyin.

## Interaction and Design

- A consistent native SwiftUI hierarchy that adapts to light and dark appearances, with a manual appearance control at the bottom of the sidebar.
- Every tool has a top-right switch for changing instantly between Chinese and English; the selection is stored locally.
- While running, the app keeps an icon in the menu bar; choose any tool there to reveal the main window and open that tool directly.
- Native Liquid Glass action bars, search, and primary buttons on macOS 26. Older systems and Reduce Transparency mode fall back to clear system materials or solid surfaces.
- The blue glass `MG` monogram icon receives transparent safe-area padding and continuous corners during packaging, with a complete set of macOS icon sizes.
- PDF and image lists support file drop, row dragging, and button-assisted ordering.
- Text editors show live line and character counts, while success and error feedback stays within the active tool.
- Common keyboard shortcuts include `Command-O` to open, `Command-S` to save, and `Command-Return` to convert or compare.
- All files and text stay on the local Mac.

## Requirements

- macOS 14 or later
- Xcode 26 or later (verified with Swift 6.2 and the macOS 26 SDK)

## Run for Development

```bash
swift run MacGadgets
```

You can also open the root `Package.swift` in Xcode and run the `MacGadgets` scheme.

## Tests

```bash
swift test
```

Tests are organized directly under `Tests`, one suite per tool, and cover normal behavior, boundaries, failures, file round trips, and SwiftUI layout for every tool. During development, run the related suite when possible:

```bash
swift test --filter ClipboardHistoryTests
swift test --filter JSONServiceTests
swift test --filter JSONFoldingTests
swift test --filter PDFServiceTests
```

Run the complete `swift test` suite before committing. File-based tests use unique temporary directories, while clipboard tests use a dedicated pasteboard and temporary storage URL, so they never read or modify real clipboard history.

## Localization

All interface copy is maintained by key in the root `locale/zh-CN.json` and `locale/en.json` files. Add or update keys in both files; `LocalizationTests` verifies that both languages have identical key sets and that their views load correctly.

## Build a Double-Clickable App

```bash
./scripts/build-app.sh
open "dist/Mac Gadgets.app"
```

The script creates an ad-hoc signed `dist/Mac Gadgets.app`. Distribution still requires an Apple Developer signature and notarization.

## Build the Latest DMG

```bash
./scripts/build-release.sh
```

For every release, first update the version and build number in `Packaging/Info.plist`, then add the matching version, date, and changes at the top of `CHANGELOG.md`.

The script reads the version from `Packaging/Info.plist`, creates `release/Mac-Gadgets-<version>.dmg`, verifies the signature and DMG, and automatically updates the latest download link in both READMEs. Packaging stops if the matching changelog entry is missing. Do not edit the download marker blocks manually or overwrite installers for other versions.

To update or validate release documentation separately, run:

```bash
swift scripts/update-release-docs.swift --write
swift scripts/update-release-docs.swift --check
```
