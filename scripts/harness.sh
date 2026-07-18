#!/bin/bash
# FoxPhotoColor local dev harness: build / run / capture / logs / reset
# Usage:
#   scripts/harness.sh build            # build for simulator
#   scripts/harness.sh run [--seed]     # boot sim, install, launch (--seed injects sample cards)
#   scripts/harness.sh capture NAME     # screenshot -> artifacts/NAME.png
#   scripts/harness.sh logs             # recent app logs from the simulator
#   scripts/harness.sh reset            # uninstall app (clears its data)
#   scripts/harness.sh all [--seed]     # build + run + capture home
set -euo pipefail
cd "$(dirname "$0")/.."

# Only Xcode.app (16.2) has a matching simulator runtime (iOS 18.2) on this machine.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app}"
SIM_NAME="${SIM_NAME:-iPhone 16 Pro}"
BUNDLE_ID="me.sma1lboy.foxphotocolor"
DERIVED="build"
APP="$DERIVED/Build/Products/Debug-iphonesimulator/FoxPhotoColor.app"
ARTIFACTS="artifacts"

udid() {
  xcrun simctl list devices available | grep -F "$SIM_NAME (" | head -1 | grep -oE '[0-9A-F-]{36}'
}

ensure_booted() {
  local id; id="$(udid)"
  [ -n "$id" ] || { echo "simulator '$SIM_NAME' not found" >&2; exit 1; }
  if ! xcrun simctl list devices | grep -F "$id" | grep -q Booted; then
    xcrun simctl boot "$id"
  fi
  xcrun simctl bootstatus "$id" -b >/dev/null
  echo "$id"
}

cmd="${1:-all}"; shift || true

case "$cmd" in
  build)
    xcodebuild -project FoxPhotoColor.xcodeproj -scheme FoxPhotoColor \
      -destination "platform=iOS Simulator,name=$SIM_NAME" \
      -derivedDataPath "$DERIVED" \
      CODE_SIGNING_ALLOWED=NO \
      build 2>&1 | tail -20
    ;;
  run)
    id="$(ensure_booted)"
    xcrun simctl install "$id" "$APP"
    xcrun simctl terminate "$id" "$BUNDLE_ID" 2>/dev/null || true
    if [ "${1:-}" = "--seed" ]; then
      SIMCTL_CHILD_FPC_SEED=1 xcrun simctl launch "$id" "$BUNDLE_ID"
    else
      xcrun simctl launch "$id" "$BUNDLE_ID"
    fi
    sleep 2
    ;;
  capture)
    id="$(ensure_booted)"
    mkdir -p "$ARTIFACTS"
    name="${1:-shot-$(date +%H%M%S)}"
    xcrun simctl io "$id" screenshot "$PWD/$ARTIFACTS/$name.png" >/dev/null
    echo "$PWD/$ARTIFACTS/$name.png"
    ;;
  logs)
    id="$(ensure_booted)"
    xcrun simctl spawn "$id" log show --last 2m --predicate 'process == "FoxPhotoColor"' --style compact 2>/dev/null | tail -60
    ;;
  reset)
    id="$(ensure_booted)"
    xcrun simctl uninstall "$id" "$BUNDLE_ID" 2>/dev/null || true
    echo "uninstalled $BUNDLE_ID"
    ;;
  tap)
    # tap X Y — needs `brew install idb` alternative; fallback: use simctl ui? Not available.
    echo "interactive taps not supported headlessly; use FPC_SEED + deep states instead" >&2
    exit 1
    ;;
  all)
    "$0" build
    "$0" run "${1:-}"
    "$0" capture "home"
    ;;
  *)
    echo "unknown command: $cmd" >&2
    exit 1
    ;;
esac
