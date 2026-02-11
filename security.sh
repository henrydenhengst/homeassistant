setup_security() {
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow 22/tcp
  ufw allow 8123/tcp
  ufw allow 51820/udp
  ufw --force enable

  systemctl enable fail2ban
  systemctl start fail2ban
}