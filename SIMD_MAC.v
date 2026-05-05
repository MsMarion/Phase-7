module SIMD_MAC (
    input  wire signed [31:0] i_a0, i_a1, i_a2, i_a3,
    input  wire signed [31:0] i_b0, i_b1, i_b2, i_b3,
    input  wire signed [31:0] i_acc0, i_acc1, i_acc2, i_acc3,

    output wire [31:0] o_out0, o_out1, o_out2, o_out3
);

    wire signed [63:0] prod0 = i_a0 * i_b0;
    wire signed [63:0] prod1 = i_a1 * i_b1;
    wire signed [63:0] prod2 = i_a2 * i_b2;
    wire signed [63:0] prod3 = i_a3 * i_b3;

    assign o_out0 = (i_acc0 + prod0[31:0]);
    assign o_out1 = (i_acc1 + prod1[31:0]);
    assign o_out2 = (i_acc2 + prod2[31:0]);
    assign o_out3 = (i_acc3 + prod3[31:0]);

endmodule
