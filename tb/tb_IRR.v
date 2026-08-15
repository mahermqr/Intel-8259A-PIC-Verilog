// ============================================================================
// Testbench: tb_IRR
// Description: Self-checking testbench for IRR module (edge and level mode).
// ============================================================================

`timescale 1ns/1ps

module tb_IRR;

    reg        reset;
    reg        LTIM;
    reg  [7:0] IRBus;
    reg  [2:0] highestPriority;
    reg        clear_irr;
    wire [7:0] irr;

    integer errors = 0;

    IRR uut (
        .reset(reset),
        .LTIM(LTIM),
        .IRBus(IRBus),
        .highestPriority(highestPriority),
        .clear_irr(clear_irr),
        .irr(irr)
    );

    initial begin
        $dumpfile("tb_IRR.vcd");
        $dumpvars(0, tb_IRR);

        // Initialize signals
        reset = 1'b1;
        LTIM = 1'b0; // Edge triggered
        IRBus = 8'b0;
        highestPriority = 3'b0;
        clear_irr = 1'b0;
        #20;

        reset = 1'b0;
        #10;

        // Test 1: Edge Triggered Latching
        $display("[TEST 1] Testing Edge-Triggered Latching...");
        IRBus[0] = 1'b1; #10;
        IRBus[3] = 1'b1; #10;
        if (irr !== 8'b00001001) begin
            $display("[FAIL] Expected IRR 8'b00001001, got %b", irr);
            errors = errors + 1;
        end else begin
            $display("[PASS] Edge-triggered latching verified: IRR = %b", irr);
        end

        // Test 2: Clear Acknowledged Interrupt
        $display("[TEST 2] Testing Clear Acknowledged Bit...");
        highestPriority = 3'd0;
        clear_irr = 1'b1; #10;
        clear_irr = 1'b0; #10;
        if (irr !== 8'b00001000) begin
            $display("[FAIL] Expected IRR 8'b00001000 after clearing bit 0, got %b", irr);
            errors = errors + 1;
        end else begin
            $display("[PASS] Clear bit 0 verified: IRR = %b", irr);
        end

        // Test 3: Level Triggered Mode
        $display("[TEST 3] Testing Level-Triggered Mode...");
        LTIM = 1'b1;
        IRBus = 8'b10101010; #10;
        if (irr !== 8'b10101010) begin
            $display("[FAIL] Expected IRR 8'b10101010 in level mode, got %b", irr);
            errors = errors + 1;
        end else begin
            $display("[PASS] Level-triggered mode verified: IRR = %b", irr);
        end

        // Final Report
        if (errors == 0) begin
            $display("========================================");
            $display("   tb_IRR: ALL TESTS PASSED SUCCESSFULLY");
            $display("========================================");
        end else begin
            $display("========================================");
            $display("   tb_IRR: FAILED WITH %d ERRORS", errors);
            $display("========================================");
        end
        $finish;
    end

endmodule
