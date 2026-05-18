# Program RISC-V SoC to DaVinci FPGA (PowerShell wrapper)
# Usage: pwsh scripts/program.ps1
# 确保 Vivado 所有中间文件都落在 build/ 而非项目根目录
# 
# 如果 MCP 串口终端 (serial-terminal) 在运行，编程前会检查串口是否已打开。
# 设置环境变量 MCP_WEB_PORT 指向 Web 终端端口 (默认 9721)。

$ErrorActionPreference = "Stop"

# 获取脚本所在目录，计算项目根目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..")
$BuildDir = Join-Path $ProjectRoot "build"

# 确保 build 目录存在
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
}

# ===========================================================================
# 串口状态检查 - 确保编程时不遗漏设备启动日志
# ===========================================================================
$McpWebPort = if ($env:MCP_WEB_PORT) { $env:MCP_WEB_PORT } else { "9721" }
$McpStatusUrl = "http://localhost:$McpWebPort/status"

try {
    $statusResp = Invoke-RestMethod -Uri $McpStatusUrl -Method Get -TimeoutSec 2 -ErrorAction Stop
    if ($statusResp.connected) {
        Write-Host "[Serial] MCP 串口已就绪: $($statusResp.port) @ $($statusResp.baudRate) baud"
        Write-Host "[Serial] 已缓冲 $([math]::Round($statusResp.stats.totalBytes / 1024, 1)) KB - 编程后不会遗漏启动日志"
    } else {
        Write-Warning "[Serial] ⚠ MCP 串口未打开! 设备启动日志将被遗漏"
        Write-Warning "[Serial] 请在编程前确保 serial_start 或设置 SERIAL_AUTO_CONNECT=true"
    }
} catch {
    Write-Warning "[Serial] ⚠ 无法连接 MCP 串口终端 ($McpStatusUrl) - 未检查串口状态"
    Write-Warning "[Serial] 建议启动 serial-terminal MCP server 并设置 SERIAL_AUTO_CONNECT=true"
}

# 切换到 build 目录执行 vivado，保证 vivado.jou/log/.Xil 等中间文件进 build/
Push-Location $BuildDir
try {
    $VivadoArgs = @(
        "-mode", "batch",
        "-source", (Join-Path $ScriptDir "program.tcl")
    )
    & vivado @VivadoArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Vivado program failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
}

Write-Host "Programming completed successfully!"