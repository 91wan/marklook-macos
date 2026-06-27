# Manual validation

## Environment

- macOS version:
- Mac model:
- Xcode version:
- Git commit:

## Install debug build

```bash
xcodegen generate
xcodebuild -project MarkLook.xcodeproj -scheme MarkLook -configuration Debug -derivedDataPath .build/DerivedData build
open .build/DerivedData/Build/Products/Debug/MarkLook.app
qlmanage -r
qlmanage -r cache
killall Finder || true
```

## Diagnose a file

```bash
mdls -name kMDItemContentType Samples/basic.md
pluginkit -mAv -p com.apple.quicklook.preview | grep -i MarkLook
```

## Preview checks

```bash
qlmanage -p Samples/basic.md
qlmanage -p Samples/gfm-table-task-list.md
qlmanage -p Samples/long-ai-review.md
qlmanage -p Samples/unsafe-html.md
```

Expected:

- Markdown is rendered, not shown as raw text.
- Headings, lists, task lists, tables, fenced code blocks, and blockquotes are readable.
- Unsafe HTML does not execute.
- Remote images do not load.
- Errors show a local error view, not a blank view.

## Thumbnail checks

```bash
qlmanage -r cache
qlmanage -t -s 512 -o /tmp Samples/basic.md
open /tmp/basic.md.png || true
```

Expected:

- Thumbnail identifies the file as Markdown.
- Large files do not trigger full rendering.

## Reset Quick Look

```bash
qlmanage -r
qlmanage -r cache
killall Finder || true
```
