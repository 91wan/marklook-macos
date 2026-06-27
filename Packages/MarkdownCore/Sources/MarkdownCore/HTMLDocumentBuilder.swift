import Foundation

struct HTMLDocumentBuilder: Sendable {
    init() {}

    func build(title: String, trustedBodyHTML: String) -> String {
        let safeTitle = ResourcePolicy.escapeHTML(title)

        return """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src 'none'; style-src 'unsafe-inline';">
        <title>\(safeTitle)</title>
        <style>
        :root {
          color-scheme: light dark;
          font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", Helvetica, Arial, sans-serif;
          line-height: 1.55;
        }
        body {
          margin: 0;
          padding: 32px;
          color: CanvasText;
          background: Canvas;
        }
        .markdown-body {
          max-width: 860px;
          margin: 0 auto;
        }
        pre {
          overflow-x: auto;
          padding: 12px;
          border: 1px solid color-mix(in srgb, CanvasText 16%, transparent);
          border-radius: 6px;
        }
        code {
          font-family: "SF Mono", Menlo, Consolas, monospace;
          font-size: 0.94em;
        }
        table {
          border-collapse: collapse;
          width: 100%;
        }
        th, td {
          border: 1px solid color-mix(in srgb, CanvasText 18%, transparent);
          padding: 6px 8px;
          text-align: left;
        }
        blockquote {
          margin-left: 0;
          padding-left: 14px;
          border-left: 3px solid color-mix(in srgb, CanvasText 24%, transparent);
        }
        .blocked-resource {
          display: inline-block;
          padding: 2px 6px;
          border: 1px solid color-mix(in srgb, CanvasText 18%, transparent);
          border-radius: 4px;
          font-size: 0.92em;
        }
        .markdown-link {
          text-decoration: underline;
          text-decoration-style: dotted;
        }
        .render-warning {
          padding: 8px 10px;
          border: 1px solid color-mix(in srgb, CanvasText 18%, transparent);
          border-radius: 4px;
        }
        </style>
        </head>
        <body>
        <main class="markdown-body">
        \(trustedBodyHTML)
        </main>
        </body>
        </html>
        """
    }
}
