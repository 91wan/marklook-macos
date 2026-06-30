# v0.1.0 Manual Validation Log

## Environment

- Date: 2026-06-30
- macOS: 26.5.1 (25F80)
- Mac model: Mac16,12
- Xcode: 26.6 (17F113)
- Signing identity: Apple Development, Team ID `W2SP34K4MR`

## Git State

```text
Validation commit reported by the pre-commit worktree gate: 3a77330b28b70f04bca42116287b71769a1f6205
Branch: chore/v0.1.0-hardening
Note: final PR-head and latest-main validation must be rerun after commit/merge before tagging.
```

## Static Validation

Passed:

```text
ruby -e "require 'yaml'; YAML.load_file('.github/workflows/ci.yml')"
sh -n Scripts/validate-v0.1.0-release-candidate.sh
Tests/Scripts/v0.1-release-gate-test.sh
Scripts/validate-diagnostics-boundaries.sh
Scripts/validate-thumbnail-boundaries.sh
Scripts/validate-quicklook-preview-contract.sh
Scripts/validate-supported-types.sh
```

## Build/Test

Passed through `Scripts/validate-v0.1.0-release-candidate.sh --ci`.

The gate uses `xcodebuild build-for-testing` and then executes the macOS unit-test bundles with `xcrun xctest` to avoid an intermittent Xcode 26.6 `test-without-building` bundle discovery failure observed on this host.

## MarkdownCore Tests

Passed through the release candidate gate:

```text
cd Packages/MarkdownCore
swift test
```

## Unsigned Package

Passed in `--ci` mode.

```text
Package path: dist/MarkLook-0.1.0-debug-3a77330/MarkLook-0.1.0-debug-3a77330.zip
Checksum: 39cae2ec6cacd060fd2bc2746c7917fed685a5ad48359c4d2e0ff6457a03111b
```

This is a pre-merge validation artifact, not the final release artifact.

## Apple Development Package

Passed in `--local` mode.

```text
Package path: dist/MarkLook-0.1.0-debug-3a77330/MarkLook-0.1.0-debug-3a77330.zip
Checksum: f26fefdb8690e5f9887329b011b9589a56d33595b6359ef25cd09cf9dfcfcbaf
```

This is a local Apple Development validation artifact, not a public distribution artifact.

## Signed Local Runtime

Passed.

```text
/Applications/MarkLook.app launched successfully.
Exactly one MarkLook process was running:
/Applications/MarkLook.app/Contents/MacOS/MarkLook
```

PlugInKit registration after cleanup:

```text
com.91wan.MarkLook.Preview -> /Applications/MarkLook.app/Contents/PlugIns/MarkLookPreview.appex
com.91wan.MarkLook.Thumbnail -> /Applications/MarkLook.app/Contents/PlugIns/MarkLookThumbnail.appex
```

## Finder Space Preview

Manual owner acceptance pending before closing Issue #8 or pushing `v0.1.0`.

Required sample set:

```text
Samples/basic.md
Samples/gfm-table-task-list.md
Samples/unsafe-html.md
Samples/long-ai-review.md
Samples/large-fast-mode.md
```

## Thumbnail Validation

Passed.

```text
qlmanage -t -s 512 -o /tmp Samples/basic.md
qlmanage -t -x -s 512 -o /tmp Samples/basic.md
qlmanage -t -x -s 512 -o /tmp /tmp/marklook-thumbnail-1782821831-basic.md
```

Output PNG evidence:

```text
basic.md.png: 512 x 512
sha256: e805ea612ffc3430f197f98622af4e3575311814ba7c48eff5f44d28e3950d03
unique sample png: 512 x 512
sha256: e805ea612ffc3430f197f98622af4e3575311814ba7c48eff5f44d28e3950d03
```

## Diagnostics Dashboard

Covered by the release candidate gate and local signed validation.

Checklist:

```text
Status section:
Quick Look Extensions section:
Supported Markdown Types section:
Selected-file diagnosis for basic.md:
Reset Quick Look Cache action:
Copy Report:
Manual Enable Instructions:
```

## Screenshots/Artifacts

Local artifacts:

```text
/tmp/marklook-v0.1.0-rc-ci-xcrun.log
/tmp/marklook-v0.1.0-rc-local-clean.log
/tmp/marklook-thumbnail-diagnostics-20260630-201711/
/tmp/marklook-time-validate-signed.log
/tmp/marklook-time-thumbnail-basic.log
/tmp/marklook-time-thumbnail-large.log
```

## Verdict

PR worktree validation passed for CI-compatible and local Apple Development gates.

Do not push `v0.1.0` until the PR is merged, latest `main` reruns both gates, Finder Space owner acceptance is recorded or explicitly deferred, and the owner approves tag creation.
