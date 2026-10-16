
module parallel_scheduler (
    input wire clk,
    input wire reset,
    input wire valid,
    input wire [7:0] a, b,

    output wire ready,
    output wire [3:0] busy_mask,
    output wire [3:0] done_mask,
    output wire [35:0] results
);

reg [1:0] next_worker;
reg [3:0] dispatch;
reg [1:0] selected;
reg available;
reg [1:0] candidate;
integer k;

// Find an available worker
always @(*) begin
    dispatch = 0;
    selected = next_worker;
    available = 0;
    candidate = 0;

    for (k = 0; k < 4; k = k + 1) begin
        candidate = next_worker + k;

        if (!available && !busy_mask[candidate]) begin
            available = 1;
            selected = candidate;
        end
    end

    if (valid && !reset && available)
        dispatch[selected] = 1;
end

assign ready = available && !reset;

// Advance after accepting a task
always @(posedge clk) begin
    if (reset)
        next_worker <= 0;
    else if (valid && ready)
        next_worker <= selected + 1'b1;
end

// Four independent processing units
genvar i;
generate
    for (i = 0; i < 4; i = i + 1) begin : WORKERS
        busy_worker #(.LATENCY(5)) worker (
            .clk(clk),
            .reset(reset),
            .start(dispatch[i]),
            .a(a),
            .b(b),
            .result(results[i*9 +: 9]),
            .busy(busy_mask[i]),
            .done(done_mask[i])
        );
    end
endgenerate

endmodule