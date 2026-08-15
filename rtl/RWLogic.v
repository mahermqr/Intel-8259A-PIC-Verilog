// ============================================================================
// Module: RWLogic (Read/Write Logic & Command Register Interface)
// Course: EC482 - Microprocessor Systems I
// Instructor: Dr. Mohamed M. Eljhani
// Authors: Maher Abdulnaser Alqadhi (ID: 2210249576)
//          Mohammed Nasreddin Khalaf (ID: 2210246039)
// Description: Decodes ICW1-ICW4 initialization sequence and OCW1-OCW3 operation commands.
// ============================================================================

`timescale 1ns/1ps

module RWLogic (
    input  wire       clk,                     // System Clock / Strobe
    input  wire       reset,                   // Master Reset
    input  wire [7:0] globalBus,               // 8-bit Data Bus input
    input  wire       A0,                      // Register Address Select
    input  wire       CS_n,                    // Chip Select (active low)
    input  wire       WR_n,                    // Write Enable (active low)
    input  wire       RD_n,                    // Read Enable (active low)
    
    // Decoded ICW Registers
    output reg  [7:0] ICW1,
    output reg  [7:0] ICW2,
    output reg  [7:0] ICW3,
    output reg  [7:0] ICW4,
    
    // Decoded OCW Registers
    output reg  [7:0] OCW1,                    // IMR (Interrupt Mask Register)
    output reg  [7:0] OCW2,                    // EOI & Priority Rotation Command
    output reg  [7:0] OCW3,                    // Status Read Command
    
    // State Signals
    output reg  [3:0] icw_step,                // Track initialization progress (0: idle, 1: ICW1, 2: ICW2, 3: ICW3, 4: ICW4, 5: ready)
    output wire       init_in_progress,        // 1 if controller is being initialized
    output reg  [1:0] read_status_sel,         // 0: none, 2: Read IRR (10), 3: Read ISR (11)
    output reg        eoi_pulse,               // 1-cycle pulse when EOI command is received
    output reg  [2:0] eoi_level                // Target level for specific EOI command
);

    wire write_active = !CS_n && !WR_n;
    assign init_in_progress = (icw_step != 4'd5);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ICW1            <= 8'b0;
            ICW2            <= 8'b0;
            ICW3            <= 8'b0;
            ICW4            <= 8'b0;
            OCW1            <= 8'b0;
            OCW2            <= 8'b0;
            OCW3            <= 8'b0;
            icw_step        <= 4'd0;
            read_status_sel <= 2'b10; // Default read IRR
            eoi_pulse       <= 1'b0;
            eoi_level       <= 3'b0;
        end else begin
            eoi_pulse <= 1'b0;

            if (write_active) begin
                // Decoding ICW1: Write with A0 = 0 and D4 = 1 triggers initialization sequence
                if (!A0 && globalBus[4]) begin
                    ICW1     <= globalBus;
                    icw_step <= 4'd2; // Expect ICW2 next
                end
                // Decoding subsequent ICWs (A0 = 1 during initialization)
                else if (A0 && icw_step == 4'd2) begin
                    ICW2 <= globalBus;
                    // Check if ICW3 is required (SNGL bit ICW1[1] = 0 means cascade mode, so ICW3 needed)
                    if (!ICW1[1]) begin
                        icw_step <= 4'd3;
                    end else if (ICW1[0]) begin // IC4 bit ICW1[0] = 1 means ICW4 needed
                        icw_step <= 4'd4;
                    end else begin
                        icw_step <= 4'd5; // Initialization complete
                    end
                end
                else if (A0 && icw_step == 4'd3) begin
                    ICW3 <= globalBus;
                    if (ICW1[0]) begin
                        icw_step <= 4'd4;
                    end else begin
                        icw_step <= 4'd5;
                    end
                end
                else if (A0 && icw_step == 4'd4) begin
                    ICW4     <= globalBus;
                    icw_step <= 4'd5; // Initialization complete
                end
                // Decoding Operational Control Words (OCWs) after initialization complete
                else if (icw_step == 4'd5) begin
                    if (A0) begin
                        // OCW1: Write to Interrupt Mask Register (IMR)
                        OCW1 <= globalBus;
                    end else if (!globalBus[4] && !globalBus[3]) begin
                        // OCW2: EOI & Priority Rotate Command (D4=0, D3=0)
                        OCW2      <= globalBus;
                        eoi_level <= globalBus[2:0];
                        if (globalBus[5]) begin // EOI bit set
                            eoi_pulse <= 1'b1;
                        end
                    end else if (!globalBus[4] && globalBus[3]) begin
                        // OCW3: Status Read / Special Mask Mode (D4=0, D3=1)
                        OCW3 <= globalBus;
                        if (globalBus[1]) begin // RR bit (Read Register)
                            read_status_sel <= {globalBus[1], globalBus[0]}; // 10: IRR, 11: ISR
                        end
                    end
                end
            end
        end
    end

endmodule
