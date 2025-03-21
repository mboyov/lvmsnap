# 🧪 LVM Snapshot Manager

Interactive Bash-based CLI tool to manage LVM snapshots: create, list, delete and restore.  
Designed for Ubuntu 24.04+ and LVM-based systems.

---

## 📁 Project Structure

```
lvm-snapshot-manager/
├── bin/                   # Main CLI script
├── lib/                   # Reusable shell functions (utils)
├── config/                # Configuration file (VG/LV names, etc.)
├── logs/                  # (Optional) Future logging output
├── tests/                 # Snapshot creation test script
├── docs/                  # Project documentation
├── LICENSE                # To be filled
├── Makefile               # Developer convenience commands
└── README.md              # README
```
---

## 🚀 Usage

Make sure `make` is installed, then run:

```bash
make run
```

Or run directly:

```bash
bash bin/snapshot_manager.sh
```

---

## 🧩 Features

- ✅ Create LVM snapshots with timestamp
- 🔍 List existing snapshots in table format
- 🗑️ Delete one or multiple snapshots interactively
- 🛠️ Restore from a snapshot (merge, reboot required)
- ⚠️ Detects and blocks actions if a snapshot is currently merging
- 🧪 Includes basic test for snapshot creation

---

## ⚙️ Configuration

Edit the `config/config.sh` file:

```bash
export VG_NAME="ubuntu-vg"
export LV_NAME="ubuntu-lv"
export SNAP_PREFIX="snap_ubuntu"
export SNAP_SIZE="10G"
```

---

## 🧪 Tests

Run snapshot creation test:

```bash
make test
```

This test will:
- Create a snapshot
- Verify it's listed
- Remove it after the test

---

## 🔍 Lint

Use ShellCheck to analyze all scripts:

```bash
make lint
```

This skips SC1091 warnings due to dynamic `source` usage (intentional).

---

## 📦 Dependencies

- `lvm2` (for LVM commands)
- `make` (optional, for command shortcuts)
- `shellcheck` (optional, for linting)
- Bash 4+

---

## 📝 Notes

- Snapshot restore requires a system reboot.
- You cannot create a new snapshot while a merge is in progress.
- Tested on Ubuntu Server 24.04 with encrypted LVM setup.

---

## ✍️ Author

**mboyov**

---

## 📄 License

To be completed in `LICENSE` file.

