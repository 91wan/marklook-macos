# Security

## Security model

MarkLook is a local-only Quick Look renderer for Markdown files.

- App Sandbox is required.
- Hardened Runtime is required.
- No network entitlement is allowed for preview rendering.
- Raw HTML must be disabled or sanitized before display.
- Remote images, scripts, styles, fonts, and CDN resources are not allowed during preview rendering.
- Quick Look links must not navigate inside the preview view.

## Reporting vulnerabilities

Open a GitHub issue with a minimal reproduction when the report does not contain private documents or sensitive exploit details. For sensitive reports, contact the repository owner privately before publishing details.

## Supported versions

Security hardening begins with the v0.1.0 release line. Until then, security claims are tracked through pull request validation and manual review.
