/*
    Phase 7 — Dynamic Branch Prediction
    Implements a Branch Target Buffer (BTB) and a Bimodal 2-bit Saturating Counter table.
*/

module BRANCH_PREDICTION #(
    parameter TABLE_SIZE = 256
) (
    input  wire        iClk,
    input  wire        iRstN,
    // IF Stage Request
    input  wire [31:0] iIF_PC,
    output wire        oPrediction,    // 1 = Taken, 0 = Not Taken
    output wire [31:0] oPredictedPC,
    // EX Stage Feedback (Update logic)
    input  wire        iUpdateEn,      
    input  wire [31:0] iUpdatePC,
    input  wire [31:0] iActualTarget,
    input  wire        iActualTaken
);

    localparam INDEX_BITS = $clog2(TABLE_SIZE);

    // Predictor Table: 2-bit saturating counters
    // 2'b00: Strong Not Taken
    // 2'b01: Weak Not Taken
    // 2'b10: Weak Taken
    // 2'b11: Strong Taken
    reg [1:0]  rBimodalTable [0:TABLE_SIZE-1];
    reg [31:0] rBTB          [0:TABLE_SIZE-1];
    reg [31:0] rTagTable     [0:TABLE_SIZE-1]; // Store PC to verify hit

    wire [INDEX_BITS-1:0] wIF_Index     = iIF_PC[INDEX_BITS+1:2];
    wire [INDEX_BITS-1:0] wUpdate_Index = iUpdatePC[INDEX_BITS+1:2];

    // Prediction Logic
    wire wHit = (rTagTable[wIF_Index] == iIF_PC);
    assign oPrediction  = wHit && rBimodalTable[wIF_Index][1]; // MSB determines prediction
    assign oPredictedPC = rBTB[wIF_Index];

    integer i;
    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            /* verilator lint_off BLKSEQ */
            for (i = 0; i < TABLE_SIZE; i = i + 1) begin
                rBimodalTable[i] = 2'b01; // Initialize to Weak Not Taken
                rBTB[i]          = 32'b0;
                rTagTable[i]     = 32'hFFFF_FFFF; // Invalid tag
            end
            /* verilator lint_on BLKSEQ */
        end else if (iUpdateEn) begin
            // Update BTB and Tag
            rBTB[wUpdate_Index]      <= iActualTarget;
            rTagTable[wUpdate_Index] <= iUpdatePC;

            // Update 2-bit counter
            case (rBimodalTable[wUpdate_Index])
                2'b00: rBimodalTable[wUpdate_Index] <= iActualTaken ? 2'b01 : 2'b00;
                2'b01: rBimodalTable[wUpdate_Index] <= iActualTaken ? 2'b10 : 2'b00;
                2'b10: rBimodalTable[wUpdate_Index] <= iActualTaken ? 2'b11 : 2'b01;
                2'b11: rBimodalTable[wUpdate_Index] <= iActualTaken ? 2'b11 : 2'b10;
            endcase
        end
    end

endmodule
