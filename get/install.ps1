# Confyro installer - Windows PowerShell (5.1 or newer).
#
# What this script does (read it - it is short on purpose):
#   1. checks that Docker Desktop is installed and running
#   2. signs in to pull the image (token from your activation email)
#   3. creates a confyro directory in your user folder and downloads the
#      official compose file into it
#   4. asks you to choose a login password, saved into .env on this machine
#   5. starts Confyro with `docker compose up -d`
#   6. puts a Confyro icon on your Desktop and in the Start menu
#
# The full copy-paste commands are in your activation email. This script is the
# guided alternative. The image sign-in token is NOT stored in this public
# file - you paste it (from your email) when prompted.
$ErrorActionPreference = "Stop"

$BaseUrl = if ($env:CONFYRO_INSTALL_BASE) { $env:CONFYRO_INSTALL_BASE } else { "https://confyro.com/get" }
$RegistryUser = "kisricsi5"

# 1. Docker present and running? PATH alone is not enough to answer this:
#    Docker Desktop installs per-user into AppData and adds itself to the USER
#    PATH, which a PowerShell window opened earlier will not have picked up. The
#    buyer has just been told to install Docker, so that is the common case, and
#    "Docker is not installed" would be a lie that sends them round in circles.
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
$docker = if ($dockerCmd) { $dockerCmd.Source } else {
    @("$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe",
      "$env:LOCALAPPDATA\Programs\DockerDesktop\resources\bin\docker.exe",
      "$env:LOCALAPPDATA\Programs\Docker\Docker\resources\bin\docker.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $docker) {
    Write-Host "Docker is not installed on this machine."
    Write-Host "Install Docker Desktop first: https://docs.docker.com/desktop/setup/install/windows-install/"
    exit 1
}
& $docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker is installed but not running. Start Docker Desktop and try again."
    exit 1
}

# 1b. Is port 8000 free? Confyro binds 127.0.0.1:8000, and a clash there fails
#     the container start with "Only one usage of each socket address is
#     normally permitted" - which tells a buyer nothing, and only appears after
#     they have already pasted their setup code and chosen a password. Check it
#     first, so the problem is named while nothing has been half-installed.
$busy = $null
try { $busy = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction Stop } catch {}
if ($busy) {
    $owner = (Get-Process -Id $busy[0].OwningProcess -ErrorAction SilentlyContinue).ProcessName
    if ($owner) { $who = " It looks like '$owner'." } else { $who = "" }
    Write-Host "Another program on this computer is already using port 8000.$who"
    Write-Host "Confyro needs that port. Close that program, then run this again."
    exit 1
}

# 2. Sign in to pull the image. Token comes from your activation email
#    (or set CONFYRO_PULL_TOKEN before running); not stored in this file.
$token = if ($env:CONFYRO_PULL_TOKEN) { $env:CONFYRO_PULL_TOKEN } else {
    # "setup code" is the wording the activation email uses; the two must match.
    Read-Host "Paste the setup code from your activation email"
}
$token | & $docker login ghcr.io -u $RegistryUser --password-stdin
if ($LASTEXITCODE -ne 0) {
    Write-Host "Sign-in failed - check the setup code from your activation email."
    exit 1
}

# 3. A directory of its own - always under the user's profile, never relative.
#    A shell opened from the Start menu often starts in C:\WINDOWS\System32,
#    where a normal account cannot create anything; a relative "confyro" then
#    fails with Access denied before the install has really begun.
$confyroDir = if ($env:CONFYRO_HOME) { $env:CONFYRO_HOME }
              else { Join-Path $env:USERPROFILE "confyro" }
New-Item -ItemType Directory -Force -Path $confyroDir | Out-Null
Set-Location $confyroDir
Write-Host "Installing into $confyroDir"

# The official compose file
Write-Host "Downloading docker-compose.yml from $BaseUrl ..."
# curl.exe (native, ships with Windows 10 1803+) handles modern TLS reliably;
# PowerShell 5.1's Invoke-WebRequest often cannot connect to the HTTPS endpoint.
curl.exe -fsSL "$BaseUrl/docker-compose.yml" -o "docker-compose.yml"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path "docker-compose.yml")) {
    Write-Host "Could not download docker-compose.yml from $BaseUrl."
    Write-Host "Check your internet connection (or a proxy/firewall) and try again."
    exit 1
}

# 4. Your login password (kept only in .\confyro\.env on this machine)
$needPassword = $true
if (Test-Path ".env") {
    $envText = Get-Content ".env" -Raw
    if ($envText -match "CONFYRO_ADMIN_PASSWORD=") { $needPassword = $false }
}
if ($needPassword) {
    Write-Host ""
    Write-Host "Choose a password to log in to Confyro."
    Write-Host "Pick something you'll remember - you can just press Enter to have one made for you."
    $password = Read-Host "   Your Confyro password"
    if ([string]::IsNullOrWhiteSpace($password)) {
        $bytes = New-Object byte[] 12
        [System.Security.Cryptography.RNGCryptoServiceProvider]::new().GetBytes($bytes)
        $password = ($bytes | ForEach-Object { $_.ToString("x2") }) -join ""
        Write-Host "   (No password typed - we made one for you: $password)"
    }
    Add-Content -Path ".env" -Value "CONFYRO_ADMIN_PASSWORD=$password" -Encoding ascii
    Write-Host "   Saved. Sign in with the password you chose."
    Write-Host ""
}

# 5. Pull and start
& $docker compose up -d
if ($LASTEXITCODE -ne 0) {
    Write-Host "docker compose failed - see the message above."
    exit 1
}

# 6. A Desktop / Start-menu icon that opens Confyro in an app-style window.
#    Never fatal: a failure here leaves a working install behind.
$launcher = Join-Path $confyroDir "Open-Confyro.ps1"
$icon = Join-Path $confyroDir "confyro.ico"
try {
    curl.exe -fsSL "$BaseUrl/Open-Confyro.ps1" -o "Open-Confyro.ps1"
    curl.exe -fsSL "$BaseUrl/confyro.ico"      -o "confyro.ico"
    if (-not (Test-Path $launcher) -or -not (Test-Path $icon)) {
        throw "the launcher files could not be downloaded"
    }

    $ps = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
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

# 7. Open it. Running the very same launcher the icon runs means the first time
#    looks exactly like every time afterwards, and nobody has to be told to type
#    an address. It waits for the server, so a few quiet seconds here are normal.
Write-Host ""
Write-Host "Starting Confyro and opening it - the first start takes a few seconds..."
if (Test-Path $launcher) {
    & $launcher
    Write-Host ""
    Write-Host "Confyro is open. Log in as  admin  with the password above."
} else {
    Write-Host ""
    Write-Host "Confyro is running. Open  http://localhost:8000  and log in as  admin ."
}
Write-Host "Then click License and paste the activation key from your email."
