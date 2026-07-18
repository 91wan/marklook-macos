import Foundation

enum PreviewErrorHTMLDocument {
    static func html(title: String, message: String) -> String {
        let safeTitle = escape(redactFullPaths(title))
        let safeMessage = escape(redactFullPaths(message))

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'">
          <style>
            :root {
              color-scheme: light dark;
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", Helvetica, Arial, sans-serif;
              background: Canvas;
              color: CanvasText;
            }
            body {
              margin: 0;
              min-height: 100vh;
              display: grid;
              place-items: center;
            }
            main {
              box-sizing: border-box;
              width: min(680px, calc(100vw - 64px));
              padding: 32px;
              border: 1px solid color-mix(in srgb, CanvasText 14%, transparent);
              border-radius: 8px;
              background: color-mix(in srgb, Canvas 94%, CanvasText 6%);
            }
            h1 {
              margin: 0 0 12px;
              font-size: 22px;
              line-height: 1.25;
              font-weight: 650;
            }
            p {
              margin: 0;
              font-size: 14px;
              line-height: 1.55;
              overflow-wrap: anywhere;
              color: color-mix(in srgb, CanvasText 76%, transparent);
            }
          </style>
        </head>
        <body>
          <main>
            <h1>\(safeTitle)</h1>
            <p>\(safeMessage)</p>
          </main>
        </body>
        </html>
        """
    }

    private static func escape(_ text: String) -> String {
        var escaped = ""
        escaped.reserveCapacity(text.count)

        for character in text {
            switch character {
            case "&":
                escaped += "&amp;"
            case "<":
                escaped += "&lt;"
            case ">":
                escaped += "&gt;"
            case "\"":
                escaped += "&quot;"
            case "'":
                escaped += "&#39;"
            default:
                escaped.append(character)
            }
        }

        return escaped
    }

    private static func redactFullPaths(_ text: String) -> String {
        let text = redactFileURLs(in: text)
        var output = ""
        var cursor = text.startIndex

        while let slash = text[cursor...].firstIndex(of: "/") {
            output.append(contentsOf: text[cursor..<slash])

            if slash > text.startIndex {
                let previous = text[text.index(before: slash)]
                if !previous.isWhitespace && previous != "\"" && previous != "'" && previous != "(" {
                    output.append("/")
                    cursor = text.index(after: slash)
                    continue
                }
            }

            var end = slash
            while end < text.endIndex,
                  !text[end].isWhitespace,
                  text[end] != ":" {
                end = text.index(after: end)
            }

            let token = String(text[slash..<end])
            output.append(URL(fileURLWithPath: token).lastPathComponent)
            cursor = end
        }

        output.append(contentsOf: text[cursor...])
        return output
    }

    private static func redactFileURLs(in text: String) -> String {
        var output = ""
        var cursor = text.startIndex

        while let scheme = text.range(
            of: "file://",
            options: .caseInsensitive,
            range: cursor..<text.endIndex
        ) {
            output.append(contentsOf: text[cursor..<scheme.lowerBound])

            var end = scheme.upperBound
            while end < text.endIndex {
                let character = text[end]
                if character.isWhitespace
                    || character == "\""
                    || character == "'"
                    || character == ")"
                    || character == "]"
                    || character == ">"
                    || character == ":" {
                    break
                }
                end = text.index(after: end)
            }

            let token = String(text[scheme.lowerBound..<end])
            if let url = URL(string: token), url.isFileURL, !url.lastPathComponent.isEmpty {
                output.append(url.lastPathComponent)
            } else {
                output.append("<redacted-file>")
            }
            cursor = end
        }

        output.append(contentsOf: text[cursor...])
        return output
    }
}
