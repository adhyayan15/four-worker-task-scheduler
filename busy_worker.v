
module busy_worker #(
    parameter LATENCY = 3
)(
    input wire clk,
    input wire reset,
    input wire start,
    input wire [7:0] a,
    input wire [7:0] b,

    output reg [8:0] result,
    output reg busy,
    output reg done
);

reg [8:0] pending_result;
reg [31:0] cycles_left;

always @(posedge clk) begin
    if (reset) begin
        result <= 0;
        pending_result <= 0;
        busy <= 0;
        done <= 0;
        cycles_left <= 0;
    end
    else begin
        done <= 0;

        // Accept a new task if available
        if (!busy && start) begin
            busy <= 1;
            pending_result <= {1'b0, a} + {1'b0, b};
            cycles_left <= LATENCY;
        end

        // Process an existing task
        else if (busy) begin
            if (cycles_left == 1) begin
                result <= pending_result;
                busy <= 0;
                done <= 1;
                cycles_left <= 0;
            end
            else begin
                cycles_left <= cycles_left - 1;
            end
        end
    end
end

endmodule