# Project Detection Utilities for DevBox Lite

function Get-ProjectType {
    param([string]$ProjectPath)

    if (Test-Path "$ProjectPath/artisan") { return "laravel" }
    if (Test-Path "$ProjectPath/next.config*") { return "nextjs" }
    if (Test-Path "$ProjectPath/manage.py") { return "django" }
    if (Test-Path "$ProjectPath/requirements.txt") { return "python" }
    if (Test-Path "$ProjectPath/main.py" -and (Select-String -Path "$ProjectPath/main.py" -Pattern "FastAPI" -Quiet -ErrorAction SilentlyContinue)) { return "fastapi" }

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

function Get-DatabaseServices {
    param([string]$ProjectType)

    $dbMap = @{
        "laravel" = @("mysql", "redis")
        "nextjs"  = @()
        "django"  = @("postgres", "redis")
        "python"  = @("postgres")
        "fastapi" = @("postgres")
    }

    return $dbMap[$ProjectType]
}
