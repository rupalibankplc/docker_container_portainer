#!/usr/bin/env bash
set -Eeuo pipefail

# Ubuntu Docker Engine + Compose v2 + Portainer CE installer.
# Run as a normal sudo-enabled user, not as root.

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as a normal user with sudo access, not as root." >&2
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1 || ! sudo -v; then
  echo "A working sudo installation and permission are required." >&2
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  echo "Cannot identify the operating system (/etc/os-release is missing)." >&2
  exit 1
fi

. /etc/os-release
if [[ "${ID:-}" != "ubuntu" ]]; then
  echo "This installer supports Ubuntu only. Detected: ${PRETTY_NAME:-unknown}" >&2
  exit 1
fi

if [[ -z "${VERSION_CODENAME:-}" ]]; then
  echo "Could not determine the Ubuntu release codename." >&2
  exit 1
fi

# Avoid removing or replacing an existing container installation automatically.
conflicts=()
for pkg in docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc; do
  if dpkg-query -W -f='${db:Status-Status}' "$pkg" 2>/dev/null | grep -qx installed; then
    conflicts+=("$pkg")
  fi
done
if ((${#conflicts[@]})); then
  printf 'Conflicting packages are installed: %s\n' "${conflicts[*]}" >&2
  echo "Review existing containers and remove conflicting packages manually before rerunning." >&2
  echo "The installer will not remove packages or risk disrupting existing workloads." >&2
  exit 1
fi

if ! command -v ufw >/dev/null 2>&1; then
  install_ufw=true
else
  install_ufw=false
fi

printf 'Installing Docker Engine, Compose v2, Portainer CE, and UFW on %s...\n' "${PRETTY_NAME:-Ubuntu}"
echo "This will configure UFW to allow SSH (OpenSSH profile) and Portainer HTTPS on TCP 9443."
echo "If SSH uses a custom port, ensure that port is allowed in UFW before proceeding."
read -r -p "Continue? [y/N] " answer
case "$answer" in
  [yY]|[yY][eE][sS]) ;;
  *) echo "Cancelled."; exit 0 ;;
esac

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl
if [[ "$install_ufw" == true ]]; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ufw
fi

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

arch="$(dpkg --print-architecture)"
printf '%s\n' \
  "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo systemctl enable --now containerd

sudo docker volume create portainer_data >/dev/null
if sudo docker container inspect portainer >/dev/null 2>&1; then
  echo "A Portainer container already exists; leaving it unchanged."
else
  sudo docker run -d \
    --name portainer \
    --restart=always \
    -p 9443:9443 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:lts
fi

# Preserve standard SSH access before enabling UFW. If UFW was already active,
# these rules are added without resetting the existing firewall configuration.
sudo ufw allow OpenSSH
sudo ufw allow 9443/tcp comment 'Portainer HTTPS'
if ! sudo ufw status | grep -q '^Status: active'; then
  sudo ufw --force enable
fi

printf '\nInstallation complete.\n'
sudo docker --version
sudo docker compose version
sudo docker ps --filter name=portainer --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
sudo ufw status verbose
printf '\nOpen Portainer at: https://SERVER-IP:9443\n'
echo "The browser may warn about Portainer's self-signed certificate."
echo "Docker socket access gives Portainer powerful control over the host; protect its login and restrict network access."
echo "Use 'sudo docker' for Docker commands. See README.md for optional docker-group access and firewall notes."
