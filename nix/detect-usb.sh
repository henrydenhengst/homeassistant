#!/usr/bin/env bash
set -e

ENV_FILE="/opt/homelab/.env"

echo "Detecting USB serial devices..."

ZIGBEE=$(ls /dev/serial/by-id/*Zigbee* 2>/dev/null | head -n1 || true)
BLE=$(ls /dev/serial/by-id/*USB* 2>/dev/null | grep -v Zigbee | head -n1 || true)

if [ -z "$ZIGBEE" ]; then
  echo "⚠️ No Zigbee dongle detected"
else
  echo "Zigbee found: $ZIGBEE"
  sed -i "s|^ZIGBEE_DEVICE=.*|ZIGBEE_DEVICE=$ZIGBEE|" $ENV_FILE || \
  echo "ZIGBEE_DEVICE=$ZIGBEE" >> $ENV_FILE
fi

if [ -z "$BLE" ]; then
  echo "⚠️ No BLE dongle detected"
else
  echo "BLE found: $BLE"
  sed -i "s|^BLE_DEVICE=.*|BLE_DEVICE=$BLE|" $ENV_FILE || \
  echo "BLE_DEVICE=$BLE" >> $ENV_FILE
fi

echo "Done."