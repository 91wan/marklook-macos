# ADR-0003: Security Model

## Status

Accepted draft

## Context

MarkLook previews local documents that may contain untrusted Markdown produced by AI tools, repositories, issue trackers, or external contributors. Quick Look rendering must not create a browser-like execution environment.

## Decision

MarkLook preview rendering is local-only and self-contained.

- App Sandbox is on.
- Hardened Runtime is on.
- Preview rendering has no network entitlement.
- HTML output is self-contained.
- CSS is inline.
- No CDN, remote fonts, remote scripts, or remote images are loaded.
- Raw HTML is disabled or sanitized.
- The preview extension does not embed WebKit; it returns data-based self-contained HTML to Quick Look.
- The preview extension does not write files.

## Consequences

- Some Markdown content will be displayed as safe text or placeholders instead of rich embedded content.
- Mermaid, KaTeX, and remote media are not v0.1 requirements.
- Security regressions must be treated as release blockers.
