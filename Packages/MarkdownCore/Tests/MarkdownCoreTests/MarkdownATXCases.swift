struct MarkdownATXTOCItem: Sendable {
    let title: String
    let level: Int
    let id: String
}

struct MarkdownATXCase: Sendable {
    let name: String
    let source: String
    let expectedRendererBodyHTML: String
    let expectedRendererTOC: [MarkdownATXTOCItem]
    let expectedThumbnailHeading: String?
}

enum MarkdownATXCases {
    static let all: [MarkdownATXCase] = [
        .init(
            name: "H1",
            source: "# One",
            expectedRendererBodyHTML: "<h1 id=\"one\">One</h1>",
            expectedRendererTOC: [.init(title: "One", level: 1, id: "one")],
            expectedThumbnailHeading: "One"
        ),
        .init(
            name: "H2",
            source: "## Two",
            expectedRendererBodyHTML: "<h2 id=\"two\">Two</h2>",
            expectedRendererTOC: [.init(title: "Two", level: 2, id: "two")],
            expectedThumbnailHeading: "Two"
        ),
        .init(
            name: "H3 enters Renderer TOC but not Thumbnail",
            source: "### Three",
            expectedRendererBodyHTML: "<h3 id=\"three\">Three</h3>",
            expectedRendererTOC: [.init(title: "Three", level: 3, id: "three")],
            expectedThumbnailHeading: nil
        ),
        .init(
            name: "H4 is outside TOC and Thumbnail",
            source: "#### Four",
            expectedRendererBodyHTML: "<h4 id=\"four\">Four</h4>",
            expectedRendererTOC: [],
            expectedThumbnailHeading: nil
        ),
        .init(
            name: "H5 is outside TOC and Thumbnail",
            source: "##### Five",
            expectedRendererBodyHTML: "<h5 id=\"five\">Five</h5>",
            expectedRendererTOC: [],
            expectedThumbnailHeading: nil
        ),
        .init(
            name: "H6 is outside TOC and Thumbnail",
            source: "###### Six",
            expectedRendererBodyHTML: "<h6 id=\"six\">Six</h6>",
            expectedRendererTOC: [],
            expectedThumbnailHeading: nil
        ),
        .init(
            name: "seven hashes are not ATX",
            source: "####### Seven",
            expectedRendererBodyHTML: "<p>####### Seven</p>",
            expectedRendererTOC: [],
            expectedThumbnailHeading: nil
        ),
        .init(
            name: "missing separator space",
            source: "##Missing",
            expectedRendererBodyHTML: "<p>##Missing</p>",
            expectedRendererTOC: [],
            expectedThumbnailHeading: nil
        ),
        .init(
            name: "tab is not an ASCII space separator",
            source: "##\tTabbed",
            expectedRendererBodyHTML: "<p>##\tTabbed</p>",
            expectedRendererTOC: [],
            expectedThumbnailHeading: nil
        ),
        .init(
            name: "whitespace-only title is rejected",
            source: "##   \t",
            expectedRendererBodyHTML: "<p>##</p>",
            expectedRendererTOC: [],
            expectedThumbnailHeading: nil
        ),
        .init(
            name: "indentation and trailing whitespace are trimmed",
            source: " \t  ## Indented \t ",
            expectedRendererBodyHTML: "<h2 id=\"indented\">Indented</h2>",
            expectedRendererTOC: [.init(title: "Indented", level: 2, id: "indented")],
            expectedThumbnailHeading: "Indented"
        ),
        .init(
            name: "Foundation whitespace trim includes nonbreaking space",
            source: "\u{00A0}## \u{00A0}Wide\u{00A0}",
            expectedRendererBodyHTML: "<h2 id=\"wide\">Wide</h2>",
            expectedRendererTOC: [.init(title: "Wide", level: 2, id: "wide")],
            expectedThumbnailHeading: "Wide"
        ),
        .init(
            name: "Renderer escapes but Thumbnail keeps literal title",
            source: "# <tag> & \"quoted\"",
            expectedRendererBodyHTML: "<h1 id=\"tag-quoted\">&lt;tag&gt; &amp; &quot;quoted&quot;</h1>",
            expectedRendererTOC: [.init(title: "<tag> & \"quoted\"", level: 1, id: "tag-quoted")],
            expectedThumbnailHeading: "<tag> & \"quoted\""
        ),
        .init(
            name: "Thumbnail skips H3 through H6 for a later H2",
            source: "### Three\n#### Four\n##### Five\n###### Six\n## Visible",
            expectedRendererBodyHTML: "<h3 id=\"three\">Three</h3>\n<h4 id=\"four\">Four</h4>\n<h5 id=\"five\">Five</h5>\n<h6 id=\"six\">Six</h6>\n<h2 id=\"visible\">Visible</h2>",
            expectedRendererTOC: [
                .init(title: "Three", level: 3, id: "three"),
                .init(title: "Visible", level: 2, id: "visible")
            ],
            expectedThumbnailHeading: "Visible"
        ),
        .init(
            name: "closing hashes remain in Renderer title",
            source: "# Kept ###",
            expectedRendererBodyHTML: "<h1 id=\"kept\">Kept ###</h1>",
            expectedRendererTOC: [.init(title: "Kept ###", level: 1, id: "kept")],
            expectedThumbnailHeading: "Kept"
        ),
        .init(
            name: "Thumbnail trims hashes at both title edges",
            source: "## ###Wrapped###",
            expectedRendererBodyHTML: "<h2 id=\"wrapped\">###Wrapped###</h2>",
            expectedRendererTOC: [.init(title: "###Wrapped###", level: 2, id: "wrapped")],
            expectedThumbnailHeading: "Wrapped"
        ),
        .init(
            name: "only Thumbnail collapses internal whitespace",
            source: "#   A    spaced\t heading   ",
            expectedRendererBodyHTML: "<h1 id=\"a-spaced-heading\">A    spaced\t heading</h1>",
            expectedRendererTOC: [.init(title: "A    spaced\t heading", level: 1, id: "a-spaced-heading")],
            expectedThumbnailHeading: "A spaced heading"
        ),
        .init(
            name: "projected-empty hash title does not stop Thumbnail scan",
            source: "# ###\n## Valid",
            expectedRendererBodyHTML: "<h1 id=\"section\">###</h1>\n<h2 id=\"valid\">Valid</h2>",
            expectedRendererTOC: [
                .init(title: "###", level: 1, id: "section"),
                .init(title: "Valid", level: 2, id: "valid")
            ],
            expectedThumbnailHeading: "Valid"
        ),
        .init(
            name: "first H2 wins over later H1 in Thumbnail",
            source: "## First\n# Later",
            expectedRendererBodyHTML: "<h2 id=\"first\">First</h2>\n<h1 id=\"later\">Later</h1>",
            expectedRendererTOC: [
                .init(title: "First", level: 2, id: "first"),
                .init(title: "Later", level: 1, id: "later")
            ],
            expectedThumbnailHeading: "First"
        ),
        .init(
            name: "ATX ends the preceding paragraph",
            source: "Lead paragraph\n## Boundary\nTail paragraph",
            expectedRendererBodyHTML: "<p>Lead paragraph</p>\n<h2 id=\"boundary\">Boundary</h2>\n<p>Tail paragraph</p>",
            expectedRendererTOC: [.init(title: "Boundary", level: 2, id: "boundary")],
            expectedThumbnailHeading: "Boundary"
        ),
        .init(
            name: "ATX is not reinterpreted as Setext",
            source: "## ATX\n---",
            expectedRendererBodyHTML: "<h2 id=\"atx\">ATX</h2>\n<hr>",
            expectedRendererTOC: [.init(title: "ATX", level: 2, id: "atx")],
            expectedThumbnailHeading: "ATX"
        ),
        .init(
            name: "non-ATX hash text remains eligible for Setext",
            source: "#NoSpace\n===\n## Later",
            expectedRendererBodyHTML: "<h1 id=\"nospace\">#NoSpace</h1>\n<h2 id=\"later\">Later</h2>",
            expectedRendererTOC: [
                .init(title: "#NoSpace", level: 1, id: "nospace"),
                .init(title: "Later", level: 2, id: "later")
            ],
            expectedThumbnailHeading: "Later"
        ),
        .init(
            name: "Setext before ATX remains Renderer-only",
            source: "Setext\n===\n# ATX",
            expectedRendererBodyHTML: "<h1 id=\"setext\">Setext</h1>\n<h1 id=\"atx\">ATX</h1>",
            expectedRendererTOC: [
                .init(title: "Setext", level: 1, id: "setext"),
                .init(title: "ATX", level: 1, id: "atx")
            ],
            expectedThumbnailHeading: "ATX"
        ),
        .init(
            name: "fenced ATX is excluded until the closing fence",
            source: "```markdown\n# Hidden\n## Hidden too\n```\n## Visible",
            expectedRendererBodyHTML: "<pre><code class=\"language-markdown\"># Hidden\n## Hidden too</code></pre>\n<h2 id=\"visible\">Visible</h2>",
            expectedRendererTOC: [.init(title: "Visible", level: 2, id: "visible")],
            expectedThumbnailHeading: "Visible"
        )
    ]
}
