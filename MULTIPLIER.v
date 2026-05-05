module MULTIPLIER (
    input  wire [31:0] iDataA,
    input  wire [31:0] iDataB,
    output wire [31:0] oProduct
);

    wire signed [31:0] sa = $signed(iDataA);
    wire signed [31:0] sb = $signed(iDataB);
    wire signed [63:0] fullProd = sa * sb;

    assign oProduct = fullProd[31:0];

endmodule