# Review checklist

Use this checklist for every pull request.

## Scope

- The change stays inside the current issue.
- Behavior changes are explicitly listed, or the PR says `behavior changes: none`.
- Architecture changes have an ADR before implementation.

## Validation

- Commands are listed exactly.
- Results are summarized clearly.
- Failures, skipped checks, and local-only limitations are disclosed.

## Security and privacy

- No network access is added without explicit review.
- No telemetry is added.
- Raw HTML and scripts remain disabled or sanitized.
- Remote resources are not loaded during preview rendering.
- Sandbox and Hardened Runtime settings are preserved or explained.

## Quick Look

- Preview extension changes include rendered preview validation when relevant.
- Thumbnail extension changes include thumbnail validation when relevant.
- `QLSupportedContentTypes` changes avoid `public.plain-text`.
- Cache reset commands are documented when behavior changes.

## Release

- Public docs remain accurate.
- Known limitations are recorded when applicable.
