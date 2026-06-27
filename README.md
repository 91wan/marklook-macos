# MarkLook

Fast, stable, minimal macOS Quick Look Markdown preview for AI/developer long docs.

## What it does

- Renders `.md` files in Finder Quick Look.
- Handles long AI/Codex review documents.
- Supports GFM basics: headings, lists, task lists, tables, fenced code blocks.
- Runs locally.
- No telemetry.
- No network during preview rendering.

## What it is not

- Not a Markdown editor.
- Not a notes app.
- Not a knowledge base.
- Not an Electron app.
- Not a deprecated `.qlgenerator`.

## Current status

The app and Quick Look extension shells build. Markdown rendering is not implemented yet.

## Build

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project MarkLook.xcodeproj -scheme MarkLook -configuration Debug -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
open .build/DerivedData/Build/Products/Debug/MarkLook.app
```

## Refresh Quick Look

```bash
qlmanage -r
qlmanage -r cache
killall Finder || true
```

## Diagnose a file

```bash
mdls -name kMDItemContentType path/to/file.md
pluginkit -mAv -p com.apple.quicklook.preview | grep -i MarkLook
```

## Privacy

MarkLook renders documents locally. It does not upload documents, collect analytics, or contact remote servers during preview rendering.
