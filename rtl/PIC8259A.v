// ============================================================================
// Module: PIC8259A (Top-Level Programmable Interrupt Controller)
// Course: EC482 - Microprocessor Systems I
// Instructor: Dr. Mohamed M. Eljhani
// Authors: Maher Abdulnaser Alqadhi (ID: 2210249576)
//          Mohammed Nasreddin Khalaf (ID: 2210246039)
// Description: Fully integrated 8259A PIC combining RWLogic, IRR, ISR,
//              PriorityResolver, and CascadeModule.
// ============================================================================

`timescale 1ns/1ps

module PIC8259A (
    input  wire       clk,             // System clock / Strobe
    input  wire       reset,           // Active High Reset
    input  wire       VCC,             // 5V Power Supply (Simulation constant)
    input  wire       GND,             // Ground (Simulation constant)
    input  wire       CS_n,            // Chip Select (active low)
    input  wire       WR_n,            // Write Strobe (active low)
    input  wire       RD_n,            // Read Strobe (active low)
    input  wire       A0,              // Address line
    input  wire       INTA_n,          // Interrupt Acknowledge from CPU (active low)
    input  wire [7:0] IRBus,           // Interrupt Request Lines (IR7-IR0)
    input  wire       SP,              // Slave/Programmed (1 = Master, 0 = Slave)
    output reg        INT,             // Interrupt Request to CPU (active high)
    inout  wire [2:0] CASBus,          // Cascade Bus
    inout  wire [7:0] DBus             // Bidirectional Data Bus
);

    // Internal Wires & Registers
    wire [7:0] ICW1, ICW2, ICW3, ICW4;
    wire [7:0] OCW1, OCW2, OCW3;
    wire [3:0] icw_step;
    wire       init_in_progress;
    wire [1:0] read_status_sel;
    wire       eoi_pulse;
    wire [2:0] eoi_level;

    wire [7:0] irr_out;
    wire [7:0] isr_out;
    wire [2:0] highestPriority;
    wire       interruptExists;
    wire       Address_Write_Enable;
    wire [7:0] currentAddress;

    reg  [2:0] ack_level;              // Latched interrupt level during INTA sequence
    reg  [1:0] inta_state;
    reg        set_isr;
    reg        clear_irr;
    reg        clear_isr;
    reg  [2:0] clear_index;
    reg  [7:0] dbus_out;
    reg        dbus_drive;

    // Decoding Control Bits
    wire LTIM = ICW1[3];               // 0 = Edge-triggered, 1 = Level-triggered
    wire SNGL = ICW1[1];               // 0 = Cascade mode, 1 = Single mode
    wire AEOI = ICW4[1];               // 1 = Auto End-of-Interrupt

    // 1. Read/Write Control Module
    RWLogic rwLogic (
        .clk(clk),
        .reset(reset),
        .globalBus(DBus),
        .A0(A0),
        .CS_n(CS_n),
        .WR_n(WR_n),
        .RD_n(RD_n),
        .ICW1(ICW1),
        .ICW2(ICW2),
        .ICW3(ICW3),
        .ICW4(ICW4),
        .OCW1(OCW1),
        .OCW2(OCW2),
        .OCW3(OCW3),
        .icw_step(icw_step),
        .init_in_progress(init_in_progress),
        .read_status_sel(read_status_sel),
        .eoi_pulse(eoi_pulse),
        .eoi_level(eoi_level)
    );

    // 2. Interrupt Request Register (IRR)
    IRR irrModule (
        .reset(reset),
        .LTIM(LTIM),
        .IRBus(IRBus),
        .highestPriority(ack_level),
        .clear_irr(clear_irr),
        .irr(irr_out)
    );

    // 3. In-Service Register (ISR)
    ISR isrModule (
        .reset(reset),
        .set_isr(set_isr),
        .clear_isr(clear_isr),
        .clear_index(clear_index),
        .highestPriority(ack_level),
        .AddressBase(ICW2),
        .isr_reg(isr_out),
        .currentAddress(currentAddress)
    );

    // 4. Priority Resolver
    PriorityResolver priorityResolver (
        .irr(irr_out),
        .imr(OCW1),
        .isr(isr_out),
        .autoRotateMode(1'b0),          // Default fully nested mode
        .rotate_bottom(3'd7),
        .highestPriority(highestPriority),
        .interruptExists(interruptExists)
    );

    // Active interrupt or active INTA acknowledge cycle flag
    wire active_int_or_ack = interruptExists || (inta_state != 2'b00);

    // 5. Cascade Module
    CascadeModule cascadeModule (
        .SP(SP),
        .SNGL(SNGL),
        .ICW3(ICW3),
        .Interrupt_Location(ack_level),
        .interruptExists(active_int_or_ack),
        .CAS(CASBus),
        .Address_Write_Enable(Address_Write_Enable)
    );

    // Dynamic INT Line Generation
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            INT <= 1'b0;
        end else begin
            if (interruptExists && !INT) begin
                INT <= 1'b1;
            end else if (!interruptExists) begin
                INT <= 1'b0;
            end
        end
    end

    // Slave match on CAS bus
    wire slave_matched = (!SP && !SNGL) ? (CASBus == ICW3[2:0]) : 1'b0;

    // INTA Acknowledge Handshake (2-pulse sequence)
    always @(negedge INTA_n or posedge reset) begin
        if (reset) begin
            inta_state  <= 2'b00;
            ack_level   <= 3'b000;
            set_isr     <= 1'b0;
            clear_irr   <= 1'b0;
            clear_isr   <= 1'b0;
            clear_index <= 3'b000;
        end else begin
            if (inta_state == 2'b00) begin
                if (SP || slave_matched) begin
                    // INTA Pulse 1: Freeze priority, latch active interrupt level, set ISR bit, clear IRR bit
                    inta_state <= 2'b01;
                    ack_level  <= highestPriority;
                    set_isr    <= 1'b1;
                    clear_irr  <= 1'b1;
                end
            end else if (inta_state == 2'b01) begin
                // INTA Pulse 2: Vector output phase
                inta_state <= 2'b10;
                set_isr    <= 1'b0;
                clear_irr  <= 1'b0;
                if (AEOI) begin
                    clear_isr   <= 1'b1;
                    clear_index <= ack_level;
                end
            end
        end
    end

    // Allow Slave to latch on falling edge of INTA Pulse 2 if selected during Pulse 1
    always @(negedge INTA_n) begin
        if (!SP && !SNGL && inta_state == 2'b00 && slave_matched) begin
            inta_state <= 2'b01;
            ack_level  <= highestPriority;
            set_isr    <= 1'b1;
            clear_irr  <= 1'b1;
        end
    end

    always @(posedge INTA_n) begin
        if (inta_state == 2'b10) begin
            inta_state <= 2'b00;
            clear_isr  <= 1'b0;
        end
    end

    // Function to calculate highest set bit in ISR for Non-Specific EOI
    function [2:0] get_highest_isr;
        input [7:0] isr_val;
        integer k;
        begin
            get_highest_isr = 3'd0;
            for (k = 0; k < 8; k = k + 1) begin
                if (isr_val[k]) begin
                    get_highest_isr = k[2:0];
                    k = 8;
                end
            end
        end
    endfunction

    // Handling Manual EOI Command from OCW2
    always @(posedge eoi_pulse) begin
        clear_isr <= 1'b1;
        if (OCW2[6]) begin // Specific EOI (SL bit = 1)
            clear_index <= eoi_level;
        end else begin // Non-specific EOI (SL bit = 0)
            clear_index <= get_highest_isr(isr_out);
        end
    end

    // Data Bus Tristate Control & Status Readback
    assign DBus = dbus_drive ? dbus_out : 8'bzzzzzzzz;

    always @(*) begin
        dbus_drive = 1'b0;
        dbus_out   = 8'h00;

        if (!CS_n && !RD_n) begin
            dbus_drive = 1'b1;
            if (A0) begin
                // Read IMR (OCW1)
                dbus_out = OCW1;
            end else begin
                // Read Status based on OCW3 (IRR or ISR)
                if (read_status_sel == 2'b10) begin
                    dbus_out = irr_out;
                end else if (read_status_sel == 2'b11) begin
                    dbus_out = isr_out;
                end
            end
        end else if (!INTA_n && (inta_state == 2'b10 || (inta_state == 2'b01 && slave_matched)) && Address_Write_Enable) begin
            // 2nd INTA pulse: Drive interrupt vector byte
            dbus_drive = 1'b1;
            dbus_out   = currentAddress;
        end
    end

endmodule
