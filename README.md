# RISC-V SoC for ALIENTEK DaVinci FPGA

## 项目概述

本项目实现了一个在正点原子达芬奇 FPGA 开发板上运行的 RISC-V 处理器系统，包含以下外设：

- **GPIO**: 32位通用输入输出 (4个按键输入, 4个LED输出)
- **PWM**: 脉冲宽度调制输出 (蜂鸣器)
- **UART**: 串行通信接口 (115200波特率)

## 目录结构

```
Riscv/
├── rtl/
│   ├── cpu/
│   │   └── riscv_core.v       # RISC-V CPU核心 (RV32I)
│   ├── peripheral/
│   │   ├── gpio.v             # GPIO外设
│   │   ├── pwm.v              # PWM外设
│   │   └── uart.v             # UART外设
│   ├── soc/
│   │   ├── riscv_soc.v       # SoC顶层集成
│   │   └── inst_rom.v        # 指令存储器
│   └── top.v                  # FPGA顶层模块
├── constraints/
│  .xdc           # └── daVinci 引脚约束文件
├── create_project.tcl         # Vivado工程创建脚本
└── README.md                  # 本文档
```

## 硬件资源

| 外设    | 基地址       | 说明 |
|---------|--------------|------|
| GPIO    | 0x10000000   | 4按键输入, 4 LED输出 |
| PWM     | 0x10001000   | 蜂鸣器PWM输出 |
| UART    | 0x10002000   | 串口通信 |

### 引脚分配 (来自官方DaVinci_FPGA_IO.xdc)

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

1. **Xilinx Vivado 2020.2** 或更高版本
2. **RISC-V GCC 工具链** (位于资料盘: `tinyriscv-gcc-toolchain.tar.gz`)

## 使用方法

### 1. 创建 Vivado 工程

```bash
cd Riscv
vivado -mode batch -source create_project.tcl
```

### 2. 手动创建工程

1. 打开 Vivado
2. 创建新工程，选择器件: **xc7a35tfgg484-2**
3. 添加 RTL 源文件 (rtl/ 目录下所有 .v 文件)
4. 添加约束文件 (constraints/daVinci.xdc)
5. 综合、实现、生成比特流

### 3. 烧录到开发板

1. 连接开发板 (JTAG或USB)
2. 打开硬件管理器
3. 编程设备

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

- 指令集: RV32I (基础整数指令集)
- 流水线: 五级流水线 (IF-取指, ID-译码, EX-执行, MEM-访存, WB-写回)
- 支持指令: add, sub, and, or, xor, sll, srl, sra, slt, sltu
- 频率: 最高 50MHz

## 注意事项

1. 本项目的CPU核心是一个简化版RISC-V实现，适合学习和入门
2. 如需完整功能，建议使用 [tinyriscv](https://gitee.com/liangkangnan/tinyriscv) 项目
3. 引脚约束基于达芬奇V2.1版本，其他版本请核对原理图
4. CPU核心已更新为五级流水线架构，支持完整的R-type指令集

## 参考资料

- [RISC-V 官方规格](https://riscv.org/technical/specifications/)
- [正点原子达芬奇开发板资料](http://www.openedv.com/)
- [tinyriscv 开源项目](https://gitee.com/liangkangnan/tinyriscv)
- 工具链位置: `D:\Downloads\BaiduNetdiskDownload\tinyriscv-gcc-toolchain.tar.gz`
- 开发板资料位置:
  - A盘: `D:\Downloads\BaiduNetdiskDownload\【新资料-Vivado_2020.2-已完结】达芬奇FPGA开发板资料盘（A盘）`
  - B盘: `D:\Downloads\BaiduNetdiskDownload\【新资料-Vivado_2020.2-持续更新中】正点原子达芬奇FPGA开发板资料盘（B盘）`
