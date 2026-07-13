. "$PSScriptRoot/common.ps1"
. "$PSScriptRoot/project-utils.ps1"

Show-Header "Stopping DevBox"

# ۱. توقف تمام compose files مربوط به پروژه‌ها
$workspacePath = Join-Path $PSScriptRoot "..\workspace"

if (Test-Path $workspacePath) {
    $projects = Get-ChildItem -Path $workspacePath -Directory -ErrorAction SilentlyContinue

    foreach ($project in $projects) {
        $projectType = Get-ProjectType -ProjectPath $project.FullName

        if ($projectType) {
            $composeFile = Get-ComposeFile -ProjectType $projectType

            if ($composeFile) {
                $fullComposePath = Join-Path $PSScriptRoot "..\$composeFile"

                if (Test-Path $fullComposePath) {
                    Write-Host "Stopping database services for $($project.Name)..."
                    docker compose -f $fullComposePath down 2>$null
                }
            }
        }
    }
}

# ۲. توقف کانتینر اصلی
docker compose `
    -f $ComposeFile `
    down

Test-Result "DevBox stopped." "Failed to stop DevBox."
