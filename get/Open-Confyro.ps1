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

# 2. Not running. Find docker.exe: PATH is the normal answer but not a reliable
#    one, because Docker Desktop installs per-user into AppData and only adds
#    itself to the user PATH, so a shell opened before that cannot see it.
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

# 3. Is the engine up? If not, start Docker Desktop and wait for it.
& $docker info *> $null
if ($LASTEXITCODE -ne 0) {
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

# 4. Bring the Confyro container up (idempotent - no-op if already running).
& $docker compose up -d *> $null

# 5. Wait for the web server, then open it.
for ($i = 0; $i -lt 100; $i++) { if (Test-Port) { break }; Start-Sleep -Milliseconds 300 }
Open-Confyro
