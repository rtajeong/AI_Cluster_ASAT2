`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
module pipelined_multiplier (
    input  logic clk,
    input  logic rst,
    input  logic [15:0] A,
    input  logic [15:0] B,
    output logic [31:0] C
);

    // Stage 1: Input latch
    logic [15:0] A_reg, B_reg;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            A_reg <= 16'd0;
            B_reg <= 16'd0;
        end else begin
            A_reg <= A;
            B_reg <= B;
        end
    end

    // Stage 2: Partial products
    logic [7:0] A_low, A_high, B_low, B_high;
    logic [15:0] P0, P1, P2, P3;

    assign A_low  = A_reg[7:0];
    assign A_high = A_reg[15:8];
    assign B_low  = B_reg[7:0];
    assign B_high = B_reg[15:8];

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            P0 <= 16'd0;
            P1 <= 16'd0;
            P2 <= 16'd0;
            P3 <= 16'd0;
        end else begin
            P0 <= A_low * B_low;
            P1 <= A_low * B_high;
            P2 <= A_high * B_low;
            P3 <= A_high * B_high;
        end
    end

    // Stage 3: Final addition
    logic [31:0] P0_ext, P1_ext, P2_ext, P3_ext;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            C <= 32'd0;
        end else begin
            P0_ext = P0;
            P1_ext = {P1, 8'd0};  // Shift by 8 bits
            P2_ext = {P2, 8'd0};  // Shift by 8 bits
            P3_ext = {P3, 16'd0}; // Shift by 16 bits
            C <= P0_ext + P1_ext + P2_ext + P3_ext;
        end
    end

endmodule

