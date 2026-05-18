# Create Vivado Project for RISC-V SoC on DaVinci FPGA (PowerShell wrapper)
# Usage: pwsh scripts/create_project.ps1
# 确保 Vivado 所有中间文件都落在 build/ 而非项目根目录

$ErrorActionPreference = "Stop"

# 获取脚本所在目录，计算项目根目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..")
$BuildDir = Join-Path $ProjectRoot "build"

# 确保 build 目录存在
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
}

# 切换到 build 目录执行 vivado，保证 vivado.jou/log/.Xil 等中间文件进 build/
Push-Location $BuildDir
try {
    $VivadoArgs = @(
        "-mode", "batch",
        "-source", (Join-Path $ScriptDir "create_project.tcl")
    )
    & vivado @VivadoArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Vivado create_project failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
}

Write-Host "Project creation completed successfully!"