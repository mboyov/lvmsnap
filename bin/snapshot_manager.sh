#!/bin/bash

# ------------------------------------------------------------------------------
# Script Name   : snapshot_manager.sh
# Description   : Interactive script to manage LVM snapshots (create, list, delete, restore)
# ------------------------------------------------------------------------------

# Runtime dynamic sources (ShellCheck won't follow these, and that's OK)
# shellcheck disable=SC1091
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/config.sh"
source "$SCRIPT_DIR/../lib/utils.sh"

# Main interactive menu
echo "=== LVM Snapshot Manager ==="
echo "1) Create a snapshot"
echo "2) List snapshots"
echo "3) Delete one or more snapshots"
echo "4) Restore a snapshot"
echo "5) Exit"
read -rp "Choice: " choice

case "$choice" in

1)
  # Prevent creation if a merge is in progress
  check_merge_in_progress

  # Create a snapshot with timestamp
  SNAP_NAME="${SNAP_PREFIX}_$(date +%F_%H%M%S)"
  if lvcreate -L"$SNAP_SIZE" -s -n "$SNAP_NAME" "/dev/$VG_NAME/$LV_NAME"; then
    echo "✅ Snapshot $SNAP_NAME created successfully."
  else
    echo "❌ Failed to create snapshot."
  fi
  ;;

2)
  list_snapshots
  ;;

3)
  list_snapshots
  echo ""
  read -rp "Enter snapshot names to delete (space-separated): " snaps
  for snap in $snaps; do
    if lvremove -f "/dev/$VG_NAME/$snap"; then
      echo "🗑️  Snapshot $snap deleted."
    else
      echo "⚠️  Failed to delete $snap."
    fi
  done
  ;;

4)
  list_snapshots
  echo ""
  read -rp "Enter the snapshot name to restore: " snap_to_restore
  echo "⚠️  Warning: Restoring will overwrite the current state of $LV_NAME."
  read -rp "Are you sure you want to restore from $snap_to_restore? (yes/no): " confirm
  if [[ "$confirm" == "yes" ]]; then
    if lvconvert --merge "/dev/$VG_NAME/$snap_to_restore"; then
      echo "✅ Snapshot $snap_to_restore will be restored after a reboot."
      echo "🔁 Please reboot the system to complete the restoration."
    else
      echo "❌ Failed to restore snapshot $snap_to_restore."
    fi
  else
    echo "❎ Operation cancelled."
  fi
  ;;

5)
  echo "👋 Exiting."
  exit 0
  ;;

*)
  echo "❌ Invalid choice."
  ;;
esac
