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
