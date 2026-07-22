#!/bin/sh
# Confyro installer — Mac / Linux / any cloud server.
#
# What this script does (read it — it is short on purpose):
#   1. checks that Docker is installed and running
#   2. signs in to pull the image (token from your activation email)
#   3. creates a ./confyro directory and downloads the official compose file
#   4. generates a local admin password into .env (printed once, below)
#   5. starts Confyro with `docker compose up -d`
#
# The full copy-paste commands are in your activation email. This script is
# the guided alternative. The image sign-in token is NOT stored in this public
# file — you paste it (from your email) when prompted.
set -eu

BASE_URL="${CONFYRO_INSTALL_BASE:-https://confyro.com/get}"
REGISTRY_USER="kisricsi5"

# 1. Docker present and running?
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is not installed on this machine."
    echo "Install it first: https://docs.docker.com/engine/install/  (or Docker Desktop on a Mac)"
    exit 1
fi
if ! docker info >/dev/null 2>&1; then
    echo "Docker is installed but not running (or needs sudo)."
    echo "Start Docker (or re-run this script with sudo) and try again."
    exit 1
fi

# 2. Sign in to pull the image. The read-only token is in your activation
#    email; paste it when prompted, or set CONFYRO_PULL_TOKEN before running.
if [ -n "${CONFYRO_PULL_TOKEN:-}" ]; then
    echo "$CONFYRO_PULL_TOKEN" | docker login ghcr.io -u "$REGISTRY_USER" --password-stdin
else
    printf 'Paste the image token from your activation email: '
    stty -echo 2>/dev/null || true
    read -r TOKEN
    stty echo 2>/dev/null || true
    echo
    echo "$TOKEN" | docker login ghcr.io -u "$REGISTRY_USER" --password-stdin
fi

# 3. A directory of its own + the official compose file
mkdir -p confyro
cd confyro
echo "Downloading docker-compose.yml from ${BASE_URL} ..."
curl -fsS -o docker-compose.yml "${BASE_URL}/docker-compose.yml"

# 4. Your login password (kept only in ./confyro/.env on this machine)
if [ ! -f .env ] || ! grep -q '^CONFYRO_ADMIN_PASSWORD=' .env 2>/dev/null; then
    echo
    echo "Choose a password to log in to Confyro (the username is always 'admin')."
    echo "Pick something you'll remember — or just press Enter to have one made for you."
    printf '   Your Confyro password: '
    read -r PASSWORD
    if [ -z "$PASSWORD" ]; then
        PASSWORD="$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')"
        echo "   (No password typed — we made one for you: $PASSWORD)"
    fi
    printf 'CONFYRO_ADMIN_PASSWORD=%s\n' "$PASSWORD" >> .env
    echo "   Saved. Log in with  user: admin  and the password you chose."
    echo
fi

# 5. Pull and start
docker compose up -d

echo
echo "Confyro is starting."
echo "Open  http://localhost:8000  and paste your activation key (from your email)."
