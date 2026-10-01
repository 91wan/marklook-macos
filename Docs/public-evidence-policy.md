# Public evidence policy

## Purpose

MarkLook is a public repository. Validation evidence must be useful without exposing local environment details.

## Allowed public evidence

- command names
- pass/fail summaries
- redacted signing status
- redacted TeamIdentifier values, such as `TeamIdentifier: redacted`
- synthetic examples, such as `DEVELOPMENT_TEAM=<TEAM_ID>`
- checksums of generated local artifacts when they do not identify local paths
- text-only summaries of screenshots
- sanitized screenshots only after explicit review

## Disallowed public evidence

- Finder screenshots showing sidebar items, usernames, local folders, tags, Downloads content, personal filenames, or account details
- generated Quick Look thumbnail PNGs from local user files
- raw home paths such as `/Users/<name>/...`
- real Apple TeamIdentifier values
- real Apple Development certificate subject values
- private-user-images URLs
- raw GitHub evidence image links
- screenshots committed under `Docs/evidence`
- local path screenshots used as durable proof

## Evidence storage

- Store runtime screenshots locally.
- Summarize visual evidence in text.
- Commit only sanitized evidence.
- Prefer testable scripts over screenshots.

## Tracked content validation

`Scripts/validate-public-repo-privacy.sh` scans index-tracked working files; `--archive`
scans HEAD-tracked archive bytes. Both use NUL-safe inventories and scan every strict
UTF-8 file, including empty files and UTF-8 BOMs, regardless of extension. Unmerged
entries, symlinks (including ancestor traversal), gitlinks, missing/unreadable files,
inventory or scan errors, UTF-16/32 BOMs, invalid UTF-8, and NUL-containing binary
content fail closed. Archive modes are admitted before extraction.

The only binary exception is positively classified PNG content at the ten existing
AppIcon filenames under `MarkLookApp/Assets.xcassets/AppIcon.appiconset`; each exception
is reported. A filename alone never exempts text from scanning. PNG/JPEG files under
`Docs/evidence` remain forbidden: current mode also checks untracked evidence images,
while archive mode stays HEAD-only. Other untracked files and repository history are
not covered by these two snapshot checks.

## History policy

- Current-tree cleanup is standard.
- Git history rewrite requires explicit owner approval.
- GitHub support purge requires explicit owner approval.
