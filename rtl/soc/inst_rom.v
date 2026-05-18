module inst_rom (
    input wire [31:0] addr,
    output reg [31:0] rdata
);
    
    // 使用 case 语句实现组合逻辑 ROM，确保 Vivado 综合时能正确保留所有初始值
    always @(*) begin
        case (addr[9:2])
            // ===== 初始化 (6条指令) =====
            // 0: lui x29, 0x10002    # x29 = 0x10002000 (UART基地址)
            8'd0: rdata = 32'h10002EB7;
            // 1: lui x30, 0x10000    # x30 = 0x10000000 (GPIO基地址)
            8'd1: rdata = 32'h10000F37;
            // 2: addi x31, x0, 3     # x31 = 3 (uart_enable=1, tx_enable=1)
            8'd2: rdata = 32'h00300F93;
            // 3: sw x31, 0(x29)      # UART_CTRL = 3
            8'd3: rdata = 32'h01FEA023;
            // 4: addi x31, x0, 0xF   # x31 = 0xF (GPIO低4位输出)
            8'd4: rdata = 32'h00F00F93;
            // 5: sw x31, 4(x30)      # GPIO_DIR = 0xF
            8'd5: rdata = 32'h01FF2223;
            
            // ===== 发送 'H' (3条指令 + 3条等待循环) =====
            8'd6: rdata = 32'h04800F93;  // addi x31, x0, 0x48  # 'H'
            8'd7: rdata = 32'h01FEA423;  // sw x31, 8(x29)      # write UART_TXDATA


            8'd8: rdata = 32'h004EAF83;  // lw x31, 4(x29)      # read UART_STATUS
            8'd9: rdata = 32'h001FFF93;  // andi x31, x31, 1    # check TX ready bit
            8'd10: rdata = 32'hFE0F8AE3; // beq x31, x0, -12    # loop if TX not ready
            
            // ===== 发送 'e' =====
            8'd11: rdata = 32'h06500F93;
            8'd12: rdata = 32'h01FEA423;
            8'd13: rdata = 32'h004EAF83;
            8'd14: rdata = 32'h001FFF93;
            8'd15: rdata = 32'hFE0F8AE3;
            
            // ===== 发送 'l' =====
            8'd16: rdata = 32'h06C00F93;
            8'd17: rdata = 32'h01FEA423;
            8'd18: rdata = 32'h004EAF83;
            8'd19: rdata = 32'h001FFF93;
            8'd20: rdata = 32'hFE0F8AE3;
            
            // ===== 发送 'l' =====
            8'd21: rdata = 32'h06C00F93;
            8'd22: rdata = 32'h01FEA423;
            8'd23: rdata = 32'h004EAF83;
            8'd24: rdata = 32'h001FFF93;
            8'd25: rdata = 32'hFE0F8AE3;
            
            // ===== 发送 'o' =====
            8'd26: rdata = 32'h06F00F93;
            8'd27: rdata = 32'h01FEA423;
            8'd28: rdata = 32'h004EAF83;
            8'd29: rdata = 32'h001FFF93;
            8'd30: rdata = 32'hFE0F8AE3;
            
            // ===== 发送 ' ' =====
            8'd31: rdata = 32'h02000F93;
            8'd32: rdata = 32'h01FEA423;
            8'd33: rdata = 32'h004EAF83;
            8'd34: rdata = 32'h001FFF93;
            8'd35: rdata = 32'hFE0F8AE3;
            
            // ===== 发送 'J' =====
            8'd36: rdata = 32'h04A00F93;
            8'd37: rdata = 32'h01FEA423;
            8'd38: rdata = 32'h004EAF83;
            8'd39: rdata = 32'h001FFF93;
            8'd40: rdata = 32'hFE0F8AE3;
            
            // ===== 发送 'u' =====
            8'd41: rdata = 32'h07500F93;
            8'd42: rdata = 32'h01FEA423;
            8'd43: rdata = 32'h004EAF83;
            8'd44: rdata = 32'h001FFF93;
            8'd45: rdata = 32'hFE0F8AE3;
            
            // ===== 发送 's' =====
            8'd46: rdata = 32'h07300F93;
            8'd47: rdata = 32'h01FEA423;
            8'd48: rdata = 32'h004EAF83;
            8'd49: rdata = 32'h001FFF93;
            8'd50: rdata = 32'hFE0F8AE3;
            
            // ===== 发送 't' =====
            8'd51: rdata = 32'h07400F93;
            8'd52: rdata = 32'h01FEA423;
            8'd53: rdata = 32'h004EAF83;
            8'd54: rdata = 32'h001FFF93;
            8'd55: rdata = 32'hFE0F8AE3;
            
            // ===== 发送 'i' =====
            8'd56: rdata = 32'h06900F93;
            8'd57: rdata = 32'h01FEA423;
            8'd58: rdata = 32'h004EAF83;
            8'd59: rdata = 32'h001FFF93;
            8'd60: rdata = 32'hFE0F8AE3;
            
            // ===== 发送 'n' =====
            8'd61: rdata = 32'h06E00F93;
            8'd62: rdata = 32'h01FEA423;
            8'd63: rdata = 32'h004EAF83;
            8'd64: rdata = 32'h001FFF93;
            8'd65: rdata = 32'hFE0F8AE3;
            
            // ===== 发送 '!' =====
            8'd66: rdata = 32'h02100F93;
            8'd67: rdata = 32'h01FEA423;
            8'd68: rdata = 32'h004EAF83;
            8'd69: rdata = 32'h001FFF93;
            8'd70: rdata = 32'hFE0F8AE3;
            
            // ===== 发送 '\n' =====
            8'd71: rdata = 32'h00A00F93;
            8'd72: rdata = 32'h01FEA423;
            8'd73: rdata = 32'h004EAF83;
            8'd74: rdata = 32'h001FFF93;
            8'd75: rdata = 32'hFE0F8AE3;
            
            // ===== 循环 =====
            // 76: jal x0, -300       # 跳回rom[1]重新开始（byte addr 304→4）
            8'd76: rdata = 32'hED5FF06F;
            
            // 其他地址填充nop
            default: rdata = 32'h00000013;  // NOP (ADDI x0, x0, 0)
        endcase
    end

endmodule
