// 综合演示程序
// 功能: 展示所有外设的综合功能

module demo_program (
    input wire clk,
    input wire rst_n,
    input wire [31:0] uart_status,
    input wire uart_rx_ready,
    input wire [31:0] uart_rx_data,  // 添加UART接收数据输入
    output reg uart_tx_en,
    output reg [8:0] uart_txdata,
    input wire [3:0] gpio_in,
    output reg [3:0] gpio_out,
    output reg pwm_out
);
    // 状态机
    reg [3:0] state;
    reg [7:0] counter;
    reg [7:0] led_pattern;
    reg [15:0] pwm_counter;
    reg [15:0] pwm_period;
    reg [15:0] pwm_duty;
    
    // 状态定义
    localparam IDLE = 4'd0;
    localparam INIT = 4'd1;
    localparam LED_PATTERN = 4'd2;
    localparam PWM_TEST = 4'd3;
    localparam UART_ECHO = 4'd4;
    localparam DEMO_COMPLETE = 4'd5;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 8'd0;
            led_pattern <= 8'd0;
            pwm_counter <= 16'd0;
            pwm_period <= 16'd1000;
            pwm_duty <= 16'd500;
            uart_tx_en <= 1'b0;
            uart_txdata <= 9'd0;
            gpio_out <= 4'b0000;
            pwm_out <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    state <= INIT;
                    counter <= 8'd0;
                end
                
                INIT: begin
                    // 初始化LED模式
                    led_pattern <= 8'b00000001;
                    state <= LED_PATTERN;
                end
                
                LED_PATTERN: begin
                    // 流水灯效果
                    gpio_out <= led_pattern[3:0];
                    led_pattern <= {led_pattern[7:0], led_pattern[0]};
                    
                    // 每500次时钟变化一次
                    if (counter < 8'd250) begin
                        counter <= counter + 1;
                    end else begin
                        counter <= 8'd0;
                        state <= PWM_TEST;
                    end
                end
                
                PWM_TEST: begin
                    // PWM信号测试
                    pwm_counter <= pwm_counter + 1;
                    
                    if (pwm_counter < pwm_duty) begin
                        pwm_out <= 1'b1;
                    end else begin
                        pwm_out <= 1'b0;
                    end
                    
                    if (pwm_counter >= pwm_period - 1) begin
                        pwm_counter <= 16'd0;
                    end
                    
                    // 每1000次时钟变化一次
                    if (counter < 8'd250) begin
                        counter <= counter + 1;
                    end else begin
                        counter <= 8'd0;
                        state <= UART_ECHO;
                    end
                end
                
                UART_ECHO: begin
                    // UART回显测试
                    if (uart_rx_ready && uart_status[1]) begin  // 使用RX ready标志
                        uart_tx_en <= 1'b1;
                        uart_txdata <= {1'b0, uart_rx_data[7:0]}; // 发送接收到的数据
                        state <= DEMO_COMPLETE;
                    end
                end
                
                DEMO_COMPLETE: begin
                    uart_tx_en <= 1'b0;
                    // 保持最后状态
                end
            endcase
        end
    end

endmodule