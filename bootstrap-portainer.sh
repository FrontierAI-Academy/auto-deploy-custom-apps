#!/usr/bin/env bash
set -euo pipefail

red(){ printf "\033[31m%s\033[0m\n" "$*"; }
green(){ printf "\033[32m%s\033[0m\n" "$*"; }
yellow(){ printf "\033[33m%s\033[0m\n" "$*"; }

# --- Inputs ---------------------------------------------------------------
read -rp "Customer DOMAIN (e.g. example.com): " DOMAIN
read -rp "Admin email for Let's Encrypt: " EMAIL

PASSWORD_32="GBMmWvoKPt9JKHVaPsTWwmA2vgmavYcS"  # per request (default for everyone)
SERVER_IP="$(curl -fsSL https://ipinfo.io/ip || curl -fsSL ifconfig.me || hostname -I | awk '{print $1}')"

yellow "Using SERVER_IP=$SERVER_IP, DOMAIN=$DOMAIN, EMAIL=$EMAIL"

# --- Packages / Docker ----------------------------------------------------
yellow "Installing updates and Docker..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl jq ca-certificates >/dev/null 2>&1 || true
if ! command -v docker >/dev/null 2>&1; then
  yellow "Installing Docker 24.0.9 (stable version for Swarm)..."

  # Add official Docker repo (Ubuntu 22.04 Jammy)
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt update -y
  sudo apt install -y \
    docker-ce=5:24.0.9-1~ubuntu.22.04~jammy \
    docker-ce-cli=5:24.0.9-1~ubuntu.22.04~jammy \
    containerd.io \
    docker-compose-plugin
fi

# --- Swarm / networks / volumes ------------------------------------------
yellow "Initializing Docker Swarm (if needed)..."
if ! docker info 2>/dev/null | grep -q 'Swarm: active'; then
  docker swarm init --advertise-addr="${SERVER_IP}" || true
fi

yellow "Creating overlay networks..."
docker network create --driver=overlay traefik_public >/dev/null 2>&1 || true
docker network create --driver=overlay general_network >/dev/null 2>&1 || true
docker network create --driver=overlay agent_network  >/dev/null 2>&1 || true

yellow "Creating volumes..."
for v in certificados portainer_data; do docker volume create "$v" >/dev/null; done

# --- Traefik stack --------------------------------------------------------
yellow "Deploying Traefik..."
cat > /tmp/traefik.yaml <<'YAML'
version: '3.8'
services:
  traefik:
    image: traefik:v2.11
    command:
      - --providers.docker=true
      - --providers.docker.swarmMode=true
      - --providers.docker.network=traefik_public
      - --providers.docker.exposedbydefault=false
      - --providers.docker.endpoint=unix:///var/run/docker.sock
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --entrypoints.web.http.redirections.entryPoint.to=websecure
      - --entrypoints.web.http.redirections.entryPoint.scheme=https
      - --certificatesresolvers.le.acme.email=${EMAIL}
      - --certificatesresolvers.le.acme.storage=/letsencrypt/acme.json
      - --certificatesresolvers.le.acme.httpchallenge=true
      - --certificatesresolvers.le.acme.httpchallenge.entrypoint=web
      - --ping=true
      - --accesslog=true
      - --log.level=INFO
    ports: ["80:80","443:443"]
    volumes:
      - certificados:/letsencrypt
      - /var/run/docker.sock:/var/run/docker.sock:ro
    deploy:
      replicas: 1
      placement:
        constraints: [ node.role == manager ]
    networks: [traefik_public]
volumes:
  certificados:
    external: true
networks:
  traefik_public: { external: true }
YAML

EMAIL="$EMAIL" docker stack deploy -c /tmp/traefik.yaml traefik

# --- Portainer secret / stack --------------------------------------------
yellow "Creating Portainer admin secret from PASSWORD_32..."
docker secret rm portainer_admin_password >/dev/null 2>&1 || true
printf '%s' "$PASSWORD_32" | docker secret create portainer_admin_password - >/dev/null

yellow "Deploying Portainer (agent + server) at https://portainerapp.${DOMAIN}"
cat > /tmp/portainer.yaml <<'YAML'
version: '3.8'
services:
  agent:
    image: portainer/agent:2.20.1
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes
    networks: [agent_network]
    deploy:
      mode: global
      placement:
        constraints: [ node.platform.os == linux ]

  portainer:
    image: portainer/portainer-ce:2.20.1
    command:
      - -H
      - tcp://tasks.agent:9001
      - --tlsskipverify
      - --admin-password-file
      - /run/secrets/portainer_admin_password
    volumes:
      - portainer_data:/data
    networks: [agent_network, traefik_public]
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints: [ node.role == manager ]
      labels:
        - traefik.enable=true
        - traefik.http.routers.portainer.rule=Host(`portainerapp.${DOMAIN}`)
        - traefik.http.routers.portainer.entrypoints=websecure
        - traefik.http.routers.portainer.tls.certresolver=le
        - traefik.http.services.portainer.loadbalancer.server.port=9000
    secrets:
      - portainer_admin_password
networks:
  agent_network:  { external: true }
  traefik_public: { external: true }
volumes:
  portainer_data: { external: true }
secrets:
  portainer_admin_password: { external: true }
YAML

DOMAIN="$DOMAIN" docker stack deploy -c /tmp/portainer.yaml portainer

green "==============================================================="
green "✅ Bootstrap done."
echo  "Create the following DNS A records pointing to ${SERVER_IP}:"
cat <<DNS
- portainerapp.${DOMAIN}
# (Más tarde, tus apps usarán:)
- rabbitmqapp.${DOMAIN}
- miniofrontapp.${DOMAIN}
- miniobackapp.${DOMAIN}
- chatwootapp.${DOMAIN}
- n8napp.${DOMAIN}
- n8nwebhookapp.${DOMAIN}
DNS
green "When DNS propagates, Traefik will issue certificates automatically."
green "Login: https://portainerapp.${DOMAIN}  user: admin  pass: ${PASSWORD_32}"
