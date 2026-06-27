# Contributing

MarkLook is intentionally small. Changes should preserve the one-job product boundary: fast, stable, local Markdown Quick Look preview.

## Scope

In scope:

- macOS host app diagnostics.
- Quick Look preview extension.
- Quick Look thumbnail extension.
- MarkdownCore safe rendering.
- Local packaging and validation tooling.

Out of scope:

- Markdown editing.
- Cloud sync.
- Accounts.
- AI summarization.
- Electron or web app shells.
- Deprecated `.qlgenerator` plugins.

## Pull requests

Every pull request must include validation results, behavior changes, risks, and security/privacy impact. If there is no behavior change, write `behavior changes: none`.

Architecture changes require an ADR before implementation.
