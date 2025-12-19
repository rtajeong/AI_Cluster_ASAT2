`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////


module tb_pipelined_multiplier;

    logic clk, rst;
    logic [15:0] A, B;
    logic [31:0] C;

    pipelined_multiplier uut (
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
        A = 16'd0;
        B = 16'd0;
        #10;
        rst = 0;

        // Test case 1
        A = 16'd25;
        B = 16'd15;
        #10;

        // Test case 2
        A = 16'd255;
        B = 16'd255;
        #10;

        // Test case 3
        A = 16'd1024;
        B = 16'd512;
        #30;

        $stop;
    end

endmodule

