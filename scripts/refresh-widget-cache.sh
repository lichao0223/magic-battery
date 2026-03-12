#!/usr/bin/env bash
set -euo pipefail

CHRONO_CACHE_DIR="${HOME}/Library/Caches/com.apple.chrono"
SNAPSHOT_CACHE_DIR="${CHRONO_CACHE_DIR}/snapshot-cache"
RELEVANCE_CACHE_DIR="${CHRONO_CACHE_DIR}/widget-relevance-cache"

echo "Clearing WidgetKit chrono caches..."
rm -rf "${SNAPSHOT_CACHE_DIR}" "${RELEVANCE_CACHE_DIR}"

echo "Restarting NotificationCenter..."
killall NotificationCenter 2>/dev/null || true

echo "Restarting chronod..."
killall chronod 2>/dev/null || true

echo "Restarting WidgetKit Simulator..."
killall "WidgetKit Simulator" 2>/dev/null || true

echo "Widget cache refresh complete."
echo "Next: clean build folder in Xcode, rebuild MagicBattery, then relaunch the widget scheme."
