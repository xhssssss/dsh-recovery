
param(
  [string]$RepoName = "dsh-recovery",
  [ValidateSet("private","public")][string]$Visibility = "private"
)
$ErrorActionPreference = 'Continue'
$gh = "C:\Program Files\GitHub CLI\gh.exe"
if (-not (Test-Path -LiteralPath $gh)) { throw "gh not found at $gh; install GitHub CLI first" }
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

& $gh auth status 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host "Not logged in. A browser (Edge) will open for GitHub device authorization."
  & $gh auth login --hostname github.com --git-protocol https --web --skip-ssh-key
  if ($LASTEXITCODE -ne 0) { throw "gh auth login failed" }
}

$existing = & $gh repo view $RepoName 2>$null
if ($LASTEXITCODE -eq 0) {
  Write-Host "Repository already exists: $RepoName"
  git remote remove origin 2>$null
  git remote add origin "https://github.com/$(& $gh api user --jq .login)/$RepoName.git"
  git push -u origin main
} else {
  & $gh repo create $RepoName --$Visibility --source . --remote origin --push
}
Write-Host "Done: https://github.com/$(& $gh api user --jq .login)/$RepoName"
