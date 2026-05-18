#!/usr/bin/env pwsh
# Sync header from index.html to all other .html files in the site directory tree.
# Usage: Run from repository root or execute this script directly.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$siteDir = Split-Path -Parent $scriptDir

$indexPath = Join-Path $siteDir 'index.html'
if (-not (Test-Path $indexPath)) { Write-Error "index.html not found at $indexPath"; exit 1 }

$indexContent = Get-Content $indexPath -Raw -ErrorAction Stop

# Try to extract header between markers, otherwise between <div class="wrap"> and </header>
if ($indexContent -match '(?s)<!--\s*HEADER START\s*-->(.*)<!--\s*HEADER END\s*-->') {
    $header = $matches[1]
} elseif ($indexContent -match '(?s)(<div class="wrap">.*?</header>)') {
    $header = $matches[1]
} else {
    Write-Error "Could not locate header block in index.html"
    exit 1
}

$headerWithMarkers = "<!-- HEADER START -->`n$header`n<!-- HEADER END -->"

function Set-ActiveNav([string]$content, [string]$fileName) {
    # Remove any existing active class from previously copied header markup.
    $content = [regex]::Replace($content, '(?i)<li\s+class=([\'\"]?)active\1>', '<li>')

    $activeTarget = switch ($fileName) {
        'small-fleet.html' { 'fleet.html' }
        'medium-fleet.html' { 'fleet.html' }
        'compact-fleet.html' { 'fleet.html' }
        default { $fileName }
    }

    $pattern = '(?i)(<li>)(\s*<a\s+href="' + [regex]::Escape($activeTarget) + '")'
    if ($content -match $pattern) {
        $content = [regex]::Replace($content, $pattern, '<li class="active">$2', 1)
    }

    return $content
}

function Sync-HeaderInFile([string]$filePath) {
    $content = Get-Content $filePath -Raw

    if ($content -match '(?s)<!--\s*HEADER START\s*-->(.*)<!--\s*HEADER END\s*-->') {
        $content = [regex]::Replace($content, '(?s)<!--\s*HEADER START\s*-->.*?<!--\s*HEADER END\s*-->', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) return $headerWithMarkers })
    }
    elseif ($content -match '(?s)(<div class="wrap">.*?</header>)') {
        $content = [regex]::Replace($content, '(?s)(<div class="wrap">.*?</header>)', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) return $headerWithMarkers })
    }
    elseif ($content -match '(?is)(<body[^>]*>)') {
        $content = [regex]::Replace($content, '(?is)(<body[^>]*>)', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) return "$($m.Value)`n$headerWithMarkers" })
    }
    else {
        return $null
    }

    return Set-ActiveNav $content (Split-Path $filePath -Leaf)
}

$files = Get-ChildItem -Path $siteDir -Recurse -Filter *.html | Where-Object { $_.FullName -ne $indexPath }
foreach ($f in $files) {
    Write-Host "Syncing header into $($f.FullName)"
    $newContent = Sync-HeaderInFile $f.FullName
    if ($newContent) {
        Set-Content -Path $f.FullName -Value $newContent -Encoding UTF8
    } else {
        Write-Warning "No suitable header location found in $($f.FullName); skipping"
    }
}

Write-Host "Header sync complete."
