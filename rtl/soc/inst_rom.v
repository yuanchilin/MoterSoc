module inst_rom (
    input wire [31:0] addr,
    output reg [31:0] rdata
);
    reg [31:0] rom [0:255];
    
    initial begin
        // 简单测试: LED闪烁
        // lui x30, 0x10          # x30 = 0x10000
        // x30 = 0x10000 (GPIO基地址)
        rom[0] = 32'h10000F37;
        // addi x30, x30, 0      # 加载高20位
        rom[1] = 32'h000F0F13;
        // ori x31, x0, 1        # x31 = 1 (LED开)
        rom[2] = 32'h00100F9b;
        // sw x31, 0(x30)        # 写GPIO DATA
        rom[3] = 32'h00F02223;
        // nop
        rom[4] = 32'h00000013;
        // nop
        rom[5] = 32'h00000013;
        // jal x0, -8            # 跳回循环
        rom[6] = 32'hffc0106f;
    end
    
    wire [7:0] rom_addr;
    assign rom_addr = addr[9:2];
    
    always @(*) begin
        rdata = rom[rom_addr];
    end

endmodule
