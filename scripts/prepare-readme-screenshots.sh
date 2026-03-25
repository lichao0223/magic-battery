#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCREENSHOT_DIR="${ROOT_DIR}/docs/screenshots"

require_file() {
  local path="$1"
  if [[ ! -f "${path}" ]]; then
    echo "Missing screenshot: ${path}" >&2
    exit 1
  fi
}

resize_png() {
  local src="$1"
  local dst="$2"
  local width="$3"

  require_file "${src}"
  cp "${src}" "${dst}"
  sips --resampleWidth "${width}" "${dst}" >/dev/null
}

mkdir -p "${SCREENSHOT_DIR}"

resize_png "${SCREENSHOT_DIR}/01-menubar-popover.png" "${SCREENSHOT_DIR}/01-menubar-popover-readme.png" 640
resize_png "${SCREENSHOT_DIR}/02-device-details.png" "${SCREENSHOT_DIR}/02-device-details-readme.png" 680
resize_png "${SCREENSHOT_DIR}/03-settings.png" "${SCREENSHOT_DIR}/03-settings-readme.png" 860
resize_png "${SCREENSHOT_DIR}/04-widget-small.png" "${SCREENSHOT_DIR}/04-widget-small-readme.png" 360
resize_png "${SCREENSHOT_DIR}/05-widget-medium.png" "${SCREENSHOT_DIR}/05-widget-medium-readme.png" 760
resize_png "${SCREENSHOT_DIR}/06-widget-large.png" "${SCREENSHOT_DIR}/06-widget-large-readme.png" 420

echo "README screenshots refreshed in ${SCREENSHOT_DIR}"
