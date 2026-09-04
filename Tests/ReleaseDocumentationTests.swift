import Foundation
import XCTest

final class ReleaseDocumentationTests: TemporaryDirectoryTestCase {
    func testRepositoryReleaseVersionChangelogAndReadmeLinksAreConsistent() throws {
        let result = try run("--check", root: testRepositoryRoot)
        XCTAssertEqual(result.status, 0, result.output)
    }

    func testUpdatingBothLanguagesPreservesOtherContentAndIsIdempotent() throws {
        try fixture()
        let first = try run("--write")
        XCTAssertEqual(first.status, 0, first.output)
        let chinese = try read("README.md")
        let english = try read("README.en.md")
        XCTAssertTrue(chinese.contains("[下载 Mac Gadgets v0.2.1 DMG](release/Mac-Gadgets-0.2.1.dmg)"))
        XCTAssertTrue(english.contains("[Download Mac Gadgets v0.2.1 DMG](release/Mac-Gadgets-0.2.1.dmg)"))
        for text in [chinese, english] {
            XCTAssertTrue(text.hasPrefix("# Unchanged title\n\n"))
            XCTAssertTrue(text.hasSuffix("\n\nUnchanged instructions.\n"))
        }
        XCTAssertEqual(try run("--write").status, 0)
        XCTAssertEqual(try read("README.md"), chinese)
        XCTAssertEqual(try read("README.en.md"), english)
        XCTAssertEqual(try run("--check").status, 0)
    }

    func testStaleLinksFailCheckButPrebuildValidationAllowsAutomaticRefresh() throws {
        try fixture()
        XCTAssertNotEqual(try run("--check").status, 0)
        XCTAssertEqual(try run("--validate").status, 0)
        XCTAssertTrue(try read("README.md").contains("old.dmg"))
    }

    func testMissingCurrentChangelogEntryBlocksReleaseWithoutChangingDocs() throws {
        try fixture(changelog: "## [0.2.0] - 2026-09-04\n\n- Old release.\n")
        let original = try read("README.md")
        for mode in ["--validate", "--write", "--check"] {
            let result = try run(mode)
            XCTAssertNotEqual(result.status, 0)
            XCTAssertTrue(result.output.contains("CHANGELOG.md"))
        }
        XCTAssertEqual(try read("README.md"), original)
    }

    func testEmptyDuplicateOrInvalidDateEntriesAreRejected() throws {
        let valid = "## [0.2.1] - 2026-09-05\n\n- Fixed a bug.\n"
        for changelog in ["## [0.2.1] - 2026-09-05\n\n### Fixed\n",
                          "## [0.2.1] - 2026-02-30\n\n- Invalid date.\n", valid + "\n" + valid] {
            try fixture(changelog: changelog)
            XCTAssertNotEqual(try run("--validate").status, 0, changelog)
        }
    }

    func testMalformedSecondReadmeDoesNotPartiallyUpdateFirstReadme() throws {
        try fixture()
        let original = try read("README.md")
        try "Missing markers".write(to: temporaryDirectory.appendingPathComponent("README.en.md"), atomically: true, encoding: .utf8)
        XCTAssertNotEqual(try run("--write").status, 0)
        XCTAssertEqual(try read("README.md"), original)
    }

    func testInvalidVersionCannotBecomeAnInstallerPath() throws {
        for version in ["../invalid", "0.2", "0.2.1\n", "01.2.1"] {
            try fixture(version: version)
            XCTAssertNotEqual(try run("--validate").status, 0, version)
        }
    }

    private func fixture(version: String = "0.2.1", changelog: String = "## [0.2.1] - 2026-09-05\n\n- Fixed a bug.\n") throws {
        let packaging = temporaryDirectory.appendingPathComponent("Packaging", isDirectory: true)
        try FileManager.default.createDirectory(at: packaging, withIntermediateDirectories: true)
        let plist = ["CFBundleShortVersionString": version, "CFBundleVersion": "4"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: packaging.appendingPathComponent("Info.plist"))
        try changelog.write(to: temporaryDirectory.appendingPathComponent("CHANGELOG.md"), atomically: true, encoding: .utf8)
        let readme = "# Unchanged title\n\n<!-- release-download:start -->\n[Old](old.dmg)\n<!-- release-download:end -->\n\nUnchanged instructions.\n"
        for name in ["README.md", "README.en.md"] {
            try readme.write(to: temporaryDirectory.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
    }

    private func read(_ name: String) throws -> String {
        try String(contentsOf: temporaryDirectory.appendingPathComponent(name), encoding: .utf8)
    }

    private func run(_ mode: String, root: URL? = nil) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = [testRepositoryRoot.appendingPathComponent("scripts/update-release-docs.swift").path,
                             mode, "--root", (root ?? temporaryDirectory!).path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
