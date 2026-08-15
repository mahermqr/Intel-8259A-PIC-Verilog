// ============================================================================
// Module: PriorityResolver
// Course: EC482 - Microprocessor Systems I
// Instructor: Dr. Mohamed M. Eljhani
// Authors: Maher Abdulnaser Alqadhi (ID: 2210249576)
//          Mohammed Nasreddin Khalaf (ID: 2210246039)
// Description: Determines the highest priority pending interrupt.
//              Supports Fully Nested Mode (IR0 > IR1 > ... > IR7)
//              and Auto-Rotating Priority Mode.
// ============================================================================

`timescale 1ns/1ps

module PriorityResolver (
    input  wire [7:0] irr,                // Interrupt Request Register
    input  wire [7:0] imr,                // Interrupt Mask Register (OCW1)
    input  wire [7:0] isr,                // In-Service Register
    input  wire       autoRotateMode,     // 0 = Fully Nested, 1 = Auto-Rotate
    input  wire [2:0] rotate_bottom,      // Lowest priority index in rotating mode
    output reg  [2:0] highestPriority,    // Index (0-7) of highest priority request
    output reg        interruptExists     // 1 if an eligible interrupt exists
);

    wire [7:0] maskedIRR;
    assign maskedIRR = irr & (~imr);

    integer i, idx;
    reg found;

    always @(*) begin
        highestPriority = 3'd0;
        interruptExists = 1'b0;
        found = 1'b0;

        if (!autoRotateMode) begin
            // Fully Nested Mode: Priority order IR0 (highest) -> IR7 (lowest)
            for (i = 0; i < 8; i = i + 1) begin
                if (maskedIRR[i] && !found) begin
                    // Check nesting against ISR: request must be higher priority than any active ISR
                    // In fully nested mode, higher priority means lower pin number (i < active ISR bit)
                    if (isr == 8'b0 || (1 << i) < (isr & -isr)) begin
                        highestPriority = i[2:0];
                        interruptExists = 1'b1;
                        found = 1'b1;
                    end
                end
            end
        end else begin
            // Auto-Rotating Mode: Priority starts at (rotate_bottom + 1) % 8 down to rotate_bottom
            for (i = 1; i <= 8; i = i + 1) begin
                idx = (rotate_bottom + i) % 8;
                if (maskedIRR[idx] && !found) begin
                    highestPriority = idx[2:0];
                    interruptExists = 1'b1;
                    found = 1'b1;
                end
            end
        end
    end

endmodule
