#!/bin/bash

# ------------------------------------------------------------------------------
# Utility Functions for LVM Snapshot Manager
# Includes checks and snapshot listing
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

# Check if LVM tools are available
if ! command -v lvs >/dev/null 2>&1; then
  echo "❌ LVM tools are not installed. Please install lvm2."
  exit 1
fi

# Check if the logical volume exists
if ! lvdisplay "/dev/$VG_NAME/$LV_NAME" >/dev/null 2>&1; then
  echo "❌ Logical volume /dev/$VG_NAME/$LV_NAME not found. Try as root"
  exit 1
fi

# Function to list existing snapshots
list_snapshots() {
  echo -e "\n📦 Available Snapshots:"
  printf "%-30s %-18s %-10s %-8s %-10s\n" "Snapshot Name" "Origin Volume" "Size" "Used%" "Attributes"
  echo "---------------------------------------------------------------------------------------------------------"

  lvs --noheadings --separator '|' -o lv_name,origin,lv_size,data_percent,lv_attr | while IFS='|' read -r name origin size used attr; do
    name=$(echo "$name" | xargs)
    origin=$(echo "$origin" | xargs)
    size=$(echo "$size" | xargs)
    used=$(echo "$used" | xargs)
    attr=$(echo "$attr" | xargs)

    if [[ -n "$origin" ]]; then
      printf "%-30s %-18s %-10s %-8s %-10s\n" "$name" "$origin" "$size" "${used:-0.00}" "$attr"
    fi
  done
}

# Check if a snapshot merge is currently in progress
check_merge_in_progress() {
  if dmsetup status | grep -E 'snapshot.*merging' >/dev/null; then
    echo "⚠️  A snapshot merge is currently in progress on $LV_NAME."
    echo "⏳ Please wait until the merge is completed (typically requires a reboot)."
    exit 1
  fi
}
