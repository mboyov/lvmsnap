#!/bin/bash
# shellcheck shell=bash

# ------------------------------------------------------------------------------
# Configuration File
# Defines variables used throughout the LVM snapshot management script
# ------------------------------------------------------------------------------

export VG_NAME="ubuntu-vg"       # Volume Group name
export LV_NAME="ubuntu-lv"       # Logical Volume name
export SNAP_PREFIX="snap_ubuntu" # Prefix used for snapshot names
export SNAP_SIZE="10G"           # Default size of snapshots
