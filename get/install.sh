#!/bin/sh
# Confyro installer — Mac / Linux / any cloud server.
#
# What this script does (read it — it is short on purpose):
#   1. checks that Docker is installed and running
#   2. signs in to pull the image (token from your activation email)
#   3. creates a confyro directory in your home folder and downloads the
#      official compose file into it
#   4. generates a local admin password into .env (printed once, below)
#   5. starts Confyro with `docker compose up -d`
#   6. adds a Confyro icon (an app on macOS, a menu entry on Linux)
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

# 1b. Is port 8000 free? A clash there fails the container start with a socket
#     error that means nothing to a buyer, and only after they have pasted their
#     setup code. Name it first, while nothing is half-installed. Best effort:
#     if neither tool is present we simply carry on.
port_8000_busy() {
    if command -v lsof >/dev/null 2>&1; then
        lsof -nP -iTCP:8000 -sTCP:LISTEN >/dev/null 2>&1 && return 0
    elif command -v ss >/dev/null 2>&1; then
        ss -ltn 2>/dev/null | grep -q '[:.]8000[[:space:]]' && return 0
    fi
    return 1
}
if port_8000_busy; then
    echo "Another program on this computer is already using port 8000."
    echo "Confyro needs that port. Close that program, then run this again."
    exit 1
fi

# 2. Sign in to pull the image. The read-only token is in your activation
#    email; paste it when prompted, or set CONFYRO_PULL_TOKEN before running.
if [ -n "${CONFYRO_PULL_TOKEN:-}" ]; then
    echo "$CONFYRO_PULL_TOKEN" | docker login ghcr.io -u "$REGISTRY_USER" --password-stdin
else
    # "setup code" is what the activation email calls it. Keep the two in step:
    # a buyer hunting for an "image token" in an email that never says those
    # words is a buyer who stops here.
    printf 'Paste the setup code from your activation email (it stays hidden): '
    stty -echo 2>/dev/null || true
    read -r TOKEN
    stty echo 2>/dev/null || true
    echo
    echo "$TOKEN" | docker login ghcr.io -u "$REGISTRY_USER" --password-stdin
fi

# 3. A directory of its own -- always under $HOME, never relative to wherever
#    the terminal happened to be sitting when this was pasted.
CONFYRO_DIR="${CONFYRO_HOME:-$HOME/confyro}"
mkdir -p "$CONFYRO_DIR"
cd "$CONFYRO_DIR"
echo "Installing into $CONFYRO_DIR"
echo "Downloading docker-compose.yml from ${BASE_URL} ..."
curl -fsSL -o docker-compose.yml "${BASE_URL}/docker-compose.yml"

# 4. Local admin password (kept only in ./confyro/.env on this machine)
if [ ! -f .env ] || ! grep -q '^CONFYRO_ADMIN_PASSWORD=' .env 2>/dev/null; then
    PASSWORD="$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    printf 'CONFYRO_ADMIN_PASSWORD=%s\n' "$PASSWORD" >> .env
    echo
    echo "  Confyro sign-in password  ->  $PASSWORD"
    echo "  (saved in $CONFYRO_DIR/.env — you will not see it printed again)"
    echo
fi

# 5. Pull and start
docker compose up -d

# 6. An icon that opens Confyro in an app-style window — the same one-click way
#    in as the Windows installer gives. Never fatal: if anything here fails the
#    install is still complete and http://localhost:8000 always works.
make_icon() {
    curl -fsSL -o open-confyro.sh "${BASE_URL}/open-confyro.sh" || return 1
    chmod +x open-confyro.sh

    if [ "$(uname)" = "Darwin" ]; then
        curl -fsSL -o confyro.icns "${BASE_URL}/confyro.icns" || true
        APP="$HOME/Applications/Confyro.app"
        mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
        cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Confyro</string>
  <key>CFBundleDisplayName</key><string>Confyro</string>
  <key>CFBundleIdentifier</key><string>com.confyro.launcher</string>
  <key>CFBundleExecutable</key><string>Confyro</string>
  <key>CFBundleIconFile</key><string>confyro</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
        printf '#!/bin/sh\nexec "%s/open-confyro.sh"\n' "$CONFYRO_DIR" \
            > "$APP/Contents/MacOS/Confyro"
        chmod +x "$APP/Contents/MacOS/Confyro"
        if [ -f confyro.icns ]; then
            cp confyro.icns "$APP/Contents/Resources/confyro.icns"
        fi
        ln -sf "$APP" "$HOME/Desktop/Confyro.app" 2>/dev/null || true
        echo "A 'Confyro' app is now in your Applications folder and on your Desktop."
    else
        curl -fsSL -o confyro.png "${BASE_URL}/confyro.png" || true
        DESKTOP_DIR="${XDG_DESKTOP_DIR:-$HOME/Desktop}"
        APPS_DIR="$HOME/.local/share/applications"
        mkdir -p "$APPS_DIR"
        cat > "$APPS_DIR/confyro.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Confyro
Comment=Check a document against the ones you trust
Exec=$CONFYRO_DIR/open-confyro.sh
Icon=$CONFYRO_DIR/confyro.png
Terminal=false
Categories=Office;
DESKTOP
        chmod +x "$APPS_DIR/confyro.desktop"
        if [ -d "$DESKTOP_DIR" ]; then
            cp "$APPS_DIR/confyro.desktop" "$DESKTOP_DIR/confyro.desktop"
            chmod +x "$DESKTOP_DIR/confyro.desktop"
        fi
        echo "A 'Confyro' entry is now in your applications menu."
    fi
}
make_icon || echo "Confyro is installed; the icon could not be created. Open http://localhost:8000"

echo
echo "Confyro is starting."
echo "Click the new Confyro icon, or open  http://localhost:8000 , then paste"
echo "your activation key (from your email)."
