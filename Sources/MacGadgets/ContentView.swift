import SwiftUI

struct ContentView: View {
    @State private var selectedTool: ToolKind? = .chineseConversion
    @State private var searchText = ""
    @AppStorage("appearance") private var appearanceRawValue = AppAppearance.system.rawValue

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }

    private var filteredTools: [ToolKind] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ToolKind.pinyinSorted
        }

        let needle = searchText.lowercased()
        return ToolKind.pinyinSorted.filter {
            $0.title.lowercased().contains(needle)
                || $0.subtitle.lowercased().contains(needle)
                || $0.pinyinSortKey.contains(needle)
        }
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
                        Text("Mac Gadgets")
                            .font(.headline)
                        Text("\(ToolKind.allCases.count) 个本地工具")
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
                    TextField("搜索工具", text: $searchText, prompt: Text("名称或拼音"))
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
                        .help("清除搜索")
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .appGlassSurface(cornerRadius: 10, interactive: true)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

                List(selection: $selectedTool) {
                    ForEach(groupedTools, id: \.initial) { group in
                        Section(group.initial) {
                            ForEach(group.tools) { tool in
                                ToolSidebarRow(tool: tool, isSelected: selectedTool == tool)
                                    .tag(tool)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)

                HStack(spacing: 8) {
                    Label("文件只在本机处理", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        Picker("外观", selection: $appearanceRawValue) {
                            ForEach(AppAppearance.allCases) { item in
                                Label(item.title, systemImage: item.systemImage)
                                    .tag(item.rawValue)
                            }
                        }
                    } label: {
                        Label("外观", systemImage: appearance.systemImage)
                            .labelStyle(.iconOnly)
                            .frame(
                                width: AppTheme.compactControlHitSize,
                                height: AppTheme.compactControlHitSize
                            )
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("外观：\(appearance.title)")
                    .accessibilityLabel("外观")
                    .accessibilityValue(appearance.title)
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
                switch selectedTool {
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
                        "选择一个工具",
                        systemImage: "wrench.and.screwdriver",
                        description: Text("从左侧列表中选择要使用的便捷工具。")
                    )
                }
            }
            .navigationTitle(selectedTool?.title ?? "Mac Gadgets")
        }
        .navigationSplitViewStyle(.balanced)
        .tint(AppTheme.accent)
        .preferredColorScheme(appearance.colorScheme)
    }
}

private struct ToolSidebarRow: View {
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
                Text(tool.title)
                    .font(.body.weight(.medium))
                Text(tool.subtitle)
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
