
`timescale 1ns/1ps

module busy_worker_tb;

reg clk = 0;
reg reset = 1;
reg start = 0;
reg [7:0] a = 0, b = 0;

wire [8:0] result;
wire busy, done;

// Connect our worker
busy_worker #(.LATENCY(3)) dut (
    .clk(clk),
    .reset(reset),
    .start(start),
    .a(a),
    .b(b),
    .result(result),
    .busy(busy),
    .done(done)
);

// Clock period = 10 ns
always #5 clk = ~clk;

initial begin
    $dumpfile("busy_worker.vcd");
    $dumpvars(0, busy_worker_tb);

    // Release reset and send first task
    @(negedge clk);
    reset = 0;
    a = 15;
    b = 20;
    start = 1;

    @(posedge clk);
    #1;
    if (busy !== 1 || done !== 0)
        $fatal(1, "FAIL: Worker did not become busy");

    $display("PASS: Worker accepted task");

    // Try sending another task while busy
    @(negedge clk);
    a = 200;
    b = 200;

    repeat (2) begin
        @(posedge clk);
        #1;
        if (busy !== 1 || done !== 0)
            $fatal(1, "FAIL: Worker finished too early");
    end

    $display("PASS: Worker stayed busy");

    // Third processing cycle: result becomes ready
    @(posedge clk);
    #1;

    if (done !== 1 || busy !== 0 ||
        result !== 9'd35)
        $fatal(1, "FAIL: Incorrect first result");

    $display("PASS: Busy task ignored");
    $display("PASS: Result = %0d", result);

    // Stop sending tasks
    @(negedge clk);
    start = 0;

    @(posedge clk);
    #1;
    if (done !== 0)
        $fatal(1, "FAIL: Done did not clear");

    // Send a second task
    @(negedge clk);
    a = 200;
    b = 100;
    start = 1;

    @(posedge clk);
    #1;

    @(negedge clk);
    start = 0;

    repeat (3) @(posedge clk);
    #1;

    if (done !== 1 || busy !== 0 ||
        result !== 9'd300)
        $fatal(1, "FAIL: Second task incorrect");

    $display("PASS: Second result = %0d", result);
    $display("ALL TESTS PASSED!");

    $finish;
end

endmodule