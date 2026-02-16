#!/usr/bin/env bash
set -e

USER_NAME="${SUDO_USER:-$(whoami)}"
HOMELAB_DIR="/srv/homelab"

echo "===================================="
echo " Homelab Post Setup Script"
echo "===================================="

# ----------------------------
# Check docker group
# ----------------------------
echo ">>> Checking docker group membership"

if id -nG "$USER_NAME" | grep -qw docker; then
    echo "User $USER_NAME is in docker group ✅"
else
    echo "Adding $USER_NAME to docker group"
    usermod -aG docker "$USER_NAME"
fi

# ----------------------------
# Maak homelab folder
# ----------------------------
echo ">>> Ensuring homelab directory exists"
mkdir -p "$HOMELAB_DIR"
chown -R "$USER_NAME":"$USER_NAME" "$HOMELAB_DIR"

# ----------------------------
# Docker check
# ----------------------------
echo ">>> Checking Docker service"
systemctl enable docker || true
systemctl start docker || true

# ----------------------------
# Force docker group refresh
# ----------------------------
echo ">>> Refreshing group membership"

if command -v loginctl >/dev/null 2>&1; then
    echo "Restarting user session (clean method)"
    loginctl terminate-user "$USER_NAME" || true
else
    echo "Fallback to newgrp"
    su - "$USER_NAME" -c "newgrp docker <<EOF
echo Docker group refreshed
EOF"
fi

echo ""
echo "===================================="
echo " DONE"
echo "===================================="
echo ""
echo "➡ Reconnect SSH if session closed"
echo "➡ Then run:"
echo ""
echo "cd $HOMELAB_DIR"
echo "docker compose up -d"
echo ""