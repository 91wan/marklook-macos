# Manual validation

## Environment

- macOS version:
- Mac model:
- Xcode version:
- Git commit:

## Build products

```bash
xcodegen generate
xcodebuild -project MarkLook.xcodeproj -scheme MarkLook -configuration Debug -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
test -d .build/DerivedData/Build/Products/Debug/MarkLook.app
test -d .build/DerivedData/Build/Products/Debug/MarkLook.app/Contents/PlugIns/MarkLookPreview.appex
test -d .build/DerivedData/Build/Products/Debug/MarkLook.app/Contents/PlugIns/MarkLookThumbnail.appex
```

Expected for Issue #2:

- MarkLook.app builds.
- Preview and Thumbnail app extensions are embedded in `Contents/PlugIns`.
- Preview shell is local placeholder UI only.
- Thumbnail shell compiles and can provide a static Markdown identity thumbnail when the provider is registered.
- Rendered Markdown preview is not implemented yet.

`CODE_SIGNING_ALLOWED=NO` is a build gate only. On current macOS releases, unsigned or ad-hoc debug bundles may be rejected by AppleSystemPolicy and PlugInKit may ignore their entitlements.

## Local launch and registration smoke

Use a signed build that the host macOS policy accepts. A developer signing identity may be required on stricter hosts.

```bash
xcodebuild -project MarkLook.xcodeproj -scheme MarkLook -configuration Debug -derivedDataPath .build/LocalDerivedData build
open .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
qlmanage -r
qlmanage -r cache
killall Finder || true
```

Record these diagnostics if launch or registration fails:

```bash
security find-identity -p codesigning -v
spctl --assess --type execute --verbose=4 .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
codesign --verify --deep --strict --verbose=4 .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
```

Expected for Issue #2:

- MarkLook.app opens when signed by an identity accepted by the host.
- Quick Look extensions appear in PlugInKit only after macOS accepts the app and extensions.
- If local policy rejects the build, record the signing/policy output rather than treating Finder behavior as product behavior.

## Diagnose a file

```bash
mdls -name kMDItemContentType Samples/basic.md
pluginkit -mAv -p com.apple.quicklook.preview | grep -i MarkLook
```

## Preview checks

```bash
qlmanage -p Samples/basic.md
qlmanage -p Samples/gfm-table-task-list.md
qlmanage -p Samples/long-ai-review.md
qlmanage -p Samples/unsafe-html.md
```

Expected:

- Issue #2 may show only the preview shell placeholder if the extension is registered.
- Rendered Markdown is not expected until Issue #4.
- Unsafe HTML and remote resource behavior are renderer concerns and are not implemented in Issue #2.
- Errors should show a local error view, not a blank view, once the preview extension is selected.

## Thumbnail checks

```bash
qlmanage -r cache
qlmanage -t -s 512 -o /tmp Samples/basic.md
open /tmp/basic.md.png || true
```

Expected:

- Issue #2 thumbnail provider draws a static Markdown identity thumbnail when selected.
- If macOS selects the system raw-text thumbnail, record PlugInKit/signing status.
- Large files do not trigger full rendering.

## Reset Quick Look

```bash
qlmanage -r
qlmanage -r cache
killall Finder || true
```
