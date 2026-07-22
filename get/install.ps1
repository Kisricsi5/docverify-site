# Confyro installer — Windows PowerShell (5.1 or newer).
#
# What this script does (read it — it is short on purpose):
#   1. checks that Docker Desktop is installed and running
#   2. signs in to pull the image (token from your activation email)
#   3. creates a .\confyro directory and downloads the official compose file
#   4. generates a local admin password into .env (printed once, below)
#   5. starts Confyro with `docker compose up -d`
#
# The full copy-paste commands are in your activation email. This script is the
# guided alternative. The image sign-in token is NOT stored in this public
# file — you paste it (from your email) when prompted.
$ErrorActionPreference = "Stop"

$BaseUrl = if ($env:CONFYRO_INSTALL_BASE) { $env:CONFYRO_INSTALL_BASE } else { "https://confyro.com/get" }
$RegistryUser = "kisricsi5"

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

# 2. Sign in to pull the image. Token comes from your activation email
#    (or set CONFYRO_PULL_TOKEN before running); not stored in this file.
$token = if ($env:CONFYRO_PULL_TOKEN) { $env:CONFYRO_PULL_TOKEN } else {
    Read-Host "Paste the image token from your activation email"
}
$token | docker login ghcr.io -u $RegistryUser --password-stdin
if ($LASTEXITCODE -ne 0) {
    Write-Host "Sign-in failed — check the token from your activation email."
    exit 1
}

# 3. A directory of its own
New-Item -ItemType Directory -Force -Path "confyro" | Out-Null
Set-Location "confyro"

# The official compose file
Write-Host "Downloading docker-compose.yml from $BaseUrl ..."
Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/docker-compose.yml" -OutFile "docker-compose.yml"

# 4. Your login password (kept only in .\confyro\.env on this machine)
$needPassword = $true
if (Test-Path ".env") {
    $envText = Get-Content ".env" -Raw
    if ($envText -match "CONFYRO_ADMIN_PASSWORD=") { $needPassword = $false }
}
if ($needPassword) {
    Write-Host ""
    Write-Host "Choose a password to log in to Confyro (the username is always 'admin')."
    Write-Host "Pick something you'll remember — you can just press Enter to have one made for you."
    $password = Read-Host "   Your Confyro password"
    if ([string]::IsNullOrWhiteSpace($password)) {
        $bytes = New-Object byte[] 12
        [System.Security.Cryptography.RNGCryptoServiceProvider]::new().GetBytes($bytes)
        $password = ($bytes | ForEach-Object { $_.ToString("x2") }) -join ""
        Write-Host "   (No password typed — we made one for you: $password)"
    }
    Add-Content -Path ".env" -Value "CONFYRO_ADMIN_PASSWORD=$password" -Encoding ascii
    Write-Host "   Saved. Log in with  user: admin   and the password you chose."
    Write-Host ""
}

# 5. Pull and start
docker compose up -d
if ($LASTEXITCODE -ne 0) {
    Write-Host "docker compose failed — see the message above."
    exit 1
}

# 6. A desktop / Start-menu icon that opens Confyro in an app-style window.
$confyroDir = (Get-Location).Path
try {
    Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/Open-Confyro.ps1" -OutFile "Open-Confyro.ps1"
    Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/confyro.ico"     -OutFile "confyro.ico"

    $ps = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $launcher = Join-Path $confyroDir "Open-Confyro.ps1"
    $icon = Join-Path $confyroDir "confyro.ico"
    $wsh = New-Object -ComObject WScript.Shell
    foreach ($dir in @([Environment]::GetFolderPath("Desktop"),
                       [Environment]::GetFolderPath("Programs"))) {
        $lnk = $wsh.CreateShortcut((Join-Path $dir "Confyro.lnk"))
        $lnk.TargetPath = $ps
        $lnk.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$launcher`""
        $lnk.WorkingDirectory = $confyroDir
        $lnk.IconLocation = $icon
        $lnk.Description = "Open Confyro"
        $lnk.Save()
    }
    Write-Host "A 'Confyro' icon is now on your Desktop and in the Start menu."
    Write-Host "(Right-click it -> Pin to taskbar to keep it handy.)"
} catch {
    Write-Host "Confyro is installed; the desktop icon could not be created ($($_.Exception.Message))."
    Write-Host "You can always open it at http://localhost:8000"
}

Write-Host ""
Write-Host "Confyro is starting."
Write-Host "Click the new Confyro icon, or open  http://localhost:8000 , then paste"
Write-Host "your activation key from your email."
