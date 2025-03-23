# Makefile for LVM Snapshot Manager (Refactored)

BIN_DIR := bin
LIB_DIR := lib
TEST_DIR := tests

SCRIPT := $(BIN_DIR)/snapshot_manager.sh

.PHONY: run test lint clean help

run:
	@echo "🚀 Running Snapshot Manager..."
	bash $(SCRIPT)

test:
	@echo "🧪 Running tests..."
	bash $(TEST_DIR)/snap_creation.sh

lint:
	@echo "🔍 Running ShellCheck (ignoring SC1091)..."
	shellcheck -e SC1091 bin/snapshot_manager.sh
	shellcheck -e SC1091 lib/utils.sh
	shellcheck -e SC1091 tests/snap_creation.sh

clean:
	@echo "🧹 Cleaning logs..."
	rm -f logs/*.log

help:
	@echo "Available commands:"
	@echo "  make run     - Run the snapshot manager script"
	@echo "  make test    - Run the test scripts"
	@echo "  make lint    - Lint all scripts with ShellCheck"
	@echo "  make clean   - Remove logs"

