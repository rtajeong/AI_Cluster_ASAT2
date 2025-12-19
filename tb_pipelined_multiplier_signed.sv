
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module tb_pipelined_multiplier_signed;

    logic clk, rst;
    logic signed [15:0] A, B;
    logic signed [31:0] C;

    pipelined_multiplier_signed uut (
        .clk(clk),
        .rst(rst),
        .A(A),
        .B(B),
        .C(C)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Test sequence
    initial begin
        rst = 1;
        A = 0;
        B = 0;
        #10;
        rst = 0;

        // -------------------------
        // Test case 1: + ¡¿ +
        // -------------------------
        # 1; 
        A = 16'sd25;
        B = 16'sd15;     // expected: 375
        #30;

        // -------------------------
        // Test case 2: - ¡¿ +
        // -------------------------
        A = -16'sd25;
        B =  16'sd15;    // expected: -375
        #30;

        // -------------------------
        // Test case 3: - ¡¿ -
        // -------------------------
        A = -16'sd128;
        B = -16'sd64;    // expected: 8192
        #30;

        // -------------------------
        // Test case 4: mixed
        // -------------------------
        A =  16'sd123;
        B = -16'sd45;    // expected: -5535
        #30;

        // -------------------------
        // Test case 5: edge case
        // -------------------------
        A = -16'sd32768;
        B =  16'sd1;     // expected: -32768
        #30;

        $stop;
    end

endmodule
