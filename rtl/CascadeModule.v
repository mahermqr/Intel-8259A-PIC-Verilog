// ============================================================================
// Module: CascadeModule (Cascade Controller & CAS Bus Manager)
// Description: Manages Master/Slave communication via 3-bit CAS bus.
//              Determines whether Master or matching Slave drives DBus.
// ============================================================================

`timescale 1ns/1ps

module CascadeModule (
    input  wire       SP,                     // 1 = Master PIC, 0 = Slave PIC
    input  wire       SNGL,                   // 1 = Single mode, 0 = Cascade mode
    input  wire [7:0] ICW3,                   // Master: Slave map bitmask; Slave: 3-bit Slave ID
    input  wire [2:0] Interrupt_Location,     // Current active interrupt level (0-7)
    input  wire       interruptExists,        // 1 if an active interrupt is pending
    inout  wire [2:0] CAS,                    // 3-bit Cascade Bus
    output wire       Address_Write_Enable    // 1 if THIS PIC module should drive vector onto DBus
);

    wire isSingle = (SNGL == 1'b1);
    wire isMaster = (SP == 1'b1);

    reg [2:0] CAS_Reg;

    // Master drives CAS bus; Slave listens
    assign CAS = isMaster ? CAS_Reg : 3'bz;

    // Address_Write_Enable logic:
    // Single Mode: This PIC always drives DBus.
    // Master Mode: Drives DBus IF the active interrupt pin does NOT have a slave connected (~ICW3[Interrupt_Location]).
    // Slave Mode: Drives DBus IF the CAS bus matches this slave's ID (CAS == ICW3[2:0]).
    assign Address_Write_Enable = isSingle ? 1'b1 :
                                 (isMaster ? (interruptExists && !ICW3[Interrupt_Location]) :
                                             (CAS == ICW3[2:0]));

    always @(*) begin
        if (isMaster) begin
            if (interruptExists && ICW3[Interrupt_Location]) begin
                CAS_Reg = Interrupt_Location; // Output slave ID onto CAS bus
            end else begin
                CAS_Reg = 3'b111;             // Default inactive state
            end
        end else begin
            CAS_Reg = 3'bzzz;
        end
    end

endmodule
