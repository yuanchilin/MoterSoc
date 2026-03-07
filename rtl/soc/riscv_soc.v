module riscv_soc (
    input wire clk,
    input wire rst_n,
    input wire [31:0] gpio_in,
    output wire [31:0] gpio_out,
    output wire pwm_out,
    input wire uart_rx,
    output wire uart_tx
);
    // ==================== CPU信号 ====================
    wire [31:0] inst_addr;
    wire [31:0] inst_data;
    wire [31:0] cpu_mem_addr;
    wire cpu_mem_we;
    wire cpu_mem_re;
    wire [31:0] cpu_mem_wdata;
    wire [31:0] cpu_mem_rdata;
    
    // ==================== Wishbone总线信号 ====================
    wire [31:0] wb_addr;
    wire wb_we;
    wire wb_re;
    wire [31:0] wb_wdata;
    wire [31:0] wb_rdata;
    
    // ==================== 外设选择信号 ====================
    wire gpio_sel, pwm_sel, uart_sel, rom_sel;
    
    localparam GPIO_BASE = 32'h10000000;
    localparam PWM_BASE  = 32'h10001000;
    localparam UART_BASE = 32'h10002000;
    localparam ROM_BASE  = 32'h00000000;
    
    // 地址解码 (流水线型)
    assign gpio_sel = (cpu_mem_addr[31:12] == GPIO_BASE[31:12]);
    assign pwm_sel  = (cpu_mem_addr[31:12] == PWM_BASE[31:12]);
    assign uart_sel = (cpu_mem_addr[31:12] == UART_BASE[31:12]);
    assign rom_sel  = (cpu_mem_addr[31:12] == ROM_BASE[31:12]);
    
    // ==================== 外设数据选择 ====================
    wire [31:0] gpio_rdata;
    wire [31:0] pwm_rdata;
    wire [31:0] uart_rdata;
    wire [31:0] rom_rdata;
    
    // 组合逻辑多路选择器
    wire [31:0] periph_rdata;
    assign periph_rdata = gpio_sel ? gpio_rdata :
                          pwm_sel  ? pwm_rdata :
                          uart_sel ? uart_rdata : 32'h0;
    
    // 最终数据选择 (带等待逻辑)
    reg [31:0] mem_rdata_reg;
    reg mem_ack;
    
    always @(*) begin
        if (rom_sel) begin
            mem_rdata_reg = rom_rdata;
            mem_ack = 1'b1;
        end else if (gpio_sel || pwm_sel || uart_sel) begin
            mem_rdata_reg = periph_rdata;
            mem_ack = 1'b1;
        end else begin
            mem_rdata_reg = 32'h0;
            mem_ack = 1'b0;
        end
    end
    
    assign cpu_mem_rdata = mem_rdata_reg;
    
    // ==================== CPU核心实例 ====================
    riscv_core u_riscv_core (
        .clk(clk),
        .rst_n(rst_n),
        .inst_addr(inst_addr),
        .inst_data(inst_data),
        .mem_addr(cpu_mem_addr),
        .mem_we(cpu_mem_we),
        .mem_wdata(cpu_mem_wdata),
        .mem_rdata(cpu_mem_rdata),
        .mem_re(cpu_mem_re)
    );
    
    // ==================== 指令ROM实例 ====================
    inst_rom u_inst_rom (
        .addr(inst_addr),
        .rdata(inst_data)
    );
    
    // ==================== GPIO外设实例 ====================
    gpio u_gpio (
        .clk(clk),
        .rst_n(rst_n),
        .addr(cpu_mem_addr),
        .wdata(cpu_mem_wdata),
        .we(cpu_mem_we),
        .re(cpu_mem_re),
        .rdata(gpio_rdata),
        .gpio_out(gpio_out),
        .gpio_in(gpio_in)
    );
    
    // ==================== PWM外设实例 ====================
    pwm u_pwm (
        .clk(clk),
        .rst_n(rst_n),
        .addr(cpu_mem_addr),
        .wdata(cpu_mem_wdata),
        .we(cpu_mem_we),
        .re(cpu_mem_re),
        .rdata(pwm_rdata),
        .pwm_out(pwm_out)
    );
    
    // ==================== UART外设实例 ====================
    uart u_uart (
        .clk(clk),
        .rst_n(rst_n),
        .addr(cpu_mem_addr),
        .wdata(cpu_mem_wdata),
        .we(cpu_mem_we),
        .re(cpu_mem_re),
        .rdata(uart_rdata),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx)
    );

endmodule