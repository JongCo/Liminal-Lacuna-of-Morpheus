import CoreGraphics

struct PanelLayoutMetrics {
    static func width(
        itemWidths: [CGFloat],
        spacing: CGFloat,
        horizontalPadding: CGFloat,
        emptyWidth: CGFloat,
        maximumWidth: CGFloat
    ) -> CGFloat {
        guard !itemWidths.isEmpty else {
            return min(emptyWidth, maximumWidth)
        }

        let contentWidth = itemWidths.reduce(0, +)
            + CGFloat(itemWidths.count - 1) * spacing
            + horizontalPadding * 2
        return min(contentWidth, maximumWidth)
    }
}
