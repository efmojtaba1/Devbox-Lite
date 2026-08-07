# Print heading slugs for docs markdown files
$paths = Get-ChildItem docs -Recurse -Include *.md -ErrorAction SilentlyContinue
foreach ($p in $paths) {
    Write-Output "FILE: $($p.FullName)"
    $i = 0
    Get-Content $p | ForEach-Object {
        $i++
        if ($_ -match '^(#{1,6})\s*(.+)$') {
            $text = $matches[2].Trim()
            $slug = $text.ToLower()
            try { $slug = [System.Uri]::UnescapeDataString($slug) } catch {}
            $slug = $slug -replace '`',''
            $slug = $slug -replace '\(.*?\)',''
            $slug = [regex]::Replace($slug,'[^\p{L}\p{N}\s-]','')
            $slug = $slug -replace '\s+','-'
            $slug = $slug -replace '-+','-'
            $slug = $slug.Trim('-')
            Write-Output "  $slug -> $text"
        }
    }
}
