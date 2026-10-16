
module queued_scheduler (
    input wire clk,
    input wire reset,

    // Incoming tasks
    input wire in_valid,
    output wire in_ready,
    input wire [7:0] a,
    input wire [7:0] b,

    // System status
    output wire [2:0] queue_count,
    output wire [3:0] busy_mask,
    output wire [3:0] done_mask,
    output wire [35:0] results
);

wire fifo_valid;
wire scheduler_ready;
wire [7:0] fifo_a;
wire [7:0] fifo_b;

// Stage 1: Store incoming tasks
task_fifo fifo (
    .clk(clk),
    .reset(reset),

    .in_valid(in_valid),
    .in_ready(in_ready),
    .in_a(a),
    .in_b(b),

    .out_valid(fifo_valid),
    .out_ready(scheduler_ready),
    .out_a(fifo_a),
    .out_b(fifo_b),

    .count(queue_count)
);

// Stage 2: Dispatch tasks to four workers
parallel_scheduler scheduler (
    .clk(clk),
    .reset(reset),

    .valid(fifo_valid),
    .a(fifo_a),
    .b(fifo_b),

    .ready(scheduler_ready),
    .busy_mask(busy_mask),
    .done_mask(done_mask),
    .results(results)
);

endmodule