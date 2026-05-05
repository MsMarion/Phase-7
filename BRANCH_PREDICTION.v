/*
    Phase 7 — Dynamic Branch Prediction
    Owner: Eren
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

    // TODO: Implement 2-bit saturating counter table and BTB
    assign oPrediction = 1'b0; // Default to Not Taken
    assign oPredictedPC = 32'b0;

endmodule
