`include "AND.v"
`include "barrel_shifter.v"
`include "comparator.v"
`include "LCA.v"
`include "OR.v"
`include "slt.v"
`include "sltu.v"
`include "XOR.v"
`include "MULTIPLIER.v"

module ALU (
    input [31:0] iDataA,
    input [31:0] iDataB,
    input [3:0] iAluCtrl,
    output [31:0] oData,
    output oZero
  );

  localparam ADD  = 4'b0000;
  localparam SUB  = 4'b1000;
  localparam SLL  = 4'b0001;
  localparam SRL  = 4'b1001;
  localparam SRA  = 4'b1101;
  localparam SLT  = 4'b0010;
  localparam SLTU = 4'b0011;
  localparam XOR  = 4'b0100;
  localparam OR   = 4'b0110;
  localparam AND  = 4'b0111;
  localparam MUL  = 4'b1110;

  localparam BEQ  = 4'b1000;
  localparam BNE  = 4'b1100;
  localparam BLT  = 4'b1010;
  localparam BGE  = 4'b1110;
  localparam BLTU = 4'b1011;
  localparam BGEU = 4'b1111;

  wire doSub = (iAluCtrl == SUB) || (iAluCtrl == BEQ) || (iAluCtrl == BNE) || (iAluCtrl == BLT) || (iAluCtrl == BGE) || (iAluCtrl == BLTU) || (iAluCtrl == BGEU);
  wire [31:0] adderIn = doSub ? ~iDataB : iDataB;
  wire [31:0] wSum;
  /* verilator lint_off UNUSED */
  wire wCout;
  wire wAdderZero;
  /* verilator lint_on UNUSED */

  LCA u_adder (
        .iDataA(iDataA),
        .iDataB(adderIn),
        .iCin(doSub),
        .oData(wSum),
        .oCout(wCout),
        .oZero(wAdderZero)
      );

  wire [31:0] shiftOut;
  wire [31:0] shamtVal;

  wire tooFar;
  assign tooFar   = |iDataB[31:5];
  assign shamtVal = tooFar ? 32'd31 : iDataB;

  wire doArith;
  assign doArith = (iAluCtrl == SRA);

  wire goLeft = (iAluCtrl == SLL);

  barrel_shifter shifting (
                    .i(iDataA),
                    .s(shamtVal),
                    .is_left_shift(goLeft),
                    .is_sra(doArith),
                    .o(shiftOut)
                  );

  wire [31:0] sltOut;
  slt SLTmod(
                .iDataA(iDataA),
                .iDataB(iDataB),
                .oData(sltOut)
              );

  wire [31:0] sltuOut;
  setLessThanUnsigned SLTUmod(
                        .iDataA(iDataA),
                        .iDataB(iDataB),
                        .oData(sltuOut)
                      );

  wire [31:0] wAnd;
  AND u_and (
        .iDataA(iDataA),
        .iDataB(iDataB),
        .oData(wAnd)
      );

  wire [31:0] wOr;
  OR u_or (
       .iDataA(iDataA),
       .iDataB(iDataB),
       .oData(wOr)
     );

  wire [31:0] wXor;
  XOR u_xor (
        .iDataA(iDataA),
        .iDataB(iDataB),
        .oData(wXor)
      );

  wire [31:0] mulOut;
  MULTIPLIER u_mul (
        .iDataA(iDataA),
        .iDataB(iDataB),
        .oProduct(mulOut)
      );

  reg [31:0] rData;
  reg        rZero;
  assign oData = rData;
  assign oZero = rZero;

  always @(*)
  begin
    rData = 32'b0;
    rZero = 1'b0;

    case (iAluCtrl)
      ADD, SUB:
      begin
        rData = wSum;
        rZero = ~|rData;
      end
      SLL, SRL, SRA:
      begin
        rData = shiftOut;
        rZero = ~|rData;
      end
      SLT:
      begin
        rData = sltOut;
        rZero = ~|rData;
      end
      SLTU:
      begin
        rData = sltuOut;
        rZero = ~|rData;
      end
      XOR:
      begin
        rData = wXor;
        rZero = ~|rData;
      end
      OR:
      begin
        rData = wOr;
        rZero = ~|rData;
      end
      AND:
      begin
        rData = wAnd;
        rZero = ~|rData;
      end

      MUL:
      begin
        rData = mulOut;
        rZero = ~|rData;
      end

      BNE:
      begin
        rData = wSum;
        rZero = (wSum != 32'b0);
      end
      BLT:
      begin
        rData = wSum;
        rZero = sltOut[0];
      end
      /* verilator lint_off CASEOVERLAP */
      BGE:
      begin
        rData = wSum;
        rZero = !sltOut[0];
      end
      /* verilator lint_off CASEOVERLAP */
      BLTU:
      begin
        rData = wSum;
        rZero = sltuOut[0];
      end
      BGEU:
      begin
        rData = wSum;
        rZero = !sltuOut[0];
      end

      default:
      begin
        rData = 32'b0;
        rZero = 1'b0;
      end
    endcase
  end

endmodule