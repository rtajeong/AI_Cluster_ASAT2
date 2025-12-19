`timescale 1ns / 1ps

module tb_fir_transposed;
    // Ŭ�� �� ����
    logic clk = 0;
    logic rst = 1;

    // DUT �������̽�
    logic signed [15:0] x;
    logic valid;
    logic signed [15:0] y;

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

    // Ŭ�� ���� (20ns �ֱ�)
    always #10 clk = ~clk;

    // DUT �ν��Ͻ�
    fir_transposed #(.h0(16'sd1), .h1(16'sd2), .h2(16'sd3)) dut (
        .clk(clk),
        .rst(rst),
        .x(x),
        .valid(valid),
        .y(y)
    );

    // �׽�Ʈ ������
    initial begin
        // VCD ���� ����
        $dumpfile("fir_transposed.vcd");
        $dumpvars(0, tb_fir_transposed);

        // ���� ����
        #20 rst = 0;

        // �Է� ����
        for (idx = 0; idx < 14; idx++) begin
            x = input_data[idx];
            valid = 1;
            $display("Time %t | Input x = %d", $time, x);
            #20; // Ŭ�� �ֱ�� ����
        end

        // �Է� ����
        valid = 0;
        #100 $finish;
    end

    // ��� ����͸�
    always_ff @(posedge clk) begin
        if (valid)
            $display("Time %t | Output y = \t   %d", $time, y);
    end
endmodule
