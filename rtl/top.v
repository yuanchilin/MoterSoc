module top (
    input wire sys_clk,
    input wire sys_rst_n,
    input wire [3:0] key,
    output wire [3:0] led,
    output wire pwm_out,
    input wire uart_rxd,
    output wire uart_txd
);
    // ==================== 时钟和复位 ====================
    wire clk;
    wire rst_n;
    wire rst_n_sync;
    
    // 按键同步
    reg [3:0] key_sync0;
    reg [3:0] key_sync1;
    
    // 复位同步器 (两级同步)
    reg rst_sync0;
    reg rst_sync1;
    
    assign clk = sys_clk;
    
    // 异步复位同步化
    always @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            rst_sync0 <= 1'b0;
            rst_sync1 <= 1'b0;
        end else begin
            rst_sync0 <= 1'b1;
            rst_sync1 <= rst_sync0;
        end
    end
    
    assign rst_n = rst_sync1;
    
    // 按键消抖同步
    always @(posedge clk) begin
        key_sync0 <= key;
        key_sync1 <= key_sync0;
    end
    
    // ==================== GPIO信号 ====================
    wire [31:0] gpio_out;
    wire [31:0] gpio_in;
    
    assign gpio_in[3:0] = key_sync1;
    assign gpio_in[31:4] = 28'b0;
    assign led = gpio_out[3:0];
    
    // ==================== SoC实例化 ====================
    riscv_soc u_riscv_soc (
        .clk(clk),
        .rst_n(rst_n),
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .pwm_out(pwm_out),
        .uart_rx(uart_rxd),
        .uart_tx(uart_txd)
    );

endmodule