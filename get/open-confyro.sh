#!/bin/sh
# open-confyro.sh — click-to-open launcher for Confyro on Mac and Linux.
#
# The Confyro icon (a .app on macOS, a .desktop entry on Linux) runs this. It
# makes sure Docker and the Confyro container are running, then opens Confyro in
# a clean app-style window. Safe to run any time — it never does anything
# harmful if Confyro is already up. Lives next to your docker-compose.yml.
set -eu

URL="http://localhost:8000"
cd "$(dirname "$0")"

up() {
    # A 401 (login is on) still means the server itself is up and reachable.
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "$URL" 2>/dev/null || echo 000)
    [ "$code" -ge 200 ] 2>/dev/null && [ "$code" -lt 500 ] 2>/dev/null
}

# 1. Is Docker running? On a Mac, start Docker Desktop and wait for it.
if ! docker info >/dev/null 2>&1; then
    if [ -d "/Applications/Docker.app" ]; then
        open -g -a Docker || true
    fi
    i=0
    while [ "$i" -lt 150 ]; do
        docker info >/dev/null 2>&1 && break
        i=$((i + 1))
        sleep 1
    done
fi

# 2. Bring the container up (idempotent — a no-op if it is already running).
docker compose up -d >/dev/null 2>&1 || true

# 3. Wait for the web server to answer.
i=0
while [ "$i" -lt 60 ]; do
    up && break
    i=$((i + 1))
    sleep 1
done

# 4. Open it. Chrome and Edge support an app-style window (no tabs, no address
#    bar); anything else falls back to a normal browser window.
APP_WINDOW="--app=$URL"
if [ "$(uname)" = "Darwin" ]; then
    for b in "Google Chrome" "Microsoft Edge"; do
        if [ -d "/Applications/$b.app" ]; then
            open -na "$b" --args "$APP_WINDOW" --window-size=1240,860
            exit 0
        fi
    done
    open "$URL"
else
    for b in google-chrome chromium chromium-browser microsoft-edge; do
        if command -v "$b" >/dev/null 2>&1; then
            "$b" "$APP_WINDOW" --window-size=1240,860 >/dev/null 2>&1 &
            exit 0
        fi
    done
    (xdg-open "$URL" >/dev/null 2>&1 &) || true
fi
