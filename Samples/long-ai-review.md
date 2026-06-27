# Long AI Review Sample

## Summary

This sample represents a long AI-generated review document with nested sections, checklists, code, and tables.

## Findings

### P1

- [ ] Preview extension must not load remote resources.
- [ ] Unsafe HTML must not execute.

### P2

- [ ] Code blocks need horizontal scrolling.
- [ ] Tables need horizontal scrolling.

## Evidence

| File | Risk | Note |
| --- | --- | --- |
| `PreviewViewController.swift` | Navigation | Links must be cancelled. |
| `MarkdownRenderer.swift` | Sanitization | Raw HTML must be safe. |

```swift
func render(_ markdown: String) throws -> String {
    // Implemented in a later PR.
    return markdown
}
```

## Repeated Notes

The final renderer should handle documents much longer than this sample. Performance validation belongs to the preview and hardening PRs.
