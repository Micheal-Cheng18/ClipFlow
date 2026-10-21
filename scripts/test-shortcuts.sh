#!/bin/zsh
set -eu
cd "${0:A:h}/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/clipflow-checks.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
swiftc -swift-version 5 -parse-as-library \
  Sources/ClipFlow/Shortcut.swift Sources/ClipFlow/ShortcutSettings.swift Sources/ClipFlow/Panel.swift \
  Tests/ClipFlowTests/ShortcutScenarios.swift Tests/ClipFlowTests/PanelSurfaceScenarios.swift scripts/shortcut-checks.swift \
  -o "$check_dir/shortcut-checks"
"$check_dir/shortcut-checks"
