// ============================================================================
// Testbench: tb_ISR
// Description: Self-checking testbench for ISR module.
// ============================================================================

`timescale 1ns/1ps

module tb_ISR;

    reg        reset;
    reg        set_isr;
    reg        clear_isr;
    reg  [2:0] clear_index;
    reg  [2:0] highestPriority;
    reg  [7:0] AddressBase;
    wire [7:0] isr_reg;
    wire [7:0] currentAddress;

    integer errors = 0;

    ISR uut (
        .reset(reset),
        .set_isr(set_isr),
        .clear_isr(clear_isr),
        .clear_index(clear_index),
        .highestPriority(highestPriority),
        .AddressBase(AddressBase),
        .isr_reg(isr_reg),
        .currentAddress(currentAddress)
    );

    initial begin
        $dumpfile("tb_ISR.vcd");
        $dumpvars(0, tb_ISR);

        reset = 1'b1;
        set_isr = 1'b0;
        clear_isr = 1'b0;
        clear_index = 3'b0;
        highestPriority = 3'b0;
        AddressBase = 8'h20; // Vector base 0x20
        #20;

        reset = 1'b0;
        #10;

        // Test 1: Set ISR Bit 2 and check Address
        $display("[TEST 1] Setting ISR bit 2 with AddressBase = 0x20...");
        highestPriority = 3'd2;
        set_isr = 1'b1; #10;
        set_isr = 1'b0; #10;

        if (isr_reg !== 8'b00000100) begin
            $display("[FAIL] Expected isr_reg 8'b00000100, got %b", isr_reg);
            errors = errors + 1;
        end else begin
            $display("[PASS] isr_reg bit 2 set correctly: %b", isr_reg);
        end

        if (currentAddress !== 8'h22) begin
            $display("[FAIL] Expected vector address 0x22, got 0x%h", currentAddress);
            errors = errors + 1;
        end else begin
            $display("[PASS] Vector address calculated correctly: 0x%h", currentAddress);
        end

        // Test 2: Clear ISR Bit 2 (EOI)
        $display("[TEST 2] Clearing ISR bit 2 (EOI)...");
        clear_index = 3'd2;
        clear_isr = 1'b1; #10;
        clear_isr = 1'b0; #10;

        if (isr_reg !== 8'b00000000) begin
            $display("[FAIL] Expected isr_reg 0x00 after EOI, got %b", isr_reg);
            errors = errors + 1;
        end else begin
            $display("[PASS] EOI cleared ISR bit 2 successfully");
        end

        // Final Report
        if (errors == 0) begin
            $display("========================================");
            $display("   tb_ISR: ALL TESTS PASSED SUCCESSFULLY");
            $display("========================================");
        end else begin
            $display("========================================");
            $display("   tb_ISR: FAILED WITH %d ERRORS", errors);
            $display("========================================");
        end
        $finish;
    end

endmodule
