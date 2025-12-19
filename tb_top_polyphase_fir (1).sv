`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module tb_top_polyphase_fir;
    // Ŭ�� �� ����
    logic clk_2f = 0;
    logic clk_f  = 0;
    logic rst    = 1;

    // DUT �������̽�
    logic signed [15:0] x_in;
    logic signed [15:0] y_even, y_odd;
    logic valid_out;

    // ** ok in vivado, but not in iverilog **
    // logic signed [15:0] input_data [0:13] = 
    //    '{16'sd1, 16'sd2, 16'sd3, 16'sd4, 16'sd5, 16'sd6, 16'sd7,
    //      16'sd8, 16'sd9, 16'sd10, 16'sd11, 16'sd12, 16'sd13, 16'sd14};

    // iverilog (systemverilog features not fully supported yet)
    logic signed [15:0] input_data [0:13];

    initial begin
       for (int i = 0; i < 14; i++) begin
          input_data[i] = i + 1;
       end
    end
    
    int idx = 0;

    // Ŭ�� ����
    always #5 clk_2f = ~clk_2f;   // 2f Ŭ�� (10ns �ֱ�)
    always #10 clk_f  = ~clk_f;   // f Ŭ�� (20ns �ֱ�)

    // DUT �ν��Ͻ�
    top_polyphase_fir dut (
        .clk_2f(clk_2f),
        .clk_f(clk_f),
        .rst(rst),
        .x_in(x_in),
        .y_even(y_even),
        .y_odd(y_odd),
        .valid_out(valid_out)
    );

    // �׽�Ʈ ������
    initial begin
        // VCD ����
        $dumpfile("polyphase_fir.vcd");
        $dumpvars(0, tb_top_polyphase_fir);

        #20 rst = 0;

        for (idx = 0; idx < 14; idx++) begin
            x_in = input_data[idx];
            $display("Time %t | Input x_in = %d", $time, x_in);
            #10; // 2f Ŭ�� ����
        end

        #100 $finish;
    end

    // ��� ����͸�
    always_ff @(posedge clk_f) begin
        if (valid_out)
            $display("Time %t | FIR Outputs: y_even = %d, y_odd = %d", $time, y_even, y_odd);
    end
endmodule

