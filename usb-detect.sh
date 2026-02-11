detect_usb() {
  echo "USB devices detecteren..."

  mkdir -p /opt/ha-usb

  if [ -d /dev/serial/by-id ]; then
    ls /dev/serial/by-id > /opt/ha-usb/devices.txt
  fi
}