#Requires -Version 5.1
<#
.SYNOPSIS
  Set Balatro's active profile slot (1, 2, or 3) in settings.jkr before launch.

.DESCRIPTION
  Balatro remembers the last-used profile in %AppData%\Balatro\settings.jkr
  (deflate-compressed Lua table) as ["profile"]=N.

  Close the game before changing this. Safe to call while the game is closed.

.PARAMETER Profile
  Profile slot number: 1 (single-player), 2 (multiplayer), or 3.

.PARAMETER SettingsPath
  Optional override for settings.jkr path.

.EXAMPLE
  .\Set-BalatroProfile.ps1 -Profile 1
  .\Set-BalatroProfile.ps1 -Profile 2
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateRange(1, 3)]
    [int] $Profile,

    [string] $SettingsPath = $(Join-Path $env:APPDATA 'Balatro\settings.jkr'),

    [string] $LogPath
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression

function Write-Log([string] $Message) {
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    if ($LogPath) {
        $dir = Split-Path -Parent $LogPath
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        Add-Content -LiteralPath $LogPath -Value $line
    }
    Write-Host $line
}

function Decompress-Jkr([byte[]] $Data) {
    $ms = New-Object System.IO.MemoryStream (, $Data)
    try {
        $ds = New-Object System.IO.Compression.DeflateStream(
            $ms, [System.IO.Compression.CompressionMode]::Decompress)
        try {
            $out = New-Object System.IO.MemoryStream
            $ds.CopyTo($out)
            return [System.Text.Encoding]::UTF8.GetString($out.ToArray())
        } finally { $ds.Dispose() }
    } finally { $ms.Dispose() }
}

function Compress-Jkr([string] $Text) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $ms = New-Object System.IO.MemoryStream
    try {
        $ds = New-Object System.IO.Compression.DeflateStream(
            $ms, [System.IO.Compression.CompressionLevel]::Optimal, $true)
        try {
            $ds.Write($bytes, 0, $bytes.Length)
        } finally { $ds.Dispose() }
        return $ms.ToArray()
    } finally { $ms.Dispose() }
}

if (-not (Test-Path -LiteralPath $SettingsPath)) {
    Write-Log "ERROR: settings.jkr not found: $SettingsPath"
    Write-Log "Launch Balatro once normally so it creates settings, then retry."
    exit 1
}

# Refuse if Balatro is running (file may be rewritten on exit)
$running = Get-Process -Name 'Balatro' -ErrorAction SilentlyContinue
if ($running) {
    Write-Log "ERROR: Balatro is running (PID $($running.Id -join ',')). Close it first."
    exit 2
}

$raw = [System.IO.File]::ReadAllBytes($SettingsPath)
try {
    $text = Decompress-Jkr $raw
} catch {
    Write-Log "ERROR: Could not decompress settings.jkr: $_"
    exit 3
}

$old = $null
if ($text -match '\["profile"\]=(\d+)') {
    $old = [int]$Matches[1]
}

if ($old -eq $Profile) {
    Write-Log "Profile already set to $Profile (no write needed)."
    exit 0
}

if ($null -ne $old) {
    $newText = [regex]::Replace($text, '\["profile"\]=\d+', ('["profile"]={0}' -f $Profile), 1)
} else {
    # Insert near end of table if missing
    if ($text -match '\}\s*$') {
        $newText = [regex]::Replace($text, '\}\s*$', (',["profile"]={0}}' -f $Profile), 1)
    } else {
        Write-Log "ERROR: Unexpected settings.jkr format; cannot insert profile."
        exit 4
    }
}

# Sanity: must decompress-equivalent contain new profile
if ($newText -notmatch ('\["profile"\]={0}' -f $Profile)) {
    Write-Log "ERROR: Profile patch failed validation."
    exit 5
}

$bak = $SettingsPath + '.bak-profile'
try {
    [System.IO.File]::Copy($SettingsPath, $bak, $true)
} catch {
    Write-Log "WARN: Could not write backup: $_"
}

$compressed = Compress-Jkr $newText

# Verify round-trip before overwriting
try {
    $check = Decompress-Jkr $compressed
    if ($check -notmatch ('\["profile"\]={0}' -f $Profile)) {
        throw "round-trip profile mismatch"
    }
} catch {
    Write-Log "ERROR: Compressed settings failed verification: $_"
    exit 6
}

[System.IO.File]::WriteAllBytes($SettingsPath, $compressed)
Write-Log ("Profile slot set: {0} -> {1} ({2})" -f $(if ($null -eq $old) { '?' } else { $old }), $Profile, $SettingsPath)
exit 0
