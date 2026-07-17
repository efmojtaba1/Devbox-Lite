. "$PSScriptRoot/common.ps1"

Show-Header "Rebuilding DevBox"

docker compose -f $ComposeFile build --no-cache

Test-Result "Rebuild completed successfully." "Rebuild failed."
