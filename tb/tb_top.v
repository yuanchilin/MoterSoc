module tb_top;
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
        
        // Test sequence
        #1000;
        
        // Test GPIO - press key 0
        key = 4'b1110;
        #1000;
        
        // Test GPIO - press key 1
        key = 4'b1101;
        #1000;
        
        // Test PWM
        // This would require writing to PWM registers via CPU
        // For now, just observe the output
        
        // Test UART
        // Send a character 'A' (0x41)
        send_uart_byte(8'h41);
        #10000;
        
        // End simulation
        #10000;
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
    
    // Instantiate the design under test - direct RISC-V core for simple testing
    wire [31:0] inst_addr;
    wire [31:0] inst_data;
    wire [31:0] mem_addr;
    wire mem_we;
    wire [31:0] mem_wdata;
    wire [31:0] mem_rdata;
    wire mem_re;
    
    // Simple instruction ROM
    reg [31:0] rom [0:15];
    initial begin
        rom[0] = 32'b00000000010100000000000010010011; // ADDI x1, x0, 5
        rom[1] = 32'b00000000011000000000000100010011; // ADDI x1, x0, 6
        rom[2] = 32'b00000000000000010000001010010011; // ADDI x2, x1, 1
        rom[3] = 32'b00000000001000001000000010110011; // ADD x1, x1, x2
        rom[4] = 32'h00000093;  // ADDI x1, x0, 0
        rom[5] = 32'h00100193;  // ADDI x3, x0, 1
        rom[6] = 32'h002001b3;  // ADD x3, x0, x2
        rom[7] = 32'h00000000;  // NOP
        rom[8] = 32'h00000000;  // NOP
        rom[9] = 32'h00000000;  // NOP
        rom[10] = 32'h00000000; // NOP
        rom[11] = 32'h00000000; // NOP
        rom[12] = 32'h00000000; // NOP
        rom[13] = 32'h00000000; // NOP
        rom[14] = 32'h00000000; // NOP
        rom[15] = 32'h00000000; // NOP
    end
    
    assign inst_data = rom[inst_addr[6:2]];
    
    // Instantiate RISC-V core directly
    riscv_core uut (
        .clk(clk),
        .rst_n(rst_n),
        .inst_addr(inst_addr),
        .inst_data(inst_data),
        .mem_addr(mem_addr),
        .mem_we(mem_we),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata),
        .mem_re(mem_re)
    );
    
    // Simple GPIO simulation
    assign led = mem_addr[5:2];
    assign pwm_out = 0;
    assign uart_txd = 1;
    
    // Monitor outputs
    initial begin
        $monitor("Time: %0t, CLK: %b, RST_N: %b, KEY: %b, LED: %b, PWM: %b, UART_TX: %b", 
                 $time, clk, rst_n, key, led, pwm_out, uart_txd);
    end
    
    // Dump waveform
    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);
    end

endmodule