
module worker (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [7:0] a,
    input wire [7:0] b,
    output reg [8:0] result,
    output reg done
);

always @(posedge clk) begin
    if (reset) begin
        result <= 0;
        done <= 0;
    end
    else begin
        done <= 0;

        if (start) begin
            result <= a + b;
            done <= 1;
        end
    end
end

endmodule