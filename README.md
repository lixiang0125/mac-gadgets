# Mac Gadgets

一个原生 SwiftUI macOS 便捷工具箱。所有文本与文件均在本机处理，不会上传到网络。

## 首版工具

- 中文简繁转换：文本直接转换，支持读取与保存 TXT 文件。
- 多 PDF 合并：批量添加、调整顺序并合并 PDF。
- 图片与 PDF 互转：多张图片按顺序生成 PDF；PDF 每页导出一张 PNG。
- 多图片拼成长图：支持横向、竖向拼接和顺序调整。
- JSON 格式化：语法校验、统一缩进及可选键名排序。
- JSON 对比：格式化后逐行对齐，高亮新增、删除及修改行。

左侧工具列表以工具名称的拼音排序并按首字母分组，也支持中文、说明文字和拼音搜索。

## 环境要求

- macOS 14 或更高版本
- Xcode 16 或更高版本（当前使用 Swift 6.2 验证）

## 开发运行

```bash
swift run MacGadgets
```

也可以在 Xcode 中打开根目录的 `Package.swift` 后直接运行 `MacGadgets` scheme。

## 测试

```bash
swift test
```

测试覆盖简繁转换、文本文件、PDF 合并、图片/PDF 互转、横竖图片拼接、JSON 格式化、JSON Diff 和拼音排序。

## 生成可双击运行的 App

```bash
./scripts/build-app.sh
open "dist/Mac Gadgets.app"
```

脚本会生成本机临时签名的 `dist/Mac Gadgets.app`。正式分发前仍需配置开发者签名、公证和应用图标。

## 后续绑定 GitHub

恢复 GitHub 连接后，在项目目录执行：

```bash
git remote add origin https://github.com/lixiang0125/mac-gadgets.git
git push -u origin main
```
