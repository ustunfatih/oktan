import XCTest

final class ReviewSimulationUITests: XCTestCase {
    func testGoldenPathNavigationAndBasics() {
        let app = XCUIApplication()
        app.launch()

        // Tab switching
        app.tabBars.buttons["Home"].tap()
        app.tabBars.buttons["Search"].tap()
        app.tabBars.buttons["Settings"].tap()
        app.tabBars.buttons["Home"].tap()

        // Navigate into example detail if it exists
        let detailCell = app.tables.cells.staticTexts["Detail Example"]
        if detailCell.exists {
            detailCell.tap()
            // Back should exist
            XCTAssertTrue(app.navigationBars.buttons.element(boundBy: 0).exists)
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // Search interaction
        app.tabBars.buttons["Search"].tap()
        let searchField = app.searchFields.element(boundBy: 0)
        if searchField.exists {
            searchField.tap()
            searchField.typeText("Al")
        }
    }
}
