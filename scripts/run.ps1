param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Command
)

. "$PSScriptRoot/common.ps1"

if ($Command.Count -eq 0) {
    Write-Host "Usage: run <command> [args...]" -ForegroundColor Yellow
    Write-Host "Example: run pnpm create next-app my-app" -ForegroundColor Cyan
    exit 1
}

$cmdStr = $Command -join ' '
docker exec -it $ContainerName bash -c $cmdStr
