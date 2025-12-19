module pipelined_multiplier_signed (
    input  logic        clk,
    input  logic        rst,
    input  logic [15:0] A,
    input  logic [15:0] B,
    output logic [31:0] C
);

    // -------------------------------------------------
    // Stage 1 : sign + magnitude (explicit hardware)
    // -------------------------------------------------
    logic        sign_s1;
    logic [15:0] A_mag_s1, B_mag_s1;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_s1  <= 1'b0;
            A_mag_s1 <= 16'd0;
            B_mag_s1 <= 16'd0;
        end else begin
            // sign = XOR of MSBs
            sign_s1 <= A[15] ^ B[15];

            // magnitude = two's complement if negative
            A_mag_s1 <= A[15] ? (~A + 16'd1) : A;
            B_mag_s1 <= B[15] ? (~B + 16'd1) : B;
        end
    end

    // -------------------------------------------------
    // Stage 2 : partial products (unsigned)
    // -------------------------------------------------
    logic [7:0]  A_low, A_high, B_low, B_high;
    logic [15:0] P0, P1, P2, P3;
    logic        sign_s2;

    assign A_low  = A_mag_s1[7:0];
    assign A_high = A_mag_s1[15:8];
    assign B_low  = B_mag_s1[7:0];
    assign B_high = B_mag_s1[15:8];

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            P0      <= 16'd0;
            P1      <= 16'd0;
            P2      <= 16'd0;
            P3      <= 16'd0;
            sign_s2 <= 1'b0;
        end else begin
            P0      <= A_low  * B_low;
            P1      <= A_low  * B_high;
            P2      <= A_high * B_low;
            P3      <= A_high * B_high;
            sign_s2 <= sign_s1;
        end
    end

    // -------------------------------------------------
    // Stage 3 : sum + explicit sign application
    // -------------------------------------------------
    logic [31:0] mag_sum;
    logic [31:0] mag_ext;

    // unsigned magnitude sum
    assign mag_sum =
          {16'd0, P0}
        + { 8'd0, P1, 8'd0}
        + { 8'd0, P2, 8'd0}
        + {       P3, 16'd0};

    // explicit sign extension (hardware-visible)
    assign mag_ext = sign_s2
                   ? (~mag_sum + 32'd1)   // negative
                   : mag_sum;             // positive

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            C <= 32'd0;
        end else begin
            C <= mag_ext;
        end
    end

endmodule



