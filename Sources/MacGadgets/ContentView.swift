import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var localization: LocalizationStore
    @EnvironmentObject private var router: AppRouter
    @State private var searchText = ""
    @AppStorage("appearance") private var appearanceRawValue = AppAppearance.system.rawValue

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }

    private var filteredTools: [ToolKind] {
        ToolKind.filtered(matching: searchText) { localization.text($0) }
    }

    private var groupedTools: [(initial: String, tools: [ToolKind])] {
        Dictionary(grouping: filteredTools, by: \.pinyinInitial)
            .map { (initial: $0.key, tools: $0.value) }
            .sorted { $0.initial < $1.initial }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            AppTheme.accent,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(localization.text("app.name"))
                            .font(.headline)
                        Text(localization.text("app.toolCount", Int64(ToolKind.allCases.count)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 12)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(
                        localization.text("app.search.title"),
                        text: $searchText,
                        prompt: Text(localization.text("app.search.placeholder"))
                    )
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                                .frame(
                                    width: AppTheme.compactControlHitSize,
                                    height: AppTheme.compactControlHitSize
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(localization.text("app.search.clear"))
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .appGlassSurface(cornerRadius: 10, interactive: true)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

                List(selection: $router.selectedTool) {
                    ForEach(groupedTools, id: \.initial) { group in
                        Section(group.initial) {
                            ForEach(group.tools) { tool in
                                ToolSidebarRow(tool: tool, isSelected: router.selectedTool == tool)
                                    .tag(tool)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)

                HStack(spacing: 8) {
                    Label(localization.text("app.localOnly"), systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        Picker(localization.text("appearance.title"), selection: $appearanceRawValue) {
                            ForEach(AppAppearance.allCases) { item in
                                Label(localization.text(item.titleKey), systemImage: item.systemImage)
                                    .tag(item.rawValue)
                            }
                        }
                    } label: {
                        Label(localization.text("appearance.title"), systemImage: appearance.systemImage)
                            .labelStyle(.iconOnly)
                            .frame(
                                width: AppTheme.compactControlHitSize,
                                height: AppTheme.compactControlHitSize
                            )
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help(localization.text(
                        "appearance.help",
                        localization.text(appearance.titleKey)
                    ))
                    .accessibilityLabel(localization.text("appearance.title"))
                    .accessibilityValue(localization.text(appearance.titleKey))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .appGlassSurface(cornerRadius: 10)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .navigationSplitViewColumnWidth(min: 260, ideal: 292, max: 350)
        } detail: {
            Group {
                switch router.selectedTool {
                case .clipboardHistory:
                    ClipboardHistoryView()
                case .chineseConversion:
                    ChineseConversionView()
                case .pdfMerge:
                    PDFMergeView()
                case .imagePDFConversion:
                    ImagePDFConversionView()
                case .imageStitch:
                    ImageStitchView()
                case .jsonFormatter:
                    JSONFormatterView()
                case .jsonDiff:
                    JSONDiffView()
                case nil:
                    ContentUnavailableView(
                        localization.text("app.emptySelection.title"),
                        systemImage: "wrench.and.screwdriver",
                        description: Text(localization.text("app.emptySelection.description"))
                    )
                }
            }
            .navigationTitle(
                router.selectedTool.map { localization.text($0.titleKey) }
                    ?? localization.text("app.name")
            )
        }
        .navigationSplitViewStyle(.balanced)
        .tint(AppTheme.accent)
        .preferredColorScheme(appearance.colorScheme)
        .environment(\.locale, localization.language.locale)
        .background {
            MainWindowReader { window in
                router.registerMainWindow(window)
            }
        }
    }
}

private struct ToolSidebarRow: View {
    @EnvironmentObject private var localization: LocalizationStore
    let tool: ToolKind
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: tool.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? .white : AppTheme.accent)
                .frame(width: 30, height: 30)
                .background(
                    isSelected ? AppTheme.accent : AppTheme.accent.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(localization.text(tool.titleKey))
                    .font(.body.weight(.medium))
                Text(localization.text(tool.subtitleKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
