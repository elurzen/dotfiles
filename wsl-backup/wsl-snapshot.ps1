#Requires -Version 5.1
<#
  wsl-snapshot.ps1 - snapshot the archlinux WSL2 distro before a risky pacman -Syu.

  Shuts WSL down, exports the distro's disk as a compacted .vhdx, and keeps the
  newest N snapshots. MUST be run from Windows PowerShell, not from inside WSL
  (it calls `wsl --shutdown`, which would kill the shell you launched it from).

  Run:
    powershell -ExecutionPolicy Bypass -File C:\Users\evan\wsl-backup\wsl-snapshot.ps1

  Restore: see the footer of this file.
#>
[CmdletBinding()]
param(
    [string]$Distro = 'archlinux',
    [string]$Dest   = "$env:USERPROFILE\wsl-backup\backups",
    [int]   $Keep   = 3
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::Unicode  # wsl.exe emits UTF-16

New-Item -ItemType Directory -Force -Path $Dest | Out-Null

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$out   = Join-Path $Dest "$Distro-$stamp.vhdx"

Write-Host "==> Shutting down WSL..."
wsl --shutdown

Write-Host "==> Exporting '$Distro' -> $out"
wsl --export --vhd $Distro $out
if ($LASTEXITCODE -ne 0) {
    throw "wsl --export failed (exit $LASTEXITCODE). Check the name with: wsl --list --verbose"
}
if (-not (Test-Path $out) -or (Get-Item $out).Length -lt 1MB) {
    throw "Export produced no usable file at $out"
}

$gb = (Get-Item $out).Length / 1GB
Write-Host ("==> Snapshot done: {0} ({1:N2} GB)" -f $out, $gb)

# Prune: keep the newest $Keep. Filenames sort chronologically.
Get-ChildItem $Dest -Filter "$Distro-*.vhdx" |
    Sort-Object Name -Descending |
    Select-Object -Skip $Keep |
    ForEach-Object {
        Write-Host "==> Pruning old snapshot: $($_.Name)"
        Remove-Item $_.FullName -Force
    }

Write-Host ""
Write-Host "Current snapshots in ${Dest}:"
Get-ChildItem $Dest -Filter "$Distro-*.vhdx" |
    Sort-Object Name -Descending |
    Format-Table Name, @{ N = 'GB'; E = { '{0:N2}' -f ($_.Length / 1GB) } }, LastWriteTime -AutoSize

<#
  RESTORE (swap the live disk back to a snapshot):

    wsl --shutdown
    # optional: keep the current state in case you want it back
    Copy-Item 'C:\Users\evan\AppData\Local\wsl\{1e81723e-3a02-4e9f-93df-8e7447404747}\ext4.vhdx' "$env:USERPROFILE\wsl-backup\backups\ext4-before-restore.vhdx"
    # restore the chosen snapshot over the live disk
    Copy-Item 'C:\Users\evan\wsl-backup\backups\archlinux-YYYYMMDD-HHMMSS.vhdx' 'C:\Users\evan\AppData\Local\wsl\{1e81723e-3a02-4e9f-93df-8e7447404747}\ext4.vhdx' -Force
    wsl -d archlinux   # boots the restored state

  The exported .vhdx and the live ext4.vhdx are the same kind of artifact (the
  distro's root disk), so copying one over the other is a clean swap and keeps
  the distro registration + default user intact. WSL must be fully shut down
  first or the copy hits a sharing violation. The GUID path above is current as
  of 2026-06-16; re-check it under HKCU\...\Lxss\<guid>\BasePath if it changes.
#>
