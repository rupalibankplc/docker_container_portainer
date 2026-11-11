# Ubuntu Docker + Portainer installer

A small installer for a new Ubuntu server. It installs Docker Engine, Docker Compose v2, Portainer CE, and UFW. It is intended to be run as a normal sudo-enabled user, not as root.

## What the installer changes

- Configures Docker's official Ubuntu APT repository and installs Docker Engine, the Compose v2 plugin, and Buildx.
- Enables Docker and containerd at startup.
- Creates a persistent Docker volume and runs Portainer CE on TCP port `9443`.
- Allows the standard UFW `OpenSSH` profile and TCP `9443`, then enables UFW if it was inactive. Existing firewall rules are not reset.
- Does **not** automatically remove conflicting container packages. If it finds any, it stops so you can review existing workloads first.

## Requirements and cautions

- A supported Ubuntu release with `sudo`, internet access, and a standard `OpenSSH` UFW profile. The script checks that the operating system identifies as Ubuntu, but Docker's APT repository must support that release.
- Run from a non-root account that can use `sudo`.
- If SSH uses a nonstandard port, make sure that port is allowed through UFW before running the installer. Keep your current SSH session open and verify a second SSH connection after firewall changes.
- Portainer is published on all host interfaces at `https://SERVER-IP:9443`. Restrict access to trusted IPs or use a VPN where possible. Docker-published ports can interact with firewall rules differently from ordinary host services; do not assume UFW alone restricts all published container traffic.
- Portainer can control Docker through `/var/run/docker.sock`, which grants powerful, effectively root-level control of the host. Use a strong admin credential and keep Portainer updated.
- A browser certificate warning is expected initially because Portainer uses a self-signed certificate by default.

## Install

Connect to the server over SSH, then clone and inspect the repository:

```bash
sudo apt update
sudo apt install -y git
git clone https://github.com/rupalibankplc/docker_container_portainer.git
cd docker_container_portainer
less install.sh
```

Run the installer as your regular user. It asks for confirmation before making changes:

```bash
chmod +x install.sh
./install.sh
```

The script uses `sudo` when needed. It does not add your account to the `docker` group automatically.

## Verify and open Portainer

```bash
sudo systemctl status docker
sudo systemctl status containerd
sudo docker --version
sudo docker compose version
sudo docker run --rm hello-world
sudo docker ps
sudo ufw status verbose
```

Open this URL in a browser:

```text
https://SERVER-IP:9443
```

Create the Portainer administrator account during first-time setup.

## Optional: Docker commands without `sudo`

You can add your account to the `docker` group, then log out and back in:

```bash
sudo usermod -aG docker "$USER"
```

Membership in the `docker` group grants root-equivalent privileges on the host. Only do this for trusted users. Until then, prefix Docker commands with `sudo`.

## Existing installations

The installer stops if it detects certain conflicting packages rather than removing them. Review your current Docker/container setup and data before changing or removing packages. The installer also leaves an existing container named `portainer` unchanged; it does not upgrade or replace it.

Portainer's data is stored in the `portainer_data` Docker volume. Back it up before making changes to or removing the volume.
