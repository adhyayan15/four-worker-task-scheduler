
module task_fifo (
    input wire clk,
    input wire reset,

    // Incoming task
    input wire in_valid,
    output wire in_ready,
    input wire [7:0] in_a,
    input wire [7:0] in_b,

    // Outgoing task
    output wire out_valid,
    input wire out_ready,
    output wire [7:0] out_a,
    output wire [7:0] out_b,

    // Number of waiting tasks
    output wire [2:0] count
);

// Memory for 4 tasks, 16 bits each
reg [15:0] memory [0:3];

// Read and write pointers
reg [1:0] write_ptr;
reg [1:0] read_ptr;
reg [2:0] used;

wire push;
wire pop;

// Queue status
assign in_ready = !reset && (used < 4);
assign out_valid = !reset && (used > 0);
assign count = used;

// Oldest task leaves first
assign {out_a, out_b} =
    out_valid ? memory[read_ptr] : 16'b0;

// Handshake signals
assign push = in_valid && in_ready;
assign pop = out_valid && out_ready;

always @(posedge clk) begin
    if (reset) begin
        write_ptr <= 0;
        read_ptr <= 0;
        used <= 0;
    end
    else begin

        // Store incoming task
        if (push) begin
            memory[write_ptr] <= {in_a, in_b};
            write_ptr <= write_ptr + 1'b1;
        end

        // Remove oldest task
        if (pop) begin
            read_ptr <= read_ptr + 1'b1;
        end

        // Update queue occupancy
        case ({push, pop})
            2'b10: used <= used + 1'b1;
            2'b01: used <= used - 1'b1;
            default: used <= used;
        endcase

    end
end

endmodule