import Testing
@testable import LiminalLacuna

@Test
func panelWidthTracksItemCount() {
    let width = PanelLayoutMetrics.width(
        itemCount: 4,
        itemWidth: 34,
        spacing: 6,
        horizontalPadding: 10,
        emptyWidth: 180,
        maximumWidth: 1_000
    )
    #expect(width == 174)
}

@Test
func panelWidthUsesEmptyStateWidth() {
    let width = PanelLayoutMetrics.width(
        itemCount: 0,
        itemWidth: 34,
        spacing: 6,
        horizontalPadding: 10,
        emptyWidth: 180,
        maximumWidth: 1_000
    )
    #expect(width == 180)
}

@Test
func panelWidthDoesNotExceedScreen() {
    let width = PanelLayoutMetrics.width(
        itemCount: 40,
        itemWidth: 34,
        spacing: 6,
        horizontalPadding: 10,
        emptyWidth: 180,
        maximumWidth: 900
    )
    #expect(width == 900)
}
