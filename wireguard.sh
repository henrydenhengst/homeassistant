setup_wireguard() {
  apt install -y wireguard

  wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key

  cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.10.0.1/24
ListenPort = 51820
PrivateKey = $(cat /etc/wireguard/private.key)
EOF

  systemctl enable wg-quick@wg0
  systemctl start wg-quick@wg0
}