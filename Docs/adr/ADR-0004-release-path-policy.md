# ADR-0004: Release Path Policy Ownership

## Status

Accepted for the behavior-neutral G0 extraction after independent Plan Review.

## Context

The Developer ID packager owns both DerivedData path admission and the build,
signing, and packaging sequence. Other release scripts have separate path inputs,
but they do not yet share this admission policy. Extending all of them in one
change would mix responsibility extraction with new safety behavior.

## Decision

Move the existing `canonicalize_disposable_derived_data` function into
`Scripts/release-path-policy.sh`. The Developer ID packager remains its first
and only production caller in G0. Pass the repository root and existing Ruby
and getconf executables explicitly; the helper performs no persistent writes.

Preserve the current Bash/Ruby/getconf implementation and observable behavior:

- Resolve relative inputs from the packager's repository working directory.
- Resolve the nearest existing ancestor before appending missing path components.
- Preserve the existing repository-overlap checks and disposable-directory roots.
- Preserve symlink resolution, rather than rejecting all symlinks.
- Preserve error text, exit status, stdout/stderr, and preflight ordering.
- Preserve dry-run behavior and the clean-worktree requirement before packaging.

The packager retains ownership of tool checks, cleanup, builds, signing,
validation, and reports. The helper is sourced without changing shell options
or introducing environment-variable configuration. It is not a second release
orchestrator, and it does not authorize deletion or installation.

## Validation

Extend `Tests/Scripts/developer-id-release-lane-test.sh` to characterize accepted
relative, nested, spaced, and symlinked paths, plus rejected repository ancestors
and symlink escapes. Invalid paths and dry runs must not invoke release tools.
Keep its real packager entrypoint and existing absolute-path build assertion.
Copied packager fixtures must include the helper, including the initial clean
commit of the dirty-worktree fixture.

Run the existing script tests and `Scripts/validate-release-candidate.sh --ci`
on the exact clean candidate after independent pre-Stack review. Do not run
`--local`, replace the installed app, or publish anything as part of G0.

## Boundaries and Follow-up

G0 does not change accepted paths, inherited environments, output retention,
installation behavior, release identity, or existing test discovery. In
particular, it does not claim to fix the RC gate's other path inputs.

Subsequent reviewed changes may extend the same owner with distinct contracts
for disposable directories and output files. Installation must additionally
validate bundle identity; path admission alone cannot authorize replacement.
Cleanup ownership, environment isolation, and broader adoption remain separate
behavior changes, not implicit consequences of this extraction.

## G1a: RC Path Admission

After independent Plan Review, the RC gate adopts this owner before installing
its EXIT trap or invoking any release tool. Admission uses fixed system Ruby,
getconf, and read-only plist queries, not the RC tool overrides.

- DerivedData allows strict descendants of repository `.build` or OS temporary
  roots. Dist allows repository `dist` and its descendants, or OS temp children.
- Project dumps, renderer fixtures, and internal XCTest logs must be regular-file
  targets under `.build` or OS temp children. Reject linked output files,
  non-file targets, and overlap with directories that will be removed.
- OS temp roots come from `getconf DARWIN_USER_TEMP_DIR` and `/private/tmp`, not
  the caller's `TMPDIR`. Resolve the nearest existing ancestor of missing paths.
- The only installation destination is the literal `/Applications/MarkLook.app`.
  An existing destination must be a non-linked bundle with the app's identifier.
  This check does not authorize installation or require matching version numbers.
- All independent targets must be disjoint. Consumers use the admitted paths;
  report parent directories are created only after the complete preflight.
  Overlap denials conservatively include case/Unicode-normalization aliases,
  since macOS realpath can retain alternate casing on case-insensitive volumes.

Reverse tests require empty release-tool and cleanup logs before checking the
absence of mutations. Installation identity tests use temporary fixtures through
the production helper, never a temporary installation override or real install.
The existing G0 characterization and legacy gate tests remain required.

G1a does not isolate inherited environments or close every nested packager path.
That is G1b and later adoption work. Admission is not a filesystem sandbox against
concurrent hostile path replacement; callers must control their checkout and
disposable directories during execution.
