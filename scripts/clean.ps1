. "$PSScriptRoot/common.ps1"

Show-Header "Cleaning Docker"

docker container prune -f
docker image prune -f
docker builder prune -f

Show-Success "Docker cleanup completed."
