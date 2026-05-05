/*
    Phase 7 — Multi-cycle Hardware Multiplier (M-Extension)
    Implements: MUL, MULH, MULHSU, MULHU
    Algorithm: Iterative Shift-Add with Sign Handling
*/

module MULTIPLIER (
    input  wire        iClk,
    input  wire        iRstN,
    input  wire [31:0] iDataA,
    input  wire [31:0] iDataB,
    input  wire [2:0]  iFunct3,        
    input  wire        iStart,         
    output reg  [31:0] oResult,
    output wire        oBusy,          
    output wire        oDone           
);

    // States
    localparam IDLE = 2'b00;
    localparam CALC = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0]  rState;
    reg [5:0]  rCount;
    reg [63:0] rA_reg, rProduct;
    reg [31:0] rB_reg;
    reg        rSignRes;

    // Detect signedness for each operand
    wire wIsSignedA = (iFunct3 == 3'b001 || iFunct3 == 3'b010); // MULH, MULHSU
    wire wIsSignedB = (iFunct3 == 3'b001); // MULH (MUL is handled by lower bits)
    
    // MUL (000) can be treated as unsigned for the lower 32 bits.
    // MULH (001): S * S
    // MULHSU (010): S * U
    // MULHU (011): U * U

    assign oBusy = (rState == CALC);
    assign oDone = (rState == DONE);

    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            rState   <= IDLE;
            rCount   <= 6'b0;
            rProduct <= 64'b0;
            oResult  <= 32'b0;
            rSignRes <= 1'b0;
        end else begin
            case (rState)
                IDLE: begin
                    if (iStart) begin
                        rState <= CALC;
                        rCount <= 6'd32;
                        rProduct <= 64'b0;
                        
                        // Handle operands based on Funct3
                        case (iFunct3)
                            3'b001: begin // MULH (S*S)
                                rSignRes <= iDataA[31] ^ iDataB[31];
                                rA_reg   <= {32'b0, (iDataA[31] ? (~iDataA + 1'b1) : iDataA)};
                                rB_reg   <= (iDataB[31] ? (~iDataB + 1'b1) : iDataB);
                            end
                            3'b010: begin // MULHSU (S*U)
                                rSignRes <= iDataA[31];
                                rA_reg   <= {32'b0, (iDataA[31] ? (~iDataA + 1'b1) : iDataA)};
                                rB_reg   <= iDataB;
                            end
                            default: begin // MUL, MULHU (U*U)
                                rSignRes <= 1'b0;
                                rA_reg   <= {32'b0, iDataA};
                                rB_reg   <= iDataB;
                            end
                        endcase
                    end
                end

                CALC: begin
                    if (rCount > 0) begin
                        if (rB_reg[0]) begin
                            rProduct <= rProduct + rA_reg;
                        end
                        rA_reg <= rA_reg << 1;
                        rB_reg <= rB_reg >> 1;
                        rCount <= rCount - 1'b1;
                    end else begin
                        rState <= DONE;
                    end
                end

                DONE: begin
                    // Final result with sign adjustment
                    reg [63:0] final_product;
                    final_product = rSignRes ? (~rProduct + 1'b1) : rProduct;
                    
                    if (iFunct3 == 3'b000)
                        oResult <= final_product[31:0];
                    else
                        oResult <= final_product[63:32];
                    
                    rState <= IDLE;
                end
                
                default: rState <= IDLE;
            endcase
        end
    end

endmodule
