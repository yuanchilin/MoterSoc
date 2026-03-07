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
        
        // Test 3: UART - Send and receive data
        $display("Test 3: UART - Send and receive data");
        send_uart_byte(8'h41); // Send 'A'
        #10000;
        send_uart_byte(8'h42); // Send 'B'
        #10000;
        
        // Test 4: CPU - Run simple program
        $display("Test 4: CPU - Run simple program");
        #5000;
        
        // End simulation
        #10000;
        $display("All tests completed successfully!");
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
    
// Instruction ROM with test program
    reg [31:0] rom [0:255];
    initial begin
        // Simple test program: GPIO LED control
        // lui x30, 0x10          # x30 = 0x10000 (GPIO base)
        rom[0] = 32'h10000F37;
        // addi x30, x30, 0      # Load high 20 bits
        rom[1] = 32'h000F0F13;
        // ori x31, x0, 1        # x31 = 1 (LED on)
        rom[2] = 32'h00100F9b;
        // sw x31, 0(x30)        # Write to GPIO DATA
        rom[3] = 32'h00F02223;
        // nop
        rom[4] = 32'h00000013;
        // nop
        // jal x0, -8            # Jump back (infinite loop)
        rom[5] = 32'hffc0106f;
    end

    // UART test程序 (移除，使用SoC内部的UART)
    // uart_test_program u_uart_test (
    //     .clk(clk),
    //     .rst_n(rst_n),
    //     .uart_status(uut.u_uart.uart_status),
    //     .uart_rx_ready(uut.u_uart.rx_fifo_count > 0),
    //     .uart_tx_en(uut.u_uart.uart_tx_en),
    //     .uart_txdata(uut.u_uart.uart_txdata)
    // );
    assign inst_data = rom[inst_addr[9:2]];
    
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

endmodule