# Architecture

MarkLook is a modern macOS Quick Look renderer for Markdown files.

## Shape

```text
MarkLook.app
├── Host app for settings, diagnostics, install status, cache reset guidance, and copyable reports
├── MarkLookPreview.appex for rendered Markdown previews
├── MarkLookThumbnail.appex for Finder thumbnails
└── MarkdownCore Swift package for Markdown to safe self-contained HTML
```

## Rendering pipeline

```text
file URL
  -> MarkdownFileLoader
  -> MarkdownCore.Renderer
  -> safe self-contained HTML string
  -> WKWebView.loadHTMLString(_:baseURL:nil)
```

The preview extension must treat WKWebView as a local HTML display surface, not as a browser.

## Product boundary

MarkLook renders Markdown in Finder Quick Look. It is not an editor, notes app, knowledge base, cloud service, AI summarizer, Electron app, Finder Sync extension, or deprecated `.qlgenerator`.

## Security boundary

Preview rendering is local-only:

- no telemetry
- no network entitlement
- no remote assets
- no CDN
- no raw script execution
- no navigation inside Quick Look
- no writes from the preview extension

## Content types

The extensions must target Markdown-specific content types and must not claim `public.plain-text`.

Initial supported content types:

- `net.daringfireball.markdown`
- `public.markdown`
- `net.ia.markdown`
- `com.unknown.md`
- `net.daringfireball`
- `com.apple.dt.document.markdown`

Initial extensions:

- `.md`
- `.markdown`
- `.mdown`
- `.mkd`
- `.mkdn`
- `.mdx`
- `.rmd`
- `.qmd`
