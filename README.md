# MarkLook

Fast, stable, minimal macOS Quick Look Markdown preview for AI/developer long docs.

## What it does

- Provides a macOS app and Quick Look extension shell for Markdown preview work.
- Targets `.md` files and long AI/Codex review documents.
- Keeps all future rendering local.
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

CI-compatible build and embedding check:

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project MarkLook.xcodeproj -scheme MarkLook -configuration Debug -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
test -d .build/DerivedData/Build/Products/Debug/MarkLook.app
test -d .build/DerivedData/Build/Products/Debug/MarkLook.app/Contents/PlugIns/MarkLookPreview.appex
test -d .build/DerivedData/Build/Products/Debug/MarkLook.app/Contents/PlugIns/MarkLookThumbnail.appex
```

`CODE_SIGNING_ALLOWED=NO` is for build validation only. Local app launch and Quick Look registration require a signed build accepted by the host macOS security policy.

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
