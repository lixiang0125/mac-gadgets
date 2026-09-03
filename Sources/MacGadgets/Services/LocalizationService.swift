import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case simplifiedChinese = "zh-CN"
    case english = "en"

    var id: String { rawValue }
    var resourceFileName: String { "\(rawValue).json" }
    var displayNameKey: String {
        switch self {
        case .simplifiedChinese: "language.zh-CN"
        case .english: "language.en"
        }
    }

    var locale: Locale {
        switch self {
        case .simplifiedChinese: Locale(identifier: "zh_CN")
        case .english: Locale(identifier: "en_US")
        }
    }
}

enum LocalizationCatalogError: Error {
    case missingResource(String)
    case mismatchedKeys(language: AppLanguage, missing: Set<String>, extra: Set<String>)
}

struct LocalizationCatalog: Sendable {
    private let translations: [AppLanguage: [String: String]]

    init(directoryURL: URL) throws {
        var loaded: [AppLanguage: [String: String]] = [:]
        let decoder = JSONDecoder()

        for language in AppLanguage.allCases {
            let url = directoryURL.appendingPathComponent(language.resourceFileName)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw LocalizationCatalogError.missingResource(language.resourceFileName)
            }
            loaded[language] = try decoder.decode(
                [String: String].self,
                from: Data(contentsOf: url)
            )
        }

        let referenceKeys = Set(loaded[.simplifiedChinese]?.keys.map { $0 } ?? [])
        for language in AppLanguage.allCases {
            let languageKeys = Set(loaded[language]?.keys.map { $0 } ?? [])
            guard languageKeys == referenceKeys else {
                throw LocalizationCatalogError.mismatchedKeys(
                    language: language,
                    missing: referenceKeys.subtracting(languageKeys),
                    extra: languageKeys.subtracting(referenceKeys)
                )
            }
        }

        translations = loaded
    }

    static var empty: LocalizationCatalog {
        LocalizationCatalog(translations: [:])
    }

    var keys: Set<String> {
        Set(translations[.simplifiedChinese]?.keys.map { $0 } ?? [])
    }

    func text(
        _ key: String,
        language: AppLanguage,
        arguments: [CVarArg] = []
    ) -> String {
        guard !key.isEmpty else { return "" }
        let template = translations[language]?[key]
            ?? translations[.simplifiedChinese]?[key]
            ?? key
        guard !arguments.isEmpty else { return template }
        return String(format: template, locale: language.locale, arguments: arguments)
    }

    static func defaultDirectory(
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) -> URL? {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let candidates = [
            bundle.resourceURL?.appendingPathComponent("locale", isDirectory: true),
            URL(fileURLWithPath: fileManager.currentDirectoryPath)
                .appendingPathComponent("locale", isDirectory: true),
            sourceRoot.appendingPathComponent("locale", isDirectory: true)
        ].compactMap { $0 }

        return candidates.first { directory in
            AppLanguage.allCases.allSatisfy {
                fileManager.fileExists(
                    atPath: directory.appendingPathComponent($0.resourceFileName).path
                )
            }
        }
    }

    private init(translations: [AppLanguage: [String: String]]) {
        self.translations = translations
    }
}

protocol LocalizedMessageProviding: Error {
    var localizationKey: String { get }
    var localizationArguments: [CVarArg] { get }
}

extension LocalizedMessageProviding {
    var localizationArguments: [CVarArg] { [] }
}

@MainActor
final class LocalizationStore: ObservableObject {
    static let preferenceKey = "appLanguage"

    @Published private(set) var language: AppLanguage

    private let catalog: LocalizationCatalog
    private let userDefaults: UserDefaults?

    init(
        language: AppLanguage? = nil,
        resourceDirectory: URL? = LocalizationCatalog.defaultDirectory(),
        userDefaults: UserDefaults? = .standard
    ) {
        if let resourceDirectory,
           let loadedCatalog = try? LocalizationCatalog(directoryURL: resourceDirectory) {
            catalog = loadedCatalog
        } else {
            catalog = .empty
        }
        self.userDefaults = userDefaults

        if let language {
            self.language = language
        } else if let storedValue = userDefaults?.string(forKey: Self.preferenceKey),
                  let storedLanguage = AppLanguage(rawValue: storedValue) {
            self.language = storedLanguage
        } else {
            self.language = .simplifiedChinese
        }
    }

    func select(_ language: AppLanguage) {
        guard self.language != language else { return }
        self.language = language
        userDefaults?.set(language.rawValue, forKey: Self.preferenceKey)
    }

    func text(_ key: String, _ arguments: CVarArg...) -> String {
        catalog.text(key, language: language, arguments: arguments)
    }

    func errorMessage(for error: Error) -> String {
        guard let localizedError = error as? LocalizedMessageProviding else {
            return error.localizedDescription
        }
        return catalog.text(
            localizedError.localizationKey,
            language: language,
            arguments: localizedError.localizationArguments
        )
    }
}
