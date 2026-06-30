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
Scripts/validate-diagnostics-boundaries.sh
Scripts/validate-quicklook-preview-contract.sh
Scripts/validate-thumbnail-boundaries.sh
xcodebuild -project MarkLook.xcodeproj -scheme MarkLook -configuration Debug -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO test
xcodebuild -project MarkLook.xcodeproj -scheme MarkLook -configuration Debug -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
Scripts/validate-built-bundle.sh .build/DerivedData/Build/Products/Debug/MarkLook.app
```

Expected:

- MarkLook.app builds.
- Preview and Thumbnail app extensions are embedded in `Contents/PlugIns`.
- MarkLookApp diagnostics tests, MarkdownCore renderer tests, Preview extension contract tests, and Thumbnail extension metadata/renderer tests pass.
- Bundle metadata validates.
- The diagnostics app boundary script confirms the host app stays local, diagnostic-only, editor-free, and network-free.
- The preview extension contract is data-based: `QLIsDataBasedPreview=true`, `PreviewViewController` uses `providePreview`, and PreviewExtension does not import WebKit or instantiate `WKWebView`.
- The thumbnail extension contract is bounded: no WebKit, no MarkdownCore full render, and no unbounded full-file reads in ThumbnailExtension.

## Unsigned CI limitation

`CODE_SIGNING_ALLOWED=NO` proves build, embedding, renderer tests, and preview policy tests.
It does not prove Finder Space-key behavior or PlugInKit provider selection.

Unsigned or ad-hoc debug bundles may be rejected by AppleSystemPolicy, and PlugInKit may ignore their extensions. Do not close Quick Look acceptance issues from CI-only evidence.

## Signed local Quick Look validation

Use a host-accepted signed build.

### Local development validation with ordinary Apple ID / Personal Team

Use this path for local signed runtime validation before public release packaging exists.

1. Open Xcode -> Settings -> Accounts and add the owner's Apple ID.
2. Use Manage Certificates to create an Apple Development certificate.
3. Run:

```bash
Scripts/doctor-signing.sh
security find-identity -p codesigning -v
DEVELOPMENT_TEAM=<TEAM_ID> Scripts/build-local-apple-development.sh
Scripts/validate-signed-quicklook.sh --development --noninteractive .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
```

Expected signing facts:

- Signature is not ad-hoc.
- TeamIdentifier is set.
- `--development` prints the public-distribution warning.
- `--noninteractive` skips `qlmanage -p` and remains safe for unattended signed smoke.
- Public distribution still requires Developer ID Application, hardened runtime, notarization, and stapling.

For interactive preview-window validation, run:

```bash
Scripts/validate-signed-quicklook.sh --development --interactive-preview .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
```

Close each `qlmanage -p` preview window manually so the script can continue.

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

- MarkLook.app opens to the diagnostics dashboard.
- The Status section states that Preview and Thumbnail are implemented and keeps public release as future Developer ID/notarization/stapling work.
- Preview and Thumbnail registration status are visible.
- Supported content types and file extensions are visible.
- Selecting `Samples/basic.md` shows `kMDItemContentType`, a content type tree when `mdls` returns one, and a supported yes/no verdict.
- Copy Report copies a report that uses the selected basename and redacts full local paths by default.
- Reset Quick Look Cache either succeeds or shows copyable manual commands and command output.
- Manual enable instructions show `System Settings -> General -> Login Items & Extensions -> Quick Look`.
- No editor UI appears.
- `basic.md` renders as formatted Markdown, not raw text.
- `gfm-table-task-list.md` renders tables and disabled task checkboxes.
- `long-ai-review.md` opens without a blank white view.
- `unsafe-html.md` shows escaped/safe text; scripts do not execute.
- Remote images show blocked placeholders.
- Markdown links are sanitized so they do not navigate or load remote resources.
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

The host app exposes the same registration evidence. It should interpret a missing provider-family listing plus a present exact bundle-id lookup as an incomplete provider-family listing, not as proof that the extension is absent.

## Thumbnail checks

```bash
Scripts/validate-thumbnail-boundaries.sh
qlmanage -r cache
qlmanage -t -s 512 -o /tmp Samples/basic.md
open /tmp/basic.md.png || true
```

Expected:

- Thumbnail provider draws a Markdown identity thumbnail when selected.
- The thumbnail shows an MD badge, the first H1/H2 heading when available, the file extension, and an approximate line count.
- If macOS selects the system raw-text thumbnail, record PlugInKit/signing status.
- Large files do not trigger full rendering or unbounded file reads.

## Reset Quick Look

```bash
qlmanage -r
qlmanage -r cache
killall Finder || true
```

The diagnostics dashboard runs these commands in order without invoking a shell and shows each command's exit status, stdout, and stderr. If process launch is blocked, copy and run the manual commands from Terminal.
