# v0.1.0 Known Limitations

- No public Developer ID notarized binary is available for v0.1.0 unless Developer ID credentials are provided and validation passes.
- Apple Development builds are local validation only.
- Unsigned CI packages are not installable trust artifacts.
- Homebrew cask content is draft-only until a real release artifact URL and checksum exist.
- Quick Look provider-family listings can be incomplete on some macOS versions; exact bundle-id fallback may be needed.
- The diagnostics app may show sandbox or PlugInKit errors and copyable Terminal fallback commands.
- Raw HTML is escaped or sanitized, not executed.
- Remote images and remote resources are blocked.
- Links are inert and non-navigating in preview.
- Large files may enter fast mode and show a warning.
- Thumbnail line count is approximate and prefix-based.
- Finder/Quick Look provider selection can vary by host registration state, extension enablement, signing state, and cache state.
- Local release validation should clean stale worktree PlugInKit registrations and verify only `/Applications/MarkLook.app` is active.
- MarkLook is not a Markdown editor and intentionally does not become the default Markdown file owner.
- MarkLook is designed to coexist with native Markdown editors such as Edmund; if a host has conflicting file ownership or Quick Look provider selection, use diagnostics rather than changing MarkLook into an editor.
