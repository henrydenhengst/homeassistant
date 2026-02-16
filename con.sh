#!/bin/bash
# Docker + Portainer installer for Debian 13 (Trixie)
# Uses Docker's official repository (Bookworm) and sets up Portainer CE

set -e

# --- 1. Install prerequisites ---
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

# --- 2. Setup Docker GPG key ---
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# --- 3. Add Docker repository ---
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null <<EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable
EOF

# --- 4. Update apt and install Docker ---
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# --- 5. Enable Docker service ---
sudo systemctl enable docker
sudo systemctl start docker

# --- 6. Optional: allow user to run Docker without sudo ---
read -p "Do you want to run Docker without sudo? (y/N): " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
    sudo usermod -aG docker $USER
    echo "You need to log out and log back in (or run 'newgrp docker') for changes to take effect."
fi

# --- 7. Pull and run Portainer ---
sudo docker volume create portainer_data
sudo docker run -d \
  -p 9000:9000 \
  -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

# --- 8. Verification ---
echo "Docker version:"
docker --version
echo "Portainer is running on ports 9000 (HTTP) and 9443 (HTTPS)."
echo "Access it at: http://<your-server-ip>:9000 or https://<your-server-ip>:9443"