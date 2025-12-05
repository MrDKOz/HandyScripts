housekeeping() {
  local HK_FAILED=0

  echo "🔐 Validating sudo credentials..."
  if ! sudo -v; then
    echo "❌ sudo authentication failed. Aborting."
    HK_FAILED=1
  fi

  if (( ! HK_FAILED )); then
    echo ""
    echo "📸 Creating Btrfs snapshot and pruning old ones..."
    if ! snapshot_and_prune; then
      echo "❌ Snapshot step failed. Skipping the rest of housekeeping."
      HK_FAILED=1
    fi
  fi

  if (( ! HK_FAILED  )); then
    echo ""
    echo "🔧 Updating system (pacman + AUR via paru)..."
    if ! paru -Syu; then
      echo "❌ System update failed. Skipping the rest of housekeeping."
      HK_FAILED=1
    fi
  fi

  if (( ! HK_FAILED )); then
    echo ""
    echo "📝 Cleaning journal logs (keeping ~200MB)..."
    sudo journalctl --vacuum-size=200M

    echo ""
    echo "🧽 Removing orphan packages..."
    orphans=$(pacman -Qtdq 2>/dev/null || true)
    if [[ -n "$orphans" ]]; then
      echo "$orphans"
      sudo pacman -Rns $orphans
    else
      echo "No orphan packages found."
    fi

    echo ""
    echo "🗑 Clearing pacman cache..."
    sudo paccache -r
  fi

  echo ""
  if (( HK_FAILED )); then
    echo "⚠️ Housekeeping did not complete successfully."
    return 1
  else
    echo "✨ Housekeeping done."
    return 0
  fi
}

snapshot_and_prune() {
  local snap_dir="/.snapshots"
  local timestamp snap_name keep=10
  local snaps count delete_count

  timestamp="$(date +'%Y-%m-%d_%H-%M-%S')"
  snap_name="root-pre-housekeeping-$timestamp"

  echo "📸 Creating read-only Btrfs snapshot: $snap_name"

  if ! sudo btrfs subvolume snapshot -r / "$snap_dir/$snap_name"; then
    echo "❌ Failed to create Btrfs snapshot."
    return 1
  fi

  # --- Prune old housekeeping snapshots ---

  snaps=$(sudo btrfs subvolume list / \
    | awk '{print $NF}' \
    | grep '^\.snapshots/root-pre-housekeeping-' || true)

  if [[ -z "$snaps" ]]; then
    # This would be weird right after creating one, but don't treat as fatal
    echo "No housekeeping snapshots found after creation (unexpected, but continuing)."
    return 0
  fi

  count=$(printf '%s\n' "$snaps" | wc -l)

  if (( count <= keep )); then
    echo "Nothing to prune. ($count snapshots ≤ keep $keep)"
    return 0
  fi

  delete_count=$((count - keep))

  echo "Removing $delete_count old housekeeping snapshot(s)..."

  printf '%s\n' "$snaps" \
    | sort \
    | head -n "$delete_count" \
    | while read -r rel; do
        [[ -z "$rel" ]] && continue
        path="/$rel"
        echo "🗑 Deleting: $path"
        if ! sudo btrfs subvolume delete "$path"; then
          echo "⚠️ Failed to delete snapshot: $path"
        fi
      done

  return 0
}
