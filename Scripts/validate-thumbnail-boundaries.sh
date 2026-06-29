#!/usr/bin/env bash
set -euo pipefail

! git grep -n "import WebKit" -- ThumbnailExtension
! git grep -n "WKWebView" -- ThumbnailExtension

! git grep -n "MarkdownRenderer" -- ThumbnailExtension
! git grep -n "MarkdownCore" -- ThumbnailExtension

! git grep -n "Data(contentsOf:" -- ThumbnailExtension
! git grep -n "String(contentsOf:" -- ThumbnailExtension

git grep -n "QLThumbnailProvider" -- ThumbnailExtension

test -f ThumbnailExtension/MarkdownThumbnailMetadata.swift
test -f ThumbnailExtension/MarkdownThumbnailRenderer.swift
