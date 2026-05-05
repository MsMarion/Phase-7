#include <cstdint>
#include <string>
#include <vector>
#include <iomanip>
#include <unordered_map>
#include <ios>
#include <sstream>
#include <bitset>
#include <fstream>
#include <iostream>
#include <type_traits>

enum class InstructionType { R, I, S, B, U, J };

struct Instruction {
  std::string name;
  InstructionType kind;
  uint8_t opcode;
  uint8_t fn3;
  uint8_t fn7;
};

const std::vector<Instruction> instructions = {
	{"add",   InstructionType::R, 0x33, 0x0, 0x00},
	{"sub",   InstructionType::R, 0x33, 0x0, 0x20},
	{"sll",   InstructionType::R, 0x33, 0x1, 0x00},
	{"slt",   InstructionType::R, 0x33, 0x2, 0x00},
	{"sltu",  InstructionType::R, 0x33, 0x3, 0x00},
	{"xor",   InstructionType::R, 0x33, 0x4, 0x00},
	{"srl",   InstructionType::R, 0x33, 0x5, 0x00},
	{"sra",   InstructionType::R, 0x33, 0x5, 0x20},
	{"or",    InstructionType::R, 0x33, 0x6, 0x00},
	{"and",   InstructionType::R, 0x33, 0x7, 0x00},

	{"jalr",  InstructionType::I, 0x67, 0x0, 0x00},
	{"lb",    InstructionType::I, 0x03, 0x0, 0x00},
	{"lh",    InstructionType::I, 0x03, 0x1, 0x00},
	{"lw",    InstructionType::I, 0x03, 0x2, 0x00},
	{"lbu",   InstructionType::I, 0x03, 0x4, 0x00},
	{"lhu",   InstructionType::I, 0x03, 0x5, 0x00},
	{"addi",  InstructionType::I, 0x13, 0x0, 0x00},
	{"slti",  InstructionType::I, 0x13, 0x2, 0x00},
	{"sltiu", InstructionType::I, 0x13, 0x3, 0x00},
	{"xori",  InstructionType::I, 0x13, 0x4, 0x00},
	{"ori",   InstructionType::I, 0x13, 0x6, 0x00},
	{"andi",  InstructionType::I, 0x13, 0x7, 0x00},
	{"slli",  InstructionType::I, 0x13, 0x1, 0x00},
	{"srli",  InstructionType::I, 0x13, 0x5, 0x00},
	{"srai",  InstructionType::I, 0x13, 0x5, 0x20},

	{"sb",    InstructionType::S, 0x23, 0x0, 0x00},
	{"sh",    InstructionType::S, 0x23, 0x1, 0x00},
	{"sw",    InstructionType::S, 0x23, 0x2, 0x00},

	{"beq",   InstructionType::B, 0x63, 0x0, 0x00},
	{"bne",   InstructionType::B, 0x63, 0x1, 0x00},
	{"blt",   InstructionType::B, 0x63, 0x4, 0x00},
	{"bge",   InstructionType::B, 0x63, 0x5, 0x00},
	{"bltu",  InstructionType::B, 0x63, 0x6, 0x00},
	{"bgeu",  InstructionType::B, 0x63, 0x7, 0x00},

	{"lui",   InstructionType::U, 0x37, 0x0, 0x00},
	{"auipc", InstructionType::U, 0x17, 0x0, 0x00},

	{"jal",   InstructionType::J, 0x6F, 0x0, 0x00},

	{"ecall",  InstructionType::I, 0x73, 0x0, 0x00},
	{"ebreak", InstructionType::I, 0x73, 0x0, 0x01},

	{"mult",   InstructionType::R, 0x33, 0x0, 0x01},
	{"multi",  InstructionType::I, 0x13, 0x0, 0x01},

	{"mac4",   InstructionType::R, 0x33, 0x0, 0x02},
	{"mac4i",  InstructionType::I, 0x13, 0x0, 0x02}
};

inline const Instruction* getInstructions(const std::string& tag){
  	static std::unordered_map<std::string, const Instruction*> tbl;
  	if(tbl.empty()){
		for(const auto& entry: instructions){
	  		tbl[entry.name] = &entry;
		}
  	}
  	auto it = tbl.find(tag);
  	if(it != tbl.end()){
		return it->second;
  	}
	return nullptr;
}

struct Register {
    std::string xname;
    std::string alias;
    int idx;
};

const std::vector<Register> registers = {
    {"x0", "zero", 0}, {"x1", "ra", 1}, {"x2", "sp", 2}, {"x3", "gp", 3},
    {"x4", "tp", 4}, {"x5", "t0", 5}, {"x6", "t1", 6}, {"x7", "t2", 7},
    {"x8", "s0", 8}, {"x9", "s1", 9}, {"x10", "a0", 10}, {"x11", "a1", 11},
    {"x12", "a2", 12}, {"x13", "a3", 13}, {"x14", "a4", 14}, {"x15", "a5", 15},
    {"x16", "a6", 16}, {"x17", "a7", 17}, {"x18", "s2", 18}, {"x19", "s3", 19},
    {"x20", "s4", 20}, {"x21", "s5", 21}, {"x22", "s6", 22}, {"x23", "s7", 23},
    {"x24", "s8", 24}, {"x25", "s9", 25}, {"x26", "s10", 26}, {"x27", "s11", 27},
    {"x28", "t3", 28}, {"x29", "t4", 29}, {"x30", "t5", 30}, {"x31", "t6", 31}
};

inline const Register* getRegister(const std::string& tag){
	static std::unordered_map<std::string, const Register*> tbl;
	if(tbl.empty()){
		for(const auto& r: registers){
			tbl[r.alias] = &r;
			tbl["x"+std::to_string(r.idx)]=&r;
		}	
	}
	auto it = tbl.find(tag);
	if(it != tbl.end()){
		return it->second;
	}
	return nullptr;
}

std::string doRType(std::string line, const Instruction* instr);

uint32_t curAddr = 0x0;

void firstPass(std::string fname);

std::string doITypeArith(std::string raw, const Instruction * instr);
std::string doITypeLoad(std::string raw, const Instruction* instr);

std::string doSType(std::string line, const Instruction* instr);
std::string doBType(std::string line, const Instruction* instr);
std::string doUType(std::string line, const Instruction* instr);
std::string doJType(std::string line, const Instruction* instr);
uint32_t parseImm(const std::string immStr);
int safeGetRegIdx(const std::string& regName);
static std::unordered_map<std::string, int32_t> symTab;
int pc;
void writeLE(std::ofstream& outf, uint32_t val);

int main(int argc, char* argv[]) {
    if (argc != 3) return 1;

    std::string inPath = argv[1];
    std::string outDir = argv[2];

    if (!outDir.empty() && outDir.back() != '/') {
        outDir += '/';
    }

    std::string instrPath = outDir + "instr.txt";
    std::string dataPath  = outDir + "data.txt";

    firstPass(inPath);

    std::ifstream src(inPath);
    if (!src.is_open()) {
        return 1;
    }

    std::ofstream instrOut(instrPath);
    std::ofstream dataOut(dataPath);

    std::string line;
    int lineNum = 0;
    pc = 0;
    bool inData = false;
    bool inText = false;

    while (std::getline(src, line)) {
        lineNum++;

        size_t hashPos = line.find('#');
        std::string stripped = line;
        if (hashPos != std::string::npos) {
            stripped = line.substr(0, hashPos);
        }

        std::stringstream ss(stripped);
        std::string tok;
        ss >> tok;

        if (tok == ".data") {
            inData = true;
            inText = false;
            continue;
        }
        if (tok == ".text") {
            inData = false;
            inText = true;
            continue;
        }
        if (tok == ".word") {
            std::string chunk;
            while (ss >> chunk) {
                if (!chunk.empty() && chunk.back() == ',') chunk.pop_back();
                if (chunk.empty()) continue;
                uint32_t val = parseImm(chunk);
                writeLE(dataOut, val);
            }
            continue;
        }

        if (tok.empty() || tok == ".globl") {
            continue;
        }

        if (tok.find(':') != std::string::npos) {
            if (ss >> tok) {
            } else {
                continue;
            }
            if (tok == ".word") {
                std::string chunk;
                while (ss >> chunk) {
                    if (!chunk.empty() && chunk.back() == ',') chunk.pop_back();
                    if (chunk.empty()) continue;
                    uint32_t val = parseImm(chunk);
                    writeLE(dataOut, val);
                }
                continue;
            }
        }

        const Instruction *instr = getInstructions(tok);

        std::string encoded = "";

        if (instr != nullptr) {
            switch (instr->kind) {

            case InstructionType::R:
                encoded = doRType(stripped, instr);
                break;

            case InstructionType::I:
                if (instr->name == "ebreak") {
                    encoded = std::string("00000000000100000000000001110011");
                } else if (instr->name == "ecall") {
                    encoded = std::string("00000000000000000000000001110011");
                } else if (instr->name == "addi" || instr->name == "slti" || instr->name == "sltiu" || instr->name == "xori" || instr->name == "ori"|| instr->name == "andi" || instr->name == "slli" || instr->name == "srli" || instr->name == "srai"
                           || instr->name == "multi" || instr->name == "mac4i") {
                    encoded = doITypeArith(stripped, instr);
                } else if(instr->name == "lb" || instr->name == "lh" || instr->name == "lw" || instr->name == "lbu" || instr->name == "lhu" || instr->name == "jalr") {
                    encoded = doITypeLoad(stripped, instr);
                }
                break;

            case InstructionType::S:
                encoded = doSType(stripped, instr);
                break;

            case InstructionType::B:
                encoded = doBType(stripped, instr);
                break;

            case InstructionType::U:
                encoded = doUType(stripped, instr);
                break;

            case InstructionType::J:
                encoded = doJType(stripped, instr);
                break;

            default:
                break;
            }

            pc += 4;
        }

        if(!encoded.empty() && encoded.length() == 32) {
            uint32_t asInt = std::bitset<32>(encoded).to_ulong();
            writeLE(instrOut, asInt);
        }
    }

    dataOut.close();
    instrOut.close();
    src.close();

    return 0;
}

void writeLE(std::ofstream& outf, uint32_t val) {
    for(int b=0; b<4; b++) {
        uint8_t byte = ((val >> (b*8)) & 0xFF);
        outf << "0x" << std::uppercase << std::hex << std::setw(2) << std::setfill('0') << (int)byte << "\n";
    }
}

std::string regToBits(const std::string regName) {
  std::unordered_map<std::string, int> regNums = {
      {"zero", 0}, {"ra", 1},  {"sp", 2},  {"gp", 3},  {"tp", 4},  {"t0", 5},
      {"t1", 6},   {"t2", 7},  {"s0", 8},
      {"s1", 9},   {"a0", 10}, {"a1", 11}, {"a2", 12}, {"a3", 13}, {"a4", 14},
      {"a5", 15},  {"a6", 16}, {"a7", 17}, {"s2", 18}, {"s3", 19}, {"s4", 20},
      {"s5", 21},  {"s6", 22}, {"s7", 23}, {"s8", 24}, {"s9", 25}, {"s10", 26},
      {"s11", 27}, {"t3", 28}, {"t4", 29}, {"t5", 30}, {"t6", 31},
  };

  int num = regNums[regName];
  return std::bitset<5>(num).to_string();
}

std::string doRType(std::string line, const Instruction *instr) {
  std::stringstream ss(line);
  std::string tok;
  std::string dst;
  std::string src1;
  std::string src2;
  std::string f7str;
  std::string f3str;
  std::string opcstr;

  ss >> tok;
  if (tok.find(':') != std::string::npos) {
      ss >> tok;
  }

  ss >> dst;
  if (!dst.empty() && dst.back() == ',')
    dst.pop_back();

  ss >> src1;
  if (!src1.empty() && src1.back() == ',')
    src1.pop_back();

  ss >> src2;
  if (!src2.empty() && src2.back() == ',')
    src2.pop_back();

  std::string bits_dst  = regToBits(dst);
  std::string bits_src1 = regToBits(src1);
  std::string bits_src2 = regToBits(src2);

  std::string bits_f7  = std::bitset<7>(instr->fn7).to_string();
  std::string bits_f3  = std::bitset<3>(instr->fn3).to_string();
  std::string bits_opc = std::bitset<7>(instr->opcode).to_string();

  std::string out = bits_f7 + bits_src2 + bits_src1 +
                    bits_f3 + bits_dst + bits_opc;

  return out;
}

std::string doITypeArith(std::string raw, const Instruction * instr) {
    std::istringstream sstream(raw);
	std::string piece;
	std::vector<std::string> pieces;

	while(sstream >> piece) {
		pieces.push_back(piece);
	}

	int skip = 0;
	if (!pieces.empty() && pieces[0].find(':') != std::string::npos) {
		skip = 1;
	}

    if(pieces.size() < (size_t)(skip + 4)) {
        return std::string(32, '0');
    }

	std::string dst = pieces[skip + 1];
	int ci = dst.find(",");
	if(ci != std::string::npos) {
        dst.erase(ci, 1);
    }

	std::string src1 = pieces[skip + 2];
	ci = src1.find(",");
	if(ci != std::string::npos) {
        src1.erase(ci, 1);
    }

	std::string shamtStr = pieces[skip + 3];

    const Register* rdReg  = getRegister(dst);
    const Register* rs1Reg = getRegister(src1);

    if (rdReg == nullptr || rs1Reg == nullptr) {
        return std::string(32, '0');
    }

	dst  = std::bitset<5>(getRegister(dst)->idx).to_string();
	src1 = std::bitset<5>(getRegister(src1)->idx).to_string();

    int immRaw = parseImm(shamtStr);

    uint32_t imm12;
    if (instr->name == "srai" || instr->name == "srli" || instr->name == "slli"
        || instr->name == "multi" || instr->name == "mac4i") {
        imm12 = (((uint32_t)instr->fn7 << 5) | ((uint32_t)immRaw & 0x1F)) & 0xFFF;
    } else {
        imm12 = (uint32_t)immRaw & 0xFFF;
    }
    shamtStr = std::bitset<12>(imm12).to_string();

	return (shamtStr+src1+std::bitset<3>((instr->fn3) & 0xFFF).to_string()+dst+std::bitset<7>((instr->opcode) & 0xFFF).to_string());
}

std::string doITypeLoad(std::string raw, const Instruction* instr) {
	std::istringstream sstream(raw);
	std::string piece;
	std::vector<std::string> pieces;

	while(sstream >> piece) {
		pieces.push_back(piece);
	}

    if(pieces.size() < 3) {
        return std::string(32, '0');
    }

	std::string dst = pieces[1];
	int ci = dst.find(",");
	if(ci != std::string::npos) {
        dst.erase(ci, 1);
    }

	std::string offAndRs1 = pieces[2];
    std::string offStr, src1;

    if (offAndRs1.find('(') != std::string::npos) {
        offStr = offAndRs1.substr(0, offAndRs1.find('('));
        int lp = offAndRs1.find('(');
        int rp = offAndRs1.find(')');
        src1 = offAndRs1.substr(lp+1, rp-lp-1);
    } else {
        if (!offAndRs1.empty() && offAndRs1.back() == ',') offAndRs1.pop_back();
        src1 = offAndRs1;
        offStr = (pieces.size() >= 4) ? pieces[3] : "0";
    }

    int offVal = parseImm(offStr);
    std::string immBits = std::bitset<12>(offVal & 0xFFF).to_string();

    const Register* dstReg  = getRegister(dst);
    const Register* src1Reg = getRegister(src1);

    if (dstReg == nullptr || src1Reg == nullptr) {
        return std::string(32, '0');
    }

	dst  = std::bitset<5>(dstReg->idx).to_string();
	src1 = std::bitset<5>(src1Reg->idx).to_string();

	return (immBits+src1+std::bitset<3>(instr->fn3).to_string()+dst+std::bitset<7>(instr->opcode).to_string());
}

std::string doBType(std::string line, const Instruction *instr) {
  std::stringstream ss(line);
  std::string tok;
  std::string src1;
  std::string src2;
  std::string lbl;

  ss >> tok;
  ss >> src1;
  if (!src1.empty() && src1.back() == ',')
    src1.pop_back();

  ss >> src2;
  if (!src2.empty() && src2.back() == ',')
    src2.pop_back();

  ss >> lbl;

  const Register* reg1 = getRegister(src1);
  uint32_t rs1v = 0;
  if (reg1 != nullptr) {
    rs1v = reg1->idx;
  }
  const Register* reg2 = getRegister(src2);
  uint32_t rs2v = 0;
  if (reg2 != nullptr) {
    rs2v = reg2->idx;
  }

  uint32_t f3v = instr->fn3;

  auto sit = symTab.find(lbl);
  uint32_t lblAddr = 0;
  if (sit != symTab.end()) {
    lblAddr = sit->second;
  }

  int32_t off = lblAddr - pc;

  uint32_t imm12   = (off >> 12) & 0x1;
  uint32_t imm11   = (off >> 11) & 0x1;
  uint32_t imm10_5 = (off >> 5)  & 0x3F;
  uint32_t imm4_1  = (off >> 1)  & 0xF;

  uint32_t enc = 0;
  enc |= (imm12   << 31);
  enc |= (imm10_5 << 25);
  enc |= (rs2v    << 20);
  enc |= (rs1v    << 15);
  enc |= (f3v     << 12);
  enc |= (imm4_1  << 8);
  enc |= (imm11   << 7);
  enc |= instr->opcode;

  return std::bitset<32>(enc).to_string();
}

std::string doSType(std::string line, const Instruction* instr)
{
	std::stringstream ss(line);
	std::string tok;
	std::string src1;
	std::string src2;
	std::string offStr;

	ss >> tok;
	ss >> src2;
	src2.pop_back();
	ss >> offStr;

	int lp = offStr.find('(');
	int rp = offStr.find(')');

	src1   = offStr.substr(lp+1, rp - lp -1);
	offStr = offStr.substr(0, lp);

	int rs2v = safeGetRegIdx(src2);
    int rs1v = safeGetRegIdx(src1);

    uint32_t immVal = parseImm(offStr);
    std::string immBits = std::bitset<12>(immVal).to_string();
	std::string imm_lo = immBits.substr(7);
	std::string imm_hi = immBits.substr(0,7);

	std::string out = imm_hi + std::bitset<5>(rs2v).to_string()+std::bitset<5>(rs1v).to_string()+ std::bitset<3>(instr->fn3).to_string()+imm_lo + std::bitset<7>(instr->opcode).to_string();

  return out;
}

std::string doUType(std::string line, const Instruction* instr)
{
	std::stringstream ss(line);
	std::string tok;
	std::string dst;
	std::string immStr;
	int dstIdx;

	ss >> tok;
	ss >> dst;
	if (!dst.empty() && dst.back() == ',')
		dst.pop_back();
	ss >> immStr;

	const Register* r = getRegister(dst);
	if (r == nullptr) {
		return std::string(32, '0');
	}
	dstIdx = r->idx;

	uint32_t immVal = parseImm(immStr);

	std::string out;
	out = std::bitset<20>(immVal).to_string() + std::bitset<5>(dstIdx).to_string() + std::bitset<7>(instr->opcode).to_string();
	return out;
}

std::string doJType(std::string line, const Instruction* instr)
{
	std::stringstream ss(line);
	std::string tok;
	std::string dst;
	std::string lbl;
	int dstIdx;

	ss >> tok;
	if (tok.find(':') != std::string::npos) {
		ss >> tok;
	}

	ss >> dst;
	if (!dst.empty() && dst.back() == ',')
		dst.pop_back();
	ss >> lbl;

	if (dst.empty() || lbl.empty()) {
		return std::string(32, '0');
	}

	const Register* r = getRegister(dst);
	if (r == nullptr) {
		return std::string(32, '0');
	}
	dstIdx = r->idx;

	int32_t off = 0;
	if (symTab.find(lbl) != symTab.end()) {
		int32_t tgt = symTab[lbl];
		off = tgt - pc;
	} else {
		return std::string(32, '0');
	}

	uint32_t imm20    = (off >> 20) & 0x1;
	uint32_t imm19_12 = (off >> 12) & 0xFF;
	uint32_t imm11    = (off >> 11) & 0x1;
	uint32_t imm10_1  = (off >> 1)  & 0x3FF;

	uint32_t enc = 0;
	enc |= (imm20    << 31);
	enc |= (imm10_1  << 21);
	enc |= (imm11    << 20);
	enc |= (imm19_12 << 12);
	enc |= (dstIdx   << 7);
	enc |= instr->opcode;

	std::string out = std::bitset<32>(enc).to_string();
	return out;
}

uint32_t parseImm(const std::string immStr) {
    if (immStr.empty()) return 0;

    if(immStr.find("%hi")==0) {
        int s = immStr.find('(')+1;
        int e = immStr.find(')');
        if (s == 0 || e == (int)std::string::npos) return 0;
        std::string inner = immStr.substr(s, e-s);
        if(symTab.find(inner)!=symTab.end()) {
            int addr = symTab[inner];
            return(addr>>12)&0xFFFFF;
        } else {
            return 0;
        }
    }

    if(immStr.find("%lo")==0) {
        int s = immStr.find('(')+1;
        int e = immStr.find(')');
        if (s == 0 || e == (int)std::string::npos) return 0;
        std::string inner = immStr.substr(s, e-s);
        if(symTab.find(inner)!=symTab.end()) {
            int addr = symTab[inner];
            return addr & 0xFFF;
        } else {
            return 0;
        }
    }

    if (immStr.find("0x") == 0 || immStr.find("0X") == 0) {
        try {
            return std::stoul(immStr, nullptr, 16);
        } catch (...) {
            return 0;
        }
    }

    if (symTab.find(immStr) != symTab.end()) {
        return symTab[immStr];
    }

    try {
        return std::stoi(immStr);
    } catch (...) {
        return 0;
    }
}

void firstPass(std::string fname) {
	std::ifstream src(fname);
	if (!src.is_open()) {
		return;
	}

	std::string line;
	curAddr = 0x0;
	bool inDataSec = false;
	uint32_t dataAddr = 0x0;

	while (std::getline(src, line)) {
		size_t hpos = line.find('#');
		if (hpos != std::string::npos) {
			line = line.substr(0, hpos);
		}

		std::stringstream ss(line);
		std::string tok;
		if (!(ss >> tok)) continue;

		if (tok.back() == ':') {
			std::string lname = tok.substr(0, tok.length() - 1);
			if (inDataSec) {
			    symTab[lname] = dataAddr;
			} else {
			    symTab[lname] = curAddr;
			}
			if (!(ss >> tok)) continue;
		}

		if (tok == ".data") {
			inDataSec = true;
			continue;
		}
		if (tok == ".text") {
			inDataSec = false;
            curAddr = 0x0;
			continue;
		}
		if (tok == ".word") {
			std::string v;
			while (ss >> v) {
				if (!v.empty() && v.back() == ',') v.pop_back();
				if (v.empty()) continue;
				if (inDataSec) dataAddr += 4;
				else curAddr += 4;
			}
			continue;
		}
		if (tok == ".globl") {
			continue;
		}

		if (!inDataSec && getInstructions(tok) != nullptr) {
			curAddr += 4;
		}
	}
	src.close();
}

int safeGetRegIdx(const std::string& regName) {
    const Register* r = getRegister(regName);
    if (r == nullptr) {
        return 0;
    }
    return r->idx;
}