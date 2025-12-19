module pe #(
    parameter int A_W = 4,
    parameter int P_W = 8,
    parameter logic signed [A_W-1:0] W_INIT = 4'sd1
)(
    input  logic clk,
    input  logic rst_n,

    input  logic signed [A_W-1:0] ain,
    input  logic signed [P_W-1:0] pin,

    output logic signed [A_W-1:0] aout,
    output logic signed [P_W-1:0] pout
);

    logic signed [A_W-1:0] w_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_reg <= W_INIT;
            aout  <= '0;
            pout  <= '0;
        end else begin
            // 좌->우 데이터 전달(1-cycle pipeline)
            aout <= ain;
            // MAC 누적(1-cycle pipeline)
            pout <= pin + (w_reg * ain);
        end
    end

endmodule

// systolic_2x2.sv
module systolic_2x2 #(
    parameter int A_W = 4,
    parameter int C_W = 8,

    // W = [[W00, W01],
    //      [W10, W11]]  (모두 양수 가정)
    parameter logic signed [A_W-1:0] W00 = 4'sd1,
    parameter logic signed [A_W-1:0] W01 = 4'sd2,
    parameter logic signed [A_W-1:0] W10 = 4'sd3,
    parameter logic signed [A_W-1:0] W11 = 4'sd4
)(
    input  logic clk,
    input  logic rst_n,

    // 입력: (사용자 요구) 첫 클럭: row0=A00, row1=A01 / 둘째 클럭: row0=A10, row1=A11 ...
    input  logic signed [A_W-1:0] a_row0_in,
    input  logic signed [A_W-1:0] a_row1_in,

    // 출력: 컬럼 스트림(정렬됨)
    output logic signed [C_W-1:0] c_col0_out,
    output logic signed [C_W-1:0] c_col1_out
);

    // Row1 skew(1-cycle delay)
    logic signed [A_W-1:0] a_row1_d;
    logic signed [C_W-1:0] c0_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) a_row1_d <= '0;
        else        a_row1_d <= a_row1_in;
    end

    // 내부 연결선
    logic signed [A_W-1:0] a00_to_01;
    logic signed [A_W-1:0] a10_to_11;

    logic signed [C_W-1:0] p00_to_10;
    logic signed [C_W-1:0] p01_to_11;

    logic signed [C_W-1:0] p10_out;
    logic signed [C_W-1:0] p11_out;

    // Top row pin은 0으로 시작(각 "row 계산"의 누적 시작)
    logic signed [C_W-1:0] p_zero;
    assign p_zero = '0;

    // 2x2 PE 배열
    // (0,0)
    pe #(.A_W(A_W), .P_W(C_W), .W_INIT(W00)) u_pe00 (
        .clk(clk), .rst_n(rst_n),
        .ain(a_row0_in),
        .pin(p_zero),
        .aout(a00_to_01),
        .pout(p00_to_10)
    );

    // (0,1)
    pe #(.A_W(A_W), .P_W(C_W), .W_INIT(W01)) u_pe01 (
        .clk(clk), .rst_n(rst_n),
        .ain(a00_to_01),
        .pin(p_zero),
        .aout(/* unused */),
        .pout(p01_to_11)
    );

    // (1,0)
    pe #(.A_W(A_W), .P_W(C_W), .W_INIT(W10)) u_pe10 (
        .clk(clk), .rst_n(rst_n),
        .ain(a_row1_d),      // 스큐 적용: row1은 1클럭 늦게 투입
        .pin(p00_to_10),     // 위에서 내려온 partial sum
        .aout(a10_to_11),
        .pout(p10_out)
    );

    // (1,1)
    pe #(.A_W(A_W), .P_W(C_W), .W_INIT(W11)) u_pe11 (
        .clk(clk), .rst_n(rst_n),
        .ain(a10_to_11),
        .pin(p01_to_11),
        .aout(/* unused */),
        .pout(p11_out)
    );

    // 출력 정렬:
    // col0(p10_out)가 col1(p11_out)보다 1클럭 빠름 -> col0를 1클럭 지연
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            c0_d <= '0;
        end else begin
             c0_d <= p10_out;   // col0을 한 번 더 잡아서 늦춤
        end
    end

    assign c_col0_out = c0_d;
    assign c_col1_out = p11_out;  // col1은 레지스터 추가 없이 그대로 출력

endmodule
