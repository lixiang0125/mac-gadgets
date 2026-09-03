import SwiftUI

struct ContentView: View {
    @State private var selectedTool: ToolKind? = .chineseConversion
    @State private var searchText = ""

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
            List(selection: $selectedTool) {
                ForEach(groupedTools, id: \.initial) { group in
                    Section(group.initial) {
                        ForEach(group.tools) { tool in
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tool.title)
                                        .font(.body.weight(.medium))
                                    Text(tool.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 3)
                            } icon: {
                                Image(systemName: tool.systemImage)
                                    .frame(width: 22)
                            }
                            .tag(tool)
                        }
                    }
                }
            }
            .navigationTitle("Mac Gadgets")
            .searchable(text: $searchText, prompt: "筛选工具或输入拼音")
            .navigationSplitViewColumnWidth(min: 250, ideal: 290, max: 360)
        } detail: {
            Group {
                switch selectedTool {
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
    }
}
