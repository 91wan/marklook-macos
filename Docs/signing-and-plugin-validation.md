# Signing and PlugInKit validation

MarkLook is only useful after macOS accepts the signed app bundle and PlugInKit selects the bundled Quick Look extensions. CI can prove build, embedding, and unit tests; it cannot prove Finder Space-key behavior.

This tooling supports Issue #11 evidence collection only. It does not satisfy Issue #11 by itself; Issue #11 remains open until real host-accepted signed runtime evidence is attached.

## Build a signed app

Use one of these signing paths.

Developer ID Application is the release-style path:

```bash
xcodebuild -project MarkLook.xcodeproj -scheme MarkLook -configuration Debug -derivedDataPath .build/LocalDerivedData build
codesign --verify --deep --strict --verbose=4 .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
spctl --assess --type execute --verbose=4 .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
```

For a public release build, Developer ID signing is not enough. The app must be notarized and the notarization ticket should be stapled before distribution. For this local smoke, an Apple Development identity accepted by the host is acceptable, but release packaging must use Developer ID Application, hardened runtime, notarization, and stapling.

Apple Development is acceptable for local smoke on a development Mac when the identity is trusted by the host:

```bash
security find-identity -p codesigning -v
xcodebuild -project MarkLook.xcodeproj -scheme MarkLook -configuration Debug -derivedDataPath .build/LocalDerivedData DEVELOPMENT_TEAM=<TEAM_ID> build
codesign --verify --deep --strict --verbose=4 .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
spctl --assess --type execute --verbose=4 .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
```

Do not use ad-hoc signing as PlugInKit proof. Ad-hoc signing may satisfy a narrow build or launch check, but it does not prove Gatekeeper acceptance, entitlement trust, extension registration, or Finder provider selection on another host.

## Run signed Quick Look smoke

```bash
Scripts/validate-signed-quicklook.sh .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
```

The script runs:

```bash
codesign --verify --deep --strict --verbose=4 "$APP"
spctl --assess --type execute --verbose=4 "$APP"
open "$APP"
qlmanage -r
qlmanage -r cache
killall Finder || true
pluginkit -mAv -p com.apple.quicklook.preview | grep -i MarkLook
pluginkit -mAv -p com.apple.quicklook.thumbnail | grep -i MarkLook
mdls -name kMDItemContentType Samples/basic.md
qlmanage -p Samples/basic.md
qlmanage -p Samples/gfm-table-task-list.md
qlmanage -p Samples/long-ai-review.md
qlmanage -p Samples/unsafe-html.md
qlmanage -p Samples/large-fast-mode.md
qlmanage -t -s 512 -o /tmp Samples/basic.md
```

`qlmanage -p` opens preview UI. Close each preview window to let the script continue.

## Enable Quick Look extensions

If the app is signed and opens but Finder still uses the system raw-text provider, check:

```text
System Settings -> General -> Login Items & Extensions -> Quick Look
```

Enable MarkLook Preview and MarkLook Thumbnail when macOS shows them. Then reset Quick Look:

```bash
qlmanage -r
qlmanage -r cache
killall Finder || true
```

## Expected evidence

Record exact output in the PR or issue comment:

```text
codesign verify: pass
spctl assess: pass
open MarkLook.app: pass
pluginkit preview contains MarkLookPreview
pluginkit thumbnail contains MarkLookThumbnail
mdls Samples/basic.md reports a supported Markdown UTI
qlmanage -p Samples/basic.md shows MarkLook rendered preview
qlmanage -p Samples/gfm-table-task-list.md shows table and task-list rendering
qlmanage -p Samples/long-ai-review.md does not blank out
qlmanage -p Samples/unsafe-html.md shows safe escaped content
qlmanage -p Samples/large-fast-mode.md shows the fast mode warning and stays responsive
qlmanage -t generates MarkLook thumbnail or records explicit provider-selection failure
```

Screenshots are strongly preferred for:

```text
qlmanage -p Samples/basic.md
qlmanage -p Samples/unsafe-html.md
qlmanage -p Samples/large-fast-mode.md
System Settings -> General -> Login Items & Extensions -> Quick Look
```

## Diagnostics when MarkLook is not selected

Collect:

```bash
security find-identity -p codesigning -v
codesign --verify --deep --strict --verbose=4 .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
spctl --assess --type execute --verbose=4 .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
pluginkit -mAv -p com.apple.quicklook.preview | grep -i MarkLook
pluginkit -mAv -p com.apple.quicklook.thumbnail | grep -i MarkLook
mdls -name kMDItemContentType Samples/basic.md
qlmanage -m plugins | grep -i MarkLook
```

If PlugInKit does not list MarkLook after a signed app launch and Quick Look reset, keep Issue #11 open and attach the signing, `spctl`, PlugInKit, and System Settings evidence.
