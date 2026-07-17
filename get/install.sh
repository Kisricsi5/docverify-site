#!/bin/sh
# Confyro installer — Mac / Linux / any cloud server.
#
# What this script does (read it — it is short on purpose):
#   1. checks that Docker is installed and running
#   2. creates a ./confyro directory
#   3. downloads the official docker-compose.yml from confyro.com
#   4. generates a local admin password into .env (printed once, below)
#   5. starts Confyro with `docker compose up -d`
#
# Prefer doing it by hand? The whole install is just:
#   mkdir confyro && cd confyro
#   curl -fsSO https://confyro.com/get/docker-compose.yml
#   docker compose up -d
set -eu

BASE_URL="${CONFYRO_INSTALL_BASE:-https://confyro.com/get}"

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

# 2. A directory of its own
mkdir -p confyro
cd confyro

# 3. The official compose file
echo "Downloading docker-compose.yml from ${BASE_URL} ..."
curl -fsS -o docker-compose.yml "${BASE_URL}/docker-compose.yml"

# 4. Local admin password (kept only in ./confyro/.env on this machine)
if [ ! -f .env ] || ! grep -q '^CONFYRO_ADMIN_PASSWORD=' .env 2>/dev/null; then
    PASSWORD="$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    printf 'CONFYRO_ADMIN_PASSWORD=%s\n' "$PASSWORD" >> .env
    echo
    echo "  Confyro admin login  ->  user: admin   password: $PASSWORD"
    echo "  (saved in ./confyro/.env — you will not see it printed again)"
    echo
fi

# 5. Pull and start
docker compose up -d

echo
echo "Confyro is starting."
echo "Open  http://localhost:8000  and paste your activation key (from your email)."
