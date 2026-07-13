. "$PSScriptRoot/common.ps1"

Show-Header "Opening DevBox Shell"

docker exec -it $ContainerName bash
