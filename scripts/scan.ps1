. "$PSScriptRoot/common.ps1"
. "$PSScriptRoot/project-utils.ps1"

Show-Header "Scanning Workspace Projects"

$workspacePath = Join-Path $PSScriptRoot "..\workspace"

if (-not (Test-Path $workspacePath)) {
    Write-Host "Workspace folder not found." -ForegroundColor Yellow
    Write-Host "Create projects in: $workspacePath"
    exit 0
}

$projects = Get-ChildItem -Path $workspacePath -Directory -ErrorAction SilentlyContinue

if ($projects.Count -eq 0) {
    Write-Host "No projects found in workspace." -ForegroundColor Yellow
    Write-Host "Create a project first, then run 'setup-deps' to start database services."
    exit 0
}

Write-Host ""
Write-Host "Found $($projects.Count) project(s):"
Write-Host ""

$found = 0

foreach ($project in $projects) {
    $projectType = Get-ProjectType -ProjectPath $project.FullName

    if ($projectType) {
        $description = Get-ProjectDescription -ProjectType $projectType

        Write-Host "  - $($project.Name)" -ForegroundColor Green
        Write-Host "    Type: $description"
        Write-Host ""

        $found++
    }
}

if ($found -eq 0) {
    Write-Host "No supported projects found." -ForegroundColor Yellow
    Write-Host "Supported project types:"
    Write-Host "  - Laravel (artisan)"
    Write-Host "  - Next.js (next.config*)"
    Write-Host "  - Django (manage.py)"
    Write-Host "  - Python (requirements.txt)"
    Write-Host "  - FastAPI (main.py with FastAPI)"
}

Write-Host ""
Write-Host "Run 'setup-deps' to start database services for detected projects."
