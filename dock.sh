#!/bin/bash
# Docker installation script for Debian 13 (Trixie)
# Uses Docker's official repository for Bookworm (compatible)

set -e

# Update system and install prerequisites
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

# Create keyrings directory if it doesn't exist
sudo mkdir -p /etc/apt/keyrings

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker repository (Bookworm version, works on Debian 13)
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update apt with new repo
sudo apt update

# Install Docker packages
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable Docker service
sudo systemctl enable docker
sudo systemctl start docker

# Optional: Add current user to docker group to run without sudo
read -p "Do you want to run Docker without sudo? (y/N): " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
    sudo usermod -aG docker $USER
    echo "You need to log out and log back in (or run 'newgrp docker') for changes to take effect."
fi

# Verify installation
echo "Docker version installed:"
docker --version
echo "Testing Docker with hello-world image..."
docker run --rm hello-world

echo "Docker installation completed successfully!"