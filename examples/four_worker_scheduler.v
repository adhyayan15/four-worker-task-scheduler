
module four_worker_scheduler (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [7:0] a,
    input wire [7:0] b,
    output reg [8:0] result,
    output reg [1:0] completed_worker,
    output reg done
);

// Tracks which worker receives the next task
reg [1:0] next_worker = 0;

// Signals sent to the four workers
wire [3:0] dispatch;
wire [3:0] worker_done;
wire [8:0] worker_results [0:3];

// Round-robin task distribution
assign dispatch = (start && !reset)
                ? (4'b0001 << next_worker)
                : 4'b0000;

// Create four identical workers
genvar i;
generate
    for (i = 0; i < 4; i = i + 1) begin : WORKERS
        worker w (
            .clk(clk),
            .reset(reset),
            .start(dispatch[i]),
            .a(a),
            .b(b),
            .result(worker_results[i]),
            .done(worker_done[i])
        );
    end
endgenerate

// Select the next worker for each task
always @(posedge clk) begin
    if (reset)
        next_worker <= 0;
    else if (start)
        next_worker <= next_worker + 1'b1;
end

// Collect the completed task result
always @(*) begin
    done = |worker_done;
    result = 0;
    completed_worker = 0;

    for (integer j = 0; j < 4; j = j + 1) begin
        if (worker_done[j]) begin
            result = worker_results[j];
            completed_worker = j;
        end
    end
end

endmodule