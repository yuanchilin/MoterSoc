# Agent Environment Configuration

本文档为 AI Agent 提供项目环境的完整配置信息，避免重复探测。

## 通用

| 项 | 值 |
|---|---|
| 操作系统 | Windows 11 |
| 默认 Shell | **pwsh** (PowerShell 7) |
| 项目根目录 | `d:/Downloads/Agent/Soc` |
| 主分支 | `origin: git@github.com:yuanchilin/MoterSoc.git` |

## Vivado

| 项 | 值 |
|---|---|
| 版本 | Vivado 2020.2 |
| 安装路径 | `E:/Xilinx/Vivado/2020.2` |
| vivado 命令 | `E:\Xilinx\Vivado\2020.2\bin\vivado.bat` (在 PATH 中) |
| 目标器件 | `xc7a35tfgg484-2` (Artix-7) |
| 比特流输出 | `build/riscv_davinci/riscv_davinci.runs/impl_1/top.bit` |

## 项目结构

```
d:/Downloads/Agent/Soc/
├── rtl/
│   ├── cpu/riscv_core.v          # RISC-V RV32I 五级流水线 CPU
│   ├── peripheral/
│   │   ├── gpio.v                # GPIO 外设
│   │   ├── pwm.v                 # PWM 外设
│   │   └── uart.v                # UART 外设
│   ├── soc/
│   │   ├── riscv_soc.v           # SoC 顶层 (Wishbone 总线)
│   │   └── inst_rom.v            # 指令 ROM
│   └── top.v                     # FPGA 顶层 (top module)
├── constraints/
│   └── daVinci.xdc               # 引脚约束 (ALIENTEK DaVinci V2.1)
├── tb/
│   ├── tb_soc.v
│   ├── tb_top.v
│   └── tb_uart_direct.v
├── scripts/
│   ├── create_project.tcl        # Tcl: 创建工程
│   ├── create_project.ps1        # ★ pwsh: 创建工程 (推荐)
│   ├── rebuild.tcl               # Tcl: 重建 (合成+实现+比特流)
│   ├── rebuild.ps1               # ★ pwsh: 重建 (推荐)
│   ├── program.tcl               # Tcl: 烧录
│   └── program.ps1               # ★ pwsh: 烧录 (推荐)
├── build/                        # ★ 所有 Vivado 中间文件都在这里
│   ├── vivado.jou                # Vivado 日志
│   ├── vivado.log                # Vivado 日志
│   ├── .Xil/                     # Vivado 临时目录
│   └── riscv_davinci/            # Vivado 工程
│       ├── riscv_davinci.xpr     # 工程文件
│       └── riscv_davinci.runs/
│           └── impl_1/top.bit    # 最终比特流
└── ENVIRONMENT.md                # 本文件
```

## 构建命令

> **重要**：所有构建命令必须在项目根目录 `d:/Downloads/Agent/Soc` 执行。pwsh 脚本会自动 `Push-Location build/`，避免 vivado.jou/log/.Xil 污染根目录。

| 操作 | 命令 |
|---|---|
| 创建工程 | `pwsh scripts/create_project.ps1` |
| 重建 (修改 RTL 后) | `pwsh scripts/rebuild.ps1` |
| 烧录 FPGA | `pwsh scripts/program.ps1` |

## MCP 串口终端 (v2.1.0 - 自动连接 + 双向 Web 终端)

| 项 | 值 |
|---|---|
| 服务器 | `serial-terminal` (`node E:/HuaweiMoveData/Users/Yuan/Documents/Cline/MCP/serial-terminal/build/index.js`) |
| 版本 | **v2.1.0** |
| 可用工具 | `list_ports`、`serial_start`、`serial_stop`、`serial_status`、`serial_read`、`serial_send`、`serial_clear_buffer` |
| Web 终端 | `http://localhost:9721` (实时查看 **+ 发送** 串口数据，**替代 VSCode 串口插件**) |
| 缓冲区 | 环形缓冲区，默认 1MB，环境变量 `SERIAL_BUFFER_SIZE` |
| ⭐ 自动连接 | 设 `SERIAL_AUTO_CONNECT=true`，MCP 启动即打开串口，**零遗漏** |

### 推荐配置 (MCP Settings)

```json
{
  "serial-terminal": {
    "command": "node",
    "args": ["E:/HuaweiMoveData/Users/Yuan/Documents/Cline/MCP/serial-terminal/build/index.js"],
    "env": {
      "SERIAL_AUTO_CONNECT": "true",
      "SERIAL_PORT": "COM3",
      "SERIAL_BAUDRATE": "115200"
    }
  }
}
```

> **效果**：Agent 启动时串口自动打开并开始缓冲。无论设备何时输出 UART 数据，都被完整捕获。

### MCP 串口调试工作流 (v2.1.0)

> **核心理念**：串口监听 = 常驻服务，无需"先开后下"的时序协调。

```
AUTO_CONNECT=true 时，以下步骤全自动：
1. Agent 启动 → MCP 自动打开串口开始缓冲
2. pwsh scripts/program.ps1 → 脚本检查串口已就绪
3. 设备启动 → 所有 UART 日志进入缓冲区
4. serial_read → 读取缓冲区的全部启动日志
5. 需要交互 → serial_send 发送命令
```

### Web 双向终端 (替代 VSCode 串口插件)

> **不再需要 VSCode 串口插件！** 打开 `http://localhost:9721`：
> - **实时查看**：SSE 推送，所有串口数据实时显示，带时间戳
> - **发送命令**：底部输入框可直接发送文本，支持 LF/CRLF/CR
> - **与 Agent 共存**：Web 页面只是"旁听者"，不占用独立串口连接
> - **自动重连**：SSE 断开后 3 秒自动重连

### 下载脚本的串口检查

`program.ps1` 和 `rebuild.ps1` 执行前自动查询 MCP `/status` API：
- ✅ 串口已打开 → 打印状态和已缓冲数据量
- ⚠ 串口未打开 → 警告"设备启动日志将被遗漏"
- ⚠ MCP 未运行 → 提示"建议设置 SERIAL_AUTO_CONNECT=true"

### 串口工具说明

| 工具 | 用途 |
|---|---|
| `serial_start` | 打开串口持久监听 (AUTO_CONNECT 时一般无需手动调用) |
| `serial_read` | **增量读取** Agent 尚未读过的新数据（跟踪偏移，不重复读） |
| `serial_send` | 发送命令并等待响应 |
| `serial_status` | 查看连接状态、缓冲区大小、Agent 未读数据量 |
| `serial_stop` | 停止监听 |
| `serial_clear_buffer` | 清空缓冲区（重置 Agent 读取偏移） |
| `list_ports` | 列出所有可用串口 |

## Vivado 中间文件说明

Vivado 在启动瞬间写入 `vivado.jou`、`vivado.log`、`.Xil/` 到**当前工作目录**。pwsh 脚本通过 `Push-Location build/` 在启动 Vivado 前切换 CWD，确保这些文件直接落在 `build/` 下。

**不要使用** `vivado -mode batch -source scripts/rebuild.tcl` 直接在根目录运行，这会污染根目录。

## Git 忽略

已配置 `.gitignore` 忽略：
- `build/riscv_davinci/` (Vivado 工程)
- `vivado*.jou`、`vivado*.log`、`vivado*.str`
- `.Xil/`
- `*.bit`、`*.dcp`、`*.rpt`、`*.pb` 等编译产物

## Agent 注意事项

1. **默认使用 pwsh**，不要进入 cmd 或其他 shell
2. 构建前不需要检查环境，直接执行对应的 `.ps1` 脚本即可
3. 串口相关操作使用 `serial-terminal` MCP 工具
4. Vivado 合成/实现需要数分钟，`-jobs 32` 已配好多线程