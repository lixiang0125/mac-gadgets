import AppKit
import SwiftUI
import XCTest
@testable import MacGadgets

final class FeatureViewSmokeTests: TemporaryDirectoryTestCase {
    @MainActor
    func testEveryToolViewBuildsAndLaysOutWithIsolatedDependencies() {
        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name("MacGadgetsViewTests.\(UUID().uuidString)")
        )
        defer { pasteboard.releaseGlobally() }

        let store = ClipboardHistoryStore(
            storageURL: temporaryDirectory.appendingPathComponent("view-history.json"),
            pasteboard: pasteboard,
            startsMonitoring: false
        )
        for language in AppLanguage.allCases {
            let localization = LocalizationStore(
                language: language,
                resourceDirectory: testLocaleDirectory,
                userDefaults: nil
            )
            let views: [(tool: ToolKind, view: AnyView)] = [
                (.clipboardHistory, AnyView(ClipboardHistoryView())),
                (.pdfMerge, AnyView(PDFMergeView())),
                (.imageStitch, AnyView(ImageStitchView())),
                (.imagePDFConversion, AnyView(ImagePDFConversionView())),
                (.jsonDiff, AnyView(JSONDiffView())),
                (.jsonFormatter, AnyView(JSONFormatterView())),
                (.chineseConversion, AnyView(ChineseConversionView()))
            ]

            for item in views {
                let hostingView = NSHostingView(
                    rootView: item.view
                        .environmentObject(store)
                        .environmentObject(localization)
                )
                hostingView.frame = NSRect(x: 0, y: 0, width: 1_020, height: 680)
                hostingView.layoutSubtreeIfNeeded()

                XCTAssertGreaterThan(
                    hostingView.fittingSize.width,
                    0,
                    "\(item.tool.rawValue) should lay out in \(language.rawValue)"
                )
                XCTAssertGreaterThan(
                    hostingView.fittingSize.height,
                    0,
                    "\(item.tool.rawValue) should lay out in \(language.rawValue)"
                )
            }
        }

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: temporaryDirectory.appendingPathComponent("view-history.json").path
            )
        )
    }
}
