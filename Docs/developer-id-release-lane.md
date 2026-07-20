# Developer ID public binary release lane

This lane is for public MarkLook binary distribution outside the Mac App Store. It is separate from the unsigned CI lane and the Apple Development local-validation lane.

## Guarantees

The Developer ID lane may be used for a public binary only when all of these are true:

- The app and embedded Quick Look extensions are signed with a Developer ID Application identity.
- Hardened runtime is enabled on the app and embedded extensions.
- The app retains only App Sandbox plus user-selected read-only access, and each extension retains only App Sandbox.
- The artifact has passed MarkLook bundle, preview, thumbnail, entitlement, and package checks.
- If published as a public trust artifact, the package has been notarized, stapled, and accepted by Gatekeeper assessment.

Apple Development signing and unsigned CI packages do not satisfy this lane.

## Non-goals

- This lane does not create a Git tag.
- This lane does not publish a GitHub Release.
- This lane does not submit a Homebrew cask.
- This lane does not store Apple account credentials, passwords, API keys, notary profiles, or private key material in the repository.

## Identity preflight

Check the local signing identities:

```bash
Scripts/doctor-release-identity.sh
```

If no Developer ID Application identity is available, the public binary lane must stop:

```text
Developer ID Application identity: NOT FOUND
Public binary release lane cannot proceed.
Source/local-validation remains available.
```

The script intentionally redacts certificate subject details. Use Keychain Access or Xcode locally when the owner needs to inspect private signing assets.

## Dry run

The dry run validates lane tooling and prints the commands that would be used. It does not sign or notarize anything and is safe for CI:

```bash
Scripts/package-developer-id.sh --dry-run
```

## Signed-only package

Create a Developer ID signed package without notarization:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: <NAME> (<TEAM_ID>)" \
  Scripts/package-developer-id.sh --developer-id
```

Validate the signed artifact:

```bash
Scripts/validate-developer-id-artifact.sh --signed-only dist/MarkLook-<version>-developer-id-<shortsha>/MarkLook.app
Scripts/validate-developer-id-artifact.sh --signed-only dist/MarkLook-<version>-developer-id-<shortsha>/MarkLook-<version>-developer-id-<shortsha>.zip
```

Signed-only artifacts are useful for maintainer validation, but they are not the final public trust artifact.

## Notarized package

Notarization requires a local notarytool keychain profile created outside the repository:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: <NAME> (<TEAM_ID>)" \
NOTARYTOOL_PROFILE=<PROFILE> \
  Scripts/package-developer-id.sh --developer-id --notarize
```

The notarized lane submits the ZIP with `xcrun notarytool`, staples the app with `xcrun stapler`, runs `spctl --assess --type execute --verbose=4`, rebuilds the ZIP after stapling, and validates the resulting artifact:

```bash
Scripts/validate-developer-id-artifact.sh --notarized dist/MarkLook-<version>-developer-id-<shortsha>/MarkLook-<version>-developer-id-<shortsha>.zip
```

## Public release boundary

Before a public GitHub Release or Homebrew cask is published, record:

- Developer ID Application signing status.
- Hardened runtime validation.
- Notarization result.
- Stapling result.
- `spctl --assess --type execute --verbose=4` result.
- Final ZIP SHA-256.
- The exact Git commit used for the artifact.

Do not publish screenshots, Finder thumbnails, local usernames, local file paths, certificate subjects, keychain profile names, or TeamIdentifier values unless the owner explicitly approves that evidence for public use.

## References

- Apple Developer: Developer ID - Signing Your Apps for Gatekeeper: <https://developer.apple.com/developer-id/>
- Apple Developer: Notarizing macOS software before distribution: <https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution>
- Apple Developer: Resolving common notarization issues: <https://developer.apple.com/documentation/security/resolving-common-notarization-issues>
