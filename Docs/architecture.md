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
  -> QLPreviewReply(dataOfContentType: .html)
```

The preview extension is data-based. It returns self-contained HTML to Quick Look and must not embed WebKit, add network entitlements, or behave like a browser.

## Product boundary

MarkLook renders Markdown in Finder Quick Look. It is not an editor, notes app, knowledge base, cloud service, AI summarizer, Electron app, Finder Sync extension, or deprecated `.qlgenerator`.

## Architecture invariants

- MarkLook is a Quick Look reading layer, not a Markdown editor.
- Host app remains diagnostics/install assistance only.
- MarkLook must not become the default Markdown file owner.
- `CFBundleTypeRole` remains `Viewer`.
- `LSHandlerRank` remains `Alternate`.
- PreviewExtension remains data-based: `QLPreviewReply(dataOfContentType: .html)`.
- PreviewExtension does not use `WKWebView`.
- ThumbnailExtension reads bounded metadata only and never full-renders Markdown.
- ThumbnailExtension does not use WebKit.
- Thumbnail appearance is deterministic for v0.1.x.
- ThumbnailExtension uses fixed palette values, not ambient `NSAppearance.current`.
- Dark/gray thumbnail variants require an explicit future product decision.
- No network entitlement.
- No telemetry.
- No `.qlgenerator`.

See `Docs/adjacent-markdown-editors.md` for compatibility with native Markdown editors such as Edmund.

## Security boundary

Preview rendering is local-only:

- no telemetry
- no network entitlement
- no remote assets
- no CDN
- no raw script execution
- no WebKit navigation surface inside the preview extension
- no writes from the preview extension

## Content types

The extensions must target Markdown-specific content types and must not claim `public.plain-text`.

Initial supported content types:

- `net.daringfireball.markdown`
- `net.ia.markdown`
- `io.typora.markdown`
- `com.apple.dt.document.markdown`
- `com.rstudio.rmarkdown`
- `org.quarto.qmarkdown`
- `com.91wan.marklook.markdown-alias`
- `com.91wan.marklook.mdx`

Initial extensions:

- `.md`
- `.markdown`
- `.mdown`
- `.mkd`
- `.mkdn`
- `.mdx`
- `.rmd`
- `.qmd`

The host app imports `net.daringfireball.markdown` for `.md` and `.markdown`, exports narrow fallback UTIs for `.mdown`, `.mkd`, `.mkdn`, and MDX, and imports the vendor UTIs for R Markdown and Quarto. The imported Markdown parent conforms to `public.plain-text`, so child declarations inherit a system-declared text conformance without advertising the broad parent to Quick Look. Diagnostics reports extension recognition separately from the selected file's exact Quick Look UTI match; a known suffix or matching ancestor alone is not evidence that Finder can route the file to MarkLook.
