`timescale 1ns/1ps

// Custom-input integration testbench for existing queued_scheduler.v
// Reads up to 256 input pairs from user_tasks.hex (AABB hex per line).
module user_tasks_tb;
    parameter MAX_TASKS = 256;

    reg clk = 0;
    reg reset = 1;
    reg in_valid = 0;
    reg [7:0] a = 0;
    reg [7:0] b = 0;

    wire in_ready;
    wire [2:0] queue_count;
    wire [3:0] busy_mask;
    wire [3:0] done_mask;
    wire [35:0] results;

    queued_scheduler dut (
        .clk(clk), .reset(reset),
        .in_valid(in_valid), .in_ready(in_ready),
        .a(a), .b(b),
        .queue_count(queue_count),
        .busy_mask(busy_mask),
        .done_mask(done_mask), .results(results)
    );

    always #5 clk = ~clk;  // 10 ns period (100 MHz simulated clock)

    reg [15:0] tasks [0:MAX_TASKS-1];
    reg [8:0] expected_result [0:3];
    reg [3:0] pending = 0;
    integer worker_task [0:3];
    integer input_cycle [0:MAX_TASKS-1];

    integer n = 0;
    integer accepted = 0;
    integer dispatched = 0;
    integer completed = 0;
    integer cycle = 0;
    integer first_accept_cycle = -1;
    integer last_complete_cycle = -1;
    integer latency_sum = 0;
    integer peak_queue = 0;
    integer backpressure_cycles = 0;
    integer worker_busy_cycles = 0;
    integer w;
    integer selected_worker;
    integer id;
    integer elapsed_cycles;

    // Inspect the state *before* the active edge takes effect. Completed
    // pulses observed here were asserted by the previous clock edge.
    always @(posedge clk) begin
        if (!reset) begin
            cycle = cycle + 1;

            if (queue_count > peak_queue)
                peak_queue = queue_count;
            if (in_valid && !in_ready)
                backpressure_cycles = backpressure_cycles + 1;
            for (w = 0; w < 4; w = w + 1)
                if (busy_mask[w])
                    worker_busy_cycles = worker_busy_cycles + 1;

            if (queue_count !== (accepted - dispatched))
                $fatal(1, "Queue count mismatch");

            // Retire tasks first: a worker can finish and be selected again.
            for (w = 0; w < 4; w = w + 1) begin
                if (done_mask[w]) begin
                    if (!pending[w])
                        $fatal(1, "Unexpected worker %0d completion", w);
                    if (results[w*9 +: 9] !== expected_result[w])
                        $fatal(1, "Wrong result from worker %0d", w);
                    id = worker_task[w];
                    latency_sum = latency_sum + (cycle - 1 - input_cycle[id]);
                    completed = completed + 1;
                    last_complete_cycle = cycle - 1;
                    pending[w] = 0;
                    $display("PASS Task %0d | Worker %0d | %0d + %0d = %0d | latency %0d cycles",
                             id+1, w, tasks[id][15:8], tasks[id][7:0],
                             results[w*9 +: 9], cycle-1-input_cycle[id]);
                end
            end

            // Tasks move from the FIFO into idle workers in FIFO order.
            if (dut.fifo_valid && dut.scheduler_ready) begin
                if (dispatched >= accepted)
                    $fatal(1, "Dispatch without accepted task");
                if ({dut.fifo_a, dut.fifo_b} !== tasks[dispatched])
                    $fatal(1, "FIFO order mismatch for task %0d", dispatched+1);
                selected_worker = dut.scheduler.selected;
                if (pending[selected_worker] || busy_mask[selected_worker])
                    $fatal(1, "Dispatched to occupied worker %0d", selected_worker);
                expected_result[selected_worker] =
                    {1'b0, dut.fifo_a} + {1'b0, dut.fifo_b};
                worker_task[selected_worker] = dispatched;
                pending[selected_worker] = 1;
                dispatched = dispatched + 1;
            end

            // An incoming task is accepted only on a ready/valid handshake.
            if (in_valid && in_ready) begin
                if (accepted >= n)
                    $fatal(1, "Accepted more than %0d tasks", n);
                if ({a, b} !== tasks[accepted])
                    $fatal(1, "Input mismatch for task %0d", accepted+1);
                input_cycle[accepted] = cycle;
                if (first_accept_cycle < 0)
                    first_accept_cycle = cycle;
                accepted = accepted + 1;
            end
        end
    end

    integer i;
    reg accepted_now;
    initial begin
        if (!$value$plusargs("n=%d", n) || n < 1 || n > MAX_TASKS)
            $fatal(1, "Supply +n=NUMBER (1..%0d)", MAX_TASKS);
        $readmemh("user_tasks.hex", tasks, 0, n-1);
        $dumpfile("interactive_wave.vcd");
        $dumpvars(0, user_tasks_tb);

        repeat (2) @(negedge clk);
        reset = 0;

        // Feed pairs, holding each one stable while the FIFO is full.
        for (i = 0; i < n; i = i + 1) begin
            @(negedge clk);
            {a, b} = tasks[i];
            in_valid = 1;
            accepted_now = 0;
            while (!accepted_now) begin
                @(posedge clk);
                accepted_now = in_ready;
            end
        end
        @(negedge clk);
        in_valid = 0;

        wait(completed == n);
        @(negedge clk);
        if (accepted != n || dispatched != n ||
            queue_count != 0 || busy_mask != 0 || pending != 0)
            $fatal(1, "Some tasks missing or workers still occupied");

        elapsed_cycles = last_complete_cycle - first_accept_cycle + 1;
        $display("------------------------------------------");
        $display("ALL %0d CUSTOM TASKS PASSED", n);
        $display("Tasks accepted / dispatched / completed: %0d / %0d / %0d",
                 accepted, dispatched, completed);
        $display("Elapsed: %0d simulated cycles (%0d ns)",
                 elapsed_cycles, elapsed_cycles*10);
        $display("Average end-to-end latency: %0.2f cycles (%0.2f ns)",
                 1.0*latency_sum/completed, 10.0*latency_sum/completed);
        $display("Throughput at hypothetical 100 MHz: %0.2f million tasks/sec",
                 100.0*completed/elapsed_cycles);
        $display("Average worker utilization: %0.1f%%",
                 100.0*worker_busy_cycles/(4.0*elapsed_cycles));
        $display("Peak FIFO occupancy: %0d / 4", peak_queue);
        $display("Input backpressure: %0d cycles", backpressure_cycles);
        $display("Waveforms saved to interactive_wave.vcd");
        $finish;
    end

    initial begin
        #1000000;
        $fatal(1, "Simulation timed out");
    end
endmodule