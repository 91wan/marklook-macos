# Public binary release checklist

Use this checklist only for a Developer ID signed public binary. Source/local-validation tags can proceed through their own gate without claiming public binary trust.

## Preflight

- Confirm the release branch is clean and based on current `main`.
- Confirm CI is green.
- Run `Scripts/validate-public-repo-privacy.sh`.
- Run `Scripts/validate-public-repo-privacy.sh --archive`.
- Run `Scripts/validate-release-candidate.sh --ci`.
- Confirm `Docs/developer-id-release-lane.md` and this checklist are current.
- Confirm no Git tag, GitHub Release, or Homebrew submission is created from a PR branch.

## Signing identity

- Run `Scripts/doctor-release-identity.sh`.
- Confirm `Developer ID Application identity: FOUND`.
- Do not paste full certificate subjects, private key material, Apple account identifiers, passwords, or notary profile secrets into public logs.

## Package dry run

- Run `Scripts/package-developer-id.sh --dry-run`.
- Confirm it reports intended signing and notarization commands.
- Confirm it does not sign, notarize, staple, or assess an artifact.

## Developer ID signed package

- Run:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: <NAME> (<TEAM_ID>)" \
  Scripts/package-developer-id.sh --developer-id
```

- Run:

```bash
Scripts/validate-developer-id-artifact.sh --signed-only dist/MarkLook-<version>-developer-id-<shortsha>/MarkLook.app
Scripts/validate-developer-id-artifact.sh --signed-only dist/MarkLook-<version>-developer-id-<shortsha>/MarkLook-<version>-developer-id-<shortsha>.zip
```

- Confirm app, Preview appex, and Thumbnail appex use Developer ID Application signing.
- Confirm TeamIdentifier exists.
- Confirm hardened runtime exists.
- Confirm the app entitlement set is exactly App Sandbox plus user-selected read-only access.
- Confirm each Quick Look extension entitlement set is exactly App Sandbox.
- Confirm no network or unexpected entitlement is present.
- Confirm supported Markdown content types remain bounded.
- Confirm Preview still uses the data-based self-contained HTML contract.
- Confirm thumbnail renderer boundaries remain deterministic.

## Notarization

- Run:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: <NAME> (<TEAM_ID>)" \
NOTARYTOOL_PROFILE=<PROFILE> \
  Scripts/package-developer-id.sh --developer-id --notarize
```

- Confirm `xcrun notarytool submit ... --wait` is accepted.
- Confirm `xcrun stapler staple` succeeds.
- Confirm `spctl --assess --type execute --verbose=4` succeeds.
- Run:

```bash
Scripts/validate-developer-id-artifact.sh --notarized dist/MarkLook-<version>-developer-id-<shortsha>/MarkLook-<version>-developer-id-<shortsha>.zip
```

## Publication

- Replace release draft checksum placeholders with the final ZIP SHA-256.
- Replace release draft artifact URL placeholders with the final GitHub Release URL.
- Keep Homebrew cask content as draft until the notarized artifact URL and SHA-256 are final.
- Ask the owner before pushing tags.
- Ask the owner before publishing GitHub Releases.
- Ask the owner before submitting a Homebrew cask.
