setup_network() {
  echo "Netwerk configureren..."

  IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n1)

  cat > /etc/systemd/network/10-static.network <<EOF
[Match]
Name=$IFACE

[Network]
DHCP=yes
EOF

  systemctl enable systemd-networkd
  systemctl restart systemd-networkd
}