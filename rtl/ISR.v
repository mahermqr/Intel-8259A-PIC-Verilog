// ============================================================================
// Module: ISR (In-Service Register)
// Project: Intel 8259A Programmable Interrupt Controller
// Description: Stores interrupt requests currently being serviced.
//              Calculates vector address and clears bits upon EOI command.
// ============================================================================

`timescale 1ns/1ps

module ISR (
    input  wire       reset,            // Reset signal (active high)
    input  wire       set_isr,          // Pulse to set highestPriority bit in ISR
    input  wire       clear_isr,        // Pulse to clear clear_index bit in ISR (EOI)
    input  wire [2:0] clear_index,      // Bit index to clear on EOI
    input  wire [2:0] highestPriority,  // Highest priority interrupt index being acknowledged
    input  wire [7:0] AddressBase,      // ICW2 vector address base (top 5 bits T7-T3)
    output reg  [7:0] isr_reg,          // 8-bit In-Service Register output
    output wire [7:0] currentAddress    // 8-bit vector address (Base | Interrupt Location)
);

    // Compute the 8-bit interrupt vector address
    // Intel 8259A format: AddressBase[7:3] combined with 3-bit interrupt level [2:0]
    assign currentAddress = {AddressBase[7:3], highestPriority[2:0]};

    // Sequential logic to track active in-service interrupts
    always @(posedge set_isr or posedge clear_isr or posedge reset) begin
        if (reset) begin
            isr_reg <= 8'b00000000;
        end else begin
            if (set_isr) begin
                isr_reg[highestPriority] <= 1'b1;
            end
            if (clear_isr) begin
                isr_reg[clear_index] <= 1'b0;
            end
        end
    end

endmodule
