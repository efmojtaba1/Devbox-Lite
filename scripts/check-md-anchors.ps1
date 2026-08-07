# Check Markdown anchors vs headings
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root/.. | Out-Null
$outFile = "$PWD/out/anchor-check.txt"
New-Item -ItemType Directory -Path "$PWD/out" -Force | Out-Null
$headings = @{}
# Limit search to docs/ and top-level README/MEMORY to avoid scanning node_modules
$paths = @()
if (Test-Path -Path "docs") { $paths += Get-ChildItem -Path docs -Include *.md -Recurse }
foreach ($f in @('README.md','MEMORY.md')) { if (Test-Path $f) { $paths += Get-Item $f } }
Write-Output "Found $($paths.Count) markdown files to scan."
foreach ($p in $paths) { Write-Output " - $($p.FullName)" }
foreach ($item in $paths) {
    $path = $item.FullName
    $lines = Get-Content -Raw -Path $path -ErrorAction SilentlyContinue -Encoding UTF8
    if (-not $lines) { return }
    $idx = 0
    foreach ($line in ($lines -split "\r?\n")) {
        $idx++
        if ($line -match '^(#{1,6})\s*(.+)$') {
            $text = $matches[2].Trim()
            $slug = $text.ToLower()
            try { $slug = [System.Uri]::UnescapeDataString($slug) } catch {}
            $slug = $slug -replace '`',''
            $slug = $slug -replace '\(.*?\)',''
            $slug = $slug -replace '\[.*?\]',''
            $slug = [regex]::Replace($slug,"[^\p{L}\p{N}\s-]","")
            $slug = $slug -replace '\s+','-'
            $slug = $slug -replace '-+','-'
            $slug = $slug.Trim('-')
            if (-not $headings.ContainsKey($slug)) { $headings[$slug] = @() }
            $headings[$slug] += "$path#$idx"
        }
    }
}
$anchors = @()
foreach ($item in $paths) {
    $path = $item.FullName
    $content = Get-Content -Raw -Path $path -Encoding UTF8
    if ($content -match '\]\(#([^\)]+)\)') {
        [regex]::Matches($content,'\]\(#([^\)]+)\)') | ForEach-Object {
            $a = $_.Groups[1].Value
            $orig = $a
            try { $a = [System.Uri]::UnescapeDataString($a) } catch {}
            $a = $a.ToLower()
            $a = $a -replace '`',''
            $a = $a -replace '\(.*?\)',''
            $a = $a -replace '\[.*?\]',''
            $a = [regex]::Replace($a,"[^\p{L}\p{N}\s-]","")
            $a = $a -replace '\s+','-'
            $a = $a -replace '-+','-'
            $a = $a.Trim('-')
            $anchors += [PSCustomObject]@{file=$path; anchor=$orig; normalized=$a}
        }
    }
}
$missing = @()
foreach ($an in $anchors) {
    if (-not $headings.ContainsKey($an.normalized)) { $missing += $an }
}
if ($missing.Count -eq 0) {
    "All anchors have matching headings." | Out-File -FilePath $outFile -Encoding UTF8
    Write-Output "All anchors have matching headings."
} else {
    "Missing anchors:" | Out-File -FilePath $outFile -Encoding UTF8
    $missing | ForEach-Object { $line = "File: $($_.file) -> anchor: $($_.anchor)  (normalized: $($_.normalized))"; Write-Output $line; $line | Out-File -FilePath $outFile -Encoding UTF8 -Append }
}
Write-Output "Wrote results to $outFile"
