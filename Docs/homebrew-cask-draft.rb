# Draft only. Do not submit until a real v0.1.0 GitHub Release artifact and SHA-256 exist.

cask "marklook" do
  version "0.1.0"
  sha256 "<replace-with-final-sha256>"

  url "https://github.com/91wan/marklook-macos/releases/download/v0.1.0/MarkLook-0.1.0.zip"
  name "MarkLook"
  desc "Fast local Quick Look Markdown preview for AI and developer documents"
  homepage "https://github.com/91wan/marklook-macos"

  app "MarkLook.app"

  caveats <<~EOS
    This cask is a draft. Do not submit it until MarkLook v0.1.0 has a real
    Developer ID signed, notarized, stapled GitHub Release artifact and a
    verified SHA-256 checksum.
  EOS
end
