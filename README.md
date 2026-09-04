# Mac Gadgets

[中文](README.md) | [English](README.en.md)

一个支持中文与 English 界面切换的原生 SwiftUI macOS 便捷工具箱。所有文本与文件均在本机处理，不会上传到网络。

## 下载最新版

<!-- release-download:start -->
[下载 Mac Gadgets v0.2.1 DMG](release/Mac-Gadgets-0.2.1.dmg)
<!-- release-download:end -->

版本变更详见 [CHANGELOG.md](CHANGELOG.md)。

打开 DMG 后，将 `Mac Gadgets.app` 拖入“应用程序”文件夹即可完成安装。

## 首版工具

- 剪贴板历史：应用运行期间自动保存最近 100 条文本，重复内容会置顶而不会重复，并支持按钮或双击复制。
- 中文简繁转换：文本直接转换，支持读取与保存 TXT 文件。
- 多 PDF 合并：批量添加、调整顺序并合并 PDF。
- 图片与 PDF 互转：多张图片按顺序生成 PDF；PDF 每页导出一张 PNG。
- 多图片拼成长图：竖向按最大宽度等比缩放至同宽，横向按最大高度等比缩放至同高，并支持顺序调整；列表与预览区采用 3:7 布局，预览默认适应窗口、支持缩放，点击缩略图可弹窗查看原图。
- JSON 格式化：在同一个编辑器内完成语法校验、统一缩进及可选键名排序；支持行号、对象/数组的嵌套折叠及全部折叠/展开。折叠不影响复制或保存的完整内容，开始编辑时自动展开。
- JSON 对比：格式化后逐行对齐，高亮新增、删除及修改行。

左侧工具列表以工具名称的拼音排序并按首字母分组，也支持中文、说明文字和拼音搜索。

## 交互体验

- 统一的原生 SwiftUI 页面层级，可自动适配浅色和深色外观，也可在侧边栏底部手动切换。
- 每个工具右上角都可在中文与 English 之间即时切换，语言选择会在本机保存。
- 软件运行时会常驻菜单栏图标，可从工具列表直接唤起主窗口并定位到对应工具。
- 在 macOS 26 上使用原生 Liquid Glass 操作栏、搜索框和主操作按钮；旧版系统及“减少透明度”模式会自动降级为清晰的系统材质或实色表面。
- 配套的蓝色玻璃 `MG` 字母组合图标会在打包时自动加入透明安全边距和连续圆角，并生成完整的 macOS 多尺寸图标资源。
- PDF 与图片列表支持直接拖放文件、拖动行排序，以及按钮辅助排序。
- 文本编辑区显示实时行数和字符数，完成与错误状态会在当前工具页内反馈。
- 常用操作支持快捷键：`Command-O` 打开文件、`Command-S` 保存、`Command-Return` 执行转换或对比。
- 所有文件与文本仅在本机处理。

## 环境要求

- macOS 14 或更高版本
- Xcode 26 或更高版本（使用 Swift 6.2 与 macOS 26 SDK 验证）

## 开发运行

```bash
swift run MacGadgets
```

也可以在 Xcode 中打开根目录的 `Package.swift` 后直接运行 `MacGadgets` scheme。

## 测试

```bash
swift test
```

测试按工具直接拆分在 `Tests`，覆盖正常流程、边界条件、失败路径、文件往返及全部工具页面的 SwiftUI 布局。开发时可只运行相关套件，例如：

```bash
swift test --filter ClipboardHistoryTests
swift test --filter JSONServiceTests
swift test --filter JSONFoldingTests
swift test --filter PDFServiceTests
```

提交前仍需运行完整的 `swift test`。所有文件测试使用独立临时目录，剪贴板测试使用专用 pasteboard 和临时存储地址，不会读取或修改真实剪贴板历史。

## 本地化

所有界面文案以 key 形式维护在根目录的 `locale/zh-CN.json` 与 `locale/en.json`。增加或修改文案时必须同步更新两个文件；`LocalizationTests` 会校验两种语言的 key 集合和页面加载。

## 生成可双击运行的 App

```bash
./scripts/build-app.sh
open "dist/Mac Gadgets.app"
```

脚本会生成本机临时签名的 `dist/Mac Gadgets.app`。正式分发前仍需配置 Apple Developer 签名与公证。

## 生成最新版 DMG

```bash
./scripts/build-release.sh
```

每次发布先更新 `Packaging/Info.plist` 的版本号与构建号，并在 `CHANGELOG.md` 顶部补充对应版本、日期和变更内容。

脚本从 `Packaging/Info.plist` 读取版本号，生成 `release/Mac-Gadgets-<版本号>.dmg`，验证签名及 DMG 后自动同步两个 README 的最新下载链接；缺少对应更新日志会中止打包。不要手工修改下载标记区，也不要覆盖其他版本的安装包。

仅同步或校验发布文档时可运行：

```bash
swift scripts/update-release-docs.swift --write
swift scripts/update-release-docs.swift --check
```
