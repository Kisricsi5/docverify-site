# Confyro installer — Windows PowerShell (5.1 or newer).
#
# What this script does (read it — it is short on purpose):
#   1. checks that Docker Desktop is installed and running
#   2. creates a .\confyro directory
#   3. downloads the official docker-compose.yml from confyro.com
#   4. generates a local admin password into .env (printed once, below)
#   5. starts Confyro with `docker compose up -d`
#
# Prefer doing it by hand? The whole install is just:
#   mkdir confyro; cd confyro
#   iwr https://confyro.com/get/docker-compose.yml -OutFile docker-compose.yml
#   docker compose up -d
$ErrorActionPreference = "Stop"

$BaseUrl = if ($env:CONFYRO_INSTALL_BASE) { $env:CONFYRO_INSTALL_BASE } else { "https://confyro.com/get" }

# 1. Docker present and running?
$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) {
    Write-Host "Docker is not installed on this machine."
    Write-Host "Install Docker Desktop first: https://docs.docker.com/desktop/setup/install/windows-install/"
    exit 1
}
docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker is installed but not running. Start Docker Desktop and try again."
    exit 1
}

# 2. A directory of its own
New-Item -ItemType Directory -Force -Path "confyro" | Out-Null
Set-Location "confyro"

# 3. The official compose file
Write-Host "Downloading docker-compose.yml from $BaseUrl ..."
Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/docker-compose.yml" -OutFile "docker-compose.yml"

# 4. Local admin password (kept only in .\confyro\.env on this machine)
$needPassword = $true
if (Test-Path ".env") {
    $envText = Get-Content ".env" -Raw
    if ($envText -match "CONFYRO_ADMIN_PASSWORD=") { $needPassword = $false }
}
if ($needPassword) {
    $bytes = New-Object byte[] 16
    [System.Security.Cryptography.RNGCryptoServiceProvider]::new().GetBytes($bytes)
    $password = ($bytes | ForEach-Object { $_.ToString("x2") }) -join ""
    Add-Content -Path ".env" -Value "CONFYRO_ADMIN_PASSWORD=$password" -Encoding ascii
    Write-Host ""
    Write-Host "  Confyro admin login  ->  user: admin   password: $password"
    Write-Host "  (saved in .\confyro\.env — you will not see it printed again)"
    Write-Host ""
}

# 5. Pull and start
docker compose up -d
if ($LASTEXITCODE -ne 0) {
    Write-Host "docker compose failed — see the message above."
    exit 1
}

Write-Host ""
Write-Host "Confyro is starting."
Write-Host "Open  http://localhost:8000  and paste your activation key (from your email)."
