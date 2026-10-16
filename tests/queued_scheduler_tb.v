
`timescale 1ns/1ps

module queued_scheduler_tb;

parameter TASKS = 20;

reg clk = 0;
reg reset = 1;
reg in_valid = 0;
reg [7:0] a = 0, b = 0;

wire in_ready;
wire [2:0] queue_count;
wire [3:0] busy_mask, done_mask;
wire [35:0] results;

// Complete system
queued_scheduler dut (
    .clk(clk),
    .reset(reset),
    .in_valid(in_valid),
    .in_ready(in_ready),
    .a(a),
    .b(b),
    .queue_count(queue_count),
    .busy_mask(busy_mask),
    .done_mask(done_mask),
    .results(results)
);

always #5 clk = ~clk;

// Reference data for verification
reg [15:0] expected_queue [0:TASKS-1];
reg [8:0] expected_result [0:3];
reg [3:0] pending = 0;

integer accepted = 0;
integer dispatched = 0;
integer completed = 0;
integer worker_uses [0:3];
integer i, w;

reg saw_parallel = 0;
reg saw_backpressure = 0;
reg saw_reuse = 0;

initial begin
    for (integer j = 0; j < 4; j = j + 1)
        worker_uses[j] = 0;
end

// Monitor every clock cycle
always @(posedge clk) begin
    if (!reset) begin

        // Check FIFO occupancy
        if (queue_count !== (accepted - dispatched))
            $fatal(1, "FAIL: FIFO count mismatch");

        if (busy_mask == 4'b1111)
            saw_parallel = 1;

        if (in_valid && !in_ready)
            saw_backpressure = 1;

        // Check completed tasks
        for (w = 0; w < 4; w = w + 1) begin
            if (done_mask[w]) begin
                if (!pending[w])
                    $fatal(1, "FAIL: Unexpected completion");

                if (results[w*9 +: 9] !==
                    expected_result[w])
                    $fatal(1, "FAIL: Incorrect result");

                pending[w] = 0;
                completed = completed + 1;

                $display("PASS: Worker %0d completed %0d",
                         w, results[w*9 +: 9]);
            end
        end

        // Verify FIFO order and worker assignment
        if (dut.fifo_valid && dut.scheduler_ready) begin

            if (dispatched >= accepted)
                $fatal(1, "FAIL: Unexpected task");

            if ({dut.fifo_a, dut.fifo_b} !==
                expected_queue[dispatched])
                $fatal(1, "FAIL: FIFO ordering");

            w = dut.scheduler.selected;

            if (busy_mask[w] || pending[w])
                $fatal(1, "FAIL: Busy worker selected");

            expected_result[w] =
                {1'b0, dut.fifo_a} + {1'b0, dut.fifo_b};

            pending[w] = 1;
            worker_uses[w] = worker_uses[w] + 1;

            if (worker_uses[w] > 1)
                saw_reuse = 1;

            dispatched = dispatched + 1;
        end

        // Record newly accepted tasks
        if (in_valid && in_ready) begin
            if (accepted >= TASKS)
                $fatal(1, "FAIL: Too many tasks");

            expected_queue[accepted] = {a, b};
            accepted = accepted + 1;
        end
    end
end

// Generate 20 incoming tasks
initial begin
    $dumpfile("queued_wave.vcd");
    $dumpvars(0, queued_scheduler_tb);

    repeat (2) @(negedge clk);
    reset = 0;

    for (i = 0; i < TASKS; i = i + 1) begin
        @(negedge clk);

        a = i * 17;
        b = i * 29 + 13;
        in_valid = 1;

        // Hold task until FIFO accepts it
        begin : wait_for_acceptance
            reg accepted_now;
            accepted_now = 0;

            while (!accepted_now) begin
                @(posedge clk);
                accepted_now = in_ready;
            end
        end
    end

    @(negedge clk);
    in_valid = 0;

    // Wait until every task finishes
    wait(completed == TASKS);
    @(negedge clk);

    if (accepted != TASKS ||
        dispatched != TASKS ||
        queue_count != 0 ||
        busy_mask != 0 ||
        pending != 0)
        $fatal(1, "FAIL: Tasks missing");

    if (!saw_parallel)
        $fatal(1, "FAIL: No parallel execution");

    if (!saw_backpressure)
        $fatal(1, "FAIL: Backpressure not tested");

    if (!saw_reuse)
        $fatal(1, "FAIL: Workers never reused");

    $display("----------------------------");
    $display("Tasks accepted: %0d", accepted);
    $display("Tasks dispatched: %0d", dispatched);
    $display("Tasks completed: %0d", completed);
    $display("ALL INTEGRATION TESTS PASSED!");
    $finish;
end

// Prevent infinite simulation
initial begin
    #5000;
    $fatal(1, "FAIL: Simulation timeout");
end

endmodule