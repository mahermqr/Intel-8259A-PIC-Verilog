// ============================================================================
// Testbench: tb_RWLogic
// Description: Self-checking testbench for RWLogic initialization and command decoding.
// ============================================================================

`timescale 1ns/1ps

module tb_RWLogic;

    reg        clk;
    reg        reset;
    reg  [7:0] globalBus;
    reg        A0;
    reg        CS_n;
    reg        WR_n;
    reg        RD_n;

    wire [7:0] ICW1, ICW2, ICW3, ICW4;
    wire [7:0] OCW1, OCW2, OCW3;
    wire [3:0] icw_step;
    wire       init_in_progress;
    wire [1:0] read_status_sel;
    wire       eoi_pulse;
    wire [2:0] eoi_level;

    integer errors = 0;
    reg eoi_seen;

    RWLogic uut (
        .clk(clk),
        .reset(reset),
        .globalBus(globalBus),
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

    // Clock generator
    always #5 clk = ~clk;

    always @(posedge eoi_pulse) begin
        eoi_seen <= 1'b1;
    end

    task write_reg;
        input addr;
        input [7:0] data;
        begin
            A0 = addr;
            globalBus = data;
            CS_n = 1'b0;
            WR_n = 1'b0;
            #10;
            WR_n = 1'b1;
            CS_n = 1'b1;
            #10;
        end
    endtask

    initial begin
        $dumpfile("tb_RWLogic.vcd");
        $dumpvars(0, tb_RWLogic);

        clk = 1'b0;
        reset = 1'b1;
        eoi_seen = 1'b0;
        A0 = 1'b0;
        CS_n = 1'b1;
        WR_n = 1'b1;
        RD_n = 1'b1;
        globalBus = 8'b0;
        #20;

        reset = 1'b0;
        #10;

        // Test 1: Program ICW1-ICW4 in Cascade Mode
        $display("[TEST 1] Programming ICW1-ICW4 Sequence (Cascade Mode)...");
        write_reg(1'b0, 8'h11); // ICW1: Edge, Cascade (SNGL=0), IC4=1
        write_reg(1'b1, 8'h20); // ICW2: Base 0x20
        write_reg(1'b1, 8'h04); // ICW3: Master slave on IR2
        write_reg(1'b1, 8'h01); // ICW4: 8086 mode

        if (ICW1 !== 8'h11 || ICW2 !== 8'h20 || ICW3 !== 8'h04 || ICW4 !== 8'h01) begin
            $display("[FAIL] ICW mismatch! ICW1=%h ICW2=%h ICW3=%h ICW4=%h", ICW1, ICW2, ICW3, ICW4);
            errors = errors + 1;
        end else begin
            $display("[PASS] ICW1-ICW4 initialization sequence programmed correctly");
        end

        // Test 2: Write OCW1 (IMR)
        $display("[TEST 2] Writing OCW1 (IMR = 0x0F)...");
        write_reg(1'b1, 8'h0F);
        if (OCW1 !== 8'h0F) begin
            $display("[FAIL] Expected OCW1 = 0x0F, got 0x%h", OCW1);
            errors = errors + 1;
        end else begin
            $display("[PASS] OCW1 (IMR) written successfully");
        end

        // Test 3: Write OCW2 (Non-Specific EOI)
        $display("[TEST 3] Writing OCW2 (EOI Command)...");
        eoi_seen = 1'b0;
        write_reg(1'b0, 8'h20); // Non-specific EOI (0010_0000)
        #5;
        if (!eoi_seen) begin
            $display("[FAIL] Expected eoi_pulse to be detected!");
            errors = errors + 1;
        end else begin
            $display("[PASS] OCW2 EOI pulse generated and detected successfully");
        end

        // Final Report
        if (errors == 0) begin
            $display("========================================");
            $display("   tb_RWLogic: ALL TESTS PASSED SUCCESSFULLY");
            $display("========================================");
        end else begin
            $display("========================================");
            $display("   tb_RWLogic: FAILED WITH %d ERRORS", errors);
            $display("========================================");
        end
        $finish;
    end

endmodule
