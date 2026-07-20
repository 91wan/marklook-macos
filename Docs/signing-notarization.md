# Signing and notarization

MarkLook has three separate build and distribution lanes. Do not mix their guarantees.

## 1. Unsigned CI build

Use this lane for CI and local build verification:

```bash
xcodegen generate
xcodebuild -project MarkLook.xcodeproj -scheme MarkLook -configuration Debug -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
Scripts/package-debug.sh --unsigned-ci
```

This proves source compatibility, bundle embedding, plist shape, and package mechanics. It does not prove local launch, PlugInKit registration, Finder Quick Look behavior, Gatekeeper acceptance, or public distribution trust.

Unsigned CI packages are not installable trust artifacts.

## 2. Apple Development local validation

Use this lane on the maintainer Mac to validate a host-accepted local app:

```bash
Scripts/doctor-signing.sh
DEVELOPMENT_TEAM=<TEAM_ID> Scripts/build-local-apple-development.sh
Scripts/validate-signed-quicklook.sh --development --noninteractive .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
DEVELOPMENT_TEAM=<TEAM_ID> Scripts/package-debug.sh --apple-development
```

Apple Development signing can prove local app launch, TeamIdentifier presence, PlugInKit registration, Finder preview behavior, and package mechanics on the maintainer machine.

Apple Development signing does not prove public distribution trust. A development-mode `spctl` rejection is expected and must not be treated as a release failure.

## 3. Developer ID public distribution

Public distribution outside the Mac App Store requires:

- Developer ID Application signing
- hardened runtime
- notarization
- stapling
- Gatekeeper assessment on the stapled artifact

Check the local identity first:

```bash
Scripts/doctor-release-identity.sh
Scripts/package-developer-id.sh --dry-run
```

Create a Developer ID signed artifact:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: <NAME> (<TEAM_ID>)" \
  Scripts/package-developer-id.sh --developer-id
Scripts/validate-developer-id-artifact.sh --signed-only dist/MarkLook-<version>-developer-id-<shortsha>/MarkLook-<version>-developer-id-<shortsha>.zip
```

Create a notarized artifact only when the local keychain profile is configured:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: <NAME> (<TEAM_ID>)" \
NOTARYTOOL_PROFILE=<PROFILE> \
  Scripts/package-developer-id.sh --developer-id --notarize
Scripts/validate-developer-id-artifact.sh --notarized dist/MarkLook-<version>-developer-id-<shortsha>/MarkLook-<version>-developer-id-<shortsha>.zip
```

Do not put Apple account credentials, API keys, passwords, or keychain profile secrets in repository files, PR descriptions, issue comments, logs, or release notes.

Do not claim notarization or stapling until the real artifact has been submitted, accepted, stapled, and assessed.

See `Docs/developer-id-release-lane.md` and `Docs/public-binary-release-checklist.md` for the full public binary release gate.

## Package validation

After generating a package, run:

```bash
Scripts/validate-package-artifact.sh dist/MarkLook-0.1.0-debug-<shortsha>/MarkLook-0.1.0-debug-<shortsha>.zip
```

For Apple Development packages, the validator checks the extracted app bundle and runs deep codesign verification. It intentionally does not require `spctl` to pass for Apple Development packages.
