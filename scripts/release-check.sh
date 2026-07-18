#!/bin/bash
# Release-configuration build gate: catches -O-only compile issues and
# release-config regressions without needing signing.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app}"
SIM_NAME="${SIM_NAME:-iPhone 16 Pro}"

xcodebuild -project FoxPhotoColor.xcodeproj -scheme FoxPhotoColor \
  -configuration Release \
  -destination "platform=iOS Simulator,name=$SIM_NAME" \
  -derivedDataPath build-release \
  build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | head -10
