import Cocoa

final class PreviewErrorView: NSView {
    init(title: String, message: String) {
        super.init(frame: .zero)
        buildView(title: title, message: message)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func buildView(title: String, message: String) {
        wantsLayer = true
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

        let titleView = NSTextField(labelWithString: title)
        titleView.font = .systemFont(ofSize: 22, weight: .semibold)
        titleView.textColor = .labelColor

        let messageView = NSTextField(labelWithString: message)
        messageView.font = .systemFont(ofSize: 14)
        messageView.textColor = .secondaryLabelColor
        messageView.maximumNumberOfLines = 0

        let stack = NSStackView(views: [titleView, messageView])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            messageView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -64)
        ])
    }
}
