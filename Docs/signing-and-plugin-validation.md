# Signing and PlugInKit validation

MarkLook is only useful after macOS accepts the signed app bundle and PlugInKit selects the bundled Quick Look extensions. CI can prove build, embedding, and unit tests; it cannot prove Finder Space-key behavior.

This tooling supports Issue #11 evidence collection only. It does not satisfy Issue #11 by itself; Issue #11 remains open until real host-accepted signed runtime evidence is attached.

## Build a signed app

Use one of these signing paths.

### Local development validation with ordinary Apple ID / Personal Team

Use this for Issue #11 local validation on the repository owner's Mac. It proves local host acceptance, PlugInKit registration, and Finder/Quick Look behavior for development. It does not prove public distribution trust.

1. Open Xcode -> Settings -> Accounts.
2. Add the owner's Apple ID.
3. Open Manage Certificates and create an Apple Development certificate.
4. Confirm the identity and Team ID:

```bash
Scripts/doctor-signing.sh
security find-identity -p codesigning -v
```

Then build and smoke test with the Team ID from Xcode or the certificate OU candidate printed by `Scripts/doctor-signing.sh`:

```bash
DEVELOPMENT_TEAM=<TEAM_ID> Scripts/build-local-apple-development.sh
Scripts/validate-signed-quicklook.sh --development .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
```

`--development` still rejects ad-hoc signatures and missing TeamIdentifier values. It records `spctl --assess`; if `spctl` rejects an Apple Development build, the script may continue only after proving the signature is non-ad-hoc and has a TeamIdentifier. This mode is for local development validation only.

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
Scripts/validate-signed-quicklook.sh --development .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
Scripts/validate-signed-quicklook.sh --release .build/LocalDerivedData/Build/Products/Release/MarkLook.app
```

Without a mode flag, the script defaults to `--release`.

The script runs:

```bash
codesign --verify --deep --strict --verbose=4 "$APP"
codesign -dv --verbose=4 "$APP"
spctl --assess --type execute --verbose=4 "$APP"
open "$APP"
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
signature is not ad-hoc
TeamIdentifier is set
codesign verify: pass
spctl assess: pass for release; recorded for local development
open MarkLook.app: pass
pluginkit preview contains MarkLookPreview
pluginkit preview exact bundle-id lookup contains MarkLookPreview when the provider-family query is incomplete
pluginkit thumbnail provider list or thumbnail bundle-id lookup contains MarkLookThumbnail
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
pluginkit -mAv -i com.91wan.MarkLook.Preview
pluginkit -mAv -p com.apple.quicklook.thumbnail | grep -i MarkLook
pluginkit -mAv -i com.91wan.MarkLook.Thumbnail
mdls -name kMDItemContentType Samples/basic.md
qlmanage -m plugins | grep -i MarkLook
```

If PlugInKit does not list MarkLook after a signed app launch and Quick Look reset, check the exact bundle-id lookup too. On some macOS versions, provider-family queries may be incomplete while an exact bundle-id lookup such as `pluginkit -mAv -i com.91wan.MarkLook.Preview` or `pluginkit -mAv -i com.91wan.MarkLook.Thumbnail` still proves the extension is registered. This does not prove Finder selected the provider. If both forms miss MarkLook, keep Issue #11 open and attach the signing, `spctl`, PlugInKit, and System Settings evidence.

## Provider selection diagnostics

When Finder Space still shows raw Markdown, run:

```bash
Scripts/diagnose-quicklook-selection.sh .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
```

The script records signature, PlugInKit, UTI, and `qlmanage -m plugins` output under `/tmp/marklook-quicklook-diagnostics-*`. It does not force extension enablement by default. To attempt local development enablement explicitly, run:

```bash
Scripts/diagnose-quicklook-selection.sh --enable .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
```

The script also records `pluginkit -mADv` output for all MarkLook registrations. If it reports MarkLook registrations outside the app bundle being tested, clear stale builds or test an installed app path before interpreting Finder provider selection.

To detect whether the preview extension is invoked while pressing Space in Finder, run:

```bash
log stream --style compact --info --predicate 'subsystem == "com.91wan.MarkLook" || process CONTAINS "MarkLookPreview" || eventMessage CONTAINS "MarkLookPreview"'
```

Interpretation:

```text
No PreviewViewController logs:
  MarkLookPreview is not being selected/invoked.
  Investigate UTI, extension enablement, provider priority, and install location.

PreviewViewController logs appear:
  MarkLookPreview is invoked.
  Investigate WKWebView view assignment, rendering output, or Quick Look view lifecycle.
```

DerivedData apps can behave differently from installed apps. To test install location locally:

```bash
rm -rf /Applications/MarkLook.app
ditto .build/LocalDerivedData/Build/Products/Debug/MarkLook.app /Applications/MarkLook.app
open /Applications/MarkLook.app
qlmanage -r
qlmanage -r cache
killall Finder || true
pluginkit -mAv -p com.apple.quicklook.preview | grep -i MarkLook
pluginkit -mAv -i com.91wan.MarkLook.Preview
open -R Samples/basic.md
```

Press Space in Finder and record whether installing to `/Applications` changes provider selection. Do not make `/Applications` installation part of CI.
