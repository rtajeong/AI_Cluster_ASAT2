// tb_systolic_2x2.sv
`timescale 1ns/1ps

module tb_systolic_2x2;

    localparam int A_W = 4;
    localparam int C_W = 8;

    // Weight (positive)
    localparam logic signed [A_W-1:0] W00 = 4'sd1;
    localparam logic signed [A_W-1:0] W01 = 4'sd2;
    localparam logic signed [A_W-1:0] W10 = 4'sd3;
    localparam logic signed [A_W-1:0] W11 = 4'sd4;

    logic clk, rst_n;

    logic signed [A_W-1:0] a_row0_in, a_row1_in;
    logic signed [C_W-1:0] c_col0_out, c_col1_out;

    systolic_2x2 #(
        .A_W(A_W), .C_W(C_W),
        .W00(W00), .W01(W01), .W10(W10), .W11(W11)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .a_row0_in(a_row0_in),
        .a_row1_in(a_row1_in),
        .c_col0_out(c_col0_out),
        .c_col1_out(c_col1_out)
    );

    // clock
    initial clk = 0;
    always #5 clk = ~clk; // 100MHz

    // 5개 입력 행렬 (signed 예시도 1개 넣음)
    logic signed [A_W-1:0] A [0:4][0:1][0:1];

    // 기대 결과 저장: 각 행렬의 row0, row1 순으로 스트림 출력된다고 보고 비교
    logic signed [C_W-1:0] EXP_C0 [0:9]; // col0 stream: 5 matrices * 2 rows
    logic signed [C_W-1:0] EXP_C1 [0:9]; // col1 stream
    int exp_wr;

    // 소프트웨어식 행렬곱으로 기대값 계산
    function automatic logic signed [C_W-1:0] mmul(
        input logic signed [A_W-1:0] a0,
        input logic signed [A_W-1:0] a1,
        input logic signed [A_W-1:0] w0,
        input logic signed [A_W-1:0] w1
    );
        logic signed [C_W-1:0] tmp;
        begin
            tmp = (a0*w0) + (a1*w1);
            return tmp;
        end
    endfunction

    // 입력 한 행렬(2클럭) 밀어넣기
    task automatic push_matrix(input int midx);
        begin
            // cycle for row0: (row0_in=A00, row1_in=A01)
            a_row0_in = A[midx][0][0];
            a_row1_in = A[midx][0][1];
            @(posedge clk);

            // cycle for row1: (row0_in=A10, row1_in=A11)
            a_row0_in = A[midx][1][0];
            a_row1_in = A[midx][1][1];
            @(posedge clk);
        end
    endtask

    // 출력 모니터링: 워밍업 이후부터 기대 스트림과 비교
    int cycle;
    int exp_rd;

    initial begin
        // init
        a_row0_in = '0;
        a_row1_in = '0;
        rst_n     = 0;
        cycle     = 0;
        exp_wr    = 0;
        exp_rd    = 0;

        // A 행렬들 채우기 (사용자 제안 포함 + 다양화)
        A[0] = '{ '{ 4'sd1,  4'sd0 }, '{ 4'sd2,  4'sd1 } }; // [[1,0],[2,1]]
        A[1] = '{ '{ 4'sd0,  4'sd1 }, '{ 4'sd0,  4'sd1 } }; // [[0,1],[0,1]]
        A[2] = '{ '{ 4'sd1,  4'sd1 }, '{ 4'sd3,  -4'sd1 } }; // [[0,1],[0,1]]
        A[3] = '{ '{ 4'sd1,  4'sd1 }, '{ 4'sd1,  4'sd1 } }; // [[1,1],[1,1]]
        A[4] = '{ '{-4'sd1,  4'sd2 }, '{ 4'sd3, -4'sd2 } }; // signed 포함

        // 기대값 생성: 각 행(row0, row1)마다 col0/col1 하나씩 스트림으로 나온다고 보고 저장
        for (int m=0; m<5; m++) begin
            // row0 outputs: [C00, C01]
            EXP_C0[exp_wr] = mmul(A[m][0][0], A[m][0][1], W00, W10); // C00
            EXP_C1[exp_wr] = mmul(A[m][0][0], A[m][0][1], W01, W11); // C01
            exp_wr++;

            // row1 outputs: [C10, C11]
            EXP_C0[exp_wr] = mmul(A[m][1][0], A[m][1][1], W00, W10); // C10
            EXP_C1[exp_wr] = mmul(A[m][1][0], A[m][1][1], W01, W11); // C11
            exp_wr++;
        end

        // reset 몇 클럭
        repeat (3) @(posedge clk);
        rst_n = 1;

        $display("============================================================");
        $display("2x2 Systolic Array TB Start");
        $display("W = [[%0d,%0d],[%0d,%0d]]", W00, W01, W10, W11);
        $display("Input rule: clk1 (row0=A00,row1=A01), clk2 (row0=A10,row1=A11), ...");
        $display("Outputs are column-streamed but aligned: each cycle prints (col0,col1) for a row.");
        $display("============================================================");

        // 5개 행렬 연속 입력 (10 cycles)
        fork
            begin
                for (int m=0; m<5; m++) begin
                    push_matrix(m);
                end
                // flush (파이프라인 비우기)
                a_row0_in = '0;
                a_row1_in = '0;
                repeat (6) @(posedge clk);
                $display("TB Done.");
                $finish;
            end

            // 출력 모니터: 매 클럭 출력 + 기대값 비교(초기 워밍업 고려)
            begin
                // 워밍업 이후부터 exp_rd 증가시키며 비교
                // 경험적으로 이 구조는 첫 유효 출력이 reset 해제 후 몇 클럭 뒤부터 나오므로,
                // 아래처럼 "몇 클럭은 그냥 출력만" 찍고 이후 비교합니다.
                forever begin
                    @(posedge clk);
                    cycle++;

                    $display("[cycle %0d] in(row0,row1)=(%0d,%0d) | out(col0,col1)=(%0d,%0d)",
                             cycle, a_row0_in, a_row1_in, c_col0_out, c_col1_out);

                    // 워밍업 구간을 3~4클럭 정도 둠(수업 시 파이프라인 fill 설명하기 좋음)
                    if (cycle >= 4 && exp_rd < 10) begin
                        $display("           EXPECT row-stream[%0d]: (col0,col1)=(%0d,%0d)%s",
                                 exp_rd, EXP_C0[exp_rd], EXP_C1[exp_rd],
                                 ((c_col0_out===EXP_C0[exp_rd]) && (c_col1_out===EXP_C1[exp_rd])) ? "  OK" : "  **MISMATCH**");
                        exp_rd++;
                    end
                end
            end
        join_none
    end

endmodule
