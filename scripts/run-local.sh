#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${ROOT_DIR}/.build-local"
SCHEME="battery"
PROJECT_PATH="${ROOT_DIR}/battery.xcodeproj"
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Debug/MagicBattery.app"
APP_BIN="${APP_PATH}/Contents/MacOS/MagicBattery"
ACTION="${1:-run}"

build_app() {
  xcodebuild \
    -project "${PROJECT_PATH}" \
    -scheme "${SCHEME}" \
    -configuration Debug \
    -destination 'platform=macOS' \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    build
}

run_tests() {
  xcodebuild \
    -project "${PROJECT_PATH}" \
    -scheme "${SCHEME}" \
    -destination 'platform=macOS' \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    test
}

launch_app() {
  if [[ ! -d "${APP_PATH}" ]]; then
    echo "App not found at ${APP_PATH}" >&2
    exit 1
  fi

  osascript -e 'tell application "MagicBattery" to quit' >/dev/null 2>&1 || true
  sleep 1
  open "${APP_PATH}"
}

run_mock_app() {
  if [[ ! -x "${APP_BIN}" ]]; then
    echo "App binary not found at ${APP_BIN}" >&2
    exit 1
  fi

  osascript -e 'tell application "MagicBattery" to quit' >/dev/null 2>&1 || true
  sleep 1
  MAGIC_BATTERY_USE_MOCK_DATA=1 "${APP_BIN}"
}

export_screenshots() {
  if [[ ! -x "${APP_BIN}" ]]; then
    echo "App binary not found at ${APP_BIN}" >&2
    exit 1
  fi

  MAGIC_BATTERY_EXPORT_SCREENSHOTS=1 "${APP_BIN}"
}

case "${ACTION}" in
  build)
    build_app
    ;;
  test)
    run_tests
    ;;
  run)
    build_app
    launch_app
    ;;
  mock)
    build_app
    run_mock_app
    ;;
  screenshots)
    build_app
    export_screenshots
    ;;
  *)
    echo "Usage: $0 [build|test|run|mock|screenshots]" >&2
    exit 1
    ;;
esac
