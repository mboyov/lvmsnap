#!/bin/bash

# ------------------------------------------------------------------------------
# Test Script: Snapshot Creation
# Verifies that a snapshot can be created successfully
# ------------------------------------------------------------------------------

# shellcheck disable=SC1091
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

source "$SCRIPT_DIR/../config/config.sh"

SNAP_NAME="test_${SNAP_PREFIX}_$(date +%F_%H%M%S)"

echo "🔧 Testing snapshot creation: $SNAP_NAME"

if lvcreate -L"$SNAP_SIZE" -s -n "$SNAP_NAME" "/dev/$VG_NAME/$LV_NAME" >/dev/null 2>&1; then
  echo "✅ Snapshot $SNAP_NAME created."
  if lvs | grep -q "$SNAP_NAME"; then
    echo "🧪 Test passed: Snapshot found in list."
    lvremove -f "/dev/$VG_NAME/$SNAP_NAME" >/dev/null
    echo "🧹 Snapshot $SNAP_NAME removed after test."
    exit 0
  else
    echo "❌ Test failed: Snapshot not found after creation."
    exit 1
  fi
else
  echo "❌ Test failed: Could not create snapshot."
  exit 1
fi
