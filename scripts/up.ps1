. "$PSScriptRoot/common.ps1"

Show-Header "Starting DevBox Lite"

docker compose `
    -f $ComposeFile `
    up -d

Test-Result "DevBox Lite container started." "Failed to start DevBox Lite container."

$workspacePath = Join-Path $PSScriptRoot "..\workspace"

Write-Host ""
Write-Host "========================================="
Write-Host "DevBox Lite is ready!"
Write-Host "========================================="
Write-Host ""
Write-Host "Main container: $ContainerName"
Write-Host "Workspace: $workspacePath"
Write-Host ""
Write-Host "Use 'shell' to enter the container."
Write-Host "Use 'setup-deps' to configure database services."
