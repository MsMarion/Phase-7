/*
    Phase 7 — SIMD (Single Instruction Multiple Data)
    Implements 4-lane parallel 8-bit arithmetic.
*/

module SIMD (
    input  wire [31:0] iDataA,
    input  wire [31:0] iDataB,
    input  wire [2:0]  iSimdOp,        
    output reg  [31:0] oResult
);

    // lane operations
    wire [7:0] a3 = iDataA[31:24];
    wire [7:0] a2 = iDataA[23:16];
    wire [7:0] a1 = iDataA[15:8];
    wire [7:0] a0 = iDataA[7:0];

    wire [7:0] b3 = iDataB[31:24];
    wire [7:0] b2 = iDataB[23:16];
    wire [7:0] b1 = iDataB[15:8];
    wire [7:0] b0 = iDataB[7:0];

    always @(*) begin
        case (iSimdOp)
            3'b000: begin // VADD.B (Vector Add Byte)
                oResult[31:24] = a3 + b3;
                oResult[23:16] = a2 + b2;
                oResult[15:8]  = a1 + b1;
                oResult[7:0]   = a0 + b0;
            end
            3'b001: begin // VSUB.B (Vector Sub Byte)
                oResult[31:24] = a3 - b3;
                oResult[23:16] = a2 - b2;
                oResult[15:8]  = a1 - b1;
                oResult[7:0]   = a0 - b0;
            end
            default: oResult = iDataA + iDataB; // Fallback to normal add
        endcase
    end

endmodule
