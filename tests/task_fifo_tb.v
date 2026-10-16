
`timescale 1ns/1ps

module task_fifo_tb;

reg clk = 0;
reg reset = 1;
reg in_valid = 0;
reg out_ready = 0;
reg [7:0] in_a = 0, in_b = 0;

wire in_ready, out_valid;
wire [7:0] out_a, out_b;
wire [2:0] count;

task_fifo dut (
    .clk(clk),
    .reset(reset),
    .in_valid(in_valid),
    .in_ready(in_ready),
    .in_a(in_a),
    .in_b(in_b),
    .out_valid(out_valid),
    .out_ready(out_ready),
    .out_a(out_a),
    .out_b(out_b),
    .count(count)
);

always #5 clk = ~clk;

// Reference queue for automatic verification
reg [15:0] expected [0:31];
integer head = 0;
integer tail = 0;
integer used = 0;
integer tests = 0;

// Execute and verify one clock cycle
task step;
    input v, r;
    input [7:0] x, y;
    reg push, pop;
    begin
        @(negedge clk);
        in_valid = v;
        out_ready = r;
        in_a = x;
        in_b = y;

        #1;

        if (in_ready !== (used < 4))
            $fatal(1, "FAIL: Incorrect input ready");

        if (out_valid !== (used > 0))
            $fatal(1, "FAIL: Incorrect output valid");

        if (used > 0 &&
            {out_a, out_b} !== expected[head])
            $fatal(1, "FAIL: FIFO order incorrect");

        push = in_valid && in_ready;
        pop = out_valid && out_ready;

        @(posedge clk);
        #1;

        if (push) begin
            expected[tail] = {x, y};
            tail = tail + 1;
        end

        if (pop)
            head = head + 1;

        used = used + push - pop;

        if (count !== used[2:0])
            $fatal(1, "FAIL: Incorrect queue count");

        tests = tests + 1;
        $display("PASS: Cycle %0d | Queue count = %0d",
                 tests, count);
    end
endtask

initial begin
    $dumpfile("fifo_wave.vcd");
    $dumpvars(0, task_fifo_tb);

    @(posedge clk);
    #1;
    if (count !== 0)
        $fatal(1, "FAIL: Reset");

    @(negedge clk);
    reset = 0;

    // Fill all four queue positions
    step(1, 0, 10, 20);
    step(1, 0, 30, 40);
    step(1, 0, 50, 60);
    step(1, 0, 70, 80);

    $display("PASS: Queue filled");

    // Queue full: new task must be rejected
    step(1, 0, 99, 99);
    if (count !== 4)
        $fatal(1, "FAIL: Overflow");

    $display("PASS: Overflow prevented");

    // Full queue: remove oldest task
    step(1, 1, 90, 100);

    // Simultaneous insertion and removal
    step(1, 1, 110, 120);
    step(1, 1, 130, 140);

    $display("PASS: Simultaneous push/pop");

    // Drain the remaining tasks
    step(0, 1, 0, 0);
    step(0, 1, 0, 0);
    step(0, 1, 0, 0);

    // Attempt to read an empty queue
    step(0, 1, 0, 0);

    if (count !== 0)
        $fatal(1, "FAIL: Queue not empty");

    $display("PASS: Queue empty");
    $display("ALL FIFO TESTS PASSED!");

    $finish;
end

endmodule