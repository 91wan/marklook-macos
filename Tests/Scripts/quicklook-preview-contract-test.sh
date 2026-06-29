#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/../.." && pwd -P)"
validator="$repo_root/Scripts/validate-quicklook-preview-contract.sh"

if [ ! -x "$validator" ]; then
  echo "error: validator is missing or not executable: $validator" >&2
  exit 1
fi

"$validator"

fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

if ! grep -R "providePreview" "$repo_root/PreviewExtension" >/dev/null; then
  echo "error: PreviewExtension must implement data-based providePreview" >&2
  exit 1
fi

if grep -R -E "import[[:space:]]+WebKit|WKWebView" "$repo_root/PreviewExtension" >/dev/null; then
  echo "error: PreviewExtension must not import WebKit or instantiate WKWebView" >&2
  exit 1
fi

make_fixture() {
  fixture="$1"
  source_text="$2"

  mkdir -p "$fixture/PreviewExtension"
  cp "$repo_root/PreviewExtension/Info.plist" "$fixture/PreviewExtension/Info.plist"
  if /usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionAttributes:QLIsDataBasedPreview' "$fixture/PreviewExtension/Info.plist" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c 'Set :NSExtension:NSExtensionAttributes:QLIsDataBasedPreview true' "$fixture/PreviewExtension/Info.plist"
  else
    /usr/libexec/PlistBuddy -c 'Add :NSExtension:NSExtensionAttributes:QLIsDataBasedPreview bool true' "$fixture/PreviewExtension/Info.plist"
  fi
  printf '%s\n' "$source_text" >"$fixture/PreviewExtension/PreviewViewController.swift"
}

valid_fixture="$fixture_root/valid"
make_fixture "$valid_fixture" 'final class PreviewViewController { func providePreview(for request: Any, completionHandler handler: Any) {} }'
MARKLOOK_PREVIEW_CONTRACT_REPO_ROOT="$valid_fixture" "$validator"

no_method_fixture="$fixture_root/no-method"
make_fixture "$no_method_fixture" 'final class PreviewViewController { func preparePreviewOfFile(at url: Any, completionHandler handler: Any) {} }'
if MARKLOOK_PREVIEW_CONTRACT_REPO_ROOT="$no_method_fixture" "$validator" >"$fixture_root/no-method.out" 2>&1; then
  echo "error: validator accepted QLIsDataBasedPreview=true without providePreview" >&2
  exit 1
fi
grep -q 'providePreview' "$fixture_root/no-method.out"

webkit_fixture="$fixture_root/webkit"
make_fixture "$webkit_fixture" 'import WebKit
final class PreviewViewController { let webView = WKWebView(); func providePreview(for request: Any, completionHandler handler: Any) {} }'
if MARKLOOK_PREVIEW_CONTRACT_REPO_ROOT="$webkit_fixture" "$validator" >"$fixture_root/webkit.out" 2>&1; then
  echo "error: validator accepted WebKit usage in PreviewExtension" >&2
  exit 1
fi
grep -q 'WebKit' "$fixture_root/webkit.out"
