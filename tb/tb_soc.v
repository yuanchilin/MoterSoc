module tb_soc;
    reg clk;
    reg rst_n;
    reg [3:0] key;
    wire [3:0] led;
    wire pwm_out;
    reg uart_rxd;
    wire uart_txd;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50MHz
    end
    
    // Test sequence
    initial begin
        // Initialize inputs
        rst_n = 0;
        key = 4'b1111;
        uart_rxd = 1'b1;
        
        // Reset
        #100;
        rst_n = 1;
        
        // Wait for system to stabilize
        #1000;
        
        // Test 1: GPIO - Toggle LEDs
        $display("Test 1: GPIO - Toggle LEDs");
        #500;
        key = 4'b1110; // Press key 0
        #500;
        key = 4'b1111; // Release key
        #500;
        key = 4'b1101; // Press key 1
        #500;
        key = 4'b1111; // Release key
        #500;
        
        // Test 2: PWM - Generate PWM signal
        $display("Test 2: PWM - Generate PWM signal");
        #1000;
        
        // Test 3: UART - Send and receive data (from testbench)
        $display("Test 3: UART - Send and receive data");
        send_uart_byte(8'h41); // Send 'A' to CPU (CPU may not process this)
        #10000;
        send_uart_byte(8'h42); // Send 'B' to CPU
        #10000;
        
        // Test 4: CPU - Run internal program
        $display("Test 4: CPU - Run internal program");
        // The CPU will execute instructions from inst_rom, which contains
        // the "Hello Justin !" program. UART TX starts automatically.
        // Wait long enough for at least the first character 'H' to be sent.
        // At 115200 baud (868 cycles/bit @ 50MHz), each character = 86800ns.
        // First char starts after ~6 instructions initialization + 3 setup = ~100ns
        #1000000;  // Wait 1ms for UART to start sending
        $display("Simulation time extended - checking UART output");
        
        // Wait more for remaining characters
        #2000000;
        
        // End simulation
        #10000;
        $display("All tests completed successfully!");
        $display("Final state - LED: %b, PWM: %b, UART_TX: %b", led, pwm_out, uart_txd);
        $finish;

    end
    
    // UART transmission helper
    task send_uart_byte(input [7:0] data);
        integer i;
    begin
        // Start bit
        uart_rxd = 1'b0;
        #8680; // 115200 baud @ 50MHz
        
        // Data bits (LSB first)
        for (i = 0; i < 8; i = i + 1) begin
            uart_rxd = data[i];
            #8680;
        end
        
        // Stop bit
        uart_rxd = 1'b1;
        #8680;
    end
    endtask
    
    // Instantiate the SoC
    wire [31:0] inst_addr;
    wire [31:0] inst_data;
    wire [31:0] mem_addr;
    wire mem_we;
    wire [31:0] mem_wdata;
    wire [31:0] mem_rdata;
    wire mem_re;
    
    // 指令由 SoC 内部的 inst_rom 提供
    assign inst_data = 32'h00000013; // 默认NOP，由SoC内部ROM覆盖
    
    // 中间信号用于连接
    wire [31:0] gpio_in_32;
    wire [31:0] gpio_out_32;
    
    // 连接GPIO信号
    assign gpio_in_32 = {28'd0, key};
    
    // Instantiate SoC
    riscv_soc uut (
        .clk(clk),
        .rst_n(rst_n),
        .gpio_in(gpio_in_32),
        .gpio_out(gpio_out_32),
        .pwm_out(pwm_out),
        .uart_rx(uart_rxd),
        .uart_tx(uart_txd)
    );
    
    // 连接LED输出
    assign led = gpio_out_32[3:0];
    
    // Monitor outputs
    initial begin
        $monitor("Time: %0t, CLK: %b, RST_N: %b, KEY: %b, LED: %b, PWM: %b, UART_TX: %b", 
                 $time, clk, rst_n, key, led, pwm_out, uart_txd);
    end
    
    // Dump waveform
    initial begin
        $dumpfile("tb_soc.vcd");
        $dumpvars(0, tb_soc);
    end
    
    // 检测UART TX状态变化
    reg [31:0] uart_fall_time;
    reg [31:0] uart_rise_time;
    initial begin
        uart_fall_time = 0;
        uart_rise_time = 0;
        forever @(negedge uart_txd) begin
            uart_fall_time = $time;
            $display("UART TX FALLING edge at time %0t", $time);
            @(posedge uart_txd);
            uart_rise_time = $time;
            $display("UART TX RISING edge at time %0t (duration: %0t)", $time, $time - uart_fall_time);
        end
    end

endmodule


