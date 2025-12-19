
// 실전에서는 두 개의 서로 다른 클럭을 사용하려면,정확한 사양의 FIFO가 필요함.
// splitter + cdc(clock domain crossing)

module input_splitter_2f (
    input  logic clk_2f,
    input  logic rst,
    input  logic signed [15:0] x_in,
    output logic signed [15:0] x_even,
    output logic signed [15:0] x_odd,
    output logic valid_even,
    output logic valid_odd
);
    logic toggle;

    always_ff @(posedge clk_2f or posedge rst) begin
        if (rst) begin
            toggle <= 0;
            valid_even <= 0;
            valid_odd  <= 0;
        end else begin
            toggle <= ~toggle;
            if (toggle) begin
                x_even <= x_in;
                valid_even <= 1;
                valid_odd  <= 0;
            end else begin
                x_odd <= x_in;
                valid_odd  <= 1;
                valid_even <= 0;
            end
        end
    end
endmodule


module cdc_fifo (
    input  logic clk_2f,
    input  logic clk_f,
    input  logic rst,
    input  logic signed [15:0] x_even_in,
    input  logic signed [15:0] x_odd_in,
    input  logic valid_even,
    input  logic valid_odd,
    output logic signed [15:0] x_even_out,
    output logic signed [15:0] x_odd_out,
    output logic valid_out
);
    logic signed [15:0] buf_even, buf_odd;
    logic data_ready;

    always_ff @(posedge clk_2f or posedge rst) begin
        if (rst) begin
            buf_even <= 0;
            buf_odd  <= 0;
            data_ready <= 0;
        end else if (valid_even || valid_odd) begin
            buf_even <= x_even_in;
            buf_odd  <= x_odd_in;
            data_ready <= 1;
        end
    end

    always_ff @(posedge clk_f or posedge rst) begin
        if (rst) begin
            x_even_out <= 0;
            x_odd_out  <= 0;
            valid_out  <= 0;
        end else if (data_ready) begin
            x_even_out <= buf_even;
            x_odd_out  <= buf_odd;
            valid_out  <= 1;
            data_ready <= 0;
        end else begin
            valid_out <= 0;
        end
    end
endmodule

module fir_polyphase_even (
    input  logic clk,
    input  logic rst,
    input  logic signed [15:0] x_even,
    input  logic signed [15:0] x_odd_prev,
    input  logic valid,
    output logic signed [15:0] y_even
);
    parameter signed [15:0] h0 = 16'sd1;
    parameter signed [15:0] h1 = 16'sd2;
    parameter signed [15:0] h2 = 16'sd3;

    logic signed [15:0] x_even_d1, x_even_d2;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            x_even_d1 <= 0;
            x_even_d2 <= 0;
            y_even    <= 0;
        end else begin
            if (valid) begin
                y_even <= h0 * x_even_d1 + h1 * x_odd_prev + h2 * x_even_d2;
            end
            x_even_d2 <= x_even_d1;
            x_even_d1 <= x_even;
        end
    end
endmodule

module fir_polyphase_odd (
    input  logic clk,
    input  logic rst,
    input  logic signed [15:0] x_odd,
    input  logic signed [15:0] x_even_prev_d1,
    input  logic valid,
    output logic signed [15:0] y_odd
);
    parameter signed [15:0] h0 = 16'sd1;
    parameter signed [15:0] h1 = 16'sd2;
    parameter signed [15:0] h2 = 16'sd3;

    logic signed [15:0] x_odd_d1, x_odd_d2;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            x_odd_d1 <= 0;
            x_odd_d2 <= 0;
            y_odd    <= 0;
        end else begin
            if (valid) begin
                y_odd <= h0 * x_odd_d1 + h1 * x_even_prev_d1 + h2 * x_odd_d2;
            end
            x_odd_d2 <= x_odd_d1;
            x_odd_d1 <= x_odd;
        end
    end
endmodule

module top_polyphase_fir (
    input  logic clk_2f,
    input  logic clk_f,
    input  logic rst,
    input  logic signed [15:0] x_in,
    output logic signed [15:0] y_even,
    output logic signed [15:0] y_odd,
    output logic valid_out
);
    logic signed [15:0] x_even, x_odd;
    logic valid_even, valid_odd;
    logic signed [15:0] x_even_cdc, x_odd_cdc;
    logic valid_cdc;

    input_splitter_2f splitter (
        .clk_2f(clk_2f),
        .rst(rst),
        .x_in(x_in),
        .x_even(x_even),
        .x_odd(x_odd),
        .valid_even(valid_even),
        .valid_odd(valid_odd)
    );

    cdc_fifo cdc (
        .clk_2f(clk_2f),
        .clk_f(clk_f),
        .rst(rst),
        .x_even_in(x_even),
        .x_odd_in(x_odd),
        .valid_even(valid_even),
        .valid_odd(valid_odd),
        .x_even_out(x_even_cdc),
        .x_odd_out(x_odd_cdc),
        .valid_out(valid_cdc)
    );

    logic signed [15:0] x_even_prev, x_even_prev_d1;
    logic signed [15:0] x_odd_prev;

    always_ff @(posedge clk_f or posedge rst) begin
        if (rst) begin
            x_even_prev     <= 0;
            x_even_prev_d1  <= 0;
            x_odd_prev      <= 0;
        end else if (valid_cdc) begin
            x_even_prev     <= x_even_cdc;
            x_even_prev_d1  <= x_even_prev;
            x_odd_prev      <= x_odd_cdc;
        end
    end

    fir_polyphase_even fir0 (
        .clk(clk_f),
        .rst(rst),
        .x_even(x_even_cdc),
        .x_odd_prev(x_odd_prev),
        .valid(valid_cdc),
        .y_even(y_even)
    );

    fir_polyphase_odd fir1 (
        .clk(clk_f),
        .rst(rst),
        .x_odd(x_odd_cdc),
        .x_even_prev_d1(x_even_prev_d1),
        .valid(valid_cdc),
        .y_odd(y_odd)
    );

    assign valid_out = valid_cdc;
endmodule
