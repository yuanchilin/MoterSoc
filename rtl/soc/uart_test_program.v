// UART通信测试程序
// 功能: 通过UART发送"Hello RISC-V!"字符串

module uart_test_program (
    input wire clk,
    input wire rst_n,
    input wire [31:0] uart_status,
    input wire uart_rx_ready,
    output reg uart_tx_en,
    output reg [7:0] uart_txdata
);
    // 测试字符串
    localparam MSG_LEN = 14;
    localparam MSG = "Hello RISC-V!";
    
    // 状态机
    reg [3:0] state;
    reg [7:0] msg_index;
    reg [7:0] tx_data;
    
    // 状态定义
    localparam IDLE = 4'd0;
    localparam SEND_START = 4'd1;
    localparam SEND_DATA = 4'd2;
    localparam WAIT_TX_READY = 4'd3;
    localparam SEND_COMPLETE = 4'd4;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            msg_index <= 8'd0;
            uart_tx_en <= 1'b0;
            uart_txdata <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (uart_status[0]) begin // TX ready
                        state <= SEND_START;
                        msg_index <= 8'd0;
                    end
                end
                
                SEND_START: begin
                    tx_data <= MSG[msg_index];
                    state <= WAIT_TX_READY;
                end
                
                WAIT_TX_READY: begin
                    if (uart_status[0]) begin // TX ready
                        uart_tx_en <= 1'b1;
                        uart_txdata <= tx_data;
                        state <= SEND_DATA;
                    end
                end
                
                SEND_DATA: begin
                    uart_tx_en <= 1'b0;
                    if (msg_index < MSG_LEN - 1) begin
                        msg_index <= msg_index + 1;
                        state <= SEND_START;
                    end else begin
                        state <= SEND_COMPLETE;
                    end
                end
                
                SEND_COMPLETE: begin
                    // 等待一段时间后重新开始
                    if (msg_index >= MSG_LEN) begin
                        #1000000; // 等待1秒
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule