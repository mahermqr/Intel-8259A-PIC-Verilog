// ============================================================================
// Testbench: tb_PriorityResolver
// Description: Self-checking testbench for PriorityResolver module.
// ============================================================================

`timescale 1ns/1ps

module tb_PriorityResolver;

    reg  [7:0] irr;
    reg  [7:0] imr;
    reg  [7:0] isr;
    reg        autoRotateMode;
    reg  [2:0] rotate_bottom;
    wire [2:0] highestPriority;
    wire       interruptExists;

    integer errors = 0;

    PriorityResolver uut (
        .irr(irr),
        .imr(imr),
        .isr(isr),
        .autoRotateMode(autoRotateMode),
        .rotate_bottom(rotate_bottom),
        .highestPriority(highestPriority),
        .interruptExists(interruptExists)
    );

    initial begin
        $dumpfile("tb_PriorityResolver.vcd");
        $dumpvars(0, tb_PriorityResolver);

        irr = 8'b0;
        imr = 8'b0;
        isr = 8'b0;
        autoRotateMode = 1'b0;
        rotate_bottom = 3'd7;
        #10;

        // Test 1: Fully Nested Priority (IR0 and IR5 active -> IR0 wins)
        $display("[TEST 1] Fully Nested Mode: IR0 and IR5 active...");
        irr = 8'b00100001; #10;
        if (highestPriority !== 3'd0 || !interruptExists) begin
            $display("[FAIL] Expected highestPriority=0, interruptExists=1, got %d, %b", highestPriority, interruptExists);
            errors = errors + 1;
        end else begin
            $display("[PASS] IR0 correctly selected over IR5");
        end

        // Test 2: Masking IR0 (IR0 masked -> IR5 selected)
        $display("[TEST 2] Masking IR0...");
        imr = 8'b00000001; #10;
        if (highestPriority !== 3'd5 || !interruptExists) begin
            $display("[FAIL] Expected highestPriority=5 after masking IR0, got %d", highestPriority);
            errors = errors + 1;
        end else begin
            $display("[PASS] IR5 selected after masking IR0");
        end

        // Test 3: Auto-Rotating Mode
        $display("[TEST 3] Auto-Rotating Mode with rotate_bottom = 2...");
        autoRotateMode = 1'b1;
        rotate_bottom = 3'd2; // Highest priority is 3
        imr = 8'b0;
        irr = 8'b00000111; #10; // IR0, IR1, IR2 active
        if (highestPriority !== 3'd0) begin
            $display("[FAIL] Expected highestPriority=0 (next after 2), got %d", highestPriority);
            errors = errors + 1;
        end else begin
            $display("[PASS] Rotating priority correctly selected index 0");
        end

        // Final Report
        if (errors == 0) begin
            $display("========================================");
            $display("   tb_PriorityResolver: ALL TESTS PASSED SUCCESSFULLY");
            $display("========================================");
        end else begin
            $display("========================================");
            $display("   tb_PriorityResolver: FAILED WITH %d ERRORS", errors);
            $display("========================================");
        end
        $finish;
    end

endmodule
