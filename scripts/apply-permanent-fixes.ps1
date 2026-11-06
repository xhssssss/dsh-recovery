
param(
  [string]$ProfileDir = "$env:USERPROFILE\.dsh\profiles\web",
  [switch]$SkipEgo,
  [switch]$SkipRestart
)

$ErrorActionPreference = 'Stop'
$RepoDir = Split-Path $PSScriptRoot -Parent
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

if (-not (Test-Path -LiteralPath (Join-Path $ProfileDir 'package.json'))) {
  throw "Not a DSH profile: $ProfileDir"
}

function Same-File([string]$a, [string]$b) {
  if (-not (Test-Path -LiteralPath $b)) { return $false }
  return (Get-FileHash -LiteralPath $a -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $b -Algorithm SHA256).Hash
}

function Copy-TreeIfChanged([string]$sourceRoot, [string]$targetRoot, [string]$backupRoot) {
  if (-not (Test-Path -LiteralPath $sourceRoot)) { throw "Missing source: $sourceRoot" }
  if (-not (Test-Path -LiteralPath $targetRoot)) { throw "Missing target: $targetRoot" }
  $copied = 0
  Get-ChildItem -LiteralPath $sourceRoot -Recurse -File | ForEach-Object {
    if ($_.Name -like '*.bak' -or $_.Name -like '*.backup*') { return }
    $rel = $_.FullName.Substring($sourceRoot.Length).TrimStart('\')
    $dst = Join-Path $targetRoot $rel
    $dir = Split-Path $dst -Parent
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if (Same-File $_.FullName $dst) { return }
    if (Test-Path -LiteralPath $dst) {
      $bd = Join-Path $backupRoot $rel
      $bdDir = Split-Path $bd -Parent
      if (-not (Test-Path -LiteralPath $bdDir)) { New-Item -ItemType Directory -Force -Path $bdDir | Out-Null }
      Copy-Item -LiteralPath $dst -Destination $bd -Force
    }
    Copy-Item -LiteralPath $_.FullName -Destination $dst -Force
    $copied++
  }
  Write-Host ("  copied {0} file(s) to {1}" -f $copied, $targetRoot)
}

Write-Host "== DSH permanent fixes =="
Write-Host "Profile: $ProfileDir"

# 1. ego-browser 0.8.6 patched (canonical repo: dsh-ego-browser-floating)
if (-not $SkipEgo) {
  $egoTarget = Join-Path $ProfileDir 'node_modules\dsh-ego-browser'
  $egoSource = Join-Path $RepoDir 'versions\0.8.6\patched'
  if (-not (Test-Path -LiteralPath $egoSource)) {
    $egoSource = Join-Path (Split-Path $RepoDir -Parent) 'dsh-ego-browser-floating\0.8.6\patched'
  }
  if ((Test-Path -LiteralPath $egoTarget) -and (Test-Path -LiteralPath $egoSource)) {
    Write-Host "[1/4] ego-browser 0.8.6 patch"
    $egoBackup = Join-Path $egoTarget ('.patch-backups\' + $stamp)
    Copy-TreeIfChanged $egoSource $egoTarget $egoBackup
  } elseif (-not (Test-Path -LiteralPath $egoSource)) {
    Write-Host "[1/4] SKIP: clone dsh-ego-browser-floating next to this repo"
  } else {
    Write-Host "[1/4] SKIP: dsh-ego-browser is not installed"
  }
}

# 2. setting-restart patch files (kept in a separate private repo)
if (-not $SkipRestart) {
  $srTarget = Join-Path $ProfileDir 'node_modules\dsh-setting-restart'
  $srSource = Join-Path $RepoDir 'patches\setting-restart'
  if ((Test-Path -LiteralPath $srTarget) -and (Test-Path -LiteralPath $srSource)) {
    Write-Host "[2/4] setting-restart patch"
    $srBackup = Join-Path $srTarget ('.patch-backups\' + $stamp)
    Copy-TreeIfChanged $srSource $srTarget $srBackup
  } elseif (-not (Test-Path -LiteralPath $srSource)) {
    Write-Host "[2/4] SKIP: setting-restart patch is in the separate private repo"
  } else {
    Write-Host "[2/4] SKIP: dsh-setting-restart is not installed"
  }
}

# 3. vision-router webRuntime -> webStartup override
Write-Host "[3/4] vision-router webStartup override"
$patchFile = Join-Path $ProfileDir 'cordis.patch.yml'
if (-not (Test-Path -LiteralPath $patchFile)) { throw "Missing $patchFile" }
$current = Get-Content -LiteralPath $patchFile -Raw -Encoding UTF8
if ($current -notmatch 'inject:\s*\[\s*webStartup\s*\]') {
  Copy-Item -LiteralPath $patchFile -Destination ($patchFile + '.bak-permanent-fixes-' + $stamp) -Force
  $block = @"

# 修复 dsh-vision-router 2.3.0 在 DSH 0.2.1+ 上的启动失败：
# 2.3.0 把 connection 行 inject 改成 [webRuntime, webServer]，
# 而 0.2.1 起宿主把 webRuntime 改名为 webStartup，connection 会永远 pending。
- id: modules
  name: '@deepseek-ai/dsh-client-modules'
- id: connection
  name: '@deepseek-ai/dsh-client-connection'
  inject: [webStartup]
  config:
    trustedHosts: !!js ctx.webStartup.trustedHosts
"@
  Add-Content -LiteralPath $patchFile -Value $block -Encoding UTF8
  Write-Host "  appended override block"
} else {
  Write-Host "  already present"
}

# 4. ensure setting-restart is in bundles
Write-Host "[4/4] ensure dsh-setting-restart bundle"
$pkgFile = Join-Path $ProfileDir 'package.json'
$pkg = Get-Content -LiteralPath $pkgFile -Raw -Encoding UTF8 | ConvertFrom-Json
if ($pkg.PSObject.Properties.Name -contains 'dsh' -and $pkg.dsh.profile.bundles -notcontains 'dsh-setting-restart') {
  if (Test-Path -LiteralPath (Join-Path $ProfileDir 'node_modules\dsh-setting-restart')) {
    Copy-Item -LiteralPath $pkgFile -Destination ($pkgFile + '.bak-permanent-fixes-' + $stamp) -Force
    $pkg.dsh.profile.bundles += 'dsh-setting-restart'
    $pkg | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $pkgFile -Encoding UTF8
    Write-Host "  added to bundles"
  } else {
    Write-Host "  SKIP: package not installed; run: dsh plugin --profile web add dsh-setting-restart@1.0.0"
  }
} else {
  Write-Host "  already present"
}

Write-Host ""
Write-Host "Done. Restart DSH: Ctrl+C, then run: npx @deepseek-ai/dsh web"
Write-Host "Verify: connection should activate, better-sidebar + approval-gate should mount."
