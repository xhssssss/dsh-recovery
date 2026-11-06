# reapply-patch.ps1 — re-apply the "muted + background" patch set to dsh-ego-browser
#
# The patch lives in this folder as two full snapshots:
#
#   original-0.8.6/  pristine dsh-ego-browser@0.8.6 files (from the npm tarball)
#   patched/         the same files WITH the muted + background-mode patch
#
# Why snapshots and not a .patch: the plugin sits outside the workspace on
# absolute Windows paths, which makes unified diffs awkward to re-apply. Copying
# whole files is idempotent, verifiable by hash, and trivially reversible.
#
# Usage (from anywhere; the DSH shell has Windows PowerShell 5.1, not pwsh):
#   powershell -NoProfile -ExecutionPolicy Bypass -File reapply-patch.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File reapply-patch.ps1 -Restore
#   powershell -NoProfile -ExecutionPolicy Bypass -File reapply-patch.ps1 -Target <plugin dir>
# Or from a PowerShell prompt in this folder: .\reapply-patch.ps1 [-Restore]
#
# What it refuses to do: clobber a different plugin version. If the installed
# package.json version is not the version this patch set was built against, the
# script only WARNS (an upgrade may still be compatible) and copies a timestamped
# backup of every file it touches into <Target>\.patch-backups\<stamp>\ first.

[CmdletBinding()]
param(
  [switch]$Restore,
  [string]$Target = "$env:DSH_PROFILE_DIR\node_modules\dsh-ego-browser",
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$source = if ($Restore) { Join-Path $root 'original-0.8.6' } else { Join-Path $root 'patched' }
$builtFor = '0.8.6'

if (-not (Test-Path $source)) { throw "snapshot folder not found: $source" }
if (-not (Test-Path (Join-Path $Target 'package.json'))) { throw "not a dsh-ego-browser package: $Target" }

$installed = (Get-Content (Join-Path $Target 'package.json') -Raw | ConvertFrom-Json).version
if ($installed -ne $builtFor -and -not $Force) {
  Write-Warning "installed version $installed differs from the $builtFor this patch set was built against; continuing, but review the diff afterwards."
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $Target ".patch-backups\$stamp"
$files = Get-ChildItem $source -Recurse -File
$copied = 0

foreach ($file in $files) {
  $relative = $file.FullName.Substring($source.Length).TrimStart('\')
  $destination = Join-Path $Target $relative
  if (Test-Path $destination) {
    $backupPath = Join-Path $backup $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $backupPath -Parent) | Out-Null
    Copy-Item $destination $backupPath -Force
  }
  New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null
  Copy-Item $file.FullName $destination -Force
  $copied++
}

Write-Host ("{0} {1} file(s) into {2}" -f ($(if ($Restore) { 'restored' } else { 'applied' })), $copied, $Target)
Write-Host "previous versions backed up to $backup"
Write-Host 'A DSH restart is required for lib/ changes (tools + watch panel); the runtime/ changes take effect on the next browser cold start.'