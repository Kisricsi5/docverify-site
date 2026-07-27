# Open-Confyro.ps1 - click-to-open launcher for Confyro.
#
# The desktop / Start-menu "Confyro" icon runs this. It makes sure Docker and
# the Confyro container are running, then opens Confyro in a clean app-style
# window. Safe to run any time - it never does anything harmful if Confyro is
# already up. Lives next to your docker-compose.yml (in the confyro folder).
$ErrorActionPreference = "SilentlyContinue"
Set-Location -LiteralPath $PSScriptRoot
$Url = "http://localhost:8000"

function Test-Up {
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 2 | Out-Null
        return $true
    } catch {
        # A 401 (login is on) still means the server itself is up and reachable.
        $code = $_.Exception.Response.StatusCode.value__
        return ($code -ge 200 -and $code -lt 500)
    }
}

# 0. Find docker.exe. PATH is the normal answer, but it is not reliable: Docker
#    Desktop installs per-user into AppData and only adds itself to the user
#    PATH, so any shell opened before that still cannot see it. Falling back to
#    the known install locations is the difference between the icon working and
#    the icon appearing to do nothing.
function Get-DockerExe {
    $cmd = Get-Command docker -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return @("$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe",
             "$env:LOCALAPPDATA\Programs\DockerDesktop\resources\bin\docker.exe",
             "$env:LOCALAPPDATA\Programs\Docker\Docker\resources\bin\docker.exe") |
           Where-Object { Test-Path $_ } | Select-Object -First 1
}
$docker = Get-DockerExe
if (-not $docker) { Start-Process $Url; exit }

# 1. Is Docker running? If not, start Docker Desktop and wait for it.
& $docker info *> $null
if ($LASTEXITCODE -ne 0) {
    # Docker Desktop now installs per-user by default, which lands outside
    # Program Files entirely. Miss that path and the icon looks broken on a
    # machine where Docker is merely not started yet.
    $dd = @("$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
            "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe",
            "$env:LOCALAPPDATA\Programs\Docker\Docker\Docker Desktop.exe",
            "$env:LOCALAPPDATA\Docker\Docker Desktop.exe") |
          Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($dd) { Start-Process $dd }
    for ($i = 0; $i -lt 150; $i++) {
        & $docker info *> $null
        if ($LASTEXITCODE -eq 0) { break }
        Start-Sleep -Seconds 1
    }
}

# 2. Bring the Confyro container up (idempotent - no-op if already running).
& $docker compose up -d *> $null

# 3. Wait for the web server to answer.
for ($i = 0; $i -lt 60; $i++) { if (Test-Up) { break }; Start-Sleep -Milliseconds 500 }

# 4. Open it in an app-style window (a chrome-less window that looks like a
#    native app). Falls back to the default browser if neither Edge nor Chrome
#    is installed.
$browser = @(
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($browser) {
    Start-Process $browser -ArgumentList "--app=$Url", "--window-size=1240,860"
} else {
    Start-Process $Url
}
