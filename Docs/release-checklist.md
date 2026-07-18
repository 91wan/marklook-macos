# Release checklist

Use this checklist before preparing a public MarkLook release candidate.

## Preflight

- Work from a clean release-prep worktree.
- Confirm there are no local uncommitted AppIcon changes outside the release branch.
- Confirm `MarkLookApp/Assets.xcassets/AppIcon.appiconset` is committed when packaging a polished v0.1 candidate.
- Confirm CI is green on the release-prep PR.
- Run `Scripts/validate-version-consistency.rb` and confirm the App, Preview, and Thumbnail versions match `project.yml`.
- Confirm `Scripts/validate-public-repo-privacy.sh --archive` passes before publication.
- Confirm Issue #6 diagnostics dashboard acceptance is closed.
- Confirm `Docs/v0.1.0-release-gate.md` is current.
- For v0.1.1 source/local-validation patches, confirm `Docs/v0.1.1-source-local-validation.md` is current.
- Do not create a `v0.1.0` tag inside a PR branch.
- Do not create a `v0.1.1` tag inside a PR branch.

## Build and runtime gates

- Run the CI-compatible unsigned build and tests.
- Run local Apple Development validation with `Scripts/doctor-signing.sh`.
- Run `DEVELOPMENT_TEAM=<TEAM_ID> Scripts/build-local-apple-development.sh`.
- Run `Scripts/validate-signed-quicklook.sh --development --noninteractive .build/LocalDerivedData/Build/Products/Debug/MarkLook.app`.
- Run Finder Space preview validation for representative Markdown files when doing final manual acceptance.
- Run thumbnail validation with `qlmanage -t -s 512 -o /tmp Samples/basic.md`.
- Confirm diagnostics dashboard selected-file, reset-cache, and copy-report flows remain accepted.
- Run `Scripts/validate-release-candidate.sh --ci`.
- Run `DEVELOPMENT_TEAM=<TEAM_ID> Scripts/validate-release-candidate.sh --local` on the maintainer Mac, or record explicit owner deferral.
- `Scripts/validate-v0.1.0-release-candidate.sh` remains as a compatibility wrapper for older automation.

## Package gates

- Generate the unsigned CI/debug package with `Scripts/package-debug.sh --unsigned-ci`.
- Validate the unsigned package with `Scripts/validate-package-artifact.sh <zip>`.
- Generate the local Apple Development package with `DEVELOPMENT_TEAM=<TEAM_ID> Scripts/package-debug.sh --apple-development`.
- Validate the Apple Development package with `Scripts/validate-package-artifact.sh <zip>`.
- Record the package ZIP SHA-256.
- Confirm `MANIFEST.txt` includes build mode, signing summary, TeamIdentifier when available, package path, ZIP SHA-256, AppIcon status, known limitations, and the public release caveat.

## Public distribution gates

- Confirm Developer ID Application signing is available before making a public release artifact.
- Confirm hardened runtime remains enabled for distribution signing.
- Submit the release artifact for notarization.
- Staple the notarization ticket to the app or disk image.
- Run `spctl --assess --type execute --verbose=4 <APP_OR_DMG>` on the stapled artifact.
- Do not claim public release trust from Apple Development or unsigned CI packages.

## Release publication

- Prepare release notes from `Docs/github-release-draft-v0.1.0.md`.
- Replace checksum placeholders with real SHA-256 values from the final release artifact.
- Replace artifact URL placeholders with the final GitHub Release URL.
- Keep `Docs/homebrew-cask-draft.rb` as draft until a real release artifact URL and SHA-256 exist.
- Do not publish the GitHub Release or submit a Homebrew cask until Issue #8 completes.
- After the PR merges, ask the owner before pushing `v0.1.0`.
- After the PR merges, ask the owner before pushing `v0.1.1`.
- If no Developer ID notarized artifact exists, describe `v0.1.0` as a source/local-validation milestone.
- If no Developer ID notarized artifact exists, describe `v0.1.1` as a source/local-validation patch.
