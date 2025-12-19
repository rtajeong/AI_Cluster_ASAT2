
module fir_transposed (
    input  logic clk,
    input  logic rst,
    input  logic signed [15:0] x,
    input  logic valid,
    output logic signed [15:0] y
);
    parameter signed [15:0] h0 = 16'sd1;
    parameter signed [15:0] h1 = 16'sd2;
    parameter signed [15:0] h2 = 16'sd3;

    logic signed [15:0] r1, r2;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            r1 <= 0; r2 <= 0; y <= 0;
        end else if (valid) begin
            y  <= x * h0 + r1;
            r1 <= x * h1 + r2;
            r2 <= x * h2;
        end
    end
endmodule
