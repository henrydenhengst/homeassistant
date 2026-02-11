deploy_docker_stack() {

  STACK_DIR="$HOME/home-assistant"
  mkdir -p "$STACK_DIR"

cat > "$STACK_DIR/docker-compose.yml" <<EOF
services:
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./config:/config

  mosquitto:
    image: eclipse-mosquitto
    container_name: mosquitto
    restart: unless-stopped
    ports:
      - "8120:1883"

  mariadb:
    image: mariadb:10.11
    container_name: mariadb
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD=root
    volumes:
      - ./mariadb:/var/lib/mysql
EOF

  docker compose -f "$STACK_DIR/docker-compose.yml" up -d
}