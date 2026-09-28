import CoreGraphics

struct PanelLayoutMetrics {
    static func width(
        itemCount: Int,
        itemWidth: CGFloat,
        spacing: CGFloat,
        horizontalPadding: CGFloat,
        emptyWidth: CGFloat,
        maximumWidth: CGFloat
    ) -> CGFloat {
        guard itemCount > 0 else {
            return min(emptyWidth, maximumWidth)
        }

        let contentWidth = CGFloat(itemCount) * itemWidth
            + CGFloat(itemCount - 1) * spacing
            + horizontalPadding * 2
        return min(contentWidth, maximumWidth)
    }
}
