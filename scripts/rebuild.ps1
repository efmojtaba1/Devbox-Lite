. "$PSScriptRoot/common.ps1"

Show-Header "Rebuilding DevBox"

docker build `
    --no-cache `
    -t $ImageName `
    ./docker/app

Test-Result "Rebuild completed successfully." "Rebuild failed."
