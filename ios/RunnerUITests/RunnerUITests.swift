import XCTest
import patrol

@MainActor
final class RunnerUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testBundle() async throws {
        let app = XCUIApplication()
        app.launch()
        let server = Patrol.appServer()
        await server.main()
    }
}
