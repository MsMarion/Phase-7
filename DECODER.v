module DECODER (
    input [31:0] iInstr,

    output [6:0] oOpcode,
    output [4:0] oRd,
    output [2:0] oFunct3,
    output [4:0] oRs1,
    output [4:0] oRs2,
    output [6:0] oFunct7,
    output [31:0] oImm
);
    assign oOpcode = iInstr[6:0];
    assign oRd     = iInstr[11:7];
    assign oFunct3 = iInstr[14:12];
    assign oRs1    = iInstr[19:15];
    assign oRs2    = iInstr[24:20];
    assign oFunct7 = iInstr[31:25];

    reg [31:0] rImm;
    assign oImm = rImm;

    always @(*) begin
        case (iInstr[6:0])

            7'b0010011, 7'b0000011, 7'b1100111: begin
                rImm = {{20{iInstr[31]}}, iInstr[31:20]};
            end

            7'b0100011: begin
                rImm = {{20{iInstr[31]}}, iInstr[31:25], iInstr[11:7]};
            end

            7'b1100011: begin
                rImm = {{19{iInstr[31]}}, iInstr[31], iInstr[7], iInstr[30:25], iInstr[11:8], 1'b0};
            end

            7'b0110111, 7'b0010111: begin
                rImm = {iInstr[31:12], 12'b0};
            end

            7'b1101111: begin
                rImm = {{11{iInstr[31]}}, iInstr[31], iInstr[19:12], iInstr[20], iInstr[30:21], 1'b0};
            end

            7'b1110011: begin
                rImm = {{20{iInstr[31]}}, iInstr[31:20]};
            end

            default: begin
                rImm = 32'b0;
            end

        endcase
    end

endmodule