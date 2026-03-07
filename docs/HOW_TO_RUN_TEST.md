# RISC-V SoC 测试使用说明

## 1. 项目概述

本项目提供完整的RISC-V SoC测试环境，包含仿真测试、FPGA烧录和详细的使用指南。项目支持一键测试和手动测试两种方式。

## 2. 环境准备

### 2.1 系统要求
- **操作系统**: Windows 10/11 (64位)
- **内存**: 至少8GB RAM
- **存储空间**: 至少10GB可用空间
- **网络**: 用于下载工具链（可选）

### 2.2 软件工具

#### 2.2.1 必需工具
- **Xilinx Vivado 2020.2** 或更高版本
  - 下载地址: [Xilinx官网](https://www.xilinx.com/support/download.html)
  - 安装时选择"Vivado HLx Design Editions"

- **iverilog** (用于命令行仿真)
  - 下载地址: [iverilog官网](http://iverilog.icarus.com/)
  - 安装后确认在命令行可执行

- **GTKWave** (用于查看波形)
  - 下载地址: [GTKWave官网](http://gtkwave.sourceforge.net/)
  - 安装后确认在命令行可执行

#### 2.2.2 可选工具
- **Git** (用于版本控制)
- **Notepad++** 或其他文本编辑器

### 2.3 环境配置

#### 2.3.1 Vivado环境配置
1. 安装Vivado后，将安装目录添加到系统PATH
   ```
   C:\Xilinx\Vivado\2020.2\bin
   ```

2. 验证安装
   ```bash
   vivado -version
   ```

#### 2.3.2 仿真工具配置
1. 安装iverilog和GTKWave
2. 验证安装
   ```bash
   iverilog -v
   gtkwave --version
   ```

## 3. 项目结构

### 3.1 目录说明
```
Riscv/
├── rtl/                        # RTL源代码
│   ├── cpu/                    # CPU核心
│   ├── peripheral/             # 外设模块
│   └── soc/                    # SoC集成
├── constraints/                # 约束文件
├── tb/                         # 测试文件
├── scripts/                    # 脚本文件
├── docs/                       # 文档
└── README.md                   # 项目说明
```

### 3.2 关键文件
- **`scripts/create_project.tcl`**: Vivado工程创建脚本
- **`scripts/program.tcl`**: FPGA烧录脚本
- **`tb/tb_soc.v`**: SoC仿真测试文件
- **`rtl/soc/demo_program.v`**: 演示程序
- **`constraints/daVinci.xdc`**: 引脚约束文件

## 4. 快速开始

### 4.1 一键测试 (推荐)
```bash
cd Riscv
vivado -mode batch -source scripts/create_project.tcl
```

### 4.2 完整测试流程
```bash
# 1. 创建Vivado工程
vivado -mode batch -source scripts/create_project.tcl

# 2. 运行仿真测试
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

# 3. 查看仿真波形
gtkwave tb_soc.vcd

# 4. FPGA烧录 (可选)
vivado -mode batch -source scripts/program.tcl
```

## 5. 详细测试步骤

### 5.1 Vivado工程创建

#### 5.1.1 自动创建 (推荐)
```bash
cd Riscv
vivado -mode batch -source scripts/create_project.tcl
```

#### 5.1.2 手动创建
1. 打开Vivado
2. 选择"Create Project"
3. 设置工程名称和路径
4. 选择器件: `xc7a35tfgg484-2`
5. 添加源文件: `rtl/`目录下所有`.v`文件
6. 添加约束文件: `constraints/daVinci.xdc`
7. 设置顶层模块: `top`

### 5.2 仿真测试

#### 5.2.1 编译仿真
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
```

#### 5.2.2 运行仿真
```bash
vvp tb_soc.out
```

#### 5.2.3 查看波形
```bash
gtkwave tb_soc.vcd
```

### 5.3 FPGA烧录

#### 5.3.1 自动烧录 (推荐)
```bash
vivado -mode batch -source scripts/program.tcl
```

#### 5.3.2 手动烧录
1. 连接开发板到电脑
2. 打开Vivado硬件管理器
3. 打开目标设备
4. 选择比特流文件: `riscv_davinci/riscv_davinci.runs/impl_1/top.bit`
5. 点击"Program Device"

## 6. 测试验证

### 6.1 仿真测试验证

#### 6.1.1 控制台输出
测试运行时应显示：
```
Test 1: GPIO - Toggle LEDs
Test 2: PWM - Generate PWM signal
Test 3: UART - Send and receive data
Test 4: CPU - Run simple program
All tests completed successfully!
```

#### 6.1.2 波形验证
在GTKWave中应能看到：
- **时钟信号**: 50MHz方波
- **复位信号**: 正确的复位时序
- **GPIO信号**: 按键和LED的对应关系
- **PWM信号**: 正确的PWM波形
- **UART信号**: 串行通信波形

### 6.2 FPGA测试验证

#### 6.2.1 LED测试
- 按下按键，对应的LED应点亮
- 松开按键，LED应熄灭

#### 6.2.2 PWM测试
- 使用示波器观察P16引脚
- 应能看到PWM波形

#### 6.2.3 UART测试
- 连接串口线到电脑
- 使用串口调试助手查看
- 应能收到"Hello RISC-V!"消息

## 7. 故障排查

### 7.1 Vivado相关问题

#### 7.1.1 Vivado命令未找到
**问题**: `vivado: command not found`
**解决**:
1. 检查Vivado是否正确安装
2. 确认Vivado在系统PATH中
3. 使用完整路径: `C:\Xilinx\Vivado\2020.2\bin\vivado.bat`

#### 7.1.2 工程创建失败
**问题**: `ERROR: [Common 17-39] 'create_project' failed due to earlier errors`
**解决**:
1. 检查器件型号是否正确: `xc7a35tfgg484-2`
2. 检查源文件路径是否正确
3. 检查是否有权限创建目录

#### 7.1.3 综合失败
**问题**: `ERROR: [Synth 8-439] module 'xxx' not found`
**解决**:
1. 检查所有源文件是否已添加
2. 检查模块名是否正确
3. 检查文件路径是否正确

### 7.2 仿真相关问题

#### 7.2.1 iverilog编译失败
**问题**: `error: Unable to open input file "xxx.v"`
**解决**:
1. 检查文件路径是否正确
2. 检查文件是否存在
3. 检查文件名是否正确

#### 7.2.2 仿真运行失败
**问题**: `error: vvp: unable to find module 'xxx'`
**解决**:
1. 检查编译时是否包含所有必要文件
2. 检查模块实例化是否正确
3. 检查端口连接是否正确

#### 7.2.3 波形文件无法打开
**问题**: `gtkwave: cannot open file tb_soc.vcd`
**解决**:
1. 确认仿真已成功运行
2. 检查.vcd文件是否存在
3. 使用绝对路径打开文件

### 7.3 FPGA烧录问题

#### 7.3.1 设备未检测到
**问题**: `ERROR: [Hardware 00-100] There is no current hw_target`
**解决**:
1. 检查开发板是否正确连接
2. 检查JTAG线是否连接正确
3. 检查驱动是否安装正确

#### 7.3.2 烧录失败
**问题**: `ERROR: [Labtools 27-3416] Failed to program device`
**解决**:
1. 检查比特流文件是否存在
2. 检查设备是否正确识别
3. 尝试重新连接设备

## 8. 日志文件说明

### 8.1 Vivado日志
- **位置**: `riscv_davinci/riscv_davinci.runs/synth_1/runme.log`
- **内容**: 综合、实现过程的详细信息
- **用途**: 查找ERROR和CRITICAL WARNING

### 8.2 仿真日志
- **位置**: 控制台输出
- **内容**: 测试执行过程和结果
- **用途**: 查找失败的测试项

### 8.3 波形文件
- **位置**: `tb_soc.vcd`
- **内容**: 仿真波形数据
- **用途**: 时序分析和功能验证

## 9. 性能指标

### 9.1 仿真性能
- **时钟频率**: 50MHz
- **仿真时间**: 约100000个时钟周期
- **内存占用**: 约500MB
- **运行时间**: 约1-2分钟

### 9.2 FPGA资源使用
- **LUTs**: 约5000个
- **FFs**: 约3000个
- **BRAM**: 2块
- **时钟资源**: 1个全局时钟

### 9.3 外设性能
- **GPIO延迟**: <20ns
- **PWM分辨率**: 10位
- **UART波特率**: 115200

## 10. 常见问题解答

### 10.1 Q: 为什么仿真没有输出？
A: 检查是否正确运行了`vvp tb_soc.out`命令，确保编译成功。

### 10.2 Q: GTKWave打不开波形文件怎么办？
A: 确保仿真已成功运行并生成了.vcd文件，使用绝对路径打开。

### 10.3 Q: Vivado工程创建失败怎么办？
A: 检查器件型号是否正确，确认所有源文件路径正确。

### 10.4 Q: FPGA烧录失败怎么办？
A: 检查开发板连接，确认JTAG驱动已正确安装。

### 10.5 Q: 如何修改测试程序？
A: 编辑`rtl/soc/demo_program.v`文件，然后重新运行仿真。

## 11. 下一步开发

测试完成后，您可以：

### 11.1 功能扩展
1. **添加新外设**: 在`rtl/peripheral/`目录下创建新的外设模块
2. **修改CPU**: 在`rtl/cpu/riscv_core.v`中添加新指令
3. **优化性能**: 调整流水线设计和数据前递逻辑

### 11.2 应用开发
1. **编写汇编程序**: 创建新的测试程序
2. **C语言支持**: 添加C编译器支持
3. **操作系统**: 移植轻量级RTOS

### 11.3 性能优化
1. **面积优化**: 减少LUT和FF使用
2. **速度优化**: 提高工作频率
3. **功耗优化**: 降低动态功耗

## 12. 联系支持

如有问题或建议，请联系：

- **邮箱**: support@example.com
- **文档**: docs/TESTING.md
- **源码**: README.md
- **问题反馈**: 提交GitHub Issue

## 13. 更新日志

- **2026-03-07**: 完善使用说明文档
- **2026-03-07**: 添加故障排查章节
- **2026-03-07**: 添加性能指标说明
- **2026-03-07**: 添加常见问题解答
