. "$PSScriptRoot/common.ps1"

Show-Header "Restarting DevBox"

docker compose `
    -f $ComposeFile `
    restart

Test-Result "DevBox restarted." "Failed to restart DevBox."
