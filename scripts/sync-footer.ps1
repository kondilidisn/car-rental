#!/usr/bin/env pwsh
# Sync footer from index.html to all other .html files in the site directory tree.
# Usage: Run this script from the repository root or execute it directly.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$siteDir = Split-Path -Parent $scriptDir

$indexPath = Join-Path $siteDir 'index.html'
if (-not (Test-Path $indexPath)) {
    Write-Error "index.html not found at $indexPath"
    exit 1
}

$indexContent = Get-Content $indexPath -Raw -ErrorAction Stop

# Try to extract footer between markers, otherwise by <footer> and linked sub-footer block.
if ($indexContent -match '(?s)<!--\s*FOOTER START\s*-->(.*)<!--\s*FOOTER END\s*-->') {
    $footer = $matches[1]
} elseif ($indexContent -match '(?s)(<footer>.*?</footer>\s*<div class="sub-footer">.*?</div>)') {
    $footer = $matches[1]
} else {
    Write-Error "Could not locate footer block in index.html"
    exit 1
}

$footerWithMarkers = "<!-- FOOTER START -->`n$footer`n<!-- FOOTER END -->"

function Sync-FooterInFile([string]$filePath) {
    $content = Get-Content $filePath -Raw

    if ($content -match '(?s)<!--\s*FOOTER START\s*-->(.*)<!--\s*FOOTER END\s*-->') {
        return [regex]::Replace($content, '(?s)<!--\s*FOOTER START\s*-->.*?<!--\s*FOOTER END\s*-->', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) return $footerWithMarkers })
    }

    if ($content -match '(?s)(<footer>.*?</footer>\s*<div class="sub-footer">.*?</div>)') {
        return [regex]::Replace($content, '(?s)(<footer>.*?</footer>\s*<div class="sub-footer">.*?</div>)', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) return $footerWithMarkers })
    }

    return $null
}

$files = Get-ChildItem -Path $siteDir -Recurse -Filter *.html | Where-Object { $_.FullName -ne $indexPath }
foreach ($f in $files) {
    Write-Host "Syncing footer into $($f.FullName)"
    $newContent = Sync-FooterInFile $f.FullName
    if ($newContent) {
        Set-Content -Path $f.FullName -Value $newContent -Encoding UTF8
    } else {
        Write-Warning "No suitable footer location found in $($f.FullName); skipping"
    }
}

Write-Host "Footer sync complete."
