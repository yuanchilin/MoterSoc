`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// PWM (Pulse Width Modulation) controller for piezo buzzer
// with CPU access (Wishbone) and hardware melody player
//
// Features:
//   - 50% duty square wave (optimal for piezo resonance)
//   - Note-gap silence for click-free frequency transitions
//   - 3 built-in melodies (key-triggered hardware sequencer)
//
// Design principle: piezo buzzer + 50% square wave + note gaps = smooth music
//////////////////////////////////////////////////////////////////////////////////

module pwm (
    input  wire         clk,            // 50MHz system clock
    input  wire         rst_n,          // active-low reset
    
    // Simple CPU Bus Interface (Wishbone-compatible)
    input  wire  [31:0] addr,
    input  wire  [31:0] wdata,
    input  wire         we,
    input  wire         re,
    input  wire         sel,
    output reg   [31:0] rdata,
    
    // External key inputs (active low)
    input  wire  [3:0]  keys,
    
    // PWM physical output
    output reg          pwm_out
);
    
    // ========== Internal Wishbone signals ==========
    wire wb_cyc_i = sel;
    wire wb_stb_i = sel;
    wire wb_we_i  = we;
    wire [31:0] wb_adr_i = addr;
    wire [31:0] wb_dat_i = wdata;
    wire        wb_sel;
    assign wb_sel = wb_cyc_i & wb_stb_i;
    
    reg        wb_ack_o;
    reg [31:0] wb_dat_o;
    
    // ==================== Register Map ====================
    // 0x00: CTRL   — [0]: enable, [1]: melody_enable
    // 0x04: PERIOD  — PWM period counter reload value
    // 0x08: DUTY    — PWM duty cycle threshold
    // 0x0C: CNT     — current counter value (read-only)
    
    reg         ctrl_enable;
    reg         ctrl_melody_enable;
    
    // Wishbone write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_enable        <= 1'b0;
            ctrl_melody_enable <= 1'b0;
            wb_ack_o           <= 1'b0;
        end else begin
            wb_ack_o <= wb_sel;
            if (wb_sel & wb_we_i) begin
                case (wb_adr_i[3:2])
                    2'd0: {ctrl_melody_enable, ctrl_enable} <= wb_dat_i[1:0];
                    default: ;
                endcase
            end
        end
    end
    
    // Wishbone read
    always @(*) begin
        wb_dat_o = 32'd0;
        if (wb_sel & ~wb_we_i) begin
            case (wb_adr_i[3:2])
                2'd0: wb_dat_o = {30'd0, ctrl_melody_enable, ctrl_enable};
                default: ;
            endcase
        end
    end
    
    // Drive read data output
    always @(*) begin
        rdata = wb_dat_o;
    end
    
    // ==================== Legacy PWM (CPU-controlled) ====================
    reg [19:0] period_reg;
    reg [19:0] duty_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            period_reg <= 20'd100_000;
            duty_reg   <= 20'd50_000;
        end else if (wb_sel & wb_we_i) begin
            case (wb_adr_i[3:2])
                2'd1: period_reg <= wb_dat_i[19:0];
                2'd2: duty_reg   <= wb_dat_i[19:0];
                default: ;
            endcase
        end
    end
    
    reg [19:0] legacy_cnt;
    reg        legacy_pwm_out;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            legacy_cnt <= 20'd0;
            legacy_pwm_out <= 1'b0;
        end else if (ctrl_enable) begin
            if (legacy_cnt >= period_reg - 1)
                legacy_cnt <= 20'd0;
            else
                legacy_cnt <= legacy_cnt + 1;
            
            legacy_pwm_out <= (legacy_cnt < duty_reg);
        end else begin
            legacy_cnt <= 20'd0;
            legacy_pwm_out <= 1'b0;
        end
    end
    
    // ==================== Hardware Melody Player ====================
    
    // Note period constants (50MHz / (2 * freq))
    localparam [19:0] PER_RST = 20'd0;
    localparam [19:0] PER_C4  = 20'd95558;
    localparam [19:0] PER_D4  = 20'd85131;
    localparam [19:0] PER_E4  = 20'd75843;
    localparam [19:0] PER_F4  = 20'd71585;
    localparam [19:0] PER_G4  = 20'd63776;
    localparam [19:0] PER_A4  = 20'd56818;
    localparam [19:0] PER_B4  = 20'd50620;
    localparam [19:0] PER_C5  = 20'd47779;
    localparam [19:0] PER_D5  = 20'd42566;
    localparam [19:0] PER_E5  = 20'd37921;
    localparam [19:0] PER_F5  = 20'd35791;
    localparam [19:0] PER_G5  = 20'd31888;
    localparam [19:0] PER_A5  = 20'd28409;
    localparam [19:0] PER_B5  = 20'd25309;
    
    // Duration constants (ms)
    localparam [15:0] W  = 16'd1000;  // whole
    localparam [15:0] H  = 16'd500;   // half
    localparam [15:0] Q  = 16'd250;   // quarter
    localparam [15:0] EQ = 16'd125;   // eighth
    localparam [15:0] S  = 16'd1000;  // rest whole
    localparam [15:0] E  = 16'd500;   // rest half
    
    // Note gap (ms of silence between consecutive different notes)
    // Prevents audible click from abrupt frequency change
    localparam [15:0] NOTE_GAP_MS = 16'd5;
    
    // ----- Melody state -----
    reg [1:0] melody_select;
    reg [6:0] note_idx;
    reg [15:0] note_timer;  // ms counter within current note
    reg [19:0] mel_cnt;     // audio period counter (runs at full clock speed)
    reg        melody_pwm_out;
    reg        ms_enable;
    reg [15:0] note_gap_timer;  // ms counter for gap between notes
    
    // Key debounce & tick generator
    reg [15:0] ms_divider;
    wire       ms_tick;
    assign ms_tick = (ms_divider == 16'd0);
    
    reg [3:0] key_d0, key_d1, key_d2, key_stable, key_prev;
    wire [3:0] key_press;
    assign key_press = key_prev & ~key_stable;
    
    // 1kHz tick + key debounce
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ms_divider  <= 16'd49999;
            key_d0      <= 4'hF;
            key_d1      <= 4'hF;
            key_d2      <= 4'hF;
            key_stable  <= 4'hF;
            key_prev    <= 4'hF;
        end else begin
            // 1kHz divider
            if (ms_divider == 16'd0)
                ms_divider <= 16'd49999;
            else
                ms_divider <= ms_divider - 1;
            
            // Debounce (only on ms_tick edges)
            if (ms_tick) begin
                key_d0 <= keys;
                key_d1 <= key_d0;
                key_d2 <= key_d1;
                if ((key_d0 == key_d1) && (key_d1 == key_d2))
                    key_stable <= key_d0;
                key_prev <= key_stable;
            end
        end
    end
    
    // ----- Melody ROM tables (combinational) -----
    reg [19:0] rom_period;
    reg [15:0] rom_duration;
    
    always @(*) begin
        rom_period = PER_RST;
        rom_duration = W;
        case (melody_select)
            2'd1: begin
                case (note_idx)
                    7'd0:  begin rom_period = PER_C4; rom_duration = Q;  end
                    7'd1:  begin rom_period = PER_C4; rom_duration = Q;  end
                    7'd2:  begin rom_period = PER_G4; rom_duration = Q;  end
                    7'd3:  begin rom_period = PER_G4; rom_duration = Q;  end
                    7'd4:  begin rom_period = PER_A4; rom_duration = Q;  end
                    7'd5:  begin rom_period = PER_A4; rom_duration = Q;  end
                    7'd6:  begin rom_period = PER_G4; rom_duration = H;  end
                    7'd7:  begin rom_period = PER_RST; rom_duration = S; end
                    7'd8:  begin rom_period = PER_F4; rom_duration = Q;  end
                    7'd9:  begin rom_period = PER_F4; rom_duration = Q;  end
                    7'd10: begin rom_period = PER_E4; rom_duration = Q;  end
                    7'd11: begin rom_period = PER_E4; rom_duration = Q;  end
                    7'd12: begin rom_period = PER_D4; rom_duration = Q;  end
                    7'd13: begin rom_period = PER_D4; rom_duration = Q;  end
                    7'd14: begin rom_period = PER_C4; rom_duration = H;  end
                    7'd15: begin rom_period = PER_RST; rom_duration = S; end
                    7'd16: begin rom_period = PER_G4; rom_duration = Q;  end
                    7'd17: begin rom_period = PER_G4; rom_duration = Q;  end
                    7'd18: begin rom_period = PER_F4; rom_duration = Q;  end
                    7'd19: begin rom_period = PER_F4; rom_duration = Q;  end
                    7'd20: begin rom_period = PER_E4; rom_duration = Q;  end
                    7'd21: begin rom_period = PER_E4; rom_duration = Q;  end
                    7'd22: begin rom_period = PER_D4; rom_duration = H;  end
                    7'd23: begin rom_period = PER_RST; rom_duration = S; end
                    7'd24: begin rom_period = PER_C4; rom_duration = Q;  end
                    7'd25: begin rom_period = PER_C4; rom_duration = Q;  end
                    7'd26: begin rom_period = PER_G4; rom_duration = Q;  end
                    7'd27: begin rom_period = PER_G4; rom_duration = Q;  end
                    7'd28: begin rom_period = PER_A4; rom_duration = Q;  end
                    7'd29: begin rom_period = PER_A4; rom_duration = Q;  end
                    7'd30: begin rom_period = PER_G4; rom_duration = H;  end
                    7'd31: begin rom_period = PER_RST; rom_duration = S; end
                    7'd32: begin rom_period = PER_F4; rom_duration = Q;  end
                    7'd33: begin rom_period = PER_F4; rom_duration = Q;  end
                    7'd34: begin rom_period = PER_E4; rom_duration = Q;  end
                    7'd35: begin rom_period = PER_E4; rom_duration = Q;  end
                    7'd36: begin rom_period = PER_D4; rom_duration = Q;  end
                    7'd37: begin rom_period = PER_D4; rom_duration = Q;  end
                    7'd38: begin rom_period = PER_C4; rom_duration = W;  end
                    default: begin rom_period = PER_RST; rom_duration = W; end
                endcase
            end
            2'd2: begin
                case (note_idx)
                    7'd0:  begin rom_period = PER_C4; rom_duration = Q;  end
                    7'd1:  begin rom_period = PER_C4; rom_duration = Q;  end
                    7'd2:  begin rom_period = PER_D4; rom_duration = H;  end
                    7'd3:  begin rom_period = PER_C4; rom_duration = H;  end
                    7'd4:  begin rom_period = PER_F4; rom_duration = H;  end
                    7'd5:  begin rom_period = PER_E4; rom_duration = W;  end
                    7'd6:  begin rom_period = PER_RST; rom_duration = S; end
                    7'd7:  begin rom_period = PER_C4; rom_duration = Q;  end
                    7'd8:  begin rom_period = PER_C4; rom_duration = Q;  end
                    7'd9:  begin rom_period = PER_D4; rom_duration = H;  end
                    7'd10: begin rom_period = PER_C4; rom_duration = H;  end
                    7'd11: begin rom_period = PER_G4; rom_duration = H;  end
                    7'd12: begin rom_period = PER_F4; rom_duration = W;  end
                    7'd13: begin rom_period = PER_RST; rom_duration = S; end
                    7'd14: begin rom_period = PER_C4; rom_duration = Q;  end
                    7'd15: begin rom_period = PER_C4; rom_duration = Q;  end
                    7'd16: begin rom_period = PER_C5; rom_duration = H;  end
                    7'd17: begin rom_period = PER_A4; rom_duration = H;  end
                    7'd18: begin rom_period = PER_F4; rom_duration = H;  end
                    7'd19: begin rom_period = PER_E4; rom_duration = H;  end
                    7'd20: begin rom_period = PER_D4; rom_duration = W;  end
                    7'd21: begin rom_period = PER_RST; rom_duration = S; end
                    7'd22: begin rom_period = PER_A4; rom_duration = Q;  end
                    7'd23: begin rom_period = PER_A4; rom_duration = Q;  end
                    7'd24: begin rom_period = PER_B4; rom_duration = H;  end
                    7'd25: begin rom_period = PER_A4; rom_duration = H;  end
                    7'd26: begin rom_period = PER_G4; rom_duration = H;  end
                    7'd27: begin rom_period = PER_F4; rom_duration = W;  end
                    default: begin rom_period = PER_RST; rom_duration = W; end
                endcase
            end
            2'd3: begin
                case (note_idx)
                    7'd0:  begin rom_period = PER_E4; rom_duration = Q;  end
                    7'd1:  begin rom_period = PER_E4; rom_duration = Q;  end
                    7'd2:  begin rom_period = PER_F4; rom_duration = Q;  end
                    7'd3:  begin rom_period = PER_G4; rom_duration = Q;  end
                    7'd4:  begin rom_period = PER_G4; rom_duration = Q;  end
                    7'd5:  begin rom_period = PER_F4; rom_duration = Q;  end
                    7'd6:  begin rom_period = PER_E4; rom_duration = Q;  end
                    7'd7:  begin rom_period = PER_D4; rom_duration = Q;  end
                    7'd8:  begin rom_period = PER_C4; rom_duration = Q;  end
                    7'd9:  begin rom_period = PER_C4; rom_duration = Q;  end
                    7'd10: begin rom_period = PER_D4; rom_duration = Q;  end
                    7'd11: begin rom_period = PER_E4; rom_duration = Q;  end
                    7'd12: begin rom_period = PER_E4; rom_duration = H;  end
                    7'd13: begin rom_period = PER_D4; rom_duration = H;  end
                    7'd14: begin rom_period = PER_RST; rom_duration = S; end
                    7'd15: begin rom_period = PER_E4; rom_duration = Q;  end
                    7'd16: begin rom_period = PER_E4; rom_duration = Q;  end
                    7'd17: begin rom_period = PER_F4; rom_duration = Q;  end
                    7'd18: begin rom_period = PER_G4; rom_duration = Q;  end
                    7'd19: begin rom_period = PER_G4; rom_duration = Q;  end
                    7'd20: begin rom_period = PER_F4; rom_duration = Q;  end
                    7'd21: begin rom_period = PER_E4; rom_duration = Q;  end
                    7'd22: begin rom_period = PER_D4; rom_duration = Q;  end
                    7'd23: begin rom_period = PER_C4; rom_duration = Q;  end
                    7'd24: begin rom_period = PER_C4; rom_duration = Q;  end
                    7'd25: begin rom_period = PER_D4; rom_duration = Q;  end
                    7'd26: begin rom_period = PER_E4; rom_duration = Q;  end
                    7'd27: begin rom_period = PER_D4; rom_duration = Q;  end
                    7'd28: begin rom_period = PER_C4; rom_duration = Q;  end
                    7'd29: begin rom_period = PER_C4; rom_duration = H;  end
                    7'd30: begin rom_period = PER_RST; rom_duration = E; end
                    7'd31: begin rom_period = PER_D4; rom_duration = Q;  end
                    7'd32: begin rom_period = PER_D4; rom_duration = Q;  end
                    7'd33: begin rom_period = PER_E4; rom_duration = Q;  end
                    7'd34: begin rom_period = PER_C4; rom_duration = Q;  end
                    7'd35: begin rom_period = PER_D4; rom_duration = Q;  end
                    7'd36: begin rom_period = PER_E4; rom_duration = Q;  end
                    7'd37: begin rom_period = PER_F4; rom_duration = Q;  end
                    7'd38: begin rom_period = PER_E4; rom_duration = Q;  end
                    7'd39: begin rom_period = PER_C4; rom_duration = Q;  end
                    7'd40: begin rom_period = PER_D4; rom_duration = Q;  end
                    7'd41: begin rom_period = PER_E4; rom_duration = Q;  end
                    7'd42: begin rom_period = PER_F4; rom_duration = Q;  end
                    7'd43: begin rom_period = PER_E4; rom_duration = Q;  end
                    7'd44: begin rom_period = PER_D4; rom_duration = Q;  end
                    7'd45: begin rom_period = PER_C4; rom_duration = Q;  end
                    7'd46: begin rom_period = PER_D4; rom_duration = Q;  end
                    7'd47: begin rom_period = PER_RST; rom_duration = E; end
                    7'd48: begin rom_period = PER_G4; rom_duration = Q;  end
                    7'd49: begin rom_period = PER_G4; rom_duration = Q;  end
                    7'd50: begin rom_period = PER_A4; rom_duration = Q;  end
                    7'd51: begin rom_period = PER_G4; rom_duration = Q;  end
                    7'd52: begin rom_period = PER_F4; rom_duration = Q;  end
                    7'd53: begin rom_period = PER_E4; rom_duration = Q;  end
                    7'd54: begin rom_period = PER_D4; rom_duration = Q;  end
                    7'd55: begin rom_period = PER_C4; rom_duration = Q;  end
                    7'd56: begin rom_period = PER_C4; rom_duration = Q;  end
                    7'd57: begin rom_period = PER_D4; rom_duration = Q;  end
                    7'd58: begin rom_period = PER_E4; rom_duration = Q;  end
                    7'd59: begin rom_period = PER_D4; rom_duration = Q;  end
                    7'd60: begin rom_period = PER_C4; rom_duration = W;  end
                    default: begin rom_period = PER_RST; rom_duration = W; end
                endcase
            end
            default: begin rom_period = PER_RST; rom_duration = W; end
        endcase
    end
    
    // Last note index per melody
    function [6:0] get_rom_max;
        input [1:0] sel;
        case (sel)
            2'd1: get_rom_max = 7'd41;
            2'd2: get_rom_max = 7'd27;
            2'd3: get_rom_max = 7'd60;
            default: get_rom_max = 7'd0;
        endcase
    endfunction
    
    wire [6:0] rom_max_val;
    assign rom_max_val = get_rom_max(melody_select);
    
    // ==================== Melody Sequencer (1ms tick rate) ====================
    // Handles: key triggers, note advancement, note-gap timing
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ms_enable      <= 1'b0;
            melody_select  <= 2'd0;
            note_idx       <= 7'd0;
            note_timer     <= 16'd0;
            note_gap_timer <= 16'd0;
        end else if (ms_tick) begin
            // ---- Key trigger handling ----
            if (key_press[3]) begin  // STOP
                ms_enable      <= 1'b0;
                melody_select  <= 2'd0;
                note_idx       <= 7'd0;
                note_timer     <= 16'd0;
                note_gap_timer <= 16'd0;
            end else if (key_press[2]) begin
                ms_enable      <= 1'b1;
                melody_select  <= 2'd3;  // Ode to Joy
                note_idx       <= 7'd0;
                note_timer     <= 16'd0;
                note_gap_timer <= 16'd0;
            end else if (key_press[1]) begin
                ms_enable      <= 1'b1;
                melody_select  <= 2'd2;  // Happy Birthday
                note_idx       <= 7'd0;
                note_timer     <= 16'd0;
                note_gap_timer <= 16'd0;
            end else if (key_press[0]) begin
                ms_enable      <= 1'b1;
                melody_select  <= 2'd1;  // Twinkle Twinkle
                note_idx       <= 7'd0;
                note_timer     <= 16'd0;
                note_gap_timer <= 16'd0;
            end
            
            // ---- Note sequencer (when active) ----
            if (ms_enable) begin
                if (note_gap_timer > 0) begin
                    // In gap period → silence, decrement gap timer
                    note_gap_timer <= note_gap_timer - 1;
                end else if (note_timer >= rom_duration - 1) begin
                    // Current note finished → advance to next note with gap
                    note_timer <= 16'd0;
                    // Insert gap before next note (except when wrapping around)
                    if (note_idx >= rom_max_val) begin
                        note_idx <= 7'd0;  // loop
                        note_gap_timer <= 16'd0;  // no gap on loop wrap
                    end else begin
                        note_idx <= note_idx + 1;
                        note_gap_timer <= NOTE_GAP_MS;  // gap between different notes
                    end
                end else begin
                    note_timer <= note_timer + 1;
                end
            end
        end
    end
    
    // ==================== Audio PWM Generator (full clock speed) ====================
    // Generates 50% duty square wave at rom_period frequency
    // Runs continuously at 50MHz for clean audio waveform
    // Separate from note sequencer to avoid glitches on ms_tick edges
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mel_cnt        <= 20'd0;
            melody_pwm_out <= 1'b0;
        end else if (ms_enable && rom_period != PER_RST && note_gap_timer == 16'd0) begin
            // Active note (not in gap, not a rest): generate 50% duty square wave
            if (mel_cnt >= rom_period - 1)
                mel_cnt <= 20'd0;
            else
                mel_cnt <= mel_cnt + 1;
            melody_pwm_out <= (mel_cnt < (rom_period >> 1));
        end else begin
            // Gap, rest, or stopped: output silence
            mel_cnt        <= 20'd0;
            melody_pwm_out <= 1'b0;
        end
    end
    
    // ==================== Output MUX ====================
    always @(*) begin
        if (ms_enable)
            pwm_out = melody_pwm_out;
        else if (ctrl_melody_enable)
            pwm_out = melody_pwm_out;
        else
            pwm_out = legacy_pwm_out;
    end

endmodule