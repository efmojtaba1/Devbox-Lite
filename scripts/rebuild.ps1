. "$PSScriptRoot/common.ps1"

Show-Header "Rebuilding DevBox"

$DockerFile = Join-Path $ScriptDir "docker/app/Dockerfile"
$BuildContext = Join-Path $ScriptDir "docker/app"

docker build --no-cache -t $ImageName -f $DockerFile $BuildContext

Test-Result "Rebuild completed successfully." "Rebuild failed."
