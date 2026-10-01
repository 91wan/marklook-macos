struct MarkdownFenceCase: Sendable {
    let name: String
    let source: String
    let expectedCodeHTML: String?
    let expectedHeading: String?
}

enum MarkdownFenceCases {
    static let all: [MarkdownFenceCase] = [
        .init(
            name: "minimum backtick fence",
            source: "```\n## Hidden\n<script>&code</script>\n```\n## Visible",
            expectedCodeHTML: "<pre><code>## Hidden\n&lt;script&gt;&amp;code&lt;/script&gt;</code></pre>",
            expectedHeading: "Visible"
        ),
        .init(
            name: "minimum tilde fence with info",
            source: "~~~swift\n## Hidden\n<script>&code</script>\n~~~\n## Visible",
            expectedCodeHTML: "<pre><code class=\"language-swift\">## Hidden\n&lt;script&gt;&amp;code&lt;/script&gt;</code></pre>",
            expectedHeading: "Visible"
        ),
        .init(
            name: "two backticks are not a fence",
            source: "``\n## Visible",
            expectedCodeHTML: nil,
            expectedHeading: "Visible"
        ),
        .init(
            name: "two tildes are not a fence",
            source: "~~\n## Visible",
            expectedCodeHTML: nil,
            expectedHeading: "Visible"
        ),
        .init(
            name: "longer backtick opening with equal closer",
            source: "````\n## Hidden\n<script>&code</script>\n````\n## Visible",
            expectedCodeHTML: "<pre><code>## Hidden\n&lt;script&gt;&amp;code&lt;/script&gt;</code></pre>",
            expectedHeading: "Visible"
        ),
        .init(
            name: "longer tilde opening with longer closer",
            source: "~~~~~\n## Hidden\n<script>&code</script>\n~~~~~~\n## Visible",
            expectedCodeHTML: "<pre><code>## Hidden\n&lt;script&gt;&amp;code&lt;/script&gt;</code></pre>",
            expectedHeading: "Visible"
        ),
        .init(
            name: "opening whitespace and info are trimmed",
            source: " \t``` \t swift \t \n## Hidden\n<script>&code</script>\n```\n## Visible",
            expectedCodeHTML: "<pre><code class=\"language-swift\">## Hidden\n&lt;script&gt;&amp;code&lt;/script&gt;</code></pre>",
            expectedHeading: "Visible"
        ),
        .init(
            name: "tilde does not close backtick fence",
            source: "```\n## Hidden\n~~~\n## Still code\n```\n## Visible",
            expectedCodeHTML: "<pre><code>## Hidden\n~~~\n## Still code</code></pre>",
            expectedHeading: "Visible"
        ),
        .init(
            name: "backtick does not close tilde fence",
            source: "~~~\n## Hidden\n```\n## Still code\n~~~\n## Visible",
            expectedCodeHTML: "<pre><code>## Hidden\n```\n## Still code</code></pre>",
            expectedHeading: "Visible"
        ),
        .init(
            name: "short backtick closer remains code",
            source: "````\n## Hidden\n```\n## Still code\n````\n## Visible",
            expectedCodeHTML: "<pre><code>## Hidden\n```\n## Still code</code></pre>",
            expectedHeading: "Visible"
        ),
        .init(
            name: "short tilde closer remains code",
            source: "~~~~\n## Hidden\n~~~\n## Still code\n~~~~\n## Visible",
            expectedCodeHTML: "<pre><code>## Hidden\n~~~\n## Still code</code></pre>",
            expectedHeading: "Visible"
        ),
        .init(
            name: "backtick closer with info remains code",
            source: "```\n## Hidden\n```swift\n## Still code\n```\n## Visible",
            expectedCodeHTML: "<pre><code>## Hidden\n```swift\n## Still code</code></pre>",
            expectedHeading: "Visible"
        ),
        .init(
            name: "tilde closer with info remains code",
            source: "~~~\n## Hidden\n~~~swift\n## Still code\n~~~\n## Visible",
            expectedCodeHTML: "<pre><code>## Hidden\n~~~swift\n## Still code</code></pre>",
            expectedHeading: "Visible"
        ),
        .init(
            name: "backtick closer accepts whitespace-only info",
            source: "```\n## Hidden\n<script>&code</script>\n \t``` \t \n## Visible",
            expectedCodeHTML: "<pre><code>## Hidden\n&lt;script&gt;&amp;code&lt;/script&gt;</code></pre>",
            expectedHeading: "Visible"
        ),
        .init(
            name: "tilde closer accepts whitespace-only info",
            source: "~~~\n## Hidden\n<script>&code</script>\n \t~~~ \t \n## Visible",
            expectedCodeHTML: "<pre><code>## Hidden\n&lt;script&gt;&amp;code&lt;/script&gt;</code></pre>",
            expectedHeading: "Visible"
        ),
        .init(
            name: "unterminated backtick fence",
            source: "```\n## Hidden\n<script>&code</script>\n## Visible",
            expectedCodeHTML: "<pre><code>## Hidden\n&lt;script&gt;&amp;code&lt;/script&gt;\n## Visible</code></pre>",
            expectedHeading: nil
        ),
        .init(
            name: "unterminated tilde fence",
            source: "~~~\n## Hidden\n<script>&code</script>\n## Visible",
            expectedCodeHTML: "<pre><code>## Hidden\n&lt;script&gt;&amp;code&lt;/script&gt;\n## Visible</code></pre>",
            expectedHeading: nil
        ),
        .init(
            name: "backticks remain permitted in opening info",
            source: "``` swift`extra \n## Hidden\n<script>&code</script>\n```\n## Visible",
            expectedCodeHTML: "<pre><code class=\"language-swift\">## Hidden\n&lt;script&gt;&amp;code&lt;/script&gt;</code></pre>",
            expectedHeading: "Visible"
        )
    ]
}
