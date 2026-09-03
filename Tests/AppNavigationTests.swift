import XCTest
@testable import MacGadgets

final class AppNavigationTests: XCTestCase {
    @MainActor
    func testRouterStartsAtChineseConversionAndCanSelectEveryTool() {
        let router = AppRouter()

        XCTAssertEqual(router.selectedTool, .chineseConversion)
        for tool in ToolKind.allCases {
            router.select(tool)
            XCTAssertEqual(router.selectedTool, tool)
        }
    }

    @MainActor
    func testRevealSelectsToolAndRequestsWindowWhenNoWindowIsRegistered() {
        var activationCount = 0
        let router = AppRouter { activationCount += 1 }
        var openRequestCount = 0

        router.reveal(.jsonDiff) {
            openRequestCount += 1
        }

        XCTAssertEqual(router.selectedTool, .jsonDiff)
        XCTAssertEqual(openRequestCount, 1)
        XCTAssertEqual(activationCount, 0)
    }

    @MainActor
    func testRevealUsesExistingWindowWithoutRequestingAnotherOne() {
        var activationCount = 0
        var openRequestCount = 0
        let router = AppRouter { activationCount += 1 }
        let window = TestAppWindow(isMiniaturized: false)
        router.registerMainWindow(window)

        router.reveal(.pdfMerge) {
            openRequestCount += 1
        }

        XCTAssertEqual(router.selectedTool, .pdfMerge)
        XCTAssertEqual(openRequestCount, 0)
        XCTAssertEqual(activationCount, 1)
        XCTAssertEqual(window.makeKeyAndOrderFrontCount, 1)
        XCTAssertEqual(window.deminiaturizeCount, 0)
    }

    @MainActor
    func testRevealRestoresAMinimizedWindow() {
        var activationCount = 0
        let router = AppRouter { activationCount += 1 }
        let window = TestAppWindow(isMiniaturized: true)
        router.registerMainWindow(window)

        router.reveal(.clipboardHistory) {
            XCTFail("A registered window must be reused")
        }

        XCTAssertEqual(activationCount, 1)
        XCTAssertEqual(window.deminiaturizeCount, 1)
        XCTAssertEqual(window.makeKeyAndOrderFrontCount, 1)
        XCTAssertFalse(window.isMiniaturized)
    }

    @MainActor
    func testNewlyRegisteredWindowFulfillsPendingRevealRequest() {
        var activationCount = 0
        var openRequestCount = 0
        let router = AppRouter { activationCount += 1 }

        router.reveal(.imageStitch) {
            openRequestCount += 1
        }

        let recreatedWindow = TestAppWindow(isMiniaturized: false)
        router.registerMainWindow(recreatedWindow)

        XCTAssertEqual(openRequestCount, 1)
        XCTAssertEqual(activationCount, 1)
        XCTAssertEqual(recreatedWindow.makeKeyAndOrderFrontCount, 1)
    }

    func testMenuBarToolListContainsEveryToolExactlyOnce() {
        XCTAssertEqual(ToolKind.pinyinSorted.count, ToolKind.allCases.count)
        XCTAssertEqual(Set(ToolKind.pinyinSorted), Set(ToolKind.allCases))
    }
}

@MainActor
private final class TestAppWindow: AppWindowControlling {
    var isMiniaturized: Bool
    private(set) var deminiaturizeCount = 0
    private(set) var makeKeyAndOrderFrontCount = 0

    init(isMiniaturized: Bool) {
        self.isMiniaturized = isMiniaturized
    }

    func deminiaturize(_ sender: Any?) {
        isMiniaturized = false
        deminiaturizeCount += 1
    }

    func makeKeyAndOrderFront(_ sender: Any?) {
        makeKeyAndOrderFrontCount += 1
    }
}
