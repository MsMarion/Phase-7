module miss_handler #(
    parameter BLOCK_SIZE   = 64,
    parameter MEM_LATENCY  = 100,
    parameter MEM_DEPTH    = (1_048_576 / BLOCK_SIZE)
) (
    input  wire iClk,
    input  wire iRstN,
    // I-Cache interface
    output reg  oIMemReady,
    output reg  oIMemValid,
    output wire [BLOCK_SIZE*8-1:0] oIMemData,
    input  wire iIMemRd,
    input  wire iIMemWr,
    input  wire [31:0] iIMemRdAddr,
    input  wire [31:0] iIMemWrAddr,
    input  wire [BLOCK_SIZE*8-1:0] iIMemWrData,
    // D-Cache interface
    output reg  oDMemReady,
    output reg  oDMemValid,
    output wire [BLOCK_SIZE*8-1:0] oDMemData,
    input  wire iDMemRd,
    input  wire iDMemWr,
    input  wire [31:0] iDMemRdAddr,
    input  wire [31:0] iDMemWrAddr,
    input  wire [BLOCK_SIZE*8-1:0] iDMemWrData,
    // Pipeline control
    output wire oStall
);

  
    localparam IDLE      = 2'd0;
    localparam SERVING_D = 2'd1;
    localparam SERVING_I = 2'd2;

    reg [1:0] state, next_state;

    reg [7:0] main_memory [0:4095];

    reg                     rDoRead;
    reg                     rDoWrite;
    reg [31:0]              rAddr;
    reg [BLOCK_SIZE*8-1:0]  rWriteData;

    reg [$clog2(MEM_LATENCY+1)-1:0] rDelayCnt;

    wire [11:0] base_addr = {rAddr[11:6], 6'b0};

    wire [BLOCK_SIZE*8-1:0] rd_data;
    genvar gi;
    generate
        /* verilator lint_off WIDTH */
        for (gi = 0; gi < BLOCK_SIZE; gi = gi + 1) begin : gen_rd
            assign rd_data[gi*8 +: 8] = main_memory[(base_addr + gi[11:0]) & 12'hFFF];
        end
        /* verilator lint_off WIDTH */
    endgenerate
    reg                     mem_done;

    wire [11:0] base_addr = {rAddr[11:6], 6'b0};

    integer byte_i;

    // Memory request inputs (driven by arbiter combinational block)
    reg        rd_req;
    reg        wr_req;
    reg [31:0] req_addr;
    reg [BLOCK_SIZE*8-1:0] wr_data;

    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            rDoRead   <= 1'b0;
            rDoWrite  <= 1'b0;
            rDelayCnt <= '0;
            mem_done  <= 1'b0;
        end else begin
            mem_done <= 1'b0;

            if (rd_req || wr_req) begin
                rDoRead    <= rd_req;
                rDoWrite   <= wr_req;
                rAddr      <= req_addr;
                rWriteData <= wr_data;
                rDelayCnt  <= '0;
            end else if (rDoRead || rDoWrite) begin
                if (rDelayCnt != MEM_LATENCY[$clog2(MEM_LATENCY+1)-1:0])
                    rDelayCnt <= rDelayCnt + 1'b1;
                else begin
                    if (rDoWrite) begin
                        /* verilator lint_off WIDTH */
                        /* verilator lint_off BLKSEQ */
                        for (byte_i = 0; byte_i < BLOCK_SIZE; byte_i = byte_i + 1)
                            main_memory[(base_addr + byte_i) & 12'hFFF] = rWriteData[byte_i*8 +: 8];
                        /* verilator lint_off BLKSEQ */
                        /* verilator lint_off WIDTH */
                    end 
                    mem_done  <= 1'b1;
                    rDoRead   <= 1'b0;
                    rDoWrite  <= 1'b0;
                end
            end
        end
    end

    assign oIMemData = rd_data;
    assign oDMemData = rd_data;
    assign oStall    = (state != IDLE);

    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) state <= IDLE;
        else        state <= next_state;
    end
    always @(*) begin
        next_state = state;
        oIMemReady = 1'b0;
        oIMemValid = 1'b0;
        oDMemReady = 1'b0;
        oDMemValid = 1'b0;
        rd_req     = 1'b0;
        wr_req     = 1'b0;
        req_addr   = 32'b0;
        wr_data    = '0;

        case (state)
            IDLE: begin
                if (iDMemRd || iDMemWr) begin
                    oDMemReady = 1'b1;
                    next_state = SERVING_D;
                end else if (iIMemRd || iIMemWr) begin
                    oIMemReady = 1'b1;
                    next_state = SERVING_I;
                end
            end

            SERVING_D: begin
                oDMemReady = 1'b1;
                rd_req     = iDMemRd;
                wr_req     = iDMemWr;
                req_addr   = iDMemRd ? iDMemRdAddr : iDMemWrAddr;
                wr_data    = iDMemWrData;
                if (mem_done) begin
                    oDMemValid = 1'b1;
                    next_state = IDLE;
                end
            end

            SERVING_I: begin
                oIMemReady = 1'b1;
                rd_req     = iIMemRd;
                wr_req     = iIMemWr;
                req_addr   = iIMemRd ? iIMemRdAddr : iIMemWrAddr;
                wr_data    = iIMemWrData;
                if (mem_done) begin
                    oIMemValid = 1'b1;
                    next_state = IDLE;
                end
            end

            default: ;
        endcase
    end

endmodule