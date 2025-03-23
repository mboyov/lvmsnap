#!/bin/bash

# --------------------------------------------------------------------
# Utility Functions for LVM Snapshot Manager (Dynamic Refactor)
# --------------------------------------------------------------------

# Vérification de la présence des outils LVM
if ! command -v lvs >/dev/null 2>&1; then
  echo "❌ LVM tools are not installed. Please install lvm2."
  exit 1
fi

# Fonction pour lister les snapshots existants
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

# Vérification de l'existence d'une fusion de snapshot en cours pour un VG/LV donné
check_merge_in_progress() {
  local vg=$1
  local lv=$2
  local lv_path="/dev/$vg/$lv"

  if [ ! -e "$lv_path" ]; then
    echo "⚠️  Logical volume $lv_path not found (inactive or hidden)."
    return
  fi

  if dmsetup status "$lv_path" 2>/dev/null | grep -E 'snapshot.*merging' >/dev/null; then
    echo "⚠️  A snapshot merge is currently in progress on $lv."
    echo "⏳ Please wait until the merge is completed (typically requires a reboot)."
    exit 1
  fi
}
