module tb_uart_direct;
    reg clk;
    reg rst_n;
    reg [31:0] addr;
    reg [31:0] wdata;
    reg we;
    reg re;
    wire [31:0] rdata;
    reg uart_rx;
    wire uart_tx;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50MHz
    end
    
    uart u_uart (
        .clk(clk),
        .rst_n(rst_n),
        .addr(addr),
        .wdata(wdata),
        .we(we),
        .re(re),
        .rdata(rdata),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx)
    );
    
    task wait_tx_ready;
    begin
        addr = 32'h4;  // STATUS
        re = 1;
        #20;
        while (!rdata[0]) begin
            #20;
            re = 1;
            #20;
        end
        re = 0;
    end
    endtask
    
    task write_txdata(input [7:0] data);
    begin
        wait_tx_ready;
        addr = 32'h8;  // TXDATA
        wdata = {24'h0, data};
        we = 1;
        #20;
        we = 0;
    end
    endtask
    
    initial begin
        // Initialize
        rst_n = 0;
        addr = 32'h0;
        wdata = 32'h0;
        we = 0;
        re = 0;
        uart_rx = 1;
        
        #100;
        rst_n = 1;
        #40;
        
        // Enable UART: write CTRL = 3 (enable, tx_enable)
        $display("Writing UART_CTRL = 3");
        addr = 32'h0;  // offset 0
        wdata = 32'h00000003;
        we = 1;
        #20;
        we = 0;
        
        // Send 'H' (0x48)
        $display("Writing 'H' (0x48) to TXDATA");
        write_txdata(8'h48);
        
        // Send 'e' (0x65)
        $display("Writing 'e' (0x65) to TXDATA");
        write_txdata(8'h65);
        
        // Wait for both bytes to be sent (each byte = 10 bits at 115200 = ~868us)
        $display("Waiting for transmission...");
        #2000000;  // 2ms to ensure both bytes complete
        // Now test at corrected baud rate (div=434): each byte = 10*434*20ns = 86.8us
        // With corrected timing, we'd need ~200us for both bytes, 2ms is more than enough
        // (for div=868 each byte is 10*868*20ns = 173.6us, so 2ms was also enough)
        
        // Check status
        $display("Reading UART_STATUS");
        addr = 32'h4;
        re = 1;
        #20;
        $display("UART_STATUS = %h (TX ready=%b, RX ready=%b)", 
                 rdata, rdata[0], rdata[1]);
        re = 0;
        
        #500;
        
        $display("Simulation complete. Final uart_tx = %b", uart_tx);
        $finish;
    end
    
    initial begin
        $monitor("Time: %0t, CLK: %b, uart_tx: %b, we: %b, addr: %h, wdata: %h", 
                 $time, clk, uart_tx, we, addr, wdata);
    end
    
    initial begin
        $dumpfile("tb_uart_direct.vcd");
        $dumpvars(0, tb_uart_direct);
    end
endmodule
