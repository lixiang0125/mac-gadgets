import Foundation

enum ReleaseDocsError: Error, CustomStringConvertible {
    case invalid(String)
    var description: String { switch self { case let .invalid(message): return message } }
}

// This script intentionally stays outside the application target. --root allows
// regression tests to use isolated fixture repositories without modifying real docs.
do {
    let args = Array(CommandLine.arguments.dropFirst())
    guard let mode = args.first, ["--check", "--write", "--validate"].contains(mode),
          args.count == 1 || (args.count == 3 && args[1] == "--root") else {
        throw ReleaseDocsError.invalid("Usage: swift scripts/update-release-docs.swift --check|--write|--validate [--root PATH]")
    }
    let root = args.count == 3
        ? URL(fileURLWithPath: args[2], isDirectory: true)
        : URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let plist = try PropertyListSerialization.propertyList(
        from: Data(contentsOf: root.appendingPathComponent("Packaging/Info.plist")), format: nil
    ) as? [String: Any]
    guard let version = plist?["CFBundleShortVersionString"] as? String,
          version.range(of: #"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$"#, options: .regularExpression) != nil,
          let build = plist?["CFBundleVersion"] as? String, let buildNumber = Int(build), buildNumber > 0 else {
        throw ReleaseDocsError.invalid("Info.plist must contain a valid major.minor.patch version and a positive build number.")
    }

    let changelog = try String(contentsOf: root.appendingPathComponent("CHANGELOG.md"), encoding: .utf8)
    let headings = try NSRegularExpression(pattern: #"(?m)^## \[([0-9]+\.[0-9]+\.[0-9]+)\] - ([0-9]{4}-[0-9]{2}-[0-9]{2})$"#)
    let matches = headings.matches(in: changelog, range: NSRange(changelog.startIndex..., in: changelog))
    let original = changelog as NSString
    guard let latest = matches.first, original.substring(with: latest.range(at: 1)) == version,
          matches.filter({ original.substring(with: $0.range(at: 1)) == version }).count == 1 else {
        throw ReleaseDocsError.invalid("CHANGELOG.md must start with a unique ## [\(version)] - YYYY-MM-DD release entry.")
    }
    let date = original.substring(with: latest.range(at: 2))
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.isLenient = false
    guard let parsed = formatter.date(from: date), formatter.string(from: parsed) == date else {
        throw ReleaseDocsError.invalid("Invalid release date in CHANGELOG.md: \(date)")
    }
    let sectionEnd = matches.dropFirst().first?.range.location ?? original.length
    let section = original.substring(with: NSRange(location: NSMaxRange(latest.range), length: sectionEnd - NSMaxRange(latest.range)))
    guard section.split(separator: "\n").contains(where: { $0.hasPrefix("- ") && !$0.dropFirst(2).trimmingCharacters(in: .whitespaces).isEmpty }) else {
        throw ReleaseDocsError.invalid("The \(version) changelog entry must describe at least one change.")
    }

    let start = "<!-- release-download:start -->"
    let end = "<!-- release-download:end -->"
    let download = "release/Mac-Gadgets-\(version).dmg"
    let labels = [("README.md", "下载 Mac Gadgets v\(version) DMG"),
                  ("README.en.md", "Download Mac Gadgets v\(version) DMG")]
    // Validate both files before writing either, including during the pre-build check.
    var updates: [(URL, String)] = []
    for (name, label) in labels {
        let url = root.appendingPathComponent(name)
        let text = try String(contentsOf: url, encoding: .utf8)
        guard text.components(separatedBy: start).count == 2, text.components(separatedBy: end).count == 2,
              let opening = text.range(of: start), let closing = text.range(of: end), opening.upperBound <= closing.lowerBound else {
            throw ReleaseDocsError.invalid("\(name) needs exactly one ordered release-download marker pair.")
        }
        let body = opening.upperBound..<closing.lowerBound
        let expected = "\n[\(label)](\(download))\n"
        if mode == "--check", String(text[body]) != expected {
            throw ReleaseDocsError.invalid("\(name) has a stale download link. Run swift scripts/update-release-docs.swift --write.")
        }
        updates.append((url, text.replacingCharacters(in: body, with: expected)))
    }
    if mode == "--write" {
        for (url, text) in updates { try text.write(to: url, atomically: true, encoding: .utf8) }
    }
    print("Release documentation \(mode): v\(version) (build \(buildNumber))")
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
