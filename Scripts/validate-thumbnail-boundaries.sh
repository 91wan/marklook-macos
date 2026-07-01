#!/usr/bin/env bash
set -euo pipefail

! git grep -n "import WebKit" -- ThumbnailExtension
! git grep -n "WKWebView" -- ThumbnailExtension

! git grep -n "MarkdownRenderer" -- ThumbnailExtension
! git grep -n "MarkdownCore" -- ThumbnailExtension

! git grep -n "Data(contentsOf:" -- ThumbnailExtension
! git grep -n "String(contentsOf:" -- ThumbnailExtension

# Deterministic thumbnails: no ambient appearance or dynamic system colors.
! git grep -n "NSAppearance.current" -- ThumbnailExtension
! git grep -n "NSAppearance(named:" -- ThumbnailExtension
! git grep -n "textBackgroundColor" -- ThumbnailExtension
! git grep -n "controlBackgroundColor" -- ThumbnailExtension
! git grep -n "separatorColor" -- ThumbnailExtension
! git grep -n "labelColor" -- ThumbnailExtension
! git grep -n "secondaryLabelColor" -- ThumbnailExtension
! git grep -n "controlAccentColor" -- ThumbnailExtension

git grep -n "QLThumbnailProvider" -- ThumbnailExtension
/usr/libexec/PlistBuddy \
  -c 'Print :NSExtension:NSExtensionAttributes:QLThumbnailMinimumSize' \
  ThumbnailExtension/Info.plist | grep -q '^32$'
ruby -e 'require "yaml"; v=YAML.load_file("project.yml").dig("targets","MarkLookThumbnail","info","properties","NSExtension","NSExtensionAttributes","QLThumbnailMinimumSize"); abort("bad QLThumbnailMinimumSize") unless v == 32'
git grep -n "currentContextDrawing" -- ThumbnailExtension/ThumbnailProvider.swift
git grep -n "AppLog.thumbnail" -- ThumbnailExtension/ThumbnailProvider.swift

test -f ThumbnailExtension/MarkdownThumbnailMetadata.swift
test -f ThumbnailExtension/MarkdownThumbnailRenderer.swift
test -f ThumbnailExtension/MarkdownThumbnailPalette.swift
test -f ThumbnailExtension/MarkdownThumbnailLayout.swift
