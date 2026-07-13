# یافتن مسیر داینامیک ریشه پروژه
$DevBoxRoot = (Get-Item $PSScriptRoot).Parent.FullName

# تعریف توابع به صورت داینامیک بر اساس محل پروژه کاربر
function up { & "$DevBoxRoot\scripts\up.ps1" }
function down { & "$DevBoxRoot\scripts\down.ps1" }
function shell { & "$DevBoxRoot\scripts\shell.ps1" }
function logs { & "$DevBoxRoot\scripts\logs.ps1" }
function restart { & "$DevBoxRoot\scripts\restart.ps1" }
function status { & "$DevBoxRoot\scripts\status.ps1" }
function build { & "$DevBoxRoot\scripts\build.ps1" }
function rebuild { & "$DevBoxRoot\scripts\rebuild.ps1" }
function clean { & "$DevBoxRoot\scripts\clean.ps1" }
function scan { & "$DevBoxRoot\scripts\scan.ps1" }
function setup-deps {
    . "$DevBoxRoot\scripts\common.ps1"
    Show-Header "Setting up Dependencies"
    docker exec $ContainerName bash -c "/workspace/scripts/setup-deps.sh $args"
}

# پاک‌سازی ترمینال و نمایش پیام خوش‌آمادگویی اختصاصی پروژه
Clear-Host
Write-Host "📦 DevBox Environment Loaded Successfully!" -ForegroundColor Green
Write-Host "🚀 Available commands: up, down, shell, logs, restart, status, build, rebuild, clean, scan, setup-deps" -ForegroundColor Cyan
Write-Host "🔍 Type 'up' to auto-detect projects and start database services" -ForegroundColor Yellow
