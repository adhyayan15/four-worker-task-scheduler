
`timescale 1ns/1ps

module parallel_scheduler_tb;

reg clk = 0;
reg reset = 1;
reg valid = 0;
reg [7:0] a = 0, b = 0;

wire ready;
wire [3:0] busy_mask;
wire [3:0] done_mask;
wire [35:0] results;

// Connect the parallel scheduler
parallel_scheduler dut (
    .clk(clk),
    .reset(reset),
    .valid(valid),
    .a(a),
    .b(b),
    .ready(ready),
    .busy_mask(busy_mask),
    .done_mask(done_mask),
    .results(results)
);

// Clock period = 10 ns
always #5 clk = ~clk;

// Send a task to an available worker
task send_task;
    input [7:0] x, y;
    input [3:0] expected_busy;
    begin
        @(negedge clk);
        a = x;
        b = y;
        valid = 1;

        #1;
        if (ready !== 1'b1)
            $fatal(1, "FAIL: Scheduler not ready");

        @(posedge clk);
        #1;

        if (busy_mask !== expected_busy)
            $fatal(1, "FAIL: Incorrect busy mask");

        $display("PASS: Task %0d + %0d accepted", x, y);
    end
endtask

initial begin
    $dumpfile("parallel_wave.vcd");
    $dumpvars(0, parallel_scheduler_tb);

    // Release reset
    @(negedge clk);
    reset = 0;

    // Send four tasks on consecutive clock cycles
    send_task(15, 20, 4'b0001);
    send_task(80, 40, 4'b0011);
    send_task(200, 100, 4'b0111);
    send_task(255, 255, 4'b1111);

    $display("PASS: All four workers busy simultaneously");

    // Try sending another task while all are busy
    @(negedge clk);
    a = 7;
    b = 8;
    valid = 1;

    #1;
    if (ready !== 0)
        $fatal(1, "FAIL: Scheduler accepted extra task");

    @(posedge clk);
    #1;
    if (busy_mask !== 4'b1111)
        $fatal(1, "FAIL: Busy mask changed unexpectedly");

    $display("PASS: Extra task blocked");

    // Withdraw the unaccepted task
    @(negedge clk);
    valid = 0;

    // Verify each completed result
    wait(done_mask[0]);
    #1;
    if (results[8:0] !== 9'd35)
        $fatal(1, "Worker 0 incorrect");
    $display("PASS: Worker 0 result = 35");

    wait(done_mask[1]);
    #1;
    if (results[17:9] !== 9'd120)
        $fatal(1, "Worker 1 incorrect");
    $display("PASS: Worker 1 result = 120");

    wait(done_mask[2]);
    #1;
    if (results[26:18] !== 9'd300)
        $fatal(1, "Worker 2 incorrect");
    $display("PASS: Worker 2 result = 300");

    wait(done_mask[3]);
    #1;
    if (results[35:27] !== 9'd510)
        $fatal(1, "Worker 3 incorrect");
    $display("PASS: Worker 3 result = 510");

    // Verify a worker can be reused
    send_task(6, 9, 4'b0001);

    @(negedge clk);
    valid = 0;

    wait(done_mask[0]);
    #1;
    if (results[8:0] !== 9'd15)
        $fatal(1, "Worker reuse failed");

    $display("PASS: Worker 0 reused successfully");
    $display("ALL TESTS PASSED!");

    $finish;
end

endmodule