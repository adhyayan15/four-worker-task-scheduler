
`timescale 1ns/1ps

module worker_tb;

reg clk = 0;
reg reset = 1;
reg start = 0;
reg [7:0] a = 0, b = 0;

wire [8:0] result;
wire done;

// Connect our worker
worker uut (
    .clk(clk),
    .reset(reset),
    .start(start),
    .a(a),
    .b(b),
    .result(result),
    .done(done)
);

// Generate a clock
always #5 clk = ~clk;

initial begin
    $dumpfile("worker.vcd");
    $dumpvars(0, worker_tb);

    #12;
    reset = 0;
    a = 15;
    b = 20;
    start = 1;

    #10;
    if (done && result == 35)
        $display("PASS: 15 + 20 = %0d", result);
    else
        $display("FAIL: result = %0d", result);

    start = 0;
    #10;
    $finish;
end

endmodule