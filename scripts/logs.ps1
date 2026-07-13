. "$PSScriptRoot/common.ps1"

Show-Header "DevBox Logs"

docker compose `
    -f $ComposeFile `
    logs -f
