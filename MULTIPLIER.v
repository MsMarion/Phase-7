/*
    Phase 7 — Multi-cycle Hardware Multiplier (M-Extension)
    Owner: Kai
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

    // TODO: Implement sequential multiplication logic
    assign oBusy = 1'b0;
    assign oDone = 1'b0;

    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            oResult <= 32'b0;
        end else begin
            oResult <= 32'b0;
        end
    end

endmodule
