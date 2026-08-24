#Requires -Version 5.1
<#
.SYNOPSIS
  Apply a Balatro launch mode from config (lovely, profile, optional mod set) and optionally launch.

.PARAMETER ModeId
  Apply this mode id from config (e.g. vanilla, multiplayer) without a menu.

.PARAMETER Menu
  Show an interactive menu built from config modes, then apply + launch.

.PARAMETER Launch
  After applying, start Balatro (Steam protocol or direct exe).

.PARAMETER List
  Print configured modes and exit.

.PARAMETER ConfigPath
  Explicit path to modes.json.

.PARAMETER SteamExeArgs
  Optional Balatro.exe path passed from Steam %command% (first arg).

.EXAMPLE
  .\Invoke-BalatroMode.ps1 -Menu -Launch
  .\Invoke-BalatroMode.ps1 -ModeId vanilla -Launch
  .\Invoke-BalatroMode.ps1 -List
#>
[CmdletBinding(DefaultParameterSetName = 'Menu')]
param(
    [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
    [string] $ModeId,

    [Parameter(ParameterSetName = 'Menu')]
    [switch] $Menu,

    [Parameter(ParameterSetName = 'List')]
    [switch] $List,

    [switch] $Launch,

    [string] $ConfigPath,

    [string] $SteamExeArgs,

    [string] $LogPath
)

$ErrorActionPreference = 'Stop'

$script:InstallDir = Join-Path $env:LOCALAPPDATA 'BalatroMode'
$script:RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not $LogPath) {
    $LogPath = Join-Path $script:InstallDir 'steam-gate.log'
}

function Write-Log([string] $Message) {
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    $dir = Split-Path -Parent $LogPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Add-Content -LiteralPath $LogPath -Value $line -ErrorAction SilentlyContinue
    Write-Host $Message
}

function Resolve-ConfigPath {
    if ($ConfigPath) {
        if (-not (Test-Path -LiteralPath $ConfigPath)) {
            throw "Config not found: $ConfigPath"
        }
        return (Resolve-Path -LiteralPath $ConfigPath).Path
    }

    $candidates = @(
        (Join-Path $script:InstallDir 'modes.json'),
        (Join-Path $script:RepoRoot 'config\modes.json'),
        (Join-Path $PSScriptRoot '..\config\modes.json')
    )

    foreach ($c in $candidates) {
        $full = [IO.Path]::GetFullPath($c)
        if (Test-Path -LiteralPath $full) { return $full }
    }

    $example = [IO.Path]::GetFullPath((Join-Path $script:RepoRoot 'config\modes.example.json'))
    throw @"
No modes.json found. Looked in:
  $($candidates -join "`n  ")

Copy config\modes.example.json to config\modes.json (or to %LocalAppData%\BalatroMode\modes.json) and edit it.
Example: $example
"@
}

function Get-ModesConfig {
    $path = Resolve-ConfigPath
    Write-Log "Config: $path"
    $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    $cfg = $raw | ConvertFrom-Json
    if (-not $cfg.modes -or $cfg.modes.Count -lt 1) {
        throw "Config has no modes array: $path"
    }
    return [pscustomobject]@{ Path = $path; Data = $cfg }
}

function Get-DefaultGameDir {
    $launcher = Join-Path $env:APPDATA 'Balatro Multiplayer Launcher\settings.json'
    if (Test-Path -LiteralPath $launcher) {
        try {
            $j = Get-Content -LiteralPath $launcher -Raw | ConvertFrom-Json
            if ($j.gameDirectory -and (Test-Path -LiteralPath (Join-Path $j.gameDirectory 'Balatro.exe'))) {
                return $j.gameDirectory
            }
        } catch { }
    }
    foreach ($p in @(
        'C:\Program Files (x86)\Steam\steamapps\common\Balatro',
        'C:\Program Files\Steam\steamapps\common\Balatro'
    )) {
        if (Test-Path -LiteralPath (Join-Path $p 'Balatro.exe')) { return $p }
    }
    return $null
}

function Resolve-GameDir {
    param($Config, [string] $ModeGameDir, [string] $SteamExe)

    if ($ModeGameDir -and (Test-Path -LiteralPath (Join-Path $ModeGameDir 'Balatro.exe'))) {
        return $ModeGameDir
    }
    if ($SteamExe -and (Test-Path -LiteralPath $SteamExe)) {
        return [IO.Path]::GetDirectoryName($SteamExe)
    }
    if ($Config.gameDir -and (Test-Path -LiteralPath (Join-Path $Config.gameDir 'Balatro.exe'))) {
        return $Config.gameDir
    }
    $d = Get-DefaultGameDir
    if (-not $d) { throw 'Could not find Balatro.exe. Set gameDir in modes.json.' }
    return $d
}

function Resolve-ModsDir {
    param($Config, [string] $ModeModsDir)
    if ($ModeModsDir) { return $ModeModsDir }
    if ($Config.modsDir) { return $Config.modsDir }
    return (Join-Path $env:APPDATA 'Balatro\Mods')
}

function Test-BalatroRunning {
    return [bool](Get-Process -Name 'Balatro' -ErrorAction SilentlyContinue)
}

function Set-LovelyState {
    param([string] $GameDir, [bool] $Enabled)

    $on = Join-Path $GameDir 'version.dll'
    $off = Join-Path $GameDir 'version.dll.disabled'

    if ($Enabled) {
        if (Test-Path -LiteralPath $on) {
            Write-Log 'Lovely already active.'
            return
        }
        if (Test-Path -LiteralPath $off) {
            Rename-Item -LiteralPath $off -NewName 'version.dll'
            Write-Log 'Lovely enabled (version.dll.disabled -> version.dll).'
            return
        }
        throw "Lovely not found in $GameDir (need version.dll or version.dll.disabled)."
    }

    if (Test-Path -LiteralPath $off) {
        if (Test-Path -LiteralPath $on) {
            Remove-Item -LiteralPath $on -Force
            Write-Log 'Removed active version.dll; left version.dll.disabled.'
        } else {
            Write-Log 'Lovely already disabled.'
        }
        return
    }
    if (Test-Path -LiteralPath $on) {
        Rename-Item -LiteralPath $on -NewName 'version.dll.disabled'
        Write-Log 'Lovely disabled (version.dll -> version.dll.disabled).'
        return
    }
    Write-Log 'No version.dll present - already vanilla.'
}

function Set-BalatroProfileSlot {
    param([int] $Profile)

    if ($Profile -lt 1 -or $Profile -gt 3) {
        Write-Log "Skip profile: invalid slot $Profile (use 1-3)."
        return
    }

    $helpers = @(
        (Join-Path $script:InstallDir 'Set-BalatroProfile.ps1'),
        (Join-Path $PSScriptRoot 'Set-BalatroProfile.ps1')
    )
    $helper = $helpers | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $helper) {
        Write-Log 'WARN: Set-BalatroProfile.ps1 missing - skip profile change.'
        return
    }

    Write-Log "Setting profile via $helper"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $helper -Profile $Profile -LogPath $LogPath
    if ($LASTEXITCODE -ne 0) {
        throw "Profile helper failed with exit code $LASTEXITCODE"
    }
}

function Test-NameMatchesPattern {
    param([string] $Name, [string] $Pattern)
    # glob: * ?
    $regex = '^' + [regex]::Escape($Pattern).Replace('\*', '.*').Replace('\?', '.') + '$'
    return [bool]($Name -match $regex)
}

function Get-BaseModName {
    param([string] $FolderName)
    if ($FolderName -match '^(?i)(.+)\.disabled$') { return $Matches[1] }
    return $FolderName
}

function Set-EnabledMods {
    param(
        [string] $ModsDir,
        [string[]] $EnabledPatterns
    )

    if (-not $EnabledPatterns -or $EnabledPatterns.Count -eq 0) {
        Write-Log 'No enabledMods in mode - leaving Mods folder unchanged.'
        return
    }

    if (-not (Test-Path -LiteralPath $ModsDir)) {
        Write-Log "WARN: Mods dir missing: $ModsDir"
        return
    }

    # Never rename Lovely's dump/log folder
    $preserve = @('lovely')

    $dirs = Get-ChildItem -LiteralPath $ModsDir -Directory -ErrorAction SilentlyContinue
    foreach ($d in $dirs) {
        $base = Get-BaseModName -FolderName $d.Name
        if ($preserve -contains $base.ToLowerInvariant()) {
            # ensure lovely dump is not left as lovely.disabled
            if ($d.Name -match '(?i)\.disabled$') {
                $target = Join-Path $ModsDir $base
                if (-not (Test-Path -LiteralPath $target)) {
                    Rename-Item -LiteralPath $d.FullName -NewName $base
                }
            }
            continue
        }

        $shouldEnable = $false
        foreach ($pat in $EnabledPatterns) {
            if (Test-NameMatchesPattern -Name $base -Pattern $pat) {
                $shouldEnable = $true
                break
            }
        }

        if ($shouldEnable) {
            if ($d.Name -match '(?i)\.disabled$') {
                $target = Join-Path $ModsDir $base
                if (Test-Path -LiteralPath $target) {
                    Write-Log "WARN: cannot enable '$($d.Name)' - '$base' already exists."
                } else {
                    Rename-Item -LiteralPath $d.FullName -NewName $base
                    Write-Log "Mod enabled: $base"
                }
            } else {
                Write-Log "Mod already active: $base"
            }
        } else {
            if ($d.Name -match '(?i)\.disabled$') {
                Write-Log "Mod already disabled: $base"
            } else {
                $disabledName = "$base.disabled"
                $target = Join-Path $ModsDir $disabledName
                if (Test-Path -LiteralPath $target) {
                    Write-Log "WARN: cannot disable '$base' - '$disabledName' already exists."
                } else {
                    Rename-Item -LiteralPath $d.FullName -NewName $disabledName
                    Write-Log "Mod disabled: $base -> $disabledName"
                }
            }
        }
    }
}

function Get-LovelyStatus([string] $GameDir) {
    $on = Test-Path -LiteralPath (Join-Path $GameDir 'version.dll')
    $off = Test-Path -LiteralPath (Join-Path $GameDir 'version.dll.disabled')
    if ($on) { return 'active' }
    if ($off) { return 'disabled' }
    return 'missing'
}

function Show-ModeMenu {
    param($Modes)

    Write-Host ''
    Write-Host '  ========================================' -ForegroundColor Cyan
    Write-Host '   BALATRO MODE SELECTOR' -ForegroundColor Cyan
    Write-Host '  ========================================' -ForegroundColor Cyan
    Write-Host ''

    $i = 1
    foreach ($m in $Modes) {
        $desc = if ($m.description) { " - $($m.description)" } else { '' }
        Write-Host ("  [{0}]  {1}{2}" -f $i, $m.label, $desc)
        $i++
    }
    Write-Host '  [0]  Cancel'
    Write-Host ''

    while ($true) {
        $raw = Read-Host '  Choose'
        if ($raw -eq '0' -or $raw -eq '') { return $null }
        $n = 0
        if ([int]::TryParse($raw, [ref]$n) -and $n -ge 1 -and $n -le $Modes.Count) {
            return $Modes[$n - 1]
        }
        Write-Host '  Invalid choice.' -ForegroundColor Yellow
    }
}

function Invoke-Mode {
    param($Config, $Mode, [string] $SteamExe)

    Write-Log ("Applying mode id={0} label={1}" -f $Mode.id, $Mode.label)

    if (Test-BalatroRunning) {
        throw 'Balatro is running - close it before switching modes.'
    }

    $gameDir = Resolve-GameDir -Config $Config -ModeGameDir $Mode.gameDir -SteamExe $SteamExe
    $modsDir = Resolve-ModsDir -Config $Config -ModeModsDir $Mode.modsDir
    $exe = Join-Path $gameDir 'Balatro.exe'
    if (-not (Test-Path -LiteralPath $exe)) { throw "Balatro.exe not found: $exe" }

    Write-Log "GameDir: $gameDir"
    Write-Log "ModsDir: $modsDir"
    Write-Log ("Lovely before: {0}" -f (Get-LovelyStatus $gameDir))

    $lovely = $true
    if ($null -ne $Mode.lovely) { $lovely = [bool]$Mode.lovely }
    Set-LovelyState -GameDir $gameDir -Enabled $lovely

    if ($null -ne $Mode.profile) {
        Set-BalatroProfileSlot -Profile ([int]$Mode.profile)
    } else {
        Write-Log 'No profile in mode - leaving settings.jkr unchanged.'
    }

    $enabled = @()
    if ($Mode.enabledMods) {
        $enabled = @($Mode.enabledMods | ForEach-Object { [string]$_ })
    }
    Set-EnabledMods -ModsDir $modsDir -EnabledPatterns $enabled

    Write-Log ("Lovely after: {0}" -f (Get-LovelyStatus $gameDir))
    Write-Log "Mode ready: $($Mode.id)"

    return [pscustomobject]@{
        GameDir = $gameDir
        Exe     = $exe
        Mode    = $Mode
    }
}

function Start-BalatroGame {
    param([string] $Exe, [string] $GameDir, [switch] $Direct)

    if ($Direct -or $Exe) {
        Write-Log "Launching: $Exe"
        Push-Location $GameDir
        try {
            $p = Start-Process -FilePath $Exe -WorkingDirectory $GameDir -Wait -PassThru
            return $p.ExitCode
        } finally {
            Pop-Location
        }
    }
}

# --- main ---
try {
    if (-not (Test-Path -LiteralPath $script:InstallDir)) {
        New-Item -ItemType Directory -Path $script:InstallDir -Force | Out-Null
    }

    $bundle = Get-ModesConfig
    $cfg = $bundle.Data
    $modes = @($cfg.modes)

    if ($List) {
        Write-Host "Config: $($bundle.Path)"
        $n = 1
        foreach ($m in $modes) {
            $lov = if ($null -eq $m.lovely) { '?' } elseif ($m.lovely) { 'on' } else { 'off' }
            $prof = if ($null -eq $m.profile) { '-' } else { $m.profile }
            $mods = if ($m.enabledMods) { ($m.enabledMods -join ', ') } else { '(unchanged)' }
            Write-Host ("[{0}] id={1}  label={2}  lovely={3}  profile={4}  mods={5}" -f $n, $m.id, $m.label, $lov, $prof, $mods)
            $n++
        }
        exit 0
    }

    $steamExe = $null
    if ($SteamExeArgs) {
        $steamExe = $SteamExeArgs.Trim('"')
    } elseif ($args.Count -ge 1 -and $args[0] -like '*.exe') {
        $steamExe = $args[0]
    }

    $selected = $null
    if ($PSCmdlet.ParameterSetName -eq 'ById' -or $ModeId) {
        $selected = $modes | Where-Object { $_.id -eq $ModeId } | Select-Object -First 1
        if (-not $selected) {
            throw "Unknown mode id '$ModeId'. Use -List to see ids."
        }
    } else {
        # Default: menu
        $selected = Show-ModeMenu -Modes $modes
        if (-not $selected) {
            Write-Log 'Cancelled.'
            exit 0
        }
        $Launch = $true
    }

    $result = Invoke-Mode -Config $cfg -Mode $selected -SteamExe $steamExe

    if ($Launch) {
        # Prefer direct exe when Steam passed it (playtime / same process tree for gate)
        if ($steamExe -and (Test-Path -LiteralPath $steamExe)) {
            exit (Start-BalatroGame -Exe $steamExe -GameDir $result.GameDir -Direct)
        }
        if ($result.Exe) {
            # From double-click helpers: use Steam so overlay/cloud work
            Write-Log 'Launching via Steam (app 2379780)...'
            Start-Process "steam://rungameid/2379780"
            exit 0
        }
    }

    exit 0
} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}
