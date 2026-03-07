module gpio (
    input wire clk,
    input wire rst_n,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    input wire we,
    input wire re,
    output reg [31:0] rdata,
    output wire [31:0] gpio_out,
    input wire [31:0] gpio_in
);
    // ==================== 寄存器定义 ====================
    reg [31:0] gpio_data;      // 数据寄存器
    reg [31:0] gpio_dir;       // 方向寄存器 (1=输出, 0=输入)
    reg [31:0] gpio_ie;        // 中断使能寄存器
    reg [31:0] gpio_is;        // 中断选择 (0=电平, 1=边沿)
    reg [31:0] gpio_ibe;       // 边沿中断使能 (1=双边沿, 0=单边沿)
    reg [31:0] gpio_ic;        // 中断清除寄存器
    reg [31:0] gpio_rising;    // 上升沿检测
    reg [31:0] gpio_falling;   // 下降沿检测
    reg [31:0] gpio_raw;      // 原始中断状态
    
    // ==================== 边沿检测寄存器 ====================
    reg [31:0] gpio_in_prev;
    reg [31:0] gpio_raw_next;
    
    // ==================== 地址定义 ====================
    localparam ADDR_DATA   = 4'h0;
    localparam ADDR_DIR    = 4'h1;
    localparam ADDR_IE     = 4'h2;
    localparam ADDR_IS     = 4'h3;
    localparam ADDR_IBE    = 4'h4;
    localparam ADDR_IC     = 4'h5;
    localparam ADDR_RISING = 4'h6;
    localparam ADDR_FALLING = 4'h7;
    localparam ADDR_RAW    = 4'h8;
    
    // ==================== 读端口 ====================
    always @(*) begin
        if (re) begin
            case (addr[7:2])
                ADDR_DATA:    rdata = gpio_data;
                ADDR_DIR:     rdata = gpio_dir;
                ADDR_IE:     rdata = gpio_ie;
                ADDR_IS:     rdata = gpio_is;
                ADDR_IBE:    rdata = gpio_ibe;
                ADDR_IC:     rdata = gpio_ic;
                ADDR_RISING: rdata = gpio_rising;
                ADDR_FALLING: rdata = gpio_falling;
                ADDR_RAW:    rdata = gpio_raw;
                default:      rdata = 32'h0;
            endcase
        end else
            rdata = 32'h0;
    end
    
    // ==================== GPIO输出 ====================
    assign gpio_out = gpio_data & gpio_dir;
    
    // ==================== 主逻辑 ====================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_data <= 32'h0;
            gpio_dir <= 32'h0;
            gpio_ie <= 32'h0;
            gpio_is <= 32'h0;
            gpio_ibe <= 32'h0;
            gpio_ic <= 32'h0;
            gpio_rising <= 32'h0;
            gpio_falling <= 32'h0;
            gpio_raw <= 32'h0;
            gpio_in_prev <= 32'h0;
            gpio_raw_next <= 32'h0;
        end else begin
            // 边沿检测
            gpio_in_prev <= gpio_in;
            
            // 上升沿检测
            gpio_rising <= (~gpio_in_prev) & gpio_in;
            
            // 下降沿检测
            gpio_falling <= gpio_in_prev & (~gpio_in);
            
            // 更新原始中断状态
            gpio_raw_next = 32'h0;
            
            // 电平触发中断
            if (gpio_is[0] == 1'b0) begin  // 电平触发
                gpio_raw_next = gpio_raw | (gpio_in & gpio_ie & gpio_dir);
            end
            
            // 边沿触发中断
            if (gpio_is[0] == 1'b1) begin  // 边沿触发
                if (gpio_ibe[0] == 1'b1) begin  // 双边沿
                    gpio_raw_next = gpio_raw | (gpio_rising | gpio_falling) & gpio_ie & gpio_dir;
                end else begin  // 单边沿(上升沿)
                    gpio_raw_next = gpio_raw | gpio_rising & gpio_ie & gpio_dir;
                end
            end
            
            // 写寄存器
            if (we) begin
                case (addr[7:2])
                    ADDR_DATA:    gpio_data <= wdata;
                    ADDR_DIR:     gpio_dir <= wdata;
                    ADDR_IE:     gpio_ie <= wdata;
                    ADDR_IS:     gpio_is <= wdata;
                    ADDR_IBE:    gpio_ibe <= wdata;
                    ADDR_IC:     gpio_raw <= 32'h0;  // 写1清除中断
                endcase
            end else begin
                gpio_raw <= gpio_raw_next;
            end
        end
    end

endmodule