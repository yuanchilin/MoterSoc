module inst_rom (
    input wire [31:0] addr,
    output reg [31:0] rdata
);
    reg [31:0] rom [0:255];
    
    initial begin
        // 测试程序: R-type指令序列
        // add x1, x0, x0 (x1 = 0 + 0 = 0)
        rom[0] = 32'h00000033;
        // addi x2, x0, 5 (x2 = 0 + 5 = 5)
        rom[1] = 32'h00500093;
        // add x3, x1, x2 (x3 = 0 + 5 = 5)
        rom[2] = 32'h00218133;
        // sub x4, x3, x2 (x4 = 5 - 5 = 0)
        rom[3] = 32'h4021e233;
        // and x5, x3, x2 (x5 = 5 & 5 = 5)
        rom[4] = 32'h0021f2b3;
        // or x6, x4, x5 (x6 = 0 | 5 = 5)
        rom[5] = 32'h00526333;
        // xor x7, x6, x5 (x7 = 5 ^ 5 = 0)
        rom[6] = 32'h0052d3b3;
        // sll x8, x2, x4 (x8 = 5 << 0 = 5)
        rom[7] = 32'h0002e413;
        // srl x9, x3, x4 (x9 = 5 >> 0 = 5)
        rom[8] = 32'h0002e493;
        // sra x10, x3, x4 (x10 = 5 >>> 0 = 5)
        rom[9] = 32'h0002e513;
        // slt x11, x4, x5 (x11 = (0 < 5) ? 1 : 0 = 1)
        rom[10] = 32'h0052e333;
        // sltu x12, x4, x5 (x12 = (0 < 5) ? 1 : 0 = 1)
        rom[11] = 32'h0052e3b3;
        // 无限循环
        rom[12] = 32'h0000006f;
    end
    
    wire [7:0] rom_addr;
    assign rom_addr = addr[9:2];
    
    always @(*) begin
        rdata = rom[rom_addr];
    end

endmodule
