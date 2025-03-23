#!/bin/bash

# --------------------------------------------------------------------
# Refactored Script: snapshot_manager.sh (Dynamic Multi-Volume Support)
# --------------------------------------------------------------------

# Runtime-safe sourcing
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

# Detect volumes dynamically into associative array
declare -A VOLUMES
volume_list=$(lvs --noheadings --separator '|' -o vg_name,lv_name,origin)
while IFS='|' read -r vg lv origin; do
  vg=$(echo "$vg" | xargs)
  lv=$(echo "$lv" | xargs)
  origin=$(echo "$origin" | xargs)
  [[ -n "$origin" ]] && continue # ⚠️ Skip if this LV is a snapshot
  VOLUMES["$vg"]+="$lv "
done <<<"$volume_list"

# Prompt user to select a volume
select_volume() {
  echo -e "\n📦 Available Volumes:"
  local i=1 choices=()
  for vg in "${!VOLUMES[@]}"; do
    for lv in ${VOLUMES[$vg]}; do
      echo "$i) $vg/$lv"
      choices+=("$vg|$lv")
      ((i++))
    done
  done
  read -rp $'Choose a volume (number): ' selection
  IFS='|' read -r SELECTED_VG SELECTED_LV <<<"${choices[$((selection - 1))]}"
  SELECTED_VG=$(echo "$SELECTED_VG" | xargs)
  SELECTED_LV=$(echo "$SELECTED_LV" | xargs)
}

# Display snapshot hints
display_snapshot_hints() {
  local vg="$1"
  local lv="$2"
  local lv_path="/dev/$vg/$lv"

  lv_size_raw=$(lvs --noheadings -o lv_size --units g "$lv_path" | xargs | sed 's/g//i')
  lv_size="$lv_size_raw"
  recommended_calc=$(echo "$lv_size * 0.1" | bc 2>/dev/null | xargs printf "%.0f" 2>/dev/null)
  recommended="${recommended_calc:-1}G"

  echo -e "\nYou selected: $vg/$lv (${lv_size}G)"
  echo "--------------------------------------"
  echo "📦 Available space in Volume Groups:"
  vgs --noheadings -o vg_name,vg_free --units g | column -t
  echo -e "\n💡 Recommended snapshot size: $recommended (10% of original volume)"
  echo -e "ℹ️  Snapshot tracks only changed blocks. Heavy write activity increases usage."
}

# Ask snapshot size
ask_snapshot_size() {
  echo ""
  read -rp "Enter snapshot size [default: $1]: " SNAP_SIZE
  SNAP_SIZE=${SNAP_SIZE:-$1}
}

# === Menu ===
while true; do
  echo -e "\n=== LVM Snapshot Manager ==="
  echo "1) Create a snapshot"
  echo "2) List snapshots"
  echo "3) Delete one or more snapshots"
  echo "4) Restore a snapshot"
  echo "5) Exit"
  read -rp "Choice: " choice

  case "$choice" in
  1)
    select_volume
    LV_PATH="/dev/$SELECTED_VG/$SELECTED_LV"
    if [ ! -e "$LV_PATH" ]; then
      echo "❌ Volume $LV_PATH not found. Please check LVM state."
      continue
    fi
    check_merge_in_progress "$SELECTED_VG" "$SELECTED_LV"
    display_snapshot_hints "$SELECTED_VG" "$SELECTED_LV"
    ask_snapshot_size "$recommended"
    SNAP_NAME="snap_${SELECTED_LV}_$(date +%F_%H%M%S)"
    if lvcreate -L"$SNAP_SIZE" -s -n "$SNAP_NAME" "$LV_PATH"; then
      echo "✅ Snapshot $SNAP_NAME created."
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
      for vg in "${!VOLUMES[@]}"; do
        if lvremove -f "/dev/$vg/$snap" 2>/dev/null; then
          echo "🗑️  Snapshot $snap deleted."
          break
        fi
      done
    done
    ;;
  4)
    select_volume
    list_snapshots "$SELECTED_VG" "$SELECTED_LV"
    echo ""
    read -rp "Enter the snapshot name to restore: " snap_to_restore
    echo "⚠️  Restoring will overwrite $SELECTED_LV. Reboot required."
    read -rp "Are you sure? (yes/no): " confirm
    if [[ "$confirm" == "yes" ]]; then
      if lvconvert --merge "/dev/$SELECTED_VG/$snap_to_restore"; then
        echo "✅ Snapshot $snap_to_restore will be restored after reboot."
      else
        echo "❌ Restore failed."
      fi
    else
      echo "❎ Cancelled."
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
done
