                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         module riscv_core (
    input wire clk,
    input wire rst_n,
    output wire [31:0] inst_addr,
    input wire [31:0] inst_data,
    output wire [31:0] mem_addr,
    output wire mem_we,
    output wire [31:0] mem_wdata,
    input wire [31:0] mem_rdata,
    output wire mem_re
);
    // ==================== 流水线寄存器 ====================
    // IF/ID 级寄存器
    reg [31:0] if_id_ir;
    reg [31:0] if_id_pc;
    
    // ID/EX 级寄存器
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_ir;
    reg [4:0]  id_ex_rd;
    reg [4:0]  id_ex_rs1;
    reg [4:0]  id_ex_rs2;
    reg [31:0] id_ex_imm;
    reg [31:0] id_ex_rs1_val;  // 寄存器文件中读取的 rs1 值
    reg [31:0] id_ex_rs2_val;  // 寄存器文件中读取的 rs2 值
    reg [6:0]  id_ex_opcode;
    reg [2:0]  id_ex_funct3;
    reg [6:0]  id_ex_funct7;
    reg        id_ex_reg_we;
    reg        id_ex_mem_re;
    reg        id_ex_mem_we;
    reg [1:0]  id_ex_wb_sel;  // 00: ALU, 01: MEM, 10: PC+4, 11: Imm
    
    // EX/MEM 级寄存器
    reg [31:0] ex_mem_pc;
    reg [31:0] ex_mem_alu_out;
    reg [31:0] ex_mem_mem_wdata;
    reg [4:0]  ex_mem_rd;
    reg        ex_mem_reg_we;
    reg        ex_mem_mem_re;
    reg        ex_mem_mem_we;
    reg [1:0]  ex_mem_wb_sel;
    
    // MEM/WB 级寄存器
    reg [31:0] mem_wb_pc;
    reg [31:0] mem_wb_alu_out;
    reg [31:0] mem_wb_mem_rdata;
    reg [4:0]  mem_wb_rd;
    reg        mem_wb_reg_we;
    reg [1:0]  mem_wb_wb_sel;
    
    // ==================== 寄存器文件 ====================
    reg [31:0] regs [0:31];
    
    // ==================== ID级信号声明 (移到前面) ====================
    // 这些信号在多个地方使用，需要先声明
    reg [31:0] id_imm;
    reg id_reg_we;
    reg id_mem_re;
    reg id_mem_we;
    reg [1:0] id_wb_sel;
    reg id_is_branch;
    reg id_is_jump;
    reg [31:0] id_ex_fwd_rs1;
    reg [31:0] id_ex_fwd_rs2;
    reg branch_taken;
    
    // ==================== 控制信号 ====================
    wire stall;
    wire flush;
    
    // ==================== PC 和取指 ====================
    reg [31:0] pc;
    reg [31:0] pc_next;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'h00000000;
        end else if (stall) begin
            pc <= pc;  // 停顿时保持PC
        end else begin
            pc <= pc_next;
        end
    end
    
    // ==================== 译码信号 ====================
    wire [6:0] id_opcode = if_id_ir[6:0];
    wire [4:0] id_rd = if_id_ir[11:7];
    wire [2:0] id_funct3 = if_id_ir[14:12];
    wire [4:0] id_rs1 = if_id_ir[19:15];
    wire [4:0] id_rs2 = if_id_ir[24:20];
    wire [6:0] id_funct7 = if_id_ir[31:25];
    
    // 立即数生成
    wire [31:0] imm_i  = {{20{if_id_ir[31]}}, if_id_ir[31:20]};
    wire [31:0] imm_s  = {{20{if_id_ir[31]}}, if_id_ir[31:25], if_id_ir[11:7]};
    wire [31:0] imm_b  = {{19{if_id_ir[31]}}, if_id_ir[31], if_id_ir[7], if_id_ir[30:25], if_id_ir[11:8], 1'b0};
    wire [31:0] imm_u  = {if_id_ir[31:12], 12'b0};
    wire [31:0] imm_j  = {{11{if_id_ir[31]}}, if_id_ir[31], if_id_ir[30:21], if_id_ir[20], if_id_ir[19:12], 1'b0};
    
    // 计算跳转目标地址
    wire [31:0] branch_target;
    wire [31:0] jal_target;
    wire [31:0] jalr_target;
    
    // Branch: PC + imm
    assign branch_target = if_id_pc + id_imm;
    // JAL: PC + imm  
    assign jal_target = if_id_pc + id_imm;
    // JALR: (rs1 + imm) & ~1
    assign jalr_target = {regs[id_rs1][31:1], 1'b0} + id_imm;
    
    // PC更新逻辑（支持分支和跳转）
    always @(*) begin
        if (id_is_jump) begin
            if (id_opcode == 7'b1100111) begin  // jalr
                pc_next = jalr_target;
            end else begin  // jal
                pc_next = jal_target;
            end
        end else if (id_is_branch && branch_taken) begin
            pc_next = branch_target;
        end else begin
            pc_next = pc + 32'd4;
        end
    end
    
    assign inst_addr = pc;
    
    // ==================== IF/ID 级 ====================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_ir <= 32'h00000000;
            if_id_pc <= 32'h00000000;
        end else if (flush) begin
            if_id_ir <= 32'h00000000;
            if_id_pc <= 32'h00000000;
        end else if (stall) begin
            if_id_ir <= if_id_ir;
            if_id_pc <= if_id_pc;
        end else begin
            if_id_ir <= inst_data;
            if_id_pc <= pc;
        end
    end
    
    // ==================== ID 级：译码 ====================
    // 立即数选择
    always @(*) begin
        case (id_opcode)
            7'b0010011: id_imm = imm_i;   // I-type立即数
            7'b0000011: id_imm = imm_i;   // Load
            7'b1100111: id_imm = imm_i;   // jalr
            7'b0100011: id_imm = imm_s;   // Store
            7'b1100011: id_imm = imm_b;   // Branch
            7'b1101111: id_imm = imm_j;   // jal
            7'b0110111: id_imm = imm_u;   // lui
            7'b0010111: id_imm = imm_u;   // auipc
            default: id_imm = 32'b0;
        endcase
    end
    
    // 控制信号生成
    always @(*) begin
        id_reg_we = 1'b0;
        id_mem_re = 1'b0;
        id_mem_we = 1'b0;
        id_wb_sel = 2'b00;
        id_is_branch = 1'b0;
        id_is_jump = 1'b0;
        
        case (id_opcode)
            7'b0110011: begin  // R-type
                id_reg_we = 1'b1;
                id_wb_sel = 2'b00;
            end
            7'b0010011: begin  // I-type 立即数
                id_reg_we = 1'b1;
                id_wb_sel = 2'b00;
            end
            7'b0000011: begin  // Load
                id_reg_we = 1'b1;
                id_mem_re = 1'b1;
                id_wb_sel = 2'b01;
            end
            7'b0100011: begin  // Store
                id_mem_we = 1'b1;
            end
            7'b1100011: begin  // Branch
                id_is_branch = 1'b1;
            end
            7'b1101111: begin  // jal
                id_reg_we = 1'b1;
                id_wb_sel = 2'b10;
                id_is_jump = 1'b1;
            end
            7'b1100111: begin  // jalr
                id_reg_we = 1'b1;
                id_wb_sel = 2'b10;
                id_is_jump = 1'b1;
            end
            7'b0110111: begin  // lui
                id_reg_we = 1'b1;
                id_wb_sel = 2'b11;
            end
            7'b0010111: begin  // auipc
                id_reg_we = 1'b1;
                id_wb_sel = 2'b11;
            end
        endcase
    end
    
    // 分支判断逻辑（使用前递值而非直接读寄存器文件，以正确处理流水线中的数据依赖）
    always @(*) begin
        branch_taken = 1'b0;
        if (id_is_branch) begin
            case (id_funct3)
                3'b000: branch_taken = (id_ex_fwd_rs1 == id_ex_fwd_rs2);   // beq
                3'b001: branch_taken = (id_ex_fwd_rs1 != id_ex_fwd_rs2);   // bne
                3'b100: branch_taken = ($signed(id_ex_fwd_rs1) < $signed(id_ex_fwd_rs2));  // blt
                3'b101: branch_taken = ($signed(id_ex_fwd_rs1) >= $signed(id_ex_fwd_rs2)); // bge
                3'b110: branch_taken = (id_ex_fwd_rs1 < id_ex_fwd_rs2);    // bltu
                3'b111: branch_taken = (id_ex_fwd_rs1 >= id_ex_fwd_rs2);   // bgeu
            endcase
        end
        if (id_is_jump) begin
            branch_taken = 1'b1;
        end
    end

    
    // ==================== ID/EX 级：计算ALU输出 ====================
    wire [31:0] id_ex_alu_out;

    // ==================== 前递多路选择器 (ID级) ====================
    // 优先级：EX阶段 > EX/MEM阶段 > MEM/WB阶段 > 寄存器文件
    always @(*) begin
        // RS1 前递
        if (id_ex_reg_we && (id_ex_rd != 5'h0) && (id_ex_rd == id_rs1)) begin
            // EX阶段（最年轻）— 最高优先级
            id_ex_fwd_rs1 = id_ex_alu_out;
        end else if (ex_mem_reg_we && (ex_mem_rd != 5'h0) && (ex_mem_rd == id_rs1)) begin
            // EX/MEM阶段
            if (ex_mem_mem_re) begin
                id_ex_fwd_rs1 = mem_rdata;  // 加载指令
            end else begin
                id_ex_fwd_rs1 = ex_mem_alu_out;
            end
        end else if (mem_wb_reg_we && (mem_wb_rd != 5'h0) && (mem_wb_rd == id_rs1)) begin
            // MEM/WB阶段（最老）— 最低优先级
            case (mem_wb_wb_sel)
                2'b00: id_ex_fwd_rs1 = mem_wb_alu_out;
                2'b01: id_ex_fwd_rs1 = mem_wb_mem_rdata;
                2'b10: id_ex_fwd_rs1 = mem_wb_pc + 32'd4;
                2'b11: id_ex_fwd_rs1 = mem_wb_alu_out;
            endcase
        end else begin
            // 无前递，直接从寄存器文件读取
            id_ex_fwd_rs1 = regs[id_rs1];
        end
        
        // RS2 前递
        if (id_ex_reg_we && (id_ex_rd != 5'h0) && (id_ex_rd == id_rs2)) begin
            // EX阶段（最年轻）— 最高优先级
            id_ex_fwd_rs2 = id_ex_alu_out;
        end else if (ex_mem_reg_we && (ex_mem_rd != 5'h0) && (ex_mem_rd == id_rs2)) begin
            // EX/MEM阶段
            if (ex_mem_mem_re) begin
                id_ex_fwd_rs2 = mem_rdata;  // 加载指令
            end else begin
                id_ex_fwd_rs2 = ex_mem_alu_out;
            end
        end else if (mem_wb_reg_we && (mem_wb_rd != 5'h0) && (mem_wb_rd == id_rs2)) begin
            // MEM/WB阶段（最老）— 最低优先级
            case (mem_wb_wb_sel)
                2'b00: id_ex_fwd_rs2 = mem_wb_alu_out;
                2'b01: id_ex_fwd_rs2 = mem_wb_mem_rdata;
                2'b10: id_ex_fwd_rs2 = mem_wb_pc + 32'd4;
                2'b11: id_ex_fwd_rs2 = mem_wb_alu_out;
            endcase
        end else begin
            // 无前递，直接从寄存器文件读取
            id_ex_fwd_rs2 = regs[id_rs2];
        end
    end


    
    // ==================== EX级前递信号（用于气泡后的正确转发） ====================
    // 当load-use冒险导致气泡插入ID/EX后，ALU得到错误的全0值
    // 需要从EX/MEM和MEM/WB阶段转发正确的数据到ALU输入端
    wire [31:0] ex_forward_rs1;
    wire [31:0] ex_forward_rs2;
    
    // RS1前递到ALU
    assign ex_forward_rs1 = 
        // 从EX/MEM转发（非加载指令）
        (ex_mem_reg_we && (ex_mem_rd != 5'h0) && (ex_mem_rd == id_ex_rs1) && !ex_mem_mem_re) ? ex_mem_alu_out :
        // 从EX/MEM转发（加载指令 - 数据在mem_rdata中）
        (ex_mem_reg_we && (ex_mem_rd != 5'h0) && (ex_mem_rd == id_ex_rs1) && ex_mem_mem_re) ? mem_rdata :
        // 从MEM/WB转发
        (mem_wb_reg_we && (mem_wb_rd != 5'h0) && (mem_wb_rd == id_ex_rs1)) ? (
            (mem_wb_wb_sel == 2'b01) ? mem_wb_mem_rdata :
            mem_wb_alu_out
        ) :
        id_ex_rs1_val;  // 默认使用锁存值
    
    // RS2前递到ALU
    assign ex_forward_rs2 = 
        // 从EX/MEM转发（非加载指令）
        (ex_mem_reg_we && (ex_mem_rd != 5'h0) && (ex_mem_rd == id_ex_rs2) && !ex_mem_mem_re) ? ex_mem_alu_out :
        // 从EX/MEM转发（加载指令）
        (ex_mem_reg_we && (ex_mem_rd != 5'h0) && (ex_mem_rd == id_ex_rs2) && ex_mem_mem_re) ? mem_rdata :
        // 从MEM/WB转发
        (mem_wb_reg_we && (mem_wb_rd != 5'h0) && (mem_wb_rd == id_ex_rs2)) ? (
            (mem_wb_wb_sel == 2'b01) ? mem_wb_mem_rdata :
            mem_wb_alu_out
        ) :
        id_ex_rs2_val;  // 默认使用锁存值
    
    
    // ALU组合逻辑 - 使用前递后的值（优先使用EX阶段前递，其次使用锁存值）
    assign id_ex_alu_out = 
        (id_ex_opcode == 7'b0110011) ? (
            ({id_ex_funct7[5], id_ex_funct3} == 4'b0000) ? (ex_forward_rs1 + ex_forward_rs2) :   // add
            ({id_ex_funct7[5], id_ex_funct3} == 4'b1000) ? (ex_forward_rs1 - ex_forward_rs2) :   // sub
            ({id_ex_funct7[5], id_ex_funct3} == 4'b0001) ? (ex_forward_rs1 << ex_forward_rs2[4:0]) :  // sll
            ({id_ex_funct7[5], id_ex_funct3} == 4'b0010) ? (($signed(ex_forward_rs1) < $signed(ex_forward_rs2)) ? 32'd1 : 32'd0) :  // slt
            ({id_ex_funct7[5], id_ex_funct3} == 4'b0011) ? ((ex_forward_rs1 < ex_forward_rs2) ? 32'd1 : 32'd0) :  // sltu
            ({id_ex_funct7[5], id_ex_funct3} == 4'b0100) ? (ex_forward_rs1 ^ ex_forward_rs2) :   // xor
            ({id_ex_funct7[5], id_ex_funct3} == 4'b0110) ? (ex_forward_rs1 | ex_forward_rs2) :   // or
            ({id_ex_funct7[5], id_ex_funct3} == 4'b0111) ? (ex_forward_rs1 & ex_forward_rs2) :   // and
            ({id_ex_funct7[5], id_ex_funct3} == 4'b0101) ? (ex_forward_rs1 >> ex_forward_rs2[4:0]) :  // srl
            ({id_ex_funct7[5], id_ex_funct3} == 4'b1101) ? ($signed(ex_forward_rs1) >>> ex_forward_rs2[4:0]) :  // sra
            32'h0
        ) : (id_ex_opcode == 7'b0010011) ? (
            (id_ex_funct3 == 3'b000) ? (ex_forward_rs1 + id_ex_imm) :    // addi
            (id_ex_funct3 == 3'b010) ? (($signed(ex_forward_rs1) < $signed(id_ex_imm)) ? 32'd1 : 32'd0) :  // slti
            (id_ex_funct3 == 3'b111) ? (ex_forward_rs1 & id_ex_imm) :     // andi
            (id_ex_funct3 == 3'b110) ? (ex_forward_rs1 | id_ex_imm) :     // ori
            (id_ex_funct3 == 3'b100) ? (ex_forward_rs1 ^ id_ex_imm) :    // xori
            (id_ex_funct3 == 3'b001) ? (ex_forward_rs1 << id_ex_imm[4:0]) :  // slli
            (id_ex_funct3 == 3'b101) ? (id_ex_imm[10] ? ($signed(ex_forward_rs1) >>> id_ex_imm[4:0]) : (ex_forward_rs1 >> id_ex_imm[4:0])) :  // srai/srli
            32'h0
        ) : (id_ex_opcode == 7'b0000011) ? (ex_forward_rs1 + id_ex_imm) :  // Load
        (id_ex_opcode == 7'b0100011) ? (ex_forward_rs1 + id_ex_imm) :  // Store
        (id_ex_opcode == 7'b1101111) ? (id_ex_pc + 32'd4) :           // jal
        (id_ex_opcode == 7'b1100111) ? (ex_forward_rs1 + id_ex_imm) :  // jalr
        (id_ex_opcode == 7'b0110111) ? (id_ex_imm) :                  // lui
        (id_ex_opcode == 7'b0010111) ? (id_ex_pc + id_ex_imm) :       // auipc
        32'h0;

    
    // ==================== EX/MEM 流水线寄存器 ====================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_pc <= 32'h0;
            ex_mem_alu_out <= 32'h0;
            ex_mem_mem_wdata <= 32'h0;
            ex_mem_rd <= 5'h0;
            ex_mem_reg_we <= 1'b0;
            ex_mem_mem_re <= 1'b0;
            ex_mem_mem_we <= 1'b0;
            ex_mem_wb_sel <= 2'b00;
        end else begin
            ex_mem_pc <= id_ex_pc;
            ex_mem_alu_out <= id_ex_alu_out;
            ex_mem_mem_wdata <= id_ex_rs2_val;  // 使用锁存的rs2值
            ex_mem_rd <= id_ex_rd;
            ex_mem_reg_we <= id_ex_reg_we;
            ex_mem_mem_re <= id_ex_mem_re;
            ex_mem_mem_we <= id_ex_mem_we;
            ex_mem_wb_sel <= id_ex_wb_sel;
        end
    end
    
    // ==================== MEM/WB 流水线寄存器 ====================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_pc <= 32'h0;
            mem_wb_alu_out <= 32'h0;
            mem_wb_mem_rdata <= 32'h0;
            mem_wb_rd <= 5'h0;
            mem_wb_reg_we <= 1'b0;
            mem_wb_wb_sel <= 2'b00;
        end else begin
            mem_wb_pc <= ex_mem_pc;
            mem_wb_alu_out <= ex_mem_alu_out;
            mem_wb_mem_rdata <= mem_rdata;
            mem_wb_rd <= ex_mem_rd;
            mem_wb_reg_we <= ex_mem_reg_we;
            mem_wb_wb_sel <= ex_mem_wb_sel;
        end
    end
    
    // ==================== ID/EX 流水线寄存器 ====================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_pc <= 32'h0;
            id_ex_ir <= 32'h0;
            id_ex_rd <= 5'h0;
            id_ex_rs1 <= 5'h0;
            id_ex_rs2 <= 5'h0;
            id_ex_imm <= 32'h0;
            id_ex_rs1_val <= 32'h0;
            id_ex_rs2_val <= 32'h0;
            id_ex_opcode <= 7'h0;
            id_ex_funct3 <= 3'h0;
            id_ex_funct7 <= 7'h0;
            id_ex_reg_we <= 1'b0;
            id_ex_mem_re <= 1'b0;
            id_ex_mem_we <= 1'b0;
            id_ex_wb_sel <= 2'b00;
        end else if (stall) begin
            // 停顿时插入气泡，不将IF/ID的依赖指令传递到EX
            id_ex_pc <= 32'h0;
            id_ex_ir <= 32'h0;
            id_ex_rd <= 5'h0;
            id_ex_rs1 <= 5'h0;
            id_ex_rs2 <= 5'h0;
            id_ex_imm <= 32'h0;
            id_ex_rs1_val <= 32'h0;
            id_ex_rs2_val <= 32'h0;
            id_ex_opcode <= 7'h0;
            id_ex_funct3 <= 3'h0;
            id_ex_funct7 <= 7'h0;
            id_ex_reg_we <= 1'b0;
            id_ex_mem_re <= 1'b0;
            id_ex_mem_we <= 1'b0;
            id_ex_wb_sel <= 2'b00;
        end else if (flush || branch_taken) begin
            id_ex_pc <= 32'h0;
            id_ex_ir <= 32'h0;
            id_ex_rd <= 5'h0;
            id_ex_rs1_val <= 32'h0;
            id_ex_rs2_val <= 32'h0;
            id_ex_reg_we <= 1'b0;
            id_ex_mem_re <= 1'b0;
            id_ex_mem_we <= 1'b0;
        end else begin
            id_ex_pc <= if_id_pc;
            id_ex_ir <= if_id_ir;
            id_ex_rd <= id_rd;
            id_ex_rs1 <= id_rs1;
            id_ex_rs2 <= id_rs2;
            id_ex_imm <= id_imm;
            id_ex_rs1_val <= id_ex_fwd_rs1;  // 锁存前递后的rs1值
            id_ex_rs2_val <= id_ex_fwd_rs2;  // 锁存前递后的rs2值
            id_ex_opcode <= id_opcode;
            id_ex_funct3 <= id_funct3;
            id_ex_funct7 <= id_funct7;
            id_ex_reg_we <= id_reg_we;
            id_ex_mem_re <= id_mem_re;
            id_ex_mem_we <= id_mem_we;
            id_ex_wb_sel <= id_wb_sel;
        end
    end
    
    // ==================== 流水线停顿控制 ====================
    // 检测Load-use数据冒险
    assign stall = id_ex_mem_re && (
        (id_ex_rd == id_rs1 && id_rs1 != 5'h0) ||
        (id_ex_rd == id_rs2 && id_rs2 != 5'h0)
    );
    
    // 分支冲刷信号
    assign flush = branch_taken;
    
    // ==================== 写回级 ====================
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'h0;
            end
        end else begin
            // x0 始终为 0（RISC-V 规范要求）
            regs[0] <= 32'h0;
            if (mem_wb_reg_we && mem_wb_rd != 5'h0) begin
                case (mem_wb_wb_sel)
                    2'b00: regs[mem_wb_rd] <= mem_wb_alu_out;
                    2'b01: regs[mem_wb_rd] <= mem_wb_mem_rdata;
                    2'b10: regs[mem_wb_rd] <= mem_wb_pc + 32'd4;
                    2'b11: regs[mem_wb_rd] <= mem_wb_alu_out;  // lui/auipc
                endcase
            end
        end
    end

    
    // ==================== 输出信号 ====================
    assign mem_addr = ex_mem_alu_out;
    assign mem_we = ex_mem_mem_we;
    assign mem_re = ex_mem_mem_re;
    assign mem_wdata = ex_mem_mem_wdata;

endmodule