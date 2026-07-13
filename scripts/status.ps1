. "$PSScriptRoot/common.ps1"

Show-Header "DevBox Status"

docker compose `
    -f $ComposeFile `
    ps
