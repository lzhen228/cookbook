# run-dev.ps1 - 开发环境启动脚本

# 加载 .env.local 文件
$envFile = ".\.env.local"
if (Test-Path $envFile) {
    Write-Host "Loading $envFile..." -ForegroundColor Green
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*[^#]') {
            $key, $value = $_ -split '=', 2
            if ($key -and $value) {
                [Environment]::SetEnvironmentVariable($key.Trim(), $value.Trim(), "Process")
                Write-Host "  ✓ $($key.Trim())" -ForegroundColor Cyan
            }
        }
    }
} else {
    Write-Host "Error: $envFile not found!" -ForegroundColor Red
    exit 1
}

# 确保 Maven 在 PATH 中
$mvnPath = "$env:USERPROFILE\.mvn\apache-maven-3.9.6\bin"
if ($env:Path -notlike "*$mvnPath*") {
    $env:Path += ";$mvnPath"
    Write-Host "Added Maven to PATH: $mvnPath" -ForegroundColor Green
}

# 验证 Maven
Write-Host "`nVerifying Maven..." -ForegroundColor Green
mvn --version | Select-Object -First 1

# 启动应用
Write-Host "`nStarting Spring Boot application..." -ForegroundColor Green
Write-Host "API will be available at: http://localhost:8080/api/v1" -ForegroundColor Cyan
Write-Host "Database: PostgreSQL at localhost:5432" -ForegroundColor Cyan
Write-Host "Redis: localhost:6379" -ForegroundColor Cyan
Write-Host ""

cd services\api
mvn clean spring-boot:run
