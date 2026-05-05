module BRANCH_PREDICTOR #(
    parameter BHT_ENTRIES = 16,
    parameter IDX_BITS    = 4
)(
    input  wire        clk,
    input  wire        rstn,

    input  wire [31:0] i_if_pc,
    output wire        o_predict_taken,
    output wire [31:0] o_predict_target,

    input  wire        i_ex_is_branch,
    input  wire        i_ex_is_jump,
    input  wire [31:0] i_ex_pc,
    input  wire        i_ex_taken,
    input  wire [31:0] i_ex_target,

    output wire        o_mispredict,
    output wire [31:0] o_correct_pc
);

    reg [1:0] bht [0:BHT_ENTRIES-1];

    reg [31:0] btb_tag    [0:BHT_ENTRIES-1];
    reg [31:0] btb_target [0:BHT_ENTRIES-1];
    reg        btb_valid  [0:BHT_ENTRIES-1];

    function [IDX_BITS-1:0] bht_index;
        input [31:0] pc;
        bht_index = pc[IDX_BITS+1:2];
    endfunction

    wire [IDX_BITS-1:0] fetch_idx = bht_index(i_if_pc);
    wire                cnt_hi    = bht[fetch_idx][1];
    wire                tgt_hit   = btb_valid[fetch_idx] && (btb_tag[fetch_idx] == i_if_pc);

    assign o_predict_taken  = cnt_hi && tgt_hit;
    assign o_predict_target = btb_target[fetch_idx];

    wire [IDX_BITS-1:0] exec_idx = bht_index(i_ex_pc);

    wire ex_tgt_hit  = btb_valid[exec_idx] && (btb_tag[exec_idx] == i_ex_pc);
    wire ex_predicted = bht[exec_idx][1] && ex_tgt_hit;

    wire ex_actual = i_ex_taken || i_ex_is_jump;

    wire ex_live = i_ex_is_branch || i_ex_is_jump;
    assign o_mispredict = ex_live && (ex_predicted != ex_actual);
    assign o_correct_pc = ex_actual ? i_ex_target : (i_ex_pc + 32'd4);

    integer i;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            for (i = 0; i < BHT_ENTRIES; i = i + 1) begin
                bht[i]        <= 2'b01;
                btb_valid[i]  <= 1'b0;
                btb_tag[i]    <= 32'b0;
                btb_target[i] <= 32'b0;
            end
        end else if (ex_live) begin
            case (bht[exec_idx])
                2'b00: bht[exec_idx] <= ex_actual ? 2'b01 : 2'b00;
                2'b01: bht[exec_idx] <= ex_actual ? 2'b10 : 2'b00;
                2'b10: bht[exec_idx] <= ex_actual ? 2'b11 : 2'b01;
                2'b11: bht[exec_idx] <= ex_actual ? 2'b11 : 2'b10;
            endcase

            if (ex_actual) begin
                btb_valid[exec_idx]  <= 1'b1;
                btb_tag[exec_idx]    <= i_ex_pc;
                btb_target[exec_idx] <= i_ex_target;
            end
        end
    end

endmodule