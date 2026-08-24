#Requires -Version 5.1
<#
.SYNOPSIS
  Switch Balatro between modded multiplayer and vanilla single-player.

.DESCRIPTION
  Balatro multiplayer (BalatroMultiplayer + SMODS) loads via the Lovely injector
  (version.dll next to Balatro.exe). Steam still launches the same game; this
  script only enables or disables the injector.

  Multiplayer mode : ensure version.dll is active (Lovely loads Mods).
  Single-player    : rename version.dll so the stock game starts with no mods.

.PARAMETER Mode
  multiplayer | mp | modded  - enable Lovely + multiplayer stack
  singleplayer | sp | vanilla - disable Lovely (vanilla Steam Balatro)
  status                     - show current mode (default)

.PARAMETER Launch
  After switching (or on status), start Balatro via Steam (app 2379780).

.PARAMETER GameDir
  Override game install folder. Default is auto-detected from common Steam paths
  and the Balatro Multiplayer Launcher settings.

.EXAMPLE
  .\balatro-mode.ps1 multiplayer
  .\balatro-mode.ps1 singleplayer -Launch
  .\balatro-mode.ps1 status
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet(
        'multiplayer', 'mp', 'modded',
        'singleplayer', 'sp', 'vanilla',
        'status'
    )]
    [string] $Mode = 'status',

    [switch] $Launch,

    [string] $GameDir
)

$ErrorActionPreference = 'Stop'
$SteamAppId = '2379780'
$InjectorName = 'version.dll'
$InjectorOffName = 'version.dll.disabled'
$ModsRelative = 'Balatro\Mods'
$ExpectedMods = @('smods', 'multiplayer*')

function Write-Info([string] $Message) { Write-Host $Message -ForegroundColor Cyan }
function Write-Ok([string] $Message)   { Write-Host $Message -ForegroundColor Green }
function Write-Warn([string] $Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-Err([string] $Message)  { Write-Host $Message -ForegroundColor Red }

function Get-SteamLibraryRoots {
    $roots = [System.Collections.Generic.List[string]]::new()
    $default = 'C:\Program Files (x86)\Steam'
    if (Test-Path $default) { [void]$roots.Add($default) }

    $vdf = Join-Path $default 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        Get-Content -LiteralPath $vdf | ForEach-Object {
            if ($_ -match '"path"\s*"([^"]+)"') {
                $p = $Matches[1] -replace '\\\\', '\'
                if ($p -and (Test-Path $p) -and -not $roots.Contains($p)) {
                    [void]$roots.Add($p)
                }
            }
        }
    }
    return $roots
}

function Find-BalatroGameDir {
    if ($GameDir) {
        if (-not (Test-Path -LiteralPath (Join-Path $GameDir 'Balatro.exe'))) {
            throw "GameDir does not contain Balatro.exe: $GameDir"
        }
        return (Resolve-Path -LiteralPath $GameDir).Path
    }

    $launcherSettings = Join-Path $env:APPDATA 'Balatro Multiplayer Launcher\settings.json'
    if (Test-Path -LiteralPath $launcherSettings) {
        try {
            $json = Get-Content -LiteralPath $launcherSettings -Raw | ConvertFrom-Json
            if ($json.gameDirectory -and (Test-Path -LiteralPath (Join-Path $json.gameDirectory 'Balatro.exe'))) {
                return $json.gameDirectory
            }
        } catch {
            Write-Warn "Could not read Multiplayer Launcher settings: $_"
        }
    }

    $candidates = @()
    foreach ($root in Get-SteamLibraryRoots) {
        foreach ($name in @('Balatro', 'Balatro Modded')) {
            $p = Join-Path $root "steamapps\common\$name"
            if (Test-Path -LiteralPath (Join-Path $p 'Balatro.exe')) {
                $candidates += $p
            }
        }
    }

    if (-not $candidates) {
        throw @"
Could not find Balatro.exe.
Install via Steam, or pass -GameDir 'C:\Path\To\steamapps\common\Balatro'
"@
    }

    # Prefer the folder that currently has Lovely active, then main "Balatro"
    $withInjector = $candidates | Where-Object {
        (Test-Path -LiteralPath (Join-Path $_ $InjectorName)) -or
        (Test-Path -LiteralPath (Join-Path $_ $InjectorOffName))
    }
    if ($withInjector) {
        $main = $withInjector | Where-Object { $_ -match '\\Balatro$' } | Select-Object -First 1
        if ($main) { return $main }
        return $withInjector[0]
    }

    $main = $candidates | Where-Object { $_ -match '\\Balatro$' } | Select-Object -First 1
    if ($main) { return $main }
    return $candidates[0]
}

function Get-ModsDir {
    Join-Path $env:APPDATA $ModsRelative
}

function Test-ModPresent {
    param([string] $ModsDir, [string] $Pattern)
    if (-not (Test-Path -LiteralPath $ModsDir)) { return $false }
    return [bool](Get-ChildItem -LiteralPath $ModsDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like $Pattern })
}

function Get-ModeState {
    param([string] $Dir)

    $on  = Test-Path -LiteralPath (Join-Path $Dir $InjectorName)
    $off = Test-Path -LiteralPath (Join-Path $Dir $InjectorOffName)
    $modsDir = Get-ModsDir

    $smods = Test-ModPresent -ModsDir $modsDir -Pattern 'smods'
    $mp    = Test-ModPresent -ModsDir $modsDir -Pattern 'multiplayer*'

    $mode = if ($on) { 'multiplayer' } elseif ($off) { 'singleplayer' } else { 'unknown' }

    [pscustomobject]@{
        GameDir           = $Dir
        Mode              = $mode
        LovelyActive      = $on
        LovelyDisabled    = $off
        ModsDir           = $modsDir
        SmodsPresent      = $smods
        MultiplayerPresent= $mp
        StackReady        = ($smods -and $mp)
    }
}

function Assert-WritableGameDir {
    param([string] $Dir)
    $probe = Join-Path $Dir ".balatro-mode-write-test-$PID"
    try {
        [IO.File]::WriteAllText($probe, 'ok')
        Remove-Item -LiteralPath $probe -Force
    } catch {
        throw @"
Cannot write to game folder (need permission to rename version.dll):
  $Dir

Fix: run PowerShell as your user if Steam is under your profile library,
or right-click -> Run as administrator, or take ownership of the folder.
"@
    }
}

function Enable-Multiplayer {
    param([string] $Dir)

    Assert-WritableGameDir -Dir $Dir

    $onPath  = Join-Path $Dir $InjectorName
    $offPath = Join-Path $Dir $InjectorOffName

    if (Test-Path -LiteralPath $onPath) {
        Write-Ok "Lovely already active: $onPath"
    } elseif (Test-Path -LiteralPath $offPath) {
        Rename-Item -LiteralPath $offPath -NewName $InjectorName
        Write-Ok "Enabled Lovely (renamed $InjectorOffName -> $InjectorName)"
    } else {
        throw @"
Neither $InjectorName nor $InjectorOffName found in:
  $Dir

Reinstall Lovely / open Balatro Multiplayer Launcher and install the multiplayer stack, then re-run.
"@
    }

    $state = Get-ModeState -Dir $Dir
    if (-not $state.SmodsPresent) {
        Write-Warn "SMODS not found under $($state.ModsDir) (expected folder named smods)."
    }
    if (-not $state.MultiplayerPresent) {
        Write-Warn "Multiplayer mod not found under $($state.ModsDir) (expected multiplayer*)."
    }
    if ($state.StackReady) {
        Write-Ok "Mods stack OK: SMODS + Multiplayer present."
    } else {
        Write-Warn "Mods incomplete - multiplayer may not load until SMODS and Multiplayer are in Mods."
    }
}

function Enable-Singleplayer {
    param([string] $Dir)

    Assert-WritableGameDir -Dir $Dir

    $onPath  = Join-Path $Dir $InjectorName
    $offPath = Join-Path $Dir $InjectorOffName

    if (Test-Path -LiteralPath $offPath -PathType Leaf) {
        if (Test-Path -LiteralPath $onPath) {
            # Prefer keeping the disabled copy if both exist (shouldn't happen)
            Remove-Item -LiteralPath $onPath -Force
            Write-Warn "Removed active $InjectorName; left existing $InjectorOffName in place."
        } else {
            Write-Ok "Already in single-player (injector disabled)."
        }
        return
    }

    if (Test-Path -LiteralPath $onPath) {
        Rename-Item -LiteralPath $onPath -NewName $InjectorOffName
        Write-Ok "Disabled Lovely (renamed $InjectorName -> $InjectorOffName)"
        Write-Info "Mods left in place under $(Get-ModsDir) - they only load when Lovely is active."
        return
    }

    Write-Warn "No $InjectorName found - game is already vanilla (or Lovely was never installed)."
}

function Show-Status {
    param($State)

    Write-Host ''
    Write-Host 'Balatro mode status' -ForegroundColor White
    Write-Host ('=' * 40)
    Write-Host ("Game dir     : {0}" -f $State.GameDir)
    Write-Host ("Mods dir     : {0}" -f $State.ModsDir)
    Write-Host ("Current mode : {0}" -f $State.Mode) -ForegroundColor $(
        switch ($State.Mode) {
            'multiplayer'   { 'Magenta' }
            'singleplayer'  { 'Green' }
            default         { 'Yellow' }
        }
    )
    Write-Host ("Lovely DLL   : active={0}  disabled-file={1}" -f $State.LovelyActive, $State.LovelyDisabled)
    Write-Host ("SMODS        : {0}" -f $(if ($State.SmodsPresent) { 'found' } else { 'MISSING' }))
    Write-Host ("Multiplayer  : {0}" -f $(if ($State.MultiplayerPresent) { 'found' } else { 'MISSING' }))
    Write-Host ''
    if ($State.Mode -eq 'multiplayer' -and -not $State.StackReady) {
        Write-Warn 'Multiplayer mode is on but required mods are missing from Mods.'
    }
    if ($State.Mode -eq 'unknown') {
        Write-Warn 'Could not find version.dll or version.dll.disabled - install Lovely via Multiplayer Launcher for MP.'
    }
}

function Start-BalatroSteam {
    Write-Info "Launching Balatro via Steam (app $SteamAppId)..."
    Start-Process "steam://rungameid/$SteamAppId"
}

# --- main ---
try {
    $dir = Find-BalatroGameDir
    $normalized = $Mode.ToLowerInvariant()
    switch ($normalized) {
        { $_ -in @('multiplayer', 'mp', 'modded') } {
            Write-Info "Switching to MULTIPLAYER (modded)..."
            Enable-Multiplayer -Dir $dir
        }
        { $_ -in @('singleplayer', 'sp', 'vanilla') } {
            Write-Info "Switching to SINGLE-PLAYER (vanilla)..."
            Enable-Singleplayer -Dir $dir
        }
        'status' { }
    }

    $state = Get-ModeState -Dir $dir
    Show-Status -State $state

    if ($Launch) {
        Start-BalatroSteam
    } else {
        Write-Host 'Tips:' -ForegroundColor DarkGray
        Write-Host "  .\balatro-mode.ps1 multiplayer -Launch" -ForegroundColor DarkGray
        Write-Host "  .\balatro-mode.ps1 singleplayer -Launch" -ForegroundColor DarkGray
        Write-Host "  .\balatro-mode.ps1 status" -ForegroundColor DarkGray
    }
} catch {
    Write-Err $_.Exception.Message
    exit 1
}
