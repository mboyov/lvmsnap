#!/bin/bash

# -------------------------------------------------------------------
# Updated Test Script: Snapshot Creation (Dynamic Volume Detection)
# -------------------------------------------------------------------

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

# Récupération du premier VG/LV disponible
volume_list=$(lvs --noheadings --separator '|' -o vg_name,lv_name)
first_entry=$(echo "$volume_list" | head -n1)
VG_NAME=$(echo "$first_entry" | cut -d'|' -f1 | xargs)
LV_NAME=$(echo "$first_entry" | cut -d'|' -f2 | xargs)

if [[ -z "$VG_NAME" || -z "$LV_NAME" ]]; then
  echo "❌ No logical volumes available for testing."
  exit 1
fi

LV_PATH="/dev/$VG_NAME/$LV_NAME"

# Calcul de la taille recommandée (10 % de la taille de la LV)
lv_size=$(lvs --noheadings -o lv_size --units g "$LV_PATH" | xargs | sed 's/g//i')
recommended_calc=$(echo "$lv_size * 0.1" | bc 2>/dev/null | xargs printf "%.0f")
SNAP_SIZE="${recommended_calc:-1}G"
SNAP_NAME="test_snap_${LV_NAME}_$(date +%F_%H%M%S)"

echo "🔧 Testing snapshot creation on $LV_PATH"
echo "📐 Snapshot size: $SNAP_SIZE"
echo "📛 Snapshot name: $SNAP_NAME"

# Création du snapshot
if lvcreate -L"$SNAP_SIZE" -s -n "$SNAP_NAME" "$LV_PATH" >/dev/null 2>&1; then
  echo "✅ Snapshot $SNAP_NAME created successfully."

  # Vérification de la présence du snapshot dans la liste
  if lvs | grep -q "$SNAP_NAME"; then
    echo "🧪 Test passed: Snapshot found in 'lvs' list."

    # Suppression du snapshot après test
    lvremove -f "/dev/$VG_NAME/$SNAP_NAME" >/dev/null
    echo "🧹 Snapshot $SNAP_NAME removed after test."
    exit 0
  else
    echo "❌ Snapshot not found in list after creation."
    exit 1
  fi
else
  echo "❌ Failed to create snapshot."
  exit 1
fi
