module uart (
    input wire clk,
    input wire rst_n,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    input wire we,
    input wire re,
    output reg [31:0] rdata,
    input wire uart_rx,
    output reg uart_tx
);
    // ==================== 寄存器定义 ====================
    reg [31:0] uart_ctrl;
    reg [31:0] uart_status;
    reg [31:0] uart_txdata;
    reg [31:0] uart_rxdata;
    reg [31:0] uart_bauddiv;
    reg [31:0] uart_fifo_ctrl;
    
    // ==================== TX FIFO ====================
    localparam TX_FIFO_DEPTH = 16;
    reg [7:0] tx_fifo [0:TX_FIFO_DEPTH-1];
    reg [4:0] tx_fifo_wr_ptr;
    reg [4:0] tx_fifo_rd_ptr;
    reg [4:0] tx_fifo_count;
    wire tx_fifo_full;
    wire tx_fifo_empty;
    
    assign tx_fifo_full = (tx_fifo_count == TX_FIFO_DEPTH);
    assign tx_fifo_empty = (tx_fifo_count == 0);
    
    // ==================== RX FIFO ====================
    localparam RX_FIFO_DEPTH = 16;
    reg [7:0] rx_fifo [0:RX_FIFO_DEPTH-1];
    reg [4:0] rx_fifo_wr_ptr;
    reg [4:0] rx_fifo_rd_ptr;
    reg [4:0] rx_fifo_count;
    wire rx_fifo_full;
    wire rx_fifo_empty;
    
    assign rx_fifo_full = (rx_fifo_count == RX_FIFO_DEPTH);
    assign rx_fifo_empty = (rx_fifo_count == 0);
    
    // ==================== 状态机 ====================
    localparam TX_IDLE       = 4'd0;
    localparam TX_START_BIT  = 4'd1;
    localparam TX_DATA_BITS  = 4'd2;
    localparam TX_STOP_BIT   = 4'd3;
    localparam TX_COMPLETE   = 4'd4;
    
    localparam RX_IDLE       = 4'd0;
    localparam RX_START_BIT  = 4'd1;
    localparam RX_DATA_BITS  = 4'd2;
    localparam RX_STOP_BIT   = 4'd3;
    localparam RX_COMPLETE   = 4'd4;
    
    reg [3:0] tx_state;
    reg [3:0] rx_state;
    reg [7:0] tx_shift_reg;
    reg [7:0] rx_shift_reg;
    reg [15:0] tx_baud_cnt;
    reg [15:0] rx_baud_cnt;
    reg [2:0] tx_bit_idx;
    reg [2:0] rx_bit_idx;
    reg tx_active;
    reg rx_active;
    
    // ==================== 过采样计数器 (16x采样) ====================
    reg [15:0] oversample_cnt;
    reg [3:0] oversample_idx;
    reg [2:0] rx_samples;
    reg rx_bit_stable;
    
    // ==================== 控制信号 ====================
    wire uart_enable;
    wire uart_tx_en;
    wire uart_rx_en;
    wire uart_tx_irq_en;
    wire uart_rx_irq_en;
    
    assign uart_enable = uart_ctrl[0];
    assign uart_tx_en = uart_ctrl[1];
    assign uart_rx_en = uart_ctrl[2];
    assign uart_tx_irq_en = uart_ctrl[4];
    assign uart_rx_irq_en = uart_ctrl[5];
    
    // ==================== 读端口 ====================
    always @(*) begin
        if (re) begin
            case (addr[7:2])
                4'h0: rdata = uart_ctrl;
                4'h1: rdata = {28'h0, rx_fifo_count, tx_fifo_count};
                4'h2: rdata = uart_txdata;
                4'h3: rdata = rx_fifo_empty ? 32'h0 : {24'h0, rx_fifo[rx_fifo_rd_ptr]};
                4'h4: rdata = uart_bauddiv;
                4'h5: rdata = uart_fifo_ctrl;
                4'h6: rdata = {30'h0, rx_fifo_full, tx_fifo_full};
                default: rdata = 32'h0;
            endcase
        end else
            rdata = 32'h0;
    end
    
    // ==================== 复位逻辑 ====================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_ctrl <= 32'h0;
            uart_bauddiv <= 32'd868;  // 115200 @ 50MHz
            uart_status <= 32'h0;
            uart_tx <= 1'b1;
            uart_txdata <= 32'h0;
            uart_rxdata <= 32'h0;
            uart_fifo_ctrl <= 32'h0;
            
            tx_state <= TX_IDLE;
            rx_state <= RX_IDLE;
            tx_fifo_wr_ptr <= 5'h0;
            tx_fifo_rd_ptr <= 5'h0;
            tx_fifo_count <= 5'h0;
            rx_fifo_wr_ptr <= 5'h0;
            rx_fifo_rd_ptr <= 5'h0;
            rx_fifo_count <= 5'h0;
            tx_active <= 1'b0;
            rx_active <= 1'b0;
            oversample_cnt <= 16'h0;
            rx_samples <= 3'b0;
            rx_bit_stable <= 1'b1;
        end else begin
            // ==================== TX FIFO 写 ====================
            if (we && addr[7:2] == 4'h2 && !tx_fifo_full) begin
                tx_fifo[tx_fifo_wr_ptr] <= wdata[7:0];
                tx_fifo_wr_ptr <= tx_fifo_wr_ptr + 1;
                tx_fifo_count <= tx_fifo_count + 1;
            end
            
            // ==================== RX FIFO 读 ====================
            if (re && addr[7:2] == 4'h3 && !rx_fifo_empty) begin
                rx_fifo_rd_ptr <= rx_fifo_rd_ptr + 1;
                rx_fifo_count <= rx_fifo_count - 1;
            end
            
            // ==================== 寄存器写 ====================
            if (we) begin
                case (addr[7:2])
                    4'h0: uart_ctrl <= wdata;
                    4'h4: uart_bauddiv <= wdata;
                    4'h5: uart_fifo_ctrl <= wdata;
                endcase
            end
            
            // ==================== 状态标志 ====================
            uart_status[0] <= !tx_fifo_full;  // TX ready
            uart_status[1] <= !rx_fifo_empty; // RX ready
            uart_status[4] <= tx_fifo_full;
            uart_status[5] <= rx_fifo_full;
            
            // ==================== TX 状态机 ====================
            if (uart_enable && uart_tx_en) begin
                case (tx_state)
                    TX_IDLE: begin
                        if (!tx_fifo_empty && !tx_active) begin
                            tx_shift_reg <= tx_fifo[tx_fifo_rd_ptr];
                            tx_fifo_rd_ptr <= tx_fifo_rd_ptr + 1;
                            tx_fifo_count <= tx_fifo_count - 1;
                            tx_active <= 1'b1;
                            tx_baud_cnt <= 16'h0;
                            tx_state <= TX_START_BIT;
                        end
                    end
                    
                    TX_START_BIT: begin
                        tx_baud_cnt <= tx_baud_cnt + 1;
                        if (tx_baud_cnt >= uart_bauddiv - 1) begin
                            tx_baud_cnt <= 16'h0;
                            uart_tx <= 1'b0;  // Start bit (0)
                            tx_bit_idx <= 3'h0;
                            tx_state <= TX_DATA_BITS;
                        end
                    end
                    
                    TX_DATA_BITS: begin
                        tx_baud_cnt <= tx_baud_cnt + 1;
                        if (tx_baud_cnt >= uart_bauddiv - 1) begin
                            tx_baud_cnt <= 16'h0;
                            uart_tx <= tx_shift_reg[tx_bit_idx];
                            if (tx_bit_idx == 3'd7) begin
                                tx_state <= TX_STOP_BIT;
                            end else begin
                                tx_bit_idx <= tx_bit_idx + 1;
                            end
                        end
                    end
                    
                    TX_STOP_BIT: begin
                        tx_baud_cnt <= tx_baud_cnt + 1;
                        if (tx_baud_cnt >= uart_bauddiv - 1) begin
                            tx_baud_cnt <= 16'h0;
                            uart_tx <= 1'b1;  // Stop bit (1)
                            tx_state <= TX_COMPLETE;
                        end
                    end
                    
                    TX_COMPLETE: begin
                        tx_active <= 1'b0;
                        tx_state <= TX_IDLE;
                    end
                endcase
            end else begin
                tx_state <= TX_IDLE;
                uart_tx <= 1'b1;
                tx_active <= 1'b0;
            end
            
            // ==================== RX 状态机 (16x过采样) ====================
            if (uart_enable && uart_rx_en) begin
                case (rx_state)
                    RX_IDLE: begin
                        if (uart_rx == 1'b0) begin  // 检测到起始位
                            rx_state <= RX_START_BIT;
                            oversample_cnt <= 16'h0;
                            oversample_idx <= 4'h0;
                        end
                    end
                    
                    RX_START_BIT: begin
                        // 过采样: 等待半个比特周期后开始采样
                        oversample_cnt <= oversample_cnt + 1;
                        if (oversample_cnt >= uart_bauddiv / 2) begin
                            oversample_cnt <= 16'h0;
                            if (uart_rx == 1'b0) begin
                                rx_state <= RX_DATA_BITS;
                                rx_bit_idx <= 3'h0;
                            end else begin
                                rx_state <= RX_IDLE;  // 假起始位
                            end
                        end
                    end
                    
                    RX_DATA_BITS: begin
                        oversample_cnt <= oversample_cnt + 1;
                        if (oversample_cnt >= uart_bauddiv / 16) begin
                            oversample_cnt <= 16'h0;
                            
                            // 3取2投票滤波
                            rx_samples <= {rx_samples[1:0], uart_rx};
                            
                            if (oversample_idx == 4'd7) begin
                                oversample_idx <= 4'h0;
                                // 多数投票决定 bit 值
                                rx_shift_reg[rx_bit_idx] <= (rx_samples[2] & rx_samples[1]) | 
                                                            (rx_samples[2] & rx_samples[0]) | 
                                                            (rx_samples[1] & rx_samples[0]);
                                if (rx_bit_idx == 3'd7) begin
                                    rx_state <= RX_STOP_BIT;
                                end else begin
                                    rx_bit_idx <= rx_bit_idx + 1;
                                end
                            end else begin
                                oversample_idx <= oversample_idx + 1;
                            end
                        end
                    end
                    
                    RX_STOP_BIT: begin
                        oversample_cnt <= oversample_cnt + 1;
                        if (oversample_cnt >= uart_bauddiv / 16) begin
                            oversample_cnt <= 16'h0;
                            oversample_idx <= oversample_idx + 1;
                            
                            if (oversample_idx == 4'd7) begin
                                // 停止位检测 (应该为1)
                                if (uart_rx == 1'b1 && !rx_fifo_full) begin
                                    rx_fifo[rx_fifo_wr_ptr] <= rx_shift_reg;
                                    rx_fifo_wr_ptr <= rx_fifo_wr_ptr + 1;
                                    rx_fifo_count <= rx_fifo_count + 1;
                                    uart_rxdata <= {24'h0, rx_shift_reg};
                                end
                                rx_state <= RX_COMPLETE;
                            end
                        end
                    end
                    
                    RX_COMPLETE: begin
                        rx_state <= RX_IDLE;
                    end
                endcase
            end else begin
                rx_state <= RX_IDLE;
            end
        end
    end

endmodule