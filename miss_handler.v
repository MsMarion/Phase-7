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

    // Memory Interface
    reg         rd_req;
    reg         wr_req;
    reg [31:0]  req_addr;
    reg [BLOCK_SIZE*8-1:0] wr_data;
    wire [BLOCK_SIZE*8-1:0] rd_data;
    wire        mem_done;

    // --- Integrated Main Memory (formerly SHARED_MEM) ---
    parameter MEM_LATENCY = 100;
    parameter MEM_SIZE    = 1048576; // 1 MB
    
    // THE ARRAY THE TESTBENCH EXPECTS
    reg [7:0] main_memory [0:MEM_SIZE-1];

    reg [BLOCK_SIZE*8-1:0] rReadData;
    reg [$clog2(MEM_LATENCY+1)-1:0] rDelayCnt;
    reg rBusy;

    assign rd_data  = rReadData;
    assign mem_done = (rBusy && (rDelayCnt == MEM_LATENCY[$clog2(MEM_LATENCY+1)-1:0]));

    integer i;
    always @(posedge iClk or negedge iRstN) begin
        if (!iRstN) begin
            rDelayCnt <= '0;
            rBusy     <= 1'b0;
            rReadData <= '0;
        end else begin
            if ((rd_req || wr_req) && !rBusy) begin
                rBusy     <= 1'b1;
                rDelayCnt <= '0;
            end else if (rBusy) begin
                if (rDelayCnt < MEM_LATENCY[$clog2(MEM_LATENCY+1)-1:0]) begin
                    rDelayCnt <= rDelayCnt + 1'b1;
                end else begin
                    // Operation completes
                    if (rd_req) begin
                        for (i = 0; i < BLOCK_SIZE; i = i + 1) begin
                            rReadData[i*8 +: 8] <= main_memory[req_addr + i];
                        end
                    end
                    if (wr_req) begin
                        for (i = 0; i < BLOCK_SIZE; i = i + 1) begin
                            main_memory[req_addr + i] <= wr_data[i*8 +: 8];
                        end
                    end
                    rBusy <= 1'b0;
                end
            end
        end
    end
    // --- End Integrated Memory ---

    assign oIMemData = rd_data;
    assign oDMemData = rd_data;
    assign oStall    = (state != IDLE) || rBusy; // Stall while memory is busy

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
                // D-Cache gets priority
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
            default: next_state = IDLE;
        endcase
    end

endmodule
