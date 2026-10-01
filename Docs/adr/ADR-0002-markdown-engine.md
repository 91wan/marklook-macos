# ADR-0002: Markdown Engine

## Status

Accepted for Issue #3 v0.1

## Context

MarkLook needs local Markdown rendering with GFM basics: tables, task lists, fenced code blocks, blockquotes, lists, and links. Raw HTML and remote resources must not execute or load during Quick Look preview rendering.

## Decision

Issue #3 will ship an internal MarkdownCore v0.1 renderer rather than adopting an external Markdown dependency.

Reasons:

- The current CI runner builds with Xcode 16.4. `swiftlang/swift-markdown` main currently requires a newer Swift tools version than this project can assume, so pinning main is not acceptable.
- cmark-gfm wrappers add C dependency and app-extension compatibility questions that should not block a safe renderer baseline.
- MarkLook needs a deterministic, testable security policy before Finder Quick Look integration.
- The v0.1 renderer can cover the required product subset while keeping the dependency surface at Foundation only.

License: project-owned source under the repository license.

SwiftPM compatibility: `swift-tools-version: 6.0`, macOS 14 minimum.

Xcode version tested: local Xcode 17.x and GitHub Actions Xcode 16.4 through SwiftPM and app-extension build gates.

App extension compatibility: MarkdownCore must import Foundation only and must not import WebKit or AppKit.

### Shared fence syntax

Share fence delimiter recognition in one Foundation-only internal `MarkdownFence.swift` source under MarkdownCore. SwiftPM discovers it normally; XcodeGen explicitly compiles that same file in the Thumbnail extension and its tests, without importing or linking the full MarkdownCore engine there. No new target, product, package, or module is introduced.

This behavior-neutral extraction preserves `.whitespaces` trimming, backtick/tilde runs of at least three characters, trimmed info strings, and closing fences with the same marker, at least the opening length, and empty info. The existing permissive backtick info-string behavior remains unchanged. Each consumer retains fence state, newline/BOM handling, heading/front-matter priorities, escaping/sanitization, and IO/read bounds.

A data-only characterization table under MarkdownCoreTests is compiled only in Core and Thumbnail tests. Both real consumers use its fixed inputs and expected outputs to preserve the existing contract.

### Shared ATX syntax

Share ATX heading recognition in one Foundation-only internal source under MarkdownCore, using normal SwiftPM discovery and explicit compilation of the same file in Thumbnail and its tests. Thumbnail must not import or link the full MarkdownCore engine; no target, product, package, module, or dependency is added.

Recognition preserves `.whitespaces` trimming, levels 1 through 6, a literal ASCII space after the hash run, and a nonempty whitespace-trimmed title without further projection. Renderer retains its three recognition sites, Setext precedence, inline escaping/rendering, and level 1 through 3 TOC. Thumbnail retains H1/H2 eligibility, hash trimming, whitespace collapse, first-eligible scan order, and continuing past projected-empty titles. Fence state, front matter, newline/BOM handling, and IO/read bounds stay with their existing consumers.

A test-only, data-only table declares identical source inputs but distinct fixed Renderer HTML/TOC and Thumbnail heading expectations. Characterization runs against unchanged production before extraction; this is not a heading feature change.

GFM support level for v0.1:

- headings `#` / `##` / `###`
- paragraphs
- unordered and ordered lists
- blockquotes
- fenced code blocks
- inline code
- emphasis and strong emphasis
- GFM strikethrough
- GFM-style tables
- GFM task lists
- horizontal rules
- links
- images with resource-policy handling
- YAML front matter extraction
- basic table of contents extraction

Deferred:

- Mermaid
- KaTeX / MathJax
- syntax highlighting
- local image loading
- source/render toggle
- copy code button
- TOC sidebar UI

Fallback plan: if the internal subset becomes too costly or fails compatibility requirements, update this ADR before replacing it with a pinned app-extension-compatible dependency. The update must document dependency name, license, SwiftPM compatibility, CI result, raw HTML behavior, remote resource handling, and fallback behavior.

## Security policy

- Raw HTML must be disabled or sanitized.
- Script tags must not enter an executable context.
- Remote images must be blocked or replaced with safe placeholders.
- Links may be displayed, but Quick Look navigation must be cancelled.
- Output HTML must be self-contained with inline CSS and a restrictive CSP.
- Runtime network access is not allowed in MarkdownCore.
- MarkdownCore must not read or write files.

## Fallback rule

If the preferred dependency fails in the app extension or CI environment, replace it only after updating this ADR with:

- original failure reason
- replacement dependency
- license
- app extension compatibility
- CI result
- raw HTML safety strategy
