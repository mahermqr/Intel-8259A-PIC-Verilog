// ============================================================================
// Module: IRR (Interrupt Request Register)
// Course: EC482 - Microprocessor Systems I
// Instructor: Dr. Mohamed M. Eljhani
// Authors: Maher Abdulnaser Alqadhi (ID: 2210249576)
//          Mohammed Nasreddin Khalaf (ID: 2210246039)
// Description: Stores interrupt requests from 8 input lines (IR7-IR0).
//              Supports Edge-Triggered (0->1 transition) and Level-Triggered modes.
// ============================================================================

`timescale 1ns/1ps

module IRR (
    input  wire       reset,            // Reset signal (active high)
    input  wire       LTIM,             // 0 = Edge-triggered, 1 = Level-triggered
    input  wire [7:0] IRBus,            // 8 interrupt request lines (IR7-IR0)
    input  wire [2:0] highestPriority,  // Index of interrupt currently acknowledged
    input  wire       clear_irr,        // Pulse to clear acknowledged interrupt bit
    output wire [7:0] irr               // 8-bit Interrupt Request Register output
);

    reg [7:0] edge_latch;

    always @(posedge IRBus[0] or posedge reset or posedge clear_irr) begin
        if (reset) begin
            edge_latch[0] <= 1'b0;
        end else if (clear_irr) begin
            if (highestPriority == 3'd0) edge_latch[0] <= 1'b0;
        end else if (!LTIM && IRBus[0]) begin
            edge_latch[0] <= 1'b1;
        end
    end

    always @(posedge IRBus[1] or posedge reset or posedge clear_irr) begin
        if (reset) begin
            edge_latch[1] <= 1'b0;
        end else if (clear_irr) begin
            if (highestPriority == 3'd1) edge_latch[1] <= 1'b0;
        end else if (!LTIM && IRBus[1]) begin
            edge_latch[1] <= 1'b1;
        end
    end

    always @(posedge IRBus[2] or posedge reset or posedge clear_irr) begin
        if (reset) begin
            edge_latch[2] <= 1'b0;
        end else if (clear_irr) begin
            if (highestPriority == 3'd2) edge_latch[2] <= 1'b0;
        end else if (!LTIM && IRBus[2]) begin
            edge_latch[2] <= 1'b1;
        end
    end

    always @(posedge IRBus[3] or posedge reset or posedge clear_irr) begin
        if (reset) begin
            edge_latch[3] <= 1'b0;
        end else if (clear_irr) begin
            if (highestPriority == 3'd3) edge_latch[3] <= 1'b0;
        end else if (!LTIM && IRBus[3]) begin
            edge_latch[3] <= 1'b1;
        end
    end

    always @(posedge IRBus[4] or posedge reset or posedge clear_irr) begin
        if (reset) begin
            edge_latch[4] <= 1'b0;
        end else if (clear_irr) begin
            if (highestPriority == 3'd4) edge_latch[4] <= 1'b0;
        end else if (!LTIM && IRBus[4]) begin
            edge_latch[4] <= 1'b1;
        end
    end

    always @(posedge IRBus[5] or posedge reset or posedge clear_irr) begin
        if (reset) begin
            edge_latch[5] <= 1'b0;
        end else if (clear_irr) begin
            if (highestPriority == 3'd5) edge_latch[5] <= 1'b0;
        end else if (!LTIM && IRBus[5]) begin
            edge_latch[5] <= 1'b1;
        end
    end

    always @(posedge IRBus[6] or posedge reset or posedge clear_irr) begin
        if (reset) begin
            edge_latch[6] <= 1'b0;
        end else if (clear_irr) begin
            if (highestPriority == 3'd6) edge_latch[6] <= 1'b0;
        end else if (!LTIM && IRBus[6]) begin
            edge_latch[6] <= 1'b1;
        end
    end

    always @(posedge IRBus[7] or posedge reset or posedge clear_irr) begin
        if (reset) begin
            edge_latch[7] <= 1'b0;
        end else if (clear_irr) begin
            if (highestPriority == 3'd7) edge_latch[7] <= 1'b0;
        end else if (!LTIM && IRBus[7]) begin
            edge_latch[7] <= 1'b1;
        end
    end

    // Select between edge-triggered latched register and level-triggered direct input
    assign irr = LTIM ? IRBus : edge_latch;

endmodule
