#!/bin/bash

# --------------------------------------------------------------------
# Refactored Script: snapshot_manager.sh (Dynamic Multi-Volume Support)
# --------------------------------------------------------------------

# Résolution sécurisée du chemin du script
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

# Inclusion de la bibliothèque utilitaire
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

# Fonction pour lister les snapshots existants et les backups manuels
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

  echo -e "\n🗃️  Available Manual Backups:"
  printf "%-30s %-10s %-10s\n" "Backup Name" "VG" "Size"
  echo "---------------------------------------------------------"
  lvs --noheadings -o lv_name,vg_name,lv_size --units g | grep 'lvbackup_' | while read -r name vg size; do
    name=$(echo "$name" | xargs)
    vg=$(echo "$vg" | xargs)
    size=$(echo "$size" | xargs)
    printf "%-30s %-10s %-10s\n" "$name" "$vg" "$size"
  done
}

# -----------------------------------------------------------------------------
# Fonction select_volume() mise à jour pour :
# - Recharger dynamiquement la liste des volumes à chaque appel
# - Exclure les volumes de type lvbackup_*
# -----------------------------------------------------------------------------
select_volume() {
  # Recharger dynamiquement la liste des volumes
  declare -A VOLUMES
  volume_list=$(lvs --noheadings --separator '|' -o vg_name,lv_name,origin)
  while IFS='|' read -r vg lv origin; do
    vg=$(echo "$vg" | xargs)
    lv=$(echo "$lv" | xargs)
    origin=$(echo "$origin" | xargs)
    # Exclure les snapshots (ayant une origine) et les backups (lvbackup_*)
    [[ -n "$origin" ]] && continue
    [[ "$lv" == lvbackup_* ]] && continue
    VOLUMES["$vg"]+="$lv "
  done <<<"$volume_list"

  # Affichage de la liste des volumes disponibles
  echo -e "\n📦 Available Volumes:"
  local i=1 choices=()
  for vg in "${!VOLUMES[@]}"; do
    for lv in ${VOLUMES[$vg]}; do
      echo "$i) $vg/$lv"
      choices+=("$vg|$lv")
      ((i++))
    done
  done

  # Vérifier qu'au moins un volume est disponible
  if [ ${#choices[@]} -eq 0 ]; then
    echo "❌ Aucun volume disponible pour créer un snapshot."
    exit 1
  fi

  read -rp $'Choose a volume (number): ' selection
  IFS='|' read -r SELECTED_VG SELECTED_LV <<<"${choices[$((selection - 1))]}"
  SELECTED_VG=$(echo "$SELECTED_VG" | xargs)
  SELECTED_LV=$(echo "$SELECTED_LV" | xargs)
}

# Affichage des indices pour la création d’un snapshot
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
  vgs --noheadings -o vg_name,vg_free --units g | while read -r vg free; do
    free_clean=$(echo "$free" | sed 's/g//i' | xargs)
    if [[ $(printf "%.0f" "$free_clean") -le 0 ]]; then
      printf "%-10s %-10s ❌ (full)\n" "$vg" "$free"
    else
      printf "%-10s %-10s ✅\n" "$vg" "$free"
    fi
  done

  echo -e "\n💡 Recommended snapshot size: $recommended (10% of original volume)"
  echo -e "ℹ️  Snapshot tracks only changed blocks. Heavy write activity increases usage.\n"
}

ask_snapshot_size() {
  echo ""
  read -rp "Enter snapshot size [default: $1]: " SNAP_SIZE
  SNAP_SIZE=${SNAP_SIZE:-$1}
}

# === Menu principal ===
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

    # Vérifier l'espace libre dans le VG source
    VG_FREE=$(vgs --noheadings -o vg_free --units g "$SELECTED_VG" | xargs | sed 's/g//i')
    VG_FREE_INT=$(printf "%.0f" "$VG_FREE")
    if [[ "$VG_FREE_INT" -le 0 ]]; then
      echo -e "\n❗ No free space left in VG '$SELECTED_VG'."
      echo "💾 Do you want to create a snapshot-like backup in another VG? (yes/no): "
      read -r backup_confirm
      if [[ "$backup_confirm" == "yes" ]]; then
        echo -e "\n📦 Available Volume Groups with space:"
        vgs --noheadings -o vg_name,vg_free --units g | grep -vi "$SELECTED_VG" | column -t
        echo ""
        read -rp "Enter target VG for backup: " TARGET_VG

        LV_PATH="/dev/$SELECTED_VG/$SELECTED_LV"
        BACKUP_NAME="lvbackup_${SELECTED_LV}_$(date +%Y%m%d_%H%M)"

        echo "🔁 Full backup requires a volume at least as large as the source (${lv_size}G)."
        echo ""
        read -rp "Enter backup size [default: ${lv_size}G]: " BACKUP_SIZE
        BACKUP_SIZE=${BACKUP_SIZE:-${lv_size}G}

        # Ajout de l'unité G si manquant
        if [[ ! "$BACKUP_SIZE" =~ [0-9]+G$ ]]; then
          BACKUP_SIZE="${BACKUP_SIZE}G"
        fi

        # Validation de la taille du backup
        if [[ "$BACKUP_SIZE" < "$lv_size" ]]; then
          echo "❌ Backup size must be greater than or equal to the original volume size ($lv_size)."
          exit 1
        fi

        if lvcreate -L "$BACKUP_SIZE" -n "$BACKUP_NAME" "$TARGET_VG"; then
          echo "🚀 Copying $LV_PATH into /dev/$TARGET_VG/$BACKUP_NAME ..."
          if command -v pv >/dev/null 2>&1; then
            dd if="$LV_PATH" bs=4M | pv | dd of="/dev/$TARGET_VG/$BACKUP_NAME" bs=4M
          else
            dd if="$LV_PATH" of="/dev/$TARGET_VG/$BACKUP_NAME" bs=4M status=progress
          fi
          echo "✅ Backup completed as /dev/$TARGET_VG/$BACKUP_NAME"
        else
          echo "❌ Failed to create backup volume."
        fi
        continue
      else
        echo "❎ Cancelled."
        continue
      fi
    fi

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
    read -rp "Enter snapshot or backup names to delete (space-separated): " snaps
    for snap in $snaps; do
      deleted=0
      for vg in $(lvs --noheadings -o vg_name --select "lv_name=$snap" | xargs); do
        if lvremove -f "/dev/$vg/$snap" 2>/dev/null; then
          echo "🗑️  Snapshot $snap deleted from $vg."
          deleted=1
          break
        fi
      done
      if [[ $deleted -eq 0 ]]; then
        vg_match=$(lvs --noheadings -o vg_name --select "lv_name=$snap" | xargs)
        if [[ -n "$vg_match" ]]; then
          if lvremove -f "/dev/$vg_match/$snap" 2>/dev/null; then
            echo "🗑️  Manual backup $snap deleted from $vg_match."
          else
            echo "❌ Failed to delete $snap from $vg_match."
          fi
        else
          echo "⚠️  Snapshot or backup $snap not found."
        fi
      fi
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
