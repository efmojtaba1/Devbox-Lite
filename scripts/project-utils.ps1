# Project Detection Utilities for DevBox Lite

function Get-ProjectType {
    param([string]$ProjectPath)

    if (Test-Path "$ProjectPath/artisan") { return "laravel" }
    if (Test-Path "$ProjectPath/next.config*") { return "nextjs" }
    if (Test-Path "$ProjectPath/manage.py") { return "django" }
    if (Test-Path "$ProjectPath/requirements.txt") { return "python" }
    if (Test-Path "$ProjectPath/fastapi*") { return "fastapi" }

    return $null
}

function Get-ProjectDescription {
    param([string]$ProjectType)

    $descriptionMap = @{
        "laravel" = "Laravel (PHP + MySQL + Redis)"
        "nextjs"  = "Next.js (React + TypeScript)"
        "django"  = "Django (Python + PostgreSQL + Redis)"
        "python"  = "Python (PostgreSQL)"
        "fastapi" = "FastAPI (Python + PostgreSQL)"
    }

    return $descriptionMap[$ProjectType]
}

function Get-ComposeFile {
    param([string]$ProjectType)

    $composeMap = @{
        "laravel" = $null
        "nextjs"  = $null
        "django"  = $null
        "python"  = $null
        "fastapi" = $null
    }

    return $composeMap[$ProjectType]
}
