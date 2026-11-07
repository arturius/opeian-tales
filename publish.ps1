# Publish the Opeian Tales Obsidian vault to GitHub Pages.
#
#   .\publish.ps1            copy the vault into content/, commit, push (GitHub Actions deploys)
#   .\publish.ps1 -Preview   copy the vault and serve the site locally at http://localhost:8080
#   .\publish.ps1 -NoPush    copy and commit, but don't push
#
# Every page is protected with $Password (a casual gate, not real security).

param(
    [string]$Vault = "F:\Obsidian Vaults\Paid DND\Opeian Tales",
    [string]$Password = "vol6",
    [switch]$Preview,
    [switch]$NoPush
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$Content = Join-Path $Root "content"

if (-not (Test-Path -LiteralPath $Vault)) { throw "Vault not found: $Vault" }

Write-Host "Copying vault -> content/ ..." -ForegroundColor Cyan
# Mirror the vault, skipping Obsidian config, templates, trash, the default Welcome note,
# and the empty R note / Untitled base at the vault root.
$skipFiles = @("Welcome.md", (Join-Path $Vault "R.md"), (Join-Path $Vault "Untitled.base"))
robocopy "$Vault" "$Content" /MIR /XD ".obsidian" "z_Templates" ".trash" /XF $skipFiles /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
# robocopy /MIR keeps excluded files already in content/, so remove them explicitly.
foreach ($f in @("R.md", "Untitled.base")) {
    $p = Join-Path $Content $f
    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
}

# Homepage lives outside the vault.
Copy-Item -LiteralPath (Join-Path $Root "site\index.md") -Destination (Join-Path $Content "index.md") -Force

# Add the site password to every page's frontmatter (the encrypted-pages plugin encrypts
# any page that has one). Notes without frontmatter get a new block; this also stops Quartz
# from reading the session notes' leading "---" divider as frontmatter, so it renders as a
# horizontal rule like in Obsidian.
$utf8 = New-Object System.Text.UTF8Encoding($false)
$pwLine = "password: `"$Password`""
Get-ChildItem -LiteralPath $Content -Recurse -File -Filter *.md | ForEach-Object {
    $text = [IO.File]::ReadAllText($_.FullName, $utf8)
    if ($text -match '^---\r?\n') {
        $text = $text -replace '^---\r?\n', "---`n$pwLine`n"
    } else {
        $text = "---`n$pwLine`n---`n" + $text
    }
    [IO.File]::WriteAllText($_.FullName, $text, $utf8)
}

Set-Location $Root

if ($Preview) {
    npx quartz build --serve
    exit $LASTEXITCODE
}

git add -A
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "No changes since last publish." -ForegroundColor Yellow
} else {
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    git commit -q -m "Publish vault $stamp"
    if ($LASTEXITCODE -ne 0) { throw "git commit failed" }
    Write-Host "Committed changes." -ForegroundColor Green
}

if (-not $NoPush) {
    git push origin v5
    if ($LASTEXITCODE -ne 0) { throw "git push failed" }
    Write-Host "Pushed. GitHub Actions will deploy in about a minute." -ForegroundColor Green
}
