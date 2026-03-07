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

```
Riscv/
├── rtl/                        # RTL源代码
│   ├── cpu/
│   │   └── riscv_core.v       # RISC-V CPU核心 (RV32I)
│   ├── peripheral/             # 外设模块
│   │   ├── gpio.v             # GPIO外设
│   │   ├── pwm.v              # PWM外设
│   │   └── uart.v             # UART外设
│   ├── soc/                    # SoC集成
│   │   ├── riscv_soc.v        # SoC顶层集成
│   │   ├── inst_rom.v         # 指令存储器
│   │   ├── demo_program.v     # 综合演示程序
│   │   └── uart_test_program.v # UART测试程序
│   └── top.v                  # FPGA顶层模块
├── constraints/                # 约束文件
│   └── daVinci.xdc            # DaVinci引脚约束
├── tb/                        # 测试文件
│   ├── tb_soc.v              # SoC仿真测试
│   └── tb_top.v              # 顶层仿真测试
├── scripts/                   # 脚本文件
│   ├── create_project.tcl     # Vivado工程创建脚本
│   ├── program.tcl           # FPGA烧录脚本
│   └── rebuild.tcl           # 重建工程脚本
├── docs/                      # 文档
│   ├── TESTING.md            # 测试指南
│   ├── HOW_TO_RUN_TEST.md    # 使用说明
│   └── COMPLETED_FEATURES.md # 功能完成清单
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
- **GTKWave** (用于查看仿真波形)
- **iverilog** (用于命令行仿真)

## 快速开始

### 1. 创建 Vivado 工程

```bash
cd Riscv
vivado -mode batch -source scripts/create_project.tcl
```

### 2. 运行仿真测试

```bash
cd Riscv
iverilog -o tb_soc.out \
    rtl/cpu/riscv_core.v \
    rtl/peripheral/gpio.v \
    rtl/peripheral/pwm.v \
    rtl/peripheral/uart.v \
    rtl/soc/riscv_soc.v \
    rtl/soc/inst_rom.v \
    rtl/soc/demo_program.v \
    rtl/top.v \
    tb/tb_soc.v
vvp tb_soc.out
```

### 3. 查看仿真波形

```bash
gtkwave tb_soc.vcd
```

### 4. 烧录到开发板

```bash
vivado -mode batch -source scripts/program.tcl
```

## 详细使用指南

更多详细的使用说明请参考：
- [测试指南](docs/TESTING.md)
- [使用说明](docs/HOW_TO_RUN_TEST.md)
- [功能清单](docs/COMPLETED_FEATURES.md)

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
| 0x00 | CTRL | 控制寄存器 [0]: 使能, [1]: 模式 |
| 0x04 | PERIOD | 周期寄存器 |
| 0x08 | DUTY | 占空比寄存器 |
| 0x0C | CNT | 计数器 (只读) |

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

```
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
4. 仿真测试需要安装GTKWave和iverilog

## 参考资料

- [RISC-V 官方规格](https://riscv.org/technical/specifications/)
- [正点原子达芬奇开发板资料](http://www.openedv.com/)
- [Xilinx Vivado文档](https://www.xilinx.com/support/documentation-navigation/design-hubs/dh0002-vivado-design-hub.html)
- [Wishbone总线规范](https://opencores.org/projects/wishbone)

## 开发环境

- **操作系统**: Windows 10/11
- **FPGA工具**: Xilinx Vivado 2020.2+
- **仿真工具**: iverilog + GTKWave
- **目标器件**: xc7a35tfgg484-2 (Artix-7)

## 贡献指南

欢迎提交Issue和Pull Request来改进项目。

## 许可证

本项目采用MIT许可证，详见LICENSE文件。
