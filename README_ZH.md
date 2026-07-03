# MarkLook

[English](README.md)

MarkLook 是一个快速、稳定、极简的 macOS Quick Look Markdown 阅读层，面向 AI / 开发者长文档。

## 它做什么

- 提供可构建的 macOS app，并包含 Quick Look Preview 和 Thumbnail extensions。
- 提供诊断面板，用于查看 Quick Look 注册状态、支持的 Markdown 类型、所选文件的内容类型，以及 Quick Look 缓存重置辅助。
- 提供本地 MarkdownCore renderer，用于 v0.1 Markdown 子集。
- 通过本地 Preview extension 渲染 Markdown 预览。
- 从有界文件元数据绘制 Markdown 缩略图：MD badge、首个 H1/H2 标题、扩展名和近似行数。
- v0.1.x 使用固定浅色 document-card 缩略图样式，保证 Finder 缓存和外观上下文中的输出确定性。
- 面向 `.md` 文件和较长的 AI / Codex review 文档。
- 渲染保持本地执行。
- 无遥测。
- Preview rendering 期间不联网。

## 它不是什么

- 不是 Markdown 编辑器。
- 不是笔记软件。
- 不是知识库。
- 不是 Electron app。
- 不是旧式 `.qlgenerator`。

## 与 Markdown 编辑器兼容

MarkLook 设计为与 Edmund、Typora、MarkEdit、Obsidian、VS Code、Xcode 等 Markdown 编辑器共存。

这些应用负责编辑。MarkLook 负责 Finder Quick Look 预览和缩略图。

MarkLook 注册为 Markdown viewer / alternate handler，不作为默认 Markdown 编辑器。

## 当前状态

App 和 Quick Look extensions 可以构建。MarkdownCore 为 v0.1 Markdown 子集提供本地安全 HTML renderer；Preview extension 以 data-based self-contained HTML 形式返回 UTF-8 Markdown，不使用 WebKit，也不访问网络；Thumbnail extension 包含有界 Markdown identity renderer，不做完整 Markdown rendering。

Host app 是诊断界面：报告 Preview/Thumbnail 注册状态，列出支持的 Markdown content types 和 file extensions，诊断所选文件的 `kMDItemContentType` 与 content type tree，复制已脱敏的诊断报告，并提供 Quick Look cache reset 命令。

本地 Apple Development 验证已经证明：host 可接受 app launch、PlugInKit Preview/Thumbnail 注册、Finder Space Markdown 预览，以及有界缩略图渲染。公开分发仍需要 Developer ID Application signing、hardened runtime、notarization 和 stapling。

## v0.1.x 状态

- v0.1.0 是源码/本地验证里程碑。
- v0.1.1 是当前源码/本地验证 patch tag，包含 thumbnail determinism、public privacy gates、固定浅色 thumbnail appearance policy 文档，以及中文 README。
- Preview、thumbnail、diagnostics 和 debug packaging 已纳入 release candidate gate。
- 公开 notarized binary distribution 仍等待 Developer ID Application signing、notarization 和 stapling。
- Homebrew cask 内容仍是草稿，直到存在真实 release artifact URL 和 checksum。

## 构建

CI-compatible build 和 embedding check：

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project MarkLook.xcodeproj -scheme MarkLook -configuration Debug -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
test -d .build/DerivedData/Build/Products/Debug/MarkLook.app
test -d .build/DerivedData/Build/Products/Debug/MarkLook.app/Contents/PlugIns/MarkLookPreview.appex
test -d .build/DerivedData/Build/Products/Debug/MarkLook.app/Contents/PlugIns/MarkLookThumbnail.appex
```

`CODE_SIGNING_ALLOWED=NO` 仅用于构建验证。本地 app launch 和 Quick Look 注册需要一个被当前 macOS 主机安全策略接受的签名 build。

## Debug packaging

Issue #7 增加了本地 debug package 生成。这些 package 是验证产物，不是公开 release artifact：

```bash
Scripts/package-debug.sh --unsigned-ci
Scripts/validate-package-artifact.sh dist/MarkLook-0.1.0-debug-<shortsha>/MarkLook-0.1.0-debug-<shortsha>.zip

DEVELOPMENT_TEAM=<TEAM_ID> Scripts/package-debug.sh --apple-development
Scripts/validate-package-artifact.sh dist/MarkLook-0.1.0-debug-<shortsha>/MarkLook-0.1.0-debug-<shortsha>.zip
```

Unsigned CI packages 不是可安装的信任产物。Apple Development packages 仅用于本地验证。公开分发仍需要 Developer ID Application signing、hardened runtime、notarization 和 stapling；见 `Docs/signing-notarization.md` 和 `Docs/release-checklist.md`。

## Release candidate gate

运行 CI-compatible gate：

```bash
Scripts/validate-release-candidate.sh --ci
```

在 maintainer Mac 上运行 local gate：

```bash
DEVELOPMENT_TEAM=<TEAM_ID> Scripts/validate-release-candidate.sh --local
```

该 gate 不会创建 tag，不会发布 GitHub Release，不会提交 Homebrew cask，也不会声明 Developer ID / notarization 信任。

`Scripts/validate-v0.1.0-release-candidate.sh` 保留为 compatibility wrapper。v0.1.1 的源码/本地验证 patch 边界见 `Docs/v0.1.1-source-local-validation.md`。

## 使用普通 Apple ID / Personal Team 做本地开发验证

本地 Quick Look 验证可使用 Xcode 从 owner Apple ID 生成的 Apple Development identity。这不是公开 release signing，但可以避免 ad-hoc signing，并证明本地 app launch、PlugInKit registration 和 Finder Space preview 行为。

1. 打开 Xcode -> Settings -> Accounts，添加 Apple ID。
2. 打开 Manage Certificates，创建 Apple Development certificate。
3. 确认 signing state：

```bash
Scripts/doctor-signing.sh
security find-identity -p codesigning -v
```

4. 构建并运行 local smoke：

```bash
DEVELOPMENT_TEAM=<TEAM_ID> Scripts/build-local-apple-development.sh
Scripts/validate-signed-quicklook.sh --development --noninteractive .build/LocalDerivedData/Build/Products/Debug/MarkLook.app
```

Development mode 仍会拒绝 ad-hoc signatures 和缺失 TeamIdentifier 的值。它不证明公开分发信任。公开分发需要 Developer ID Application signing、hardened runtime、notarization 和 stapling。

## 刷新 Quick Look

```bash
qlmanage -r
qlmanage -r cache
killall Finder || true
```

App 也提供 `Reset Quick Look Cache` 按钮。如果 macOS sandbox policy 阻止进程启动，同样的命令会保留在 diagnostics dashboard 中供复制。

## 诊断文件

使用 app 的 `Select File` 按钮可以走 sandbox-safe 路径。Diagnostics report 默认脱敏完整本地路径；完整 `mdls` 命令只会从明确的 full-path copy button 提供。

```bash
mdls -name kMDItemContentType -name kMDItemContentTypeTree path/to/file.md
pluginkit -mAv -p com.apple.quicklook.preview | grep -i MarkLook
pluginkit -mAv -i com.91wan.MarkLook.Preview
pluginkit -mAv -p com.apple.quicklook.thumbnail | grep -i MarkLook
pluginkit -mAv -i com.91wan.MarkLook.Thumbnail
```

## 隐私

MarkLook 在本地渲染文档。它不会上传文档，不收集 analytics，也不会在 preview rendering 期间联系远程服务器。

公开证据和截图规则见 `Docs/public-evidence-policy.md`。Finder 截图和本地 runtime thumbnail evidence 不应提交到公开仓库。

## 缩略图外观策略

v0.1.x 的 Finder thumbnails 使用固定浅色 document-card palette。它不会随 Finder dark mode 自动切换。这个选择是为了保证 Quick Look thumbnail worker、Finder cache 和不同 appearance contexts 下的输出确定性。

Dark/gray thumbnail variants 只应作为未来明确的产品决策处理，并且必须使用固定 palette、保持 determinism tests，不能依赖 ambient `NSAppearance.current` 或 dynamic AppKit system colors。
