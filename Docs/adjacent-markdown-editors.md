# Adjacent Markdown editor compatibility

## Purpose

MarkLook is a Quick Look reading layer, not a Markdown editor.

## Adjacent editors

Adjacent Markdown editors include:

- Edmund
- Typora
- MarkEdit
- Obsidian
- VS Code
- Xcode

These tools own editing. MarkLook owns Finder Quick Look preview and thumbnails.

## Edmund review

Edmund is a native macOS Markdown editor with live preview. Its product surface includes TextKit 2 lazy rendering, AppKit editing, WebKit read mode, and Sparkle release machinery.

Edmund is adjacent, not a direct Quick Look competitor.

## Compatibility invariant

MarkLook must remain:

- `CFBundleTypeRole = Viewer`
- `LSHandlerRank = Alternate`

MarkLook must not become:

- `CFBundleTypeRole = Editor`
- `LSHandlerRank = Owner`

That preserves user choice of Markdown editor while allowing MarkLook to provide Finder preview and thumbnail behavior.

## Product non-goals

- No Markdown editor.
- No note-taking app.
- No knowledge base.
- No project graph.
- No default Markdown ownership.
- No editor-specific formatting commands.
- No Sparkle auto-update in v0.1.x.
- No crash upload path.
- No `xattr` or quarantine bypass as an official release path.

## Lessons retained

- Document architecture invariants.
- Keep visual validation durable.
- Record release gotchas.
- Keep performance bounded.
- Preserve user choice of editor.

## Review checklist

Future PRs that touch file types, document types, Launch Services, or host app behavior must prove:

- `Viewer` / `Alternate` remains true.
- MarkLook does not become the default Markdown handler.
- `Scripts/validate-supported-types.sh` still passes.
