. "$PSScriptRoot/common.ps1"

Show-Header "Building DevBox - lite"

docker build `
    -t $ImageName `
    ./docker/app

Test-Result "Build completed successfully." "Build failed."
