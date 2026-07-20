# DevBox Lite - VS Code PowerShell Profile
# Dynamically finds project root based on .vscode location

$DevBoxRoot = (Get-Item $PSScriptRoot).Parent.FullName

# Define functions dynamically based on project path
function up { & "$DevBoxRoot\scripts\up.ps1" }
function down { & "$DevBoxRoot\scripts\down.ps1" }
function down-v { & "$DevBoxRoot\scripts\down-v.ps1" }
function shell { & "$DevBoxRoot\scripts\shell.ps1" }
function logs { & "$DevBoxRoot\scripts\logs.ps1" }
function restart { & "$DevBoxRoot\scripts\restart.ps1" }
function status { & "$DevBoxRoot\scripts\status.ps1" }
function build { & "$DevBoxRoot\scripts\build.ps1" }
function rebuild { & "$DevBoxRoot\scripts\rebuild.ps1" }
function clean { & "$DevBoxRoot\scripts\clean.ps1" }
function scan { & "$DevBoxRoot\scripts\scan.ps1" }
function backup { & "$DevBoxRoot\scripts\backup.ps1" }
function restore { & "$DevBoxRoot\scripts\restore.ps1" }
function test-api { & "$DevBoxRoot\scripts\test-api.ps1" }
function run { & "$DevBoxRoot\scripts\run.ps1" $args }
function setup-deps {
    . "$DevBoxRoot\scripts\common.ps1"
    Show-Header "Setting up Dependencies"
    docker exec -it $ContainerName bash -c "/scripts/setup-deps.sh $args"
}

# Clear terminal and show welcome message
Clear-Host
Write-Host "DevBox Environment Loaded!" -ForegroundColor Green
Write-Host ""
Write-Host "Commands:" -ForegroundColor Cyan
Write-Host "  up, down, down-v, shell, logs, restart, status" -ForegroundColor White
Write-Host "  build, rebuild, clean" -ForegroundColor White
Write-Host "  scan, setup-deps, test-api, run" -ForegroundColor White
Write-Host "  backup, restore" -ForegroundColor White
Write-Host ""
Write-Host "Start with: up" -ForegroundColor Yellow
