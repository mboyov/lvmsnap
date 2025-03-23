# 🧠 LVM Snapshot Manager

A shell-based tool to manage LVM snapshots and manual backups with ease and reliability. This project includes robust volume detection, flexible restoration logic, and quality-of-life improvements for system administrators and power users.

---

## 🚀 Overview

LVM Snapshot Manager provides a user-friendly CLI for creating, restoring, and managing LVM snapshots and manual backups. Key improvements include:

- 🔄 **Dynamic Volume Reloading:** Ensures up-to-date logical volume list on each snapshot operation.
- 🚫 **Volume Exclusion Filter:** Automatically hides `lvbackup_*` volumes from snapshot selection.
- 🛠️ **VG-Aware Backup Restoration:** Accurately determines the correct Volume Group (VG) and uses `dd` for restoration.
- 🧼 **Safe Restoration Checks:** Warns and provides detailed error output if the target volume cannot be unmounted.
- 📋 **Improved Feedback:** Verbose output for error handling and recovery suggestions.

---

## ✨ Features

- **Dynamic Volume Detection:** Detects and reloads available logical volumes automatically.
- **Snapshot & Backup Management:** Create, list, delete, and restore both snapshots and manual backups.
- **Manual Backup Restoration:** Allows restoring LVs using `dd` when space is unavailable in the original VG.
- **Unmount Detection:** Checks `/dev/<VG>/<LV>` and `/dev/mapper/<VG>-<LV>` before attempting restoration.
- **Test & Lint Suite:** Included `Makefile` allows quick testing and linting.

---

## 🛠️ Installation

1. **Prerequisites:**
- `lvm2`, `dd`, `bc`
- (Optional) `pv` for progress display during data copying

2. **Clone the repository:**

```bash
git clone git@github.com:mboyov/lvmsnap.git
cd lvmsnap
```

---

## 📦 Usage

Run the Snapshot Manager with:

```bash
bash bin/snapshot_manager.sh
```

You will be presented with a menu:

- Create a snapshot
- List snapshots
- Delete one or more snapshots
- Restore a snapshot
- Exit

Follow the prompts to manage your LVM snapshots and manual backups.

---

## ♻️ Manual Backup Restoration

When restoring a manual backup:

- The script auto-detects the correct VG.
- Checks if the target LV is mounted.
- Prompts for unmount if needed.
- If unmounting fails (e.g., due to Proxmox usage), displays full error context and suggests booting into rescue/live mode.

---

## ✅ Testing

Run the test script:

```bash
make test
```

> Logs are saved in the `logs/` directory.

---

## 🧹 Linting & Cleaning

**Lint with ShellCheck:**

```bash
make lint
```

**Remove logs:**

```bash
make clean
```

---

## 🤝 Contributing

Contributions are welcome! Please open a pull request with detailed explanations.

---

## 📄 License

Licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
