`include "BRANCH_PREDICTOR.v"
`include "SIMD_MAC.v"

module RISCV_TOP (
    input iClk,
    input iRstN,
    output oFinish
  );

  wire [31:0] wInstr, wPc;

  wire wICacheHit, wICacheMiss;
  wire [31:0] wICacheReadData;
  wire wIMemReady, wIMemValid, wIMemRd, wIMemWr;
  wire [31:0] wIMemRdAddr, wIMemWrAddr;
  wire [511:0] wIMemData, wIMemRdData, wIMemWrData;

  CACHE #(
    .EVICT_POLICY(0),
    .WAYS(4),
    .CACHE_SIZE(32),
    .BLOCK_SIZE(64)
  ) icache (
    .i_clk(iClk), .i_rstn(iRstN),
    .i_read(1'b1),
    .i_write(1'b0),
    .i_funct(2'b10),
    .i_addr(wIF_PC),
    .i_cpu_data(32'b0),
    .i_mem_ready(wIMemReady),
    .i_mem_valid(wIMemValid),
    .i_mem_rd_data(wIMemData),
    .o_hit(wICacheHit), .o_miss(wICacheMiss),
    .o_cpu_data(wICacheReadData),
    .o_mem_rd(wIMemRd),
    .o_mem_wr(wIMemWr),
    .o_mem_rd_addr(wIMemRdAddr),
    .o_mem_wr_addr(wIMemWrAddr),
    .o_mem_wr_data(wIMemWrData)
  );

  assign wIF_Instr = wICacheHit ? wICacheReadData : 32'h00000013;

  wire [31:0] wID_PC, wID_Instr;
  wire wIDEXFlush, wBranchTaken;

  IF_ID reg_if_id (
    .clk(iClk),
    .rst(~iRstN),
    .stall(~wIFIDWrite || wCacheStall),
    .flush(wBranchTaken || wBP_Mispredict),
    .i_PC(wIF_PC),
    .i_instruction(wIF_Instr),
    .o_PC(wID_PC),
    .o_instruction(wID_Instr)
  );

  assign wPc    = wID_PC;
  assign wInstr = wID_Instr;

  wire        wBP_PredictTaken;
  wire [31:0] wBP_PredictTarget;
  wire        wBP_Mispredict;
  wire [31:0] wBP_CorrectPC;

  wire wEX_IsBranch_for_BP = wEX_Branch;
  wire wEX_IsJump_for_BP   = wEX_Jump;

  BRANCH_PREDICTOR #(.BHT_ENTRIES(16), .IDX_BITS(4)) bp (
    .clk              (iClk),
    .rstn             (iRstN),
    .i_if_pc          (wIF_PC),
    .o_predict_taken  (wBP_PredictTaken),
    .o_predict_target (wBP_PredictTarget),
    .i_ex_is_branch   (wEX_IsBranch_for_BP),
    .i_ex_is_jump     (wEX_IsJump_for_BP),
    .i_ex_pc          (wEX_PC),
    .i_ex_taken       (wAluZero),
    .i_ex_target      (wEX_BranchTarget),
    .o_mispredict     (wBP_Mispredict),
    .o_correct_pc     (wBP_CorrectPC)
  );

  wire [6:0] wID_Opcode, wID_Funct7;
  wire [2:0] wID_Funct3;
  wire [4:0] wID_Rd, wID_Rs1, wID_Rs2;
  wire [31:0] wID_Imm, wID_Rs1Data, wID_Rs2Data;

  wire wID_Lui, wID_PcSrc, wID_MemRd, wID_MemWr, wID_MemtoReg, wID_AluSrc1, wID_AluSrc2, wID_RegWrite, wID_Branch, wID_Jump;
  wire [2:0] wID_AluOp;

  DECODER decoder (
    .iInstr(wID_Instr),
    .oOpcode(wID_Opcode),
    .oRd(wID_Rd),
    .oFunct3(wID_Funct3),
    .oRs1(wID_Rs1),
    .oRs2(wID_Rs2),
    .oFunct7(wID_Funct7),
    .oImm(wID_Imm)
  );

  CONTROL control (
    .iOpcode(wID_Opcode),
    .oLui(wID_Lui),
    .oPcSrc(wID_PcSrc),
    .oMemRd(wID_MemRd),
    .oMemWr(wID_MemWr),
    .oAluOp(wID_AluOp),
    .oMemtoReg(wID_MemtoReg),
    .oAluSrc1(wID_AluSrc1),
    .oAluSrc2(wID_AluSrc2),
    .oRegWrite(wID_RegWrite),
    .oBranch(wID_Branch),
    .oJump(wID_Jump),
    .oFinish(wID_Finish)
  );
  wire wID_Finish;

  wire [4:0] wWB_Rd;
  wire wWB_RegWrite;
  wire [31:0] wWB_FinalWriteData;

  REGISTER register (
    .iClk(iClk),
    .iRstN(iRstN),
    .iWriteEn(wWB_RegWrite),
    .iRdAddr(wWB_Rd),
    .iRs1Addr(wID_Rs1),
    .iRs2Addr(wID_Rs2),
    .iWriteData(wWB_FinalWriteData),
    .oRs1Data(wID_Rs1Data),
    .oRs2Data(wID_Rs2Data)
  );

  wire [4:0] wEX_Rd;
  wire wEX_MemRd;

  hazard_detect hazard_unit (
    .iIDExMemRead(wEX_MemRd),
    .iIDExRegisterRd(wEX_Rd),
    .iIFIdRegisterRs1(wID_Rs1),
    .iIFIdRegisterRs2(wID_Rs2),
    .iID_isStore(wID_MemWr),
    .oPCWrite(wPCWrite),
    .oIFIDWrite(wIFIDWrite),
    .ID_EX_Flush(wIDEXFlush)
  );

  wire wEX_PcSrc, wEX_MemWr, wEX_MemtoReg, wEX_AluSrc1, wEX_AluSrc2, wEX_RegWrite, wEX_Branch, wEX_Jump, wEX_Lui;
  wire [2:0] wEX_AluOp, wEX_Funct3;
  wire [6:0] wEX_Funct7;
  wire [31:0] wEX_Rs1Data, wEX_Rs2Data, wEX_PC, wEX_Imm;
  wire [4:0] wEX_Rs1, wEX_Rs2;

  ID_EX reg_id_ex (
    .clk(iClk),
    .rst(~iRstN),
    .stall(wCacheStall),
    .flush(wIDEXFlush || wBranchTaken || wBP_Mispredict),
    .iPcSrc(wID_PcSrc),
    .iMemRead(wID_MemRd),
    .iMemWrite(wID_MemWr),
    .iAluOp(wID_AluOp),
    .iMemToReg(wID_MemtoReg),
    .iAluSrc1(wID_AluSrc1),
    .iAluSrc2(wID_AluSrc2),
    .iRegWrite(wID_RegWrite),
    .iBranch(wID_Branch),
    .iJump(wID_Jump),
    .iLui(wID_Lui),
    .i_rs1_value(wID_Rs1Data),
    .i_rs2_value(wID_Rs2Data),
    .i_PC(wID_PC),
    .i_imm(wID_Imm),
    .i_rs1_num(wID_Rs1),
    .i_rs2_num(wID_Rs2),
    .i_rd_num(wID_Rd),
    .i_funct3(wID_Funct3),
    .i_funct7(wID_Funct7),
    .iFinish(wID_Finish),
    .oPcSrc(wEX_PcSrc),
    .oMemRead(wEX_MemRd),
    .oMemWrite(wEX_MemWr),
    .oAluOp(wEX_AluOp),
    .oMemToReg(wEX_MemtoReg),
    .oAluSrc1(wEX_AluSrc1),
    .oAluSrc2(wEX_AluSrc2),
    .oRegWrite(wEX_RegWrite),
    .oBranch(wEX_Branch),
    .oJump(wEX_Jump),
    .oLui(wEX_Lui),
    .o_rs1_value(wEX_Rs1Data),
    .o_rs2_value(wEX_Rs2Data),
    .o_PC(wEX_PC),
    .o_imm(wEX_Imm),
    .o_rs1_ptr(wEX_Rs1),
    .o_rs2_ptr(wEX_Rs2),
    .o_rd_ptr(wEX_Rd),
    .o_funct3(wEX_Funct3),
    .o_funct7(wEX_Funct7),
    .oFinish(wEX_Finish)
  );
  wire wEX_Finish;

  wire [1:0] wForwardA, wForwardB;
  wire [31:0] wAluDataA, wAluDataB, wAluResult;
  wire [3:0] wAluCtrl;
  wire wAluZero;

  wire [4:0] wMEM_Rd, wWB_Rd;
  wire wMEM_RegWrite, wWB_RegWrite, wMEM_MemRd, wWB_MemRd;
  wire [31:0] wMEM_AluResult, wWB_FinalWriteData;

  ForwardingUnit forward_unit (
    .ID_EX_rs1(wEX_Rs1),
    .ID_EX_rs2(wEX_Rs2),
    .EX_MEM_rd(wMEM_Rd),
    .MEM_WB_rd(wWB_Rd),
    .EX_MEM_RegWrite(wMEM_RegWrite),
    .MEM_WB_RegWrite(wWB_RegWrite),
    .EX_MEM_rs2(wMEM_Rs2Ptr),
    .MEM_WB_MemRead(wWB_MemRd),
    .ForwardA(wForwardA),
    .ForwardB(wForwardB),
    .ForwardMem(wForwardMem)
  );
  wire wForwardMem;

  wire [31:0] wMEM_ForwardData = wMEM_Lui  ? wMEM_Imm     :
                                  wMEM_Jump ? wMEM_PcPlus4 :
                                              wMEM_AluResult;

  wire [31:0] wAluSrcA_raw, wAluSrcB_raw;
  assign wAluSrcA_raw = (wForwardA == 2'b10) ? wMEM_ForwardData :
                        (wForwardA == 2'b01) ? wWB_FinalWriteData :
                        wEX_Rs1Data;

  assign wAluSrcB_raw = (wForwardB == 2'b10) ? wMEM_ForwardData :
                        (wForwardB == 2'b01) ? wWB_FinalWriteData :
                        wEX_Rs2Data;

  MUX_2_1 #(32) alu_src1_mux (
    .iData0(wAluSrcA_raw),
    .iData1(wEX_PC),
    .iSel(wEX_AluSrc1),
    .oData(wAluDataA)
  );

  MUX_2_1 #(32) alu_src2_mux (
    .iData0(wAluSrcB_raw),
    .iData1(wEX_Imm),
    .iSel(wEX_AluSrc2),
    .oData(wAluDataB)
  );

  ALU_CONTROL alu_control (
    .iAluOp(wEX_AluOp),
    .iFunct3(wEX_Funct3),
    .iFunct7(wEX_Funct7),
    .oAluCtrl(wAluCtrl)
  );

  ALU alu (
    .iDataA(wAluDataA),
    .iDataB(wAluDataB),
    .iAluCtrl(wAluCtrl),
    .oData(wAluResult),
    .oZero(wAluZero)
  );

  BRANCH_JUMP branch_jump (
    .iBranch(wEX_Branch),
    .iJump(wEX_Jump),
    .iZero(wAluZero),
    .iOffset(wEX_Imm),
    .iPc(wEX_PC),
    .iRs1(wAluSrcA_raw),
    .iPcSrc(wEX_PcSrc),
    .oPc(wEX_BranchTarget)
  );
  wire [31:0] wEX_BranchTarget;

  assign wBranchTaken = (wEX_Branch && wAluZero) || wEX_Jump;

  assign wActualNextPC = wBP_Mispredict    ? wBP_CorrectPC       :
                         wCacheStall        ? wIF_PC              :
                         (~wPCWrite)        ? wIF_PC              :
                         wBP_PredictTaken   ? wBP_PredictTarget   :
                                             (wIF_PC + 32'd4);

  wire wMEM_MemWr, wMEM_MemtoReg, wMEM_Jump, wMEM_Lui;
  wire [31:0] wMEM_Rs2Data, wMEM_PcPlus4, wMEM_Imm;
  wire [2:0] wMEM_Funct3;
  wire [4:0] wMEM_Rs2Ptr;

  EX_MEM reg_ex_mem (
    .clk(iClk),
    .rst(~iRstN),
    .stall(wCacheStall),
    .i_rs2_ptr(wEX_Rs2),
    .iMemRead(wEX_MemRd),
    .iMemWrite(wEX_MemWr),
    .iMemToReg(wEX_MemtoReg),
    .iRegWrite(wEX_RegWrite),
    .iBranch(wEX_Branch),
    .iJump(wEX_Jump),
    .iLui(wEX_Lui),
    .i_imm(wEX_Imm),
    .i_ALU_result(wEX_FinalAluResult),
    .i_zero(wAluZero),
    .i_offset(wEX_Imm),
    .i_rs2_value(wAluSrcB_raw),
    .i_funct3(wEX_Funct3),
    .i_rd_num(wEX_Rd),
    .i_base_pc(wEX_PC + 4),
    .iFinish(wEX_Finish),
    .oMemRead(wMEM_MemRd),
    .oMemWrite(wMEM_MemWr),
    .oMemToReg(wMEM_MemtoReg),
    .oRegWrite(wMEM_RegWrite),
    .oLui(wMEM_Lui),
    .o_imm(wMEM_Imm),
    .o_ALU_result(wMEM_AluResult),
    .o_zero(wMEM_Zero),
    .o_offset(wMEM_Offset),
    .o_rs2_value(wMEM_Rs2Data),
    .o_rs2_ptr(wMEM_Rs2Ptr),
    .o_funct3(wMEM_Funct3),
    .o_rd_num(wMEM_Rd),
    .o_base_pc(wMEM_PcPlus4),
    .oJump(wMEM_Jump),
    .oBranch(wMEM_Branch),
    .oFinish(wMEM_Finish)
  );
  wire wMEM_Zero, wMEM_Branch, wMEM_Finish;
  wire [31:0] wMEM_Offset;

  wire [31:0] wMEM_ReadData;
  wire [31:0] wActualMemWriteData;
  assign wActualMemWriteData = (wForwardMem) ? wWB_FinalWriteData : wMEM_Rs2Data;

  wire wDCacheHit, wDCacheMiss;
  wire [31:0] wDCacheReadData;
  wire wDMemReady, wDMemValid, wDMemRd, wDMemWr;
  wire [31:0] wDMemRdAddr, wDMemWrAddr;
  wire [511:0] wDMemData, wDMemRdData, wDMemWrData;

  CACHE #(
    .EVICT_POLICY(0),
    .WAYS(4),
    .CACHE_SIZE(32),
    .BLOCK_SIZE(64)
  ) dcache (
    .i_clk(iClk), .i_rstn(iRstN),
    .i_read(wMEM_MemRd),
    .i_write(wMEM_MemWr),
    .i_funct(wMEM_Funct3[1:0]),
    .i_addr(wMEM_AluResult),
    .i_cpu_data(wActualMemWriteData),
    .i_mem_ready(wDMemReady),
    .i_mem_valid(wDMemValid),
    .i_mem_rd_data(wDMemData),
    .o_hit(wDCacheHit), .o_miss(wDCacheMiss),
    .o_cpu_data(wMEM_ReadData),
    .o_mem_rd(wDMemRd),
    .o_mem_wr(wDMemWr),
    .o_mem_rd_addr(wDMemRdAddr),
    .o_mem_wr_addr(wDMemWrAddr),
    .o_mem_wr_data(wDMemWrData)
  );

  wire wWB_MemtoReg, wWB_Jump, wWB_Lui;
  wire [31:0] wWB_MemData, wWB_AluResult, wWB_Imm, wWB_PcPlus4;

  MEM_WB reg_mem_wb (
    .clk(iClk),
    .rst(~iRstN),
    .stall(wCacheStall),
    .iMemToReg(wMEM_MemtoReg),
    .iRegWrite(wMEM_RegWrite),
    .iJump(wMEM_Jump),
    .iLui(wMEM_Lui),
    .iMemRead(wMEM_MemRd),
    .i_mem_data(wMEM_ReadData),
    .i_ALU_result(wMEM_AluResult),
    .i_rd_num(wMEM_Rd),
    .i_imm(wMEM_Imm),
    .i_pc_plus_4(wMEM_PcPlus4),
    .iFinish(wMEM_Finish),
    .oMemToReg(wWB_MemtoReg),
    .oRegWrite(wWB_RegWrite),
    .oJump(wWB_Jump),
    .oLui(wWB_Lui),
    .oMemRead(wWB_MemRd),
    .o_mem_data(wWB_MemData),
    .o_ALU_result(wWB_AluResult),
    .o_rd_num(wWB_Rd),
    .o_imm(wWB_Imm),
    .o_pc_plus_4(wWB_PcPlus4),
    .oFinish(wWB_Finish)
  );
  wire wWB_Finish;
  assign oFinish = wWB_Finish;

  wire [31:0] wWB_MemToRegData, wWB_WriteData;
  MUX_2_1 #(32) mem_to_reg_mux (
    .iData0(wWB_AluResult),
    .iData1(wWB_MemData),
    .iSel(wWB_MemtoReg),
    .oData(wWB_MemToRegData)
  );

  MUX_2_1 #(32) lui_mux (
    .iData0(wWB_MemToRegData),
    .iData1(wWB_Imm),
    .iSel(wWB_Lui),
    .oData(wWB_WriteData)
  );

  MUX_2_1 #(32) jump_wb_mux (
    .iData0(wWB_WriteData),
    .iData1(wWB_PcPlus4),
    .iSel(wWB_Jump),
    .oData(wWB_FinalWriteData)
  );

  wire wIsMac4 = (wAluCtrl == 4'b0101);

  wire [31:0] wSIMD_Out0, wSIMD_Out1, wSIMD_Out2, wSIMD_Out3;

  SIMD_MAC simd_mac (
    .i_a0   (wAluSrcA_raw),
    .i_a1   (wEX_Rs1Data),
    .i_a2   (wEX_Rs1Data),
    .i_a3   (wEX_Rs1Data),
    .i_b0   (wAluSrcB_raw),
    .i_b1   (wAluSrcB_raw),
    .i_b2   (wAluSrcB_raw),
    .i_b3   (wAluSrcB_raw),
    .i_acc0 (wWB_FinalWriteData),
    .i_acc1 (wWB_FinalWriteData),
    .i_acc2 (wWB_FinalWriteData),
    .i_acc3 (wWB_FinalWriteData),
    .o_out0 (wSIMD_Out0),
    .o_out1 (wSIMD_Out1),
    .o_out2 (wSIMD_Out2),
    .o_out3 (wSIMD_Out3)
  );

  wire [31:0] wEX_FinalAluResult = wIsMac4 ? wSIMD_Out0 : wAluResult;

  wire wCacheStall;
  MISS_HANDLER #(.BLOCK_SIZE(64)) miss_handler (
    .iClk(iClk), .iRstN(iRstN),
    .oIMemReady(wIMemReady),
    .oIMemValid(wIMemValid),
    .oIMemData(wIMemData),
    .iIMemRd(wIMemRd),
    .iIMemWr(wIMemWr),
    .iIMemRdAddr(wIMemRdAddr),
    .iIMemWrAddr(wIMemWrAddr),
    .iIMemWrData(wIMemWrData),
    .oDMemReady(wDMemReady),
    .oDMemValid(wDMemValid),
    .oDMemData(wDMemData),
    .iDMemRd(wDMemRd),
    .iDMemWr(wDMemWr),
    .iDMemRdAddr(wDMemRdAddr),
    .iDMemWrAddr(wDMemWrAddr),
    .iDMemWrData(wDMemWrData),
    .oStall(wCacheStall)
  );

endmodule