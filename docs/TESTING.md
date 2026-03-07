# RISC-V SoC 测试指南

## 1. 新功能概述

本项目已增强测试功能，包括：

- **改进的仿真文件** (`tb_soc.v`) - 测试所有外设功能
- **UART通信测试程序** (`rtl/soc/uart_test_program.v`) - 自动发送"Hello RISC-V!"消息
- **构建脚本** (`build_and_test.bat`) - 一键构建和测试

## 2. 测试功能

### 2.1 GPIO测试
- 测试按键输入和LED输出
- 验证GPIO寄存器的读写功能

### 2.2 PWM测试
- 观察PWM信号输出
- 验证PWM占空比和频率控制

### 2.3 UART测试
- 自动发送"Hello RISC-V!"字符串
- 测试UART发送和接收功能
- 波特率: 115200

### 2.4 CPU测试
- 运行简单的GPIO控制程序
- 验证RISC-V指令集执行

### 2.5 综合演示
- 展示所有外设的综合功能
- 流水灯效果
- PWM信号测试
- UART回显测试

## 3. 使用方法

### 3.1 运行完整测试
```bash
build_and_test.bat
```

### 3.2 手动测试步骤
1. **创建工程**
   ```bash
   vivado -mode batch -source create_project.tcl
   ```

2. **运行仿真**
   ```bash
   iverilog -o tb_soc.out \
       rtl/cpu/riscv_core.v \
       rtl/peripheral/gpio.v \
       rtl/peripheral/pwm.v \
       rtl/peripheral/uart.v \
       rtl/soc/riscv_soc.v \
       rtl/soc/inst_rom.v \
       rtl/soc/uart_test_program.v \
       rtl/top.v \
       tb_soc.v
   vvp tb_soc.out
   ```

3. **查看波形**
   - 使用GTKWave打开 `tb_soc.vcd`
   - 观察所有信号的时序行为

## 4. 测试输出

运行测试后，您将看到：

- 控制台输出测试进度
- LED状态变化
- PWM信号波形
- UART发送的"Hello RISC-V!"消息
- 详细的时序波形

## 5. 验证要点

测试完成后，请验证以下内容：

- ✅ GPIO按键能正确控制LED
- ✅ PWM信号输出正常
- ✅ UART能正确发送消息
- ✅ CPU能执行程序
- ✅ 所有外设寄存器读写正常

## 6. 故障排查

如果测试失败，请检查：

1. **时钟频率** - 确保为50MHz
2. **复位信号** - 检查复位是否正确
3. **UART连接** - 验证串口线连接
4. **波特率设置** - 确认为115200
5. **引脚约束** - 检查xdc文件

## 7. 性能指标

- **时钟频率**: 50MHz
- **UART波特率**: 115200
- **GPIO延迟**: 约20ns
- **PWM分辨率**: 10位