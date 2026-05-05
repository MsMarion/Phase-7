module MISS_HANDLER #(
    parameter BLOCK_SIZE = 64
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

    // Arbiter States
    localparam IDLE      = 2'd0;
    localparam SERVING_D = 2'd1;
    localparam SERVING_I = 2'd2;

    reg [1:0] state, next_state;

    // Latched request info
    reg         rRdReq;
    reg         rWrReq;
    reg [31:0]  rAddr;
    reg [BLOCK_SIZE*8-1:0] rWriteData;

    // Memory array (required by testbench)
    parameter MEM_LATENCY = 100;
    parameter MEM_SIZE    = 1048576; // 1 MB
    reg [7:0] main_memory [0:MEM_SIZE-1];

    reg [BLOCK_SIZE*8-1:0] rReadData;
    reg [$clog2(MEM_LATENCY+1)-1:0] rDelayCnt;
    reg rBusy;

    assign oIMemData = rReadData;
    assign oDMemData = rReadData;
    assign oStall    = (state != IDLE) || rBusy;
    
    wire mem_done = (rBusy && (rDelayCnt == MEM_LATENCY[$clog2(MEM_LATENCY+1)-1:0]));

    integer k;
    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            rDelayCnt <= '0;
            rBusy     <= 1'b0;
            rReadData <= '0;
            rRdReq    <= 1'b0;
            rWrReq    <= 1'b0;
            rAddr     <= 32'b0;
            rWriteData <= '0;
        end else begin
            // Start a new internal memory operation
            // We use the signals from the arbiter
            if ((rd_req || wr_req) && !rBusy) begin
                rBusy      <= 1'b1;
                rDelayCnt  <= '0;
                rRdReq     <= rd_req;
                rWrReq     <= wr_req;
                rAddr      <= req_addr;
                rWriteData <= wr_data;
            end else if (rBusy) begin
                if (rDelayCnt < MEM_LATENCY[$clog2(MEM_LATENCY+1)-1:0]) begin
                    rDelayCnt <= rDelayCnt + 1'b1;
                end else begin
                    // Operation completes
                    if (rRdReq) begin
                        for (k = 0; k < BLOCK_SIZE; k = k + 1) begin
                            rReadData[k*8 +: 8] <= main_memory[rAddr + k];
                        end
                    end
                    if (rWrReq) begin
                        for (k = 0; k < BLOCK_SIZE; k = k + 1) begin
                            main_memory[rAddr + k] <= rWriteData[k*8 +: 8];
                        end
                    end
                    rBusy  <= 1'b0;
                    rRdReq <= 1'b0;
                    rWrReq <= 1'b0;
                end
            end
        end
    end

    // Arbiter Logic
    reg         rd_req;
    reg         wr_req;
    reg [31:0]  req_addr;
    reg [BLOCK_SIZE*8-1:0] wr_data;

    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
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
        wr_data    = 0;

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
                // Only trigger the start of the memory operation once
                if (!rBusy && !mem_done) begin
                    rd_req     = iDMemRd;
                    wr_req     = iDMemWr;
                    req_addr   = iDMemRd ? iDMemRdAddr : iDMemWrAddr;
                    wr_data    = iDMemWrData;
                end

                if (mem_done) begin
                    oDMemValid = 1'b1;
                    next_state = IDLE;
                end
            end

            SERVING_I: begin
                oIMemReady = 1'b1;
                if (!rBusy && !mem_done) begin
                    rd_req     = iIMemRd;
                    wr_req     = iIMemWr;
                    req_addr   = iIMemRd ? iIMemRdAddr : iIMemWrAddr;
                    wr_data    = iIMemWrData;
                end

                if (mem_done) begin
                    oIMemValid = 1'b1;
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

endmodule
