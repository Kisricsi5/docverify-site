# Open-Confyro.ps1 - click-to-open launcher for Confyro.
#
# The desktop / Start-menu "Confyro" icon runs this. It makes sure Docker and
# the Confyro container are running, then opens Confyro in a clean app-style
# window. Safe to run any time - it never does anything harmful if Confyro is
# already up. Lives next to your docker-compose.yml (in the confyro folder).
$ErrorActionPreference = "SilentlyContinue"
Set-Location -LiteralPath $PSScriptRoot
$Url = "http://localhost:8000"

# Windows 11 hosts PowerShell inside Windows Terminal, which draws its own
# window and ignores -WindowStyle Hidden. We cannot stop that window appearing,
# so the next best thing is to be finished before anyone reads it: the common
# path below opens the browser in well under a second.

function Test-Port {
    # 18ms, against 2s for Invoke-WebRequest, which spends its time on proxy
    # auto-detection before it ever reaches localhost.
    try {
        $client = New-Object Net.Sockets.TcpClient
        $async = $client.BeginConnect("127.0.0.1", 8000, $null, $null)
        $up = $async.AsyncWaitHandle.WaitOne(400) -and $client.Connected
        $client.Close()
        return $up
    } catch {
        return $false
    }
}

function Open-Confyro {
    # A chrome-less window that looks like a native app. Falls back to the
    # default browser if neither Edge nor Chrome is installed.
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
}

# 1. The usual case: Confyro is already running, because the container restarts
#    with Docker and Docker starts with Windows. Nothing to check, nothing to
#    start - just open the window and get out of the way.
if (Test-Port) { Open-Confyro; exit }

# 2. Not running. This is the rare path - usually a click made during the first
#    minute after a restart, before Docker has finished waking up. The window is
#    on screen either way, so from here on it says what it is waiting for: a
#    black rectangle that sits there for a minute reads as a hung program.
Write-Host ""
Write-Host "  Confyro is not running yet."

# PATH is the normal way to find docker.exe but not a reliable one: Docker
# Desktop installs per-user into AppData and only adds itself to the user PATH,
# so a shell opened before that cannot see it.
function Get-DockerExe {
    $cmd = Get-Command docker -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return @("$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe",
             "$env:LOCALAPPDATA\Programs\DockerDesktop\resources\bin\docker.exe",
             "$env:LOCALAPPDATA\Programs\Docker\Docker\resources\bin\docker.exe") |
           Where-Object { Test-Path $_ } | Select-Object -First 1
}
$docker = Get-DockerExe
if (-not $docker) {
    Write-Host "  Could not find Docker. Opening $Url anyway."
    Start-Process $Url
    exit
}

& $docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Starting Docker Desktop. Right after a restart this takes a minute."
    $dd = @("$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
            "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe",
            "$env:LOCALAPPDATA\Programs\Docker\Docker\Docker Desktop.exe",
            "$env:LOCALAPPDATA\Docker\Docker Desktop.exe") |
          Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($dd) { Start-Process $dd }
}

# 3. Wait on the port, not on Docker. The container is set to restart with the
#    engine, so in the usual case it comes back by itself and we open the moment
#    it answers - without spending another two Docker round trips first. Only if
#    the engine is up and the port still is not do we conclude the container was
#    genuinely stopped, and start it.
$composeTried = $false
for ($i = 0; $i -lt 180; $i++) {
    if (Test-Port) { break }
    if (-not $composeTried -and $i -ge 3 -and ($i % 5) -eq 0) {
        & $docker info *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Docker is ready. Starting Confyro..."
            & $docker compose up -d *> $null
            $composeTried = $true
        }
    }
    Start-Sleep -Milliseconds 500
}

if (Test-Port) { Write-Host "  Ready. Opening Confyro." }
else { Write-Host "  Confyro did not answer. Opening $Url so you can see the error." }
Open-Confyro
