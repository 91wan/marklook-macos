import Cocoa

final class PreviewHTMLView: NSView {
    init(fileName: String, filePath: String, detail: String) {
        super.init(frame: .zero)
        buildView(fileName: fileName, filePath: filePath, detail: detail)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func buildView(fileName: String, filePath: String, detail: String) {
        wantsLayer = true
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

        let title = NSTextField(labelWithString: fileName)
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        title.textColor = .labelColor
        title.lineBreakMode = .byTruncatingMiddle

        let path = NSTextField(labelWithString: filePath)
        path.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        path.textColor = .secondaryLabelColor
        path.lineBreakMode = .byTruncatingMiddle

        let detailView = NSTextField(labelWithString: detail)
        detailView.font = .systemFont(ofSize: 14)
        detailView.textColor = .secondaryLabelColor
        detailView.maximumNumberOfLines = 0

        let stack = NSStackView(views: [title, path, detailView])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            title.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -64),
            path.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -64),
            detailView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -64)
        ])
    }
}
