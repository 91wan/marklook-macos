import AppKit

struct MarkdownThumbnailPalette: Equatable {
    let canvas: NSColor
    let card: NSColor
    let border: NSColor
    let badge: NSColor
    let badgeText: NSColor
    let primaryText: NSColor
    let secondaryText: NSColor

    static let v0Light = MarkdownThumbnailPalette(
        canvas: NSColor(srgbRed: 0.965, green: 0.970, blue: 0.980, alpha: 1),
        card: NSColor(srgbRed: 1.000, green: 1.000, blue: 1.000, alpha: 1),
        border: NSColor(srgbRed: 0.820, green: 0.840, blue: 0.870, alpha: 1),
        badge: NSColor(srgbRed: 0.000, green: 0.380, blue: 0.920, alpha: 1),
        badgeText: NSColor(srgbRed: 1.000, green: 1.000, blue: 1.000, alpha: 1),
        primaryText: NSColor(srgbRed: 0.090, green: 0.105, blue: 0.125, alpha: 1),
        secondaryText: NSColor(srgbRed: 0.360, green: 0.390, blue: 0.430, alpha: 1)
    )
}
