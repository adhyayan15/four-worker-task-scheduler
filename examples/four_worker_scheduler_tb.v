
`timescale 1ns/1ps

module four_worker_scheduler_tb;

reg clk = 0;
reg reset = 1;
reg start = 0;
reg [7:0] a = 0, b = 0;

wire [8:0] result;
wire [1:0] completed_worker;
wire done;

// Connect our 4-worker scheduler
four_worker_scheduler dut (
    .clk(clk),
    .reset(reset),
    .start(start),
    .a(a),
    .b(b),
    .result(result),
    .completed_worker(completed_worker),
    .done(done)
);

// Clock: 10 ns period
always #5 clk = ~clk;

// Send a task and verify its result
task test_task;
    input [7:0] x, y;
    input [1:0] expected_worker;
    reg [8:0] expected_result;
    begin
        expected_result = {1'b0, x} + {1'b0, y};

        @(negedge clk);
        a = x;
        b = y;
        start = 1;

        @(posedge clk);
        #1;

        if (done === 1'b1 &&
            result === expected_result &&
            completed_worker === expected_worker)
            $display("PASS: Worker %0d | %0d + %0d = %0d",
                     completed_worker, x, y, result);
        else begin
            $display("FAIL: Expected worker %0d, result %0d",
                     expected_worker, expected_result);
            $fatal(1, "Scheduler test failed");
        end

        @(negedge clk);
        start = 0;
    end
endtask

initial begin
    $dumpfile("scheduler_wave.vcd");
    $dumpvars(0, four_worker_scheduler_tb);

    @(negedge clk);
    reset = 0;

    test_task(15, 20, 0);
    test_task(80, 40, 1);
    test_task(200, 100, 2);
    test_task(255, 255, 3);
    test_task(6, 9, 0);

    $display("ALL 5 TESTS PASSED!");
    $finish;
end

endmodule