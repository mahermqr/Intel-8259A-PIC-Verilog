// ============================================================================
// Testbench: tb_PIC8259A_cascade
// Description: Full Cascaded System Testbench (1 Master PIC + 1 Slave PIC).
//              Verifies multi-PIC coordination over 3-bit CAS bus and shared DBus.
// ============================================================================

`timescale 1ns/1ps

module tb_PIC8259A_cascade;

    reg        clk;
    reg        reset;
    reg        CS_master_n;
    reg        CS_slave2_n;
    reg        WR_n;
    reg        RD_n;
    reg        A0;
    reg        INTA_n;

    reg  [7:0] Master_IRBus;
    reg  [7:0] Slave2_IRBus;

    wire       Master_INT;
    wire       Slave2_INT;

    wire [2:0] CASBus;
    wire [7:0] DBus;

    reg  [7:0] dbus_drive_reg;
    reg        dbus_oe;

    assign DBus = dbus_oe ? dbus_drive_reg : 8'bzzzzzzzz;

    // Connect Slave 2 INT output to Master IR2 line!
    wire [7:0] master_ir_inputs;
    assign master_ir_inputs[0] = Master_IRBus[0];
    assign master_ir_inputs[1] = Master_IRBus[1];
    assign master_ir_inputs[2] = Slave2_INT; // Cascade connection!
    assign master_ir_inputs[7:3] = Master_IRBus[7:3];

    integer errors = 0;

    // Master PIC
    PIC8259A MasterPIC (
        .clk(clk),
        .reset(reset),
        .VCC(1'b1),
        .GND(1'b0),
        .CS_n(CS_master_n),
        .WR_n(WR_n),
        .RD_n(RD_n),
        .A0(A0),
        .INTA_n(INTA_n),
        .IRBus(master_ir_inputs),
        .SP(1'b1), // Master mode
        .INT(Master_INT),
        .CASBus(CASBus),
        .DBus(DBus)
    );

    // Slave 2 PIC
    PIC8259A Slave2PIC (
        .clk(clk),
        .reset(reset),
        .VCC(1'b1),
        .GND(1'b0),
        .CS_n(CS_slave2_n),
        .WR_n(WR_n),
        .RD_n(RD_n),
        .A0(A0),
        .INTA_n(INTA_n),
        .IRBus(Slave2_IRBus),
        .SP(1'b0), // Slave mode
        .INT(Slave2_INT),
        .CASBus(CASBus),
        .DBus(DBus)
    );

    always #5 clk = ~clk;

    task write_master;
        input addr;
        input [7:0] data;
        begin
            A0 = addr;
            dbus_drive_reg = data;
            dbus_oe = 1'b1;
            CS_master_n = 1'b0;
            WR_n = 1'b0;
            #10;
            WR_n = 1'b1;
            CS_master_n = 1'b1;
            dbus_oe = 1'b0;
            #10;
        end
    endtask

    task write_slave2;
        input addr;
        input [7:0] data;
        begin
            A0 = addr;
            dbus_drive_reg = data;
            dbus_oe = 1'b1;
            CS_slave2_n = 1'b0;
            WR_n = 1'b0;
            #10;
            WR_n = 1'b1;
            CS_slave2_n = 1'b1;
            dbus_oe = 1'b0;
            #10;
        end
    endtask

    reg [7:0] read_val;

    initial begin
        $dumpfile("tb_PIC8259A_cascade.vcd");
        $dumpvars(0, tb_PIC8259A_cascade);

        clk = 1'b0;
        reset = 1'b1;
        CS_master_n = 1'b1;
        CS_slave2_n = 1'b1;
        WR_n = 1'b1;
        RD_n = 1'b1;
        A0 = 1'b0;
        INTA_n = 1'b1;
        Master_IRBus = 8'b0;
        Slave2_IRBus = 8'b0;
        dbus_oe = 1'b0;
        dbus_drive_reg = 8'b0;
        #20;

        reset = 1'b0;
        #20;

        // 1. Program Master PIC (Base Vector 0x20, Slave on IR2)
        $display("[STEP 1] Initializing Master PIC (Base Vector 0x20, Slave on IR2)...");
        write_master(1'b0, 8'h11); // ICW1: Edge, Cascade, ICW4 needed
        write_master(1'b1, 8'h20); // ICW2: Vector Base 0x20
        write_master(1'b1, 8'h04); // ICW3: Slave attached on IR2
        write_master(1'b1, 8'h01); // ICW4: 8086 Mode

        // 2. Program Slave 2 PIC (Base Vector 0x28, ID 2)
        $display("[STEP 2] Initializing Slave 2 PIC (Base Vector 0x28, Slave ID 2)...");
        write_slave2(1'b0, 8'h11); // ICW1: Edge, Cascade, ICW4 needed
        write_slave2(1'b1, 8'h28); // ICW2: Vector Base 0x28
        write_slave2(1'b1, 8'h02); // ICW3: Slave ID = 2
        write_slave2(1'b1, 8'h01); // ICW4: 8086 Mode
        #20;

        // 3. Trigger Interrupt on Master Local Pin IR1
        $display("[STEP 3] Triggering Interrupt on Master IR1 (Local Pin)...");
        Master_IRBus[1] = 1'b1;
        #20;

        if (!Master_INT) begin
            $display("[FAIL] Master INT line not raised for local IR1!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Master INT raised successfully");
        end

        // Execute INTA for Master Local IR1
        INTA_n = 1'b0; #10; INTA_n = 1'b1; #10; // Pulse 1
        INTA_n = 1'b0; #10; read_val = DBus; INTA_n = 1'b1; #10; // Pulse 2

        if (read_val !== 8'h21) begin
            $display("[FAIL] Expected Master Vector 0x21, got 0x%h", read_val);
            errors = errors + 1;
        end else begin
            $display("[PASS] Master vector 0x21 successfully driven to CPU bus");
        end

        write_master(1'b0, 8'h20); // EOI Master
        Master_IRBus[1] = 1'b0;
        #20;

        // 4. Trigger Interrupt on Slave 2 Pin IR4
        $display("[STEP 4] Triggering Interrupt on Slave 2 IR4...");
        Slave2_IRBus[4] = 1'b1;
        #20;

        if (!Slave2_INT) begin
            $display("[FAIL] Slave2 INT line not raised!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Slave2 INT line raised successfully to Master IR2");
        end

        if (!Master_INT) begin
            $display("[FAIL] Master INT line not raised via cascaded Slave2 INT!");
            errors = errors + 1;
        end else begin
            $display("[PASS] Master INT raised via cascaded Slave2 input");
        end

        // Execute INTA for Cascaded Slave 2 IR4
        $display("[STEP 5] Executing CPU INTA sequence for Cascaded Slave 2...");
        INTA_n = 1'b0; #10; INTA_n = 1'b1; #10; // Pulse 1: Master drives CAS = 2
        INTA_n = 1'b0; #10; read_val = DBus; INTA_n = 1'b1; #10; // Pulse 2: Slave 2 drives vector 0x2C

        if (read_val !== 8'h2C) begin // Base 0x28 + Level 4 = 0x2C
            $display("[FAIL] Expected Slave2 Vector 0x2C, got 0x%h", read_val);
            errors = errors + 1;
        end else begin
            $display("[PASS] Cascaded Slave 2 vector 0x2C successfully driven to CPU bus!");
        end

        // EOI for both Slave and Master
        write_slave2(1'b0, 8'h20);
        write_master(1'b0, 8'h20);
        #20;

        // Final Report
        if (errors == 0) begin
            $display("========================================");
            $display("   tb_PIC8259A_cascade: ALL CASCADE TESTS PASSED");
            $display("========================================");
        end else begin
            $display("========================================");
            $display("   tb_PIC8259A_cascade: FAILED WITH %d ERRORS", errors);
            $display("========================================");
        end
        $finish;
    end

endmodule
