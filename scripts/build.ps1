. "$PSScriptRoot/common.ps1"

Show-Header "Building DevBox - lite"

docker compose -f $ComposeFile build

Test-Result "Build completed successfully." "Build failed."
