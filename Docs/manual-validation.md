# Manual validation

## Environment

- macOS version:
- Mac model:
- Xcode version:
- Git commit:
- Signing identity:

## CI-compatible build and test

```bash
xcodegen generate
Scripts/validate-quicklook-preview-contract.sh
xcodebuild -project MarkLook.xcodeproj -scheme MarkLook -configuration Debug -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO test
xcodebuild -project MarkLook.xcodeproj -scheme MarkLook -configuration Debug -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
Scripts/validate-built-bundle.sh .build/DerivedData/Build/Products/Debug/MarkLook.app
```

Expected:

- MarkLook.app builds.
- Preview and Thumbnail app extensions are embedded in `Contents/PlugIns`.
- MarkdownCore renderer tests and Preview extension policy tests pass.
- Bundle metadata validates.
- The preview extension contract is view-based: `QLIsDataBasedPreview` is absent or false, and `PreviewViewController` uses `preparePreviewOfFile`.

## Unsigned CI limitation

`CODE_SIGNING_ALLOWED=NO` proves build, embedding, renderer tests, and preview policy tests.
It does not prove Finder Space-key behavior or PlugInKit provider selection.

Unsigned or ad-hoc debug bundles may be rejected by AppleSystemPolicy, and PlugInKit may ignore their extensions. Do not close Quick Look acceptance issues from CI-only evidence.

## Signed local Quick Look validation

Use a host-accepted signed build.

### Local development validation with ordinary Apple ID / Personal Team

Use this path for local Issue #11 validation before public release packaging exists.

1. Open Xcode -> Settings -> Accounts and add the owner's Apple ID.
2. Use Manage Certificates to create an Apple Development certificate.
3. Run:

```bash
Scripts/doctor-signing.sh
security find-identity -p codesigning -v
DEVELOPMENT_TEAM=<TEAM_ID> Scripts/build-local-apple-development.sh
Scripts/validate-signed-quicklook.sh --development .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
```

Expected signing facts:

- Signature is not ad-hoc.
- TeamIdentifier is set.
- `--development` prints the public-distribution warning.
- Public distribution still requires Developer ID Application, hardened runtime, notarization, and stapling.

### Manual commands

```bash
security find-identity -p codesigning -v
xcodebuild -project MarkLook.xcodeproj -scheme MarkLook -configuration Debug -derivedDataPath .build/LocalDerivedData build
codesign --verify --deep --strict --verbose=4 .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
spctl --assess --type execute --verbose=4 .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
open .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
qlmanage -r
qlmanage -r cache
killall Finder || true
pluginkit -mAv -p com.apple.quicklook.preview | grep -i MarkLook
pluginkit -mAv -i com.91wan.MarkLook.Preview
pluginkit -mAv -p com.apple.quicklook.thumbnail | grep -i MarkLook
pluginkit -mAv -i com.91wan.MarkLook.Thumbnail
mdls -name kMDItemContentType Samples/basic.md
qlmanage -p Samples/basic.md
qlmanage -p Samples/gfm-table-task-list.md
qlmanage -p Samples/long-ai-review.md
qlmanage -p Samples/unsafe-html.md
qlmanage -p Samples/large-fast-mode.md
```

Expected signed-local results:

- `basic.md` renders as formatted Markdown, not raw text.
- `gfm-table-task-list.md` renders tables and disabled task checkboxes.
- `long-ai-review.md` opens without a blank white view.
- `unsafe-html.md` shows escaped/safe text; scripts do not execute.
- Remote images show blocked placeholders.
- Markdown links are visually inert and do not navigate.
- `large-fast-mode.md` shows the fast mode warning and does not hang Finder.
- If macOS selects the system raw-text provider, record PlugInKit/signing status and keep Issue #4 open.

## Diagnose provider selection

```bash
Scripts/doctor-signing.sh
security find-identity -p codesigning -v
spctl --assess --type execute --verbose=4 .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
codesign --verify --deep --strict --verbose=4 .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
pluginkit -mAv -p com.apple.quicklook.preview | grep -i MarkLook
pluginkit -mAv -i com.91wan.MarkLook.Preview
pluginkit -mAv -p com.apple.quicklook.thumbnail | grep -i MarkLook
pluginkit -mAv -i com.91wan.MarkLook.Thumbnail
mdls -name kMDItemContentType Samples/basic.md
```

Record exact output when MarkLook is not selected. Prefer exact bundle-id lookup as fallback evidence for the thumbnail extension because provider-family listing can be incomplete on some macOS versions. Do not treat Finder behavior as product behavior until macOS accepts the signed app and extensions.

## Thumbnail checks

```bash
qlmanage -r cache
qlmanage -t -s 512 -o /tmp Samples/basic.md
open /tmp/basic.md.png || true
```

Expected:

- Thumbnail provider draws a static Markdown identity thumbnail when selected.
- If macOS selects the system raw-text thumbnail, record PlugInKit/signing status.
- Large files do not trigger full rendering.

## Reset Quick Look

```bash
qlmanage -r
qlmanage -r cache
killall Finder || true
```
