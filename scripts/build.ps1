. "$PSScriptRoot/common.ps1"

Show-Header "Building DevBox - lite"

$DockerFile = Join-Path $ScriptDir "docker/app/Dockerfile"
$BuildContext = Join-Path $ScriptDir "docker/app"

docker build -t $ImageName -f $DockerFile $BuildContext

Test-Result "Build completed successfully." "Build failed."
