# MarkLook

Fast, stable, minimal macOS Quick Look Markdown preview for AI/developer long docs.

## What it does

- Provides a buildable macOS app with Quick Look preview and thumbnail extensions.
- Provides a local MarkdownCore renderer for the v0.1 Markdown subset.
- Renders Markdown previews through the local Preview extension.
- Targets `.md` files and long AI/Codex review documents.
- Keeps rendering local.
- No telemetry.
- No network during preview rendering.

## What it is not

- Not a Markdown editor.
- Not a notes app.
- Not a knowledge base.
- Not an Electron app.
- Not a deprecated `.qlgenerator`.

## Current status

The app and Quick Look extensions build. MarkdownCore provides a local safe HTML renderer for the v0.1 Markdown subset, and the Preview extension renders UTF-8 Markdown through a non-persistent WebKit view with navigation blocked. Signed PlugInKit registration remains tracked in Issue #11.

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
