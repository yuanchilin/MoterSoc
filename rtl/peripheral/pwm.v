module pwm (
    input wire clk,
    input wire rst_n,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    input wire we,
    input wire re,
    output reg [31:0] rdata,
    output reg pwm_out
);
    reg [31:0] pwm_period;
    reg [31:0] pwm_duty;
    reg [31:0] pwm_ctrl;
    reg [31:0] pwm_cnt;
    
    localparam ADDR_CTRL  = 4'h0;
    localparam ADDR_PERIOD = 4'h4;
    localparam ADDR_DUTY  = 4'h8;
    localparam ADDR_CNT   = 4'hC;
    
    wire pwm_enable;
    wire pwm_mode;
    
    assign pwm_enable = pwm_ctrl[0];
    assign pwm_mode = pwm_ctrl[1];
    
    always @(*) begin
        if (re) begin
            case (addr[7:2])
                4'h0: rdata = pwm_ctrl;
                4'h1: rdata = pwm_period;
                4'h2: rdata = pwm_duty;
                4'h3: rdata = pwm_cnt;
                default: rdata = 32'h0;
            endcase
        end else
            rdata = 32'h0;
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_ctrl <= 32'h0;
            pwm_period <= 32'd1000;
            pwm_duty <= 32'd500;
            pwm_cnt <= 32'd0;
            pwm_out <= 1'b0;
        end else begin
            if (we) begin
                case (addr[7:2])
                    4'h0: pwm_ctrl <= wdata;
                    4'h1: pwm_period <= wdata;
                    4'h2: pwm_duty <= wdata;
                endcase
            end
            
            if (pwm_enable) begin
                pwm_cnt <= pwm_cnt + 1;
                if (pwm_cnt >= pwm_period - 1) begin
                    pwm_cnt <= 32'd0;
                end
                
                if (pwm_mode == 1'b0) begin
                    if (pwm_cnt < pwm_duty)
                        pwm_out <= 1'b1;
                    else
                        pwm_out <= 1'b0;
                end else begin
                    if (pwm_cnt < (pwm_period - pwm_duty))
                        pwm_out <= 1'b0;
                    else
                        pwm_out <= 1'b1;
                end
            end else begin
                pwm_out <= pwm_ctrl[8];
                pwm_cnt <= 32'd0;
            end
        end
    end

endmodule
