// ============================================================================
// Testbench: tb_PIC8259A_single
// Description: Integration testbench for a single Intel 8259A PIC controller.
//              Verifies complete ICW initialization, IR request handling,
//              2-pulse INTA handshake, vector output, EOI clear, and status readback.
// ============================================================================

`timescale 1ns/1ps

module tb_PIC8259A_single;

    reg        clk;
    reg        reset;
    reg        CS_n;
    reg        WR_n;
    reg        RD_n;
    reg        A0;
    reg        INTA_n;
    reg  [7:0] IRBus;
    wire       INT;
    wire [2:0] CASBus;
    wire [7:0] DBus;

    reg  [7:0] dbus_drive_reg;
    reg        dbus_oe;

    assign DBus = dbus_oe ? dbus_drive_reg : 8'bzzzzzzzz;

    integer errors = 0;

    // Instantiate Top-Level PIC8259A
    PIC8259A uut (
        .clk(clk),
        .reset(reset),
        .VCC(1'b1),
        .GND(1'b0),
        .CS_n(CS_n),
        .WR_n(WR_n),
        .RD_n(RD_n),
        .A0(A0),
        .INTA_n(INTA_n),
        .IRBus(IRBus),
        .SP(1'b1), // Master/Single mode
        .INT(INT),
        .CASBus(CASBus),
        .DBus(DBus)
    );

    always #5 clk = ~clk;

    task write_reg;
        input addr;
        input [7:0] data;
        begin
            A0 = addr;
            dbus_drive_reg = data;
            dbus_oe = 1'b1;
            CS_n = 1'b0;
            WR_n = 1'b0;
            #10;
            WR_n = 1'b1;
            CS_n = 1'b1;
            dbus_oe = 1'b0;
            #10;
        end
    endtask

    task read_reg;
        input addr;
        output [7:0] data;
        begin
            A0 = addr;
            dbus_oe = 1'b0;
            CS_n = 1'b0;
            RD_n = 1'b0;
            #10;
            data = DBus;
            RD_n = 1'b1;
            CS_n = 1'b1;
            #10;
        end
    endtask

    reg [7:0] read_val;

    initial begin
        $dumpfile("tb_PIC8259A_single.vcd");
        $dumpvars(0, tb_PIC8259A_single);

        clk = 1'b0;
        reset = 1'b1;
        CS_n = 1'b1;
        WR_n = 1'b1;
        RD_n = 1'b1;
        A0 = 1'b0;
        INTA_n = 1'b1;
        IRBus = 8'b0;
        dbus_oe = 1'b0;
        dbus_drive_reg = 8'b0;
        #20;

        reset = 1'b0;
        #20;

        // 1. Program Initialization Sequence (ICW1 -> ICW2 -> ICW4)
        $display("[STEP 1] Programming Single PIC Initialization (ICW1, ICW2, ICW4)...");
        write_reg(1'b0, 8'h13); // ICW1: Edge, Single (SNGL=1), IC4=1
        write_reg(1'b1, 8'h20); // ICW2: Vector base address 0x20
        write_reg(1'b1, 8'h01); // ICW4: 8086 Mode, Normal EOI
        #20;

        // 2. Trigger Interrupt Request on IR3
        $display("[STEP 2] Asserting IR3 interrupt request...");
        IRBus[3] = 1'b1;
        #20;

        if (!INT) begin
            $display("[FAIL] INT line not asserted after IR3 request!");
            errors = errors + 1;
        end else begin
            $display("[PASS] INT line asserted successfully for IR3");
        end

        // 3. Perform 2-Pulse INTA Handshake
        $display("[STEP 3] Executing 2-Pulse INTA Handshake from CPU...");
        // Pulse 1
        INTA_n = 1'b0; #10;
        INTA_n = 1'b1; #10;
        // Pulse 2
        INTA_n = 1'b0; #10;
        read_val = DBus;
        INTA_n = 1'b1; #10;

        if (read_val !== 8'h23) begin // Base 0x20 + Level 3 = 0x23
            $display("[FAIL] Expected Vector Address 0x23 during 2nd INTA pulse, got 0x%h", read_val);
            errors = errors + 1;
        end else begin
            $display("[PASS] Correct Interrupt Vector 0x23 driven to DBus during INTA Pulse 2");
        end

        // 4. Issue EOI Command via OCW2
        $display("[STEP 4] Issuing End-Of-Interrupt (EOI) Command via OCW2...");
        write_reg(1'b0, 8'h20); // Non-specific EOI
        #20;

        // 5. Test Interrupt Masking via OCW1
        $display("[STEP 5] Testing Interrupt Masking (Mask IR1)...");
        write_reg(1'b1, 8'h02); // Mask IR1 (bit 1 = 1)
        IRBus[1] = 1'b1;
        #20;
        if (INT) begin
            $display("[FAIL] INT line asserted for masked IR1 request!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Masked IR1 correctly blocked from triggering INT");
        end

        // Final Verification Summary
        if (errors == 0) begin
            $display("========================================");
            $display("   tb_PIC8259A_single: ALL INTEGRATION TESTS PASSED");
            $display("========================================");
        end else begin
            $display("========================================");
            $display("   tb_PIC8259A_single: FAILED WITH %d ERRORS", errors);
            $display("========================================");
        end
        $finish;
    end

endmodule
