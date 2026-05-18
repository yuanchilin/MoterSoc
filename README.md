# RISC-V SoC for ALIENTEK DaVinci FPGA

## 项目概述

本项目实现了一个在正点原子达芬奇 FPGA 开发板上运行的 RISC-V 处理器系统，包含以下外设：

- **GPIO**: 32位通用输入输出 (4个按键输入, 4个LED输出)
- **PWM**: 脉冲宽度调制输出 (蜂鸣器)
- **UART**: 串行通信接口 (115200波特率)

## 项目特性

- **五级流水线CPU**: 支持完整的RV32I指令集
- **Wishbone总线架构**: 模块化设计，易于扩展
- **完整的测试环境**: 包含仿真测试和演示程序
- **详细的文档**: 完整的使用说明和开发指南

## 目录结构

```raw
Soc/
├── rtl/                        # RTL源代码
│   ├── cpu/
│   │   └── riscv_core.v       # RISC-V CPU核心 (RV32I)
│   ├── peripheral/             # 外设模块
│   │   ├── gpio.v             # GPIO外设
│   │   ├── pwm.v              # PWM外设
│   │   └── uart.v             # UART外设
│   ├── soc/                    # SoC集成
│   │   ├── riscv_soc.v        # SoC顶层集成
│   │   └── inst_rom.v         # 指令存储器 (含"Hello Justin!"测试程序)
│   └── top.v                  # FPGA顶层模块
├── constraints/                # 约束文件
│   └── daVinci.xdc            # DaVinci引脚约束
├── tb/                        # 测试文件
│   ├── tb_soc.v              # SoC仿真测试
│   ├── tb_top.v              # 顶层仿真测试
│   └── tb_uart_direct.v      # UART直连仿真测试
├── scripts/                   # 脚本文件
│   ├── create_project.tcl     # Vivado工程创建脚本 (Tcl)
│   ├── create_project.ps1    # Vivado工程创建脚本 (PowerShell 包装器，推荐)
│   ├── program.tcl           # FPGA烧录脚本 (Tcl)
│   ├── program.ps1           # FPGA烧录脚本 (PowerShell 包装器，推荐)
│   ├── rebuild.tcl           # 重建工程脚本 (Tcl)
│   └── rebuild.ps1           # 重建工程脚本 (PowerShell 包装器，推荐)
├── tools/                     # 辅助工具
│   └── encode_jal2.js        # RISC-V JAL/BEQ指令编码/解码工具
├── build/                     # Vivado 构建输出（所有中间文件：vivado.jou/log/.Xil/.runs 均位于此目录）
│   └── riscv_davinci/
├── ENVIRONMENT.md             # Agent 环境配置信息
└── README.md                  # 项目说明
```

## 硬件资源

### 外设地址映射

| 外设    | 基地址       | 说明 |
|---------|--------------|------|
| GPIO    | 0x10000000   | 4按键输入, 4 LED输出 |
| PWM     | 0x10001000   | 蜂鸣器PWM输出 |
| UART    | 0x10002000   | 串口通信 |
| ROM     | 0x00000000   | 指令存储器 |

### FPGA引脚分配

| 信号 | FPGA引脚 | 说明 |
|------|----------|------|
| sys_clk | R4 | 系统时钟 50MHz |
| sys_rst_n | U2 | 系统复位 |
| key[0] | T1 | 按键1 |
| key[1] | U1 | 按键2 |
| key[2] | W2 | 按键3 |
| key[3] | T3 | 按键4 |
| led[0] | R2 | LED1 |
| led[1] | R3 | LED2 |
| led[2] | V2 | LED3 |
| led[3] | Y2 | LED4 |
| pwm_out | P16 | 蜂鸣器 |
| uart_rxd | U5 | UART接收 |
| uart_txd | T6 | UART发送 |

## 开发工具

- **Xilinx Vivado 2020.2** 或更高版本

## 快速开始

> **推荐使用 pwsh 包装脚本**（避免中间文件污染项目根目录）

### 1. 创建 Vivado 工程

```powershell
# 在项目根目录 (Soc/) 执行
pwsh scripts/create_project.ps1
```

### 2. 重建工程（修改 RTL 后）

```powershell
pwsh scripts/rebuild.ps1
```

### 3. 烧录到开发板

```powershell
pwsh scripts/program.ps1
```

> **为什么用 pwsh 包装脚本？** Vivado 在启动瞬间会将 `vivado.jou`、`vivado.log`、`.Xil` 写入当前工作目录。直接在 `scripts/rebuild.tcl` 里 `cd build/` 来不及拦截。pwsh 脚本在启动 Vivado 前就切到 `build/` 目录，确保所有中间文件都落在 `build/` 下，项目根目录保持清洁。

## 外设寄存器说明

### GPIO (基地址: 0x10000000)
| 偏移 | 寄存器 | 说明 |
|------|--------|------|
| 0x00 | DATA | 数据寄存器 (读/写) |
| 0x04 | DIR | 方向寄存器 (1=输出, 0=输入) |
| 0x08 | IE | 中断使能寄存器 |
| 0x0C | IS | 中断状态寄存器 |

### PWM (基地址: 0x10001000)
| 偏移 | 寄存器 | 说明 |
|------|--------|------|
| 0x00 | CTRL | 控制寄存器 [0]: 使能, [1]: 旋律使能 |
| 0x04 | PERIOD | 周期寄存器 |
| 0x08 | DUTY | 占空比寄存器 |
| 0x0C | CNT | 计数器 (只读) |

#### 蜂鸣器特性

硬件内置旋律播放器，支持按键触发播放（key[0]-key[2]选择曲目，key[3]停止）：

- **key[0]**: 小星星 (Twinkle Twinkle Little Star)
- **key[1]**: 生日快乐 (Happy Birthday)
- **key[2]**: 欢乐颂 (Ode to Joy)
- **key[3]**: 停止播放

设计特点：

- **纯 50% 占空比方波**：压电蜂鸣器在 50% 占空比时共振效果最佳，避免非对称波形引入额外谐波导致音色刺耳
- **音符间隙静音**：相邻不同音符间插入 5ms 静音间隙，消除频率跳变时产生的爆破点击声
- **时序分离**：音符序列器运行在 1kHz 节奏精度，PWM 发生器全速运行于 50MHz，保证音频波形干净无毛刺
- **3 首内置旋律**：存储在组合逻辑 ROM 中，按键即播，支持循环播放

### UART (基地址: 0x10002000)
| 偏移 | 寄存器 | 说明 |
|------|--------|------|
| 0x00 | CTRL | 控制寄存器 [0]: 使能, [1]: TX使能, [2]: RX使能 |
| 0x04 | STATUS | 状态寄存器 [0]: TX ready, [1]: RX ready |
| 0x08 | TXDATA | 发送数据寄存器 |
| 0x0C | RXDATA | 接收数据寄存器 |
| 0x10 | BAUDDIV | 波特率分频 (默认868 = 115200 @ 50MHz) |

## RISC-V 核心特性

- **指令集**: RV32I (基础整数指令集)
- **流水线**: 五级流水线 (IF-取指, ID-译码, EX-执行, MEM-访存, WB-写回)
- **数据前递**: 支持数据前递，解决数据冒险
- **分支预测**: 支持分支和跳转指令
- **频率**: 最高 50MHz

### 支持的指令

**R-type指令**:
- add, sub, and, or, xor, sll, srl, sra, slt, sltu

**I-type指令**:
- addi, slti, andi, ori, xori, slli, srli, srai

**Load/Store指令**:
- lw, sw

**分支指令**:
- beq, bne, blt, bge, bltu, bgeu

**跳转指令**:
- jal, jalr

**伪指令**:
- lui, auipc

## 项目架构

### CPU流水线设计

```raw
IF (取指) -> ID (译码) -> EX (执行) -> MEM (访存) -> WB (写回)
```

### 数据前递机制

- EX/MEM -> EX (前递到ALU输入)
- MEM/WB -> EX (前递到ALU输入)
- MEM/WB -> MEM (前递到存储器)

### Wishbone总线

- 模块化设计，易于扩展新外设
- 支持等待状态，适应不同外设速度
- 地址解码支持多个外设

## 注意事项

1. 本项目适合RISC-V架构学习和FPGA开发入门
2. CPU核心为教学用途，性能有限
3. 引脚约束基于达芬奇V2.1版本，其他版本请核对原理图

## 参考资料

- [RISC-V 官方规格](https://riscv.org/technical/specifications/)
- [正点原子达芬奇开发板资料](http://www.openedv.com/)
- [Xilinx Vivado文档](https://www.xilinx.com/support/documentation-navigation/design-hubs/dh0002-vivado-design-hub.html)
- [Wishbone总线规范](https://opencores.org/projects/wishbone)

## 开发环境

- **操作系统**: Windows 10/11
- **FPGA工具**: Xilinx Vivado 2020.2+
- **目标器件**: xc7a35tfgg484-2 (Artix-7)

## 贡献指南

欢迎提交Issue和Pull Request来改进项目。

## 许可证

本项目采用MIT许可证，详见LICENSE文件。
