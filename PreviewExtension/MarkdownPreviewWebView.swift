import Cocoa
import WebKit

final class MarkdownPreviewWebView: NSView {
    private let navigationDelegateProxy = PreviewNavigationDelegate()
    private let uiDelegateProxy = PreviewUIDelegate()
    private let webView: WKWebView

    override init(frame frameRect: NSRect) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: frameRect)
        buildView()
    }

    convenience init(html: String) {
        self.init(frame: .zero)
        load(html: html)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func load(html: String) {
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func buildView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

        webView.navigationDelegate = navigationDelegateProxy
        webView.uiDelegate = uiDelegateProxy
        webView.allowsMagnification = true
        webView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

enum PreviewNavigationPolicy {
    static func decision(for navigationType: WKNavigationType, requestURL: URL?) -> WKNavigationActionPolicy {
        switch navigationType {
        case .linkActivated, .formSubmitted, .formResubmitted:
            return .cancel
        default:
            break
        }

        guard let requestURL else {
            return .allow
        }

        if requestURL.absoluteString.lowercased() == "about:blank" {
            return .allow
        }

        return .cancel
    }
}

private final class PreviewNavigationDelegate: NSObject, WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(
            PreviewNavigationPolicy.decision(
                for: navigationAction.navigationType,
                requestURL: navigationAction.request.url
            )
        )
    }
}

private final class PreviewUIDelegate: NSObject, WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        nil
    }
}
