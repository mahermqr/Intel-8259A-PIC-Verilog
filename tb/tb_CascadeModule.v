// ============================================================================
// Testbench: tb_CascadeModule
// Description: Self-checking testbench for Master/Slave Cascade arbitration.
// ============================================================================

`timescale 1ns/1ps

module tb_CascadeModule;

    // Master Signals
    reg  [2:0] master_ir_location;
    reg        master_int_exists;
    wire [2:0] cas_bus;
    wire       master_we;

    // Slave 2 Signals (Connected to Master IR2)
    wire       slave2_we;

    integer errors = 0;

    // Instantiate Master (SP = 1, SNGL = 0, ICW3 = 8'b00000100 -> Slave on IR2)
    CascadeModule master_pic (
        .SP(1'b1),
        .SNGL(1'b0),
        .ICW3(8'b00000100),
        .Interrupt_Location(master_ir_location),
        .interruptExists(master_int_exists),
        .CAS(cas_bus),
        .Address_Write_Enable(master_we)
    );

    // Instantiate Slave 2 (SP = 0, SNGL = 0, ICW3 = 8'b00000010 -> Slave ID 2)
    CascadeModule slave2_pic (
        .SP(1'b0),
        .SNGL(1'b0),
        .ICW3(8'b00000010),
        .Interrupt_Location(3'd0),
        .interruptExists(1'b1),
        .CAS(cas_bus),
        .Address_Write_Enable(slave2_we)
    );

    initial begin
        $dumpfile("tb_CascadeModule.vcd");
        $dumpvars(0, tb_CascadeModule);

        master_ir_location = 3'd0;
        master_int_exists = 1'b0;
        #20;

        // Test 1: Interrupt on IR1 (No slave attached to IR1)
        $display("[TEST 1] Interrupt on Master IR1 (Local device, no slave)...");
        master_int_exists = 1'b1;
        master_ir_location = 3'd1;
        #10;
        if (!master_we || slave2_we) begin
            $display("[FAIL] Master should have write enable=1, Slave2 should have write enable=0. Got M=%b, S2=%b", master_we, slave2_we);
            errors = errors + 1;
        end else begin
            $display("[PASS] Master correctly claims bus for local interrupt IR1");
        end

        // Test 2: Interrupt on IR2 (Slave attached to IR2)
        $display("[TEST 2] Interrupt on Master IR2 (Slave 2 attached)...");
        master_ir_location = 3'd2;
        #10;
        if (master_we || !slave2_we || cas_bus !== 3'd2) begin
            $display("[FAIL] Expected CAS=2, Master WE=0, Slave2 WE=1. Got CAS=%d, M=%b, S2=%b", cas_bus, master_we, slave2_we);
            errors = errors + 1;
        end else begin
            $display("[PASS] CAS bus driven with ID 2, Slave 2 claimed bus successfully");
        end

        // Final Report
        if (errors == 0) begin
            $display("========================================");
            $display("   tb_CascadeModule: ALL TESTS PASSED SUCCESSFULLY");
            $display("========================================");
        end else begin
            $display("========================================");
            $display("   tb_CascadeModule: FAILED WITH %d ERRORS", errors);
            $display("========================================");
        end
        $finish;
    end

endmodule
