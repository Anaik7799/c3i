#!/bin/bash
# Run this ON nuc-1 to copy vm-101-disk-0 snapshot to nas-1 as a new VDI.
# Streams over SSH; takes ~8-10 hours for 760 GB.
set -euo pipefail

SNAP=rpool/data/vm-101-disk-0@migrate-to-nas1-20260422-1951
NAS1=root@192.168.1.219
SR_UUID=b5a35a7b-c144-fde0-1f4d-495833c4470b
LOG=/tmp/vm1-copy.log

echo "[$(date -Is)] generating VDI UUID via python"
VDI_UUID=$(python3 -c 'import uuid; print(uuid.uuid4())')
echo "VDI UUID: $VDI_UUID"
echo "$VDI_UUID" > /tmp/vm1-vdi-uuid.txt

echo "[$(date -Is)] starting zfs send | xe vdi-import"
echo "Logging to $LOG (tail -f to monitor)"

zfs send -v "$SNAP" | \
  ssh -o StrictHostKeyChecking=no "$NAS1" \
    "xe vdi-import uuid=$VDI_UUID sr-uuid=$SR_UUID filename=/dev/stdin format=raw" \
  > "$LOG" 2>&1

echo "[$(date -Is)] done"
echo "VDI UUID on nas-1: $VDI_UUID (saved to /tmp/vm1-vdi-uuid.txt)"
echo "Create a VM on nas-1 and attach this VDI as its disk with: xe vm-disk-add vm=<vm-uuid> disk-size=0 vdi-uuid=$VDI_UUID device=0"
