import CoreGraphics
import Testing
@testable import LiminalLacuna

@Test
func panelWidthTracksActualItemWidths() {
    let width = PanelLayoutMetrics.width(
        itemWidths: [34, 38, 76, 47],
        spacing: 6,
        horizontalPadding: 10,
        emptyWidth: 180,
        maximumWidth: 1_000
    )
    #expect(width == 233)
}

@Test
func panelWidthUsesEmptyStateWidth() {
    let width = PanelLayoutMetrics.width(
        itemWidths: [],
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
        itemWidths: Array(repeating: 34, count: 40),
        spacing: 6,
        horizontalPadding: 10,
        emptyWidth: 180,
        maximumWidth: 900
    )
    #expect(width == 900)
}

@Test
func menuBarWindowMatcherAcceptsTheSlotAroundTheAXImageFrame() {
    let itemFrame = CGRect(x: 940, y: 4, width: 22, height: 22)
    let windowFrame = CGRect(x: 932, y: 0, width: 38, height: 30)

    #expect(MenuBarWindowMatcher.score(itemFrame: itemFrame, windowFrame: windowFrame) != nil)
}

@Test
func menuBarWindowMatcherRejectsAnAdjacentSlot() {
    let itemFrame = CGRect(x: 940, y: 4, width: 22, height: 22)
    let adjacentWindowFrame = CGRect(x: 970, y: 0, width: 32, height: 30)

    #expect(MenuBarWindowMatcher.score(itemFrame: itemFrame, windowFrame: adjacentWindowFrame) == nil)
}
