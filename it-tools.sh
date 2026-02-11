deploy_it_tools() {

  STACK_DIR="$HOME/home-assistant"

cat >> "$STACK_DIR/docker-compose.yml" <<EOF

  it-tools:
    image: corentinth/it-tools
    container_name: it-tools
    restart: unless-stopped
    ports:
      - "8135:80"
EOF

  docker compose -f "$STACK_DIR/docker-compose.yml" up -d
}