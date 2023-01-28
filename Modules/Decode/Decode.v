`timescale 1ns / 1ps
//`define DEBUG
`define DEBUG_PRINT
//`include "DecodeFormatScan.v"
`include "../../../Modules/Decode/DecodeFormatScan.v"
`include "../../../Modules/Decode/FormatSpecificDecoders/AFormatDecoder.v"
`include "../../../Modules/Decode/FormatSpecificDecoders/BFormatDecoder.v"
`include "../../../Modules/Decode/FormatSpecificDecoders/DFormatDecoder.v"
`include "../../../Modules/Decode/DecodeMux.v"
/*/////////Decode Unit/////////////
Writen by Josh "Hakaru" Cantwell - 19.12.2022

The Power ISA specifies 25 different instruction formats 25, this decode unit operates in 3 stages, these are decribed below:
1) Format decode
The first stage takes the instruction from the fetch unit and performs a quick scan on the instruction to determine 
the instruction's format. It then provides the instruction to the format specific decoder.

2) Format specific decoder
Ths second stage of the decode unit has all of the format specific decoders, it takes the instruction from the previous stage
and performs the full decode on the instruction, then outputs it to the third stage.

3) Instruction mux
The third and final stage of the decode unit multiplexes the instructions from the previous stage to the single output signal group
of the decode unit.

The decode unit regenerates register addresses to point to a unified register space wherein all registers are in the same physical register file 
using a single address space. This means register addresses within the instruction must take into account what type of instruction is being processed
before generating the instruction.
This implements:
    Branch:
        Program counter
        CR register
        Target address register    
        Link register

    FX:
        32 FX registers
        fx XER register
        VR save register

    FP:
    32 FP registers
    FPSCR register

    VX:
    32 VX registers
    


TODO: Implement unified register space.
*/
module DecodeUnit
#(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter instMinIdWidth = 7,//width of inst minor ID
    parameter primOpcodeSize = 6,
    parameter opcodeSize = 12,
    parameter regSize = 5,
    parameter regAccessPatternSize = 2,//2 bit field, [0] == is read, [1] == is writen. Both can be true EG: (A = A + B)
    parameter funcUnitCodeSize = 3,

    ////Format Specific
    parameter BimmediateSize = 14,
    parameter DimmediateSize = 16,
    //Each format has a unique bit, this means that I can or multiple formats together into a single variable to pass to
    //the next stage for the format-specific decoders to look at for the instruction opcodes with multiple possible formats
    parameter I = 2**00, parameter B = 2**01, parameter XL = 2**02, parameter DX = 2**03, parameter SC = 2**04,
    parameter D = 2**05, parameter X = 2**06, parameter XO = 2**07, parameter Z23 = 2**08, parameter A = 2**09,
    parameter XS = 2**10, parameter XFX = 2**11, parameter DS = 2**12, parameter DQ = 2**13, parameter VA = 2**14,
    parameter VX = 2**15, parameter VC = 2**16, parameter MD = 2**17, parameter MDS = 2**18, parameter XFL = 2**19,
    parameter Z22 = 2**20, parameter XX2 = 2**21, parameter XX3 = 2**22
)(
    //////Inputs:
    input wire clock_i,    
    //command
    input wire enable_i, reset_i, stall_i,
    //data
    input wire [0:instructionWidth-1] instruction_i,
    input wire [0:addressWidth-1] instructionAddress_i,
    input wire is64Bit_i,
    input wire [0:PidSize-1] instructionPid_i,
    input wire [0:TidSize-1] instructionTid_i,
    input wire [0:instructionCounterWidth-1] instructionMajId_i,

    //output
    output wire enable_o,
    ///Total output size is 302 bits (37.75B)
    output wire [0:25-1] instFormat_o,
    output wire [0:opcodeSize-1] opcode_o,
    output wire [0:addressWidth-1] address_o,
    output wire [0:funcUnitCodeSize-1] funcUnitType_o,
    output wire [0:instructionCounterWidth-1] majID_o,
    output wire [0:instMinIdWidth-1] minID_o, numMicroOps_o,
    output wire is64Bit_o,
    output wire [0:PidSize-1] pid_o,
    output wire [0:TidSize-1] tid_o,
    output wire [0:regAccessPatternSize-1] op1rw_o, op2rw_o, op3rw_o, op4rw_o,
    output wire op1IsReg_o, op2IsReg_o, op3IsReg_o, op4IsReg_o,
    output wire modifiesCR_o,
    output wire [0:64-1] body_o//contains all operands. Large enough for 4 reg operands and a 64bit imm
);


////Decode stage 1 - Format decode
wire stage1EnableOut;
wire [0:25-1] stage1instFormatOut;
wire [0:primOpcodeSize-1] stage1OpcodeOut;
wire [0:instructionWidth-1] stage1instructionOut;
wire [0:addressWidth-1] stage1instructionAddressOut;
wire stage1is64BitOut;
wire [0:PidSize-1] stage1instructionPidOut;
wire [0:TidSize-1] stage1instructionTidOut;
wire [0:instructionCounterWidth-1] stage1instructionMajIdOut;
FormatScanner #(
    //Sizes
    .addressWidth(addressWidth),
    .instructionWidth(instructionWidth),
    .PidSize(PidSize), .TidSize(TidSize),
    .instructionCounterWidth(instructionCounterWidth),
    .primOpcodeSize(primOpcodeSize),
    //Formats
    .I(I), .B(B), .XL(XL), .DX(DX), .SC(SC),
    .D(D), .X(X), .XO(XO), .Z23(Z23), .A(A),
    .XS(XS), .XFX(XFX), .DS(DS), .DQ(DQ), .VA(VA),
    .VX(VX), .VC(VC), .MD(MD), .MDS(MDS), .XFL(XFL),
    .Z22(Z22), .XX2(XX2), .XX3(XX3)
)
formatScanner
(
    ///Input
    //command
    .clock_i(clock_i), 
    `ifdef DEBUG_PRINT .reset_i(reset_i), `endif
    .enable_i(enable_i), .stall_i(stall_i),
    //data
    .instruction_i(instruction_i),
    .instructionAddress_i(instructionAddress_i),
    .is64Bit_i(is64Bit_i),
    .instructionPid_i(instructionPid_i),
    .instructionTid_i(instructionTid_i),
    .instructionMajId_i(instructionMajId_i),
    ///Output
    .outputEnable_o(stage1EnableOut),
    .instFormat_o(stage1instFormatOut),
    .instOpcode_o(stage1OpcodeOut),
    .instruction_o(stage1instructionOut),
    .instructionAddress_o(stage1instructionAddressOut),
    .is64Bit_o(stage1is64BitOut),
    .instructionPid_o(stage1instructionPidOut),
    .instructionTid_o(stage1instructionTidOut),
    .instructionMajId_o(stage1instructionMajIdOut)
);

    ////Decode stage 2 - Format specific decode
    ///A format
    wire AenableIn;
    wire [0:opcodeSize-1] AOpcodeIn;
    wire [0:addressWidth-1] AAddressIn;
    wire [0:funcUnitCodeSize-1] AUnitTypeIn;
    wire [0:instructionCounterWidth] AMajIdIn;
    wire [0:instMinIdWidth-1] AMinIdIn, AnumMicroOpsIn;
    wire Ais64BitIn;
    wire [0:PidSize-1] APidIn;
    wire [0:TidSize-1] ATidIn;
    wire [0:regAccessPatternSize-1] Aop1rwIn, Aop2rwIn, Aop3rwIn, Aop4rwIn;
    wire Aop1IsRegIn, Aop2IsRegIn, Aop3IsRegIn, Aop4IsRegIn;
    wire AmodifiesCRIn;
    wire [0:4 * regSize] ABodyIn;

    AFormatDecoder #()
    aFormatDecoder
    (
        .clock_i(clock_i),
        `ifdef DEBUG_PRINT .reset_i(reset_i), `endif
        .enable_i(stage1EnableOut), .stall_i(!stage1EnableOut),
        .instFormat_i(stage1instFormatOut),
        .instructionOpcode_i(stage1OpcodeOut),
        .instruction_i(stage1instructionOut),
        .instructionAddress_i(stage1instructionAddressOut),
        .is64Bit_i(stage1is64BitOut),
        .instructionPid_i(stage1instructionPidOut),
        .instructionTid_i(stage1instructionTidOut),
        .instructionMajId_i(stage1instructionMajIdOut),

        .enable_o(AenableIn),
        .opcode_o(AOpcodeIn),
        .instructionAddress_o(AAddressIn),
        .functionalUnitType_o(AUnitTypeIn),
        .instMajId_o(AMajIdIn),
        .instMinId_o(AMinIdIn), .numMicroOps_o(AnumMicroOpsIn),
        .is64Bit_o(Ais64BitIn),
        .instPid_o(APidIn),
        .instTid_o(ATidIn),
        .op1rw_o(Aop1rwIn), .op2rw_o(Aop2rwIn), .op3rw_o(Aop3rwIn), .op4rw_o(Aop4rwIn),//reg operand are read/write flags
        .op1IsReg_o(Aop1IsRegIn), .op2IsReg_o(Aop2IsRegIn), .op3IsReg_o(Aop3IsRegIn), .op4IsReg_o(Aop4IsRegIn),//Reg operands isReg flags
        .modifiesCR_o(AmodifiesCRIn),
        .instructionBody_o(ABodyIn)
    );

    ///B format
    wire BenableIn;
    wire [0:opcodeSize-1] BOpcodeIn;
    wire [0:addressWidth-1] BAddressIn;
    wire [0:funcUnitCodeSize-1] BUnitTypeIn;
    wire [0:instructionCounterWidth] BMajIdIn;
    wire [0:instMinIdWidth-1] BMinIdIn, BnumMicroOpsIn;
    wire Bis64BitIn;
    wire [0:PidSize-1] BPidIn;
    wire [0:TidSize-1] BTidIn;
    wire BmodifiesCRIn;
    wire [0:(2 * regSize) + BimmediateSize + 3] BBodyIn;

    BFormatDecoder #()
    bFormatDecoder
    (
        .clock_i(clock_i),
        `ifdef DEBUG_PRINT .reset_i(reset_i), `endif
        .enable_i(stage1EnableOut), .stall_i(!stage1EnableOut),
        .instFormat_i(stage1instFormatOut),
        .instructionOpcode_i(stage1OpcodeOut),
        .instruction_i(stage1instructionOut),
        .instructionAddress_i(stage1instructionAddressOut),
        .is64Bit_i(stage1is64BitOut),
        .instructionPid_i(stage1instructionPidOut),
        .instructionTid_i(stage1instructionTidOut),
        .instructionMajId_i(stage1instructionMajIdOut),

        .enable_o(BenableIn),
        .opcode_o(BOpcodeIn),
        .instructionAddress_o(BAddressIn),
        .functionalUnitType_o(BUnitTypeIn),
        .instMajId_o(BMajIdIn),
        .instMinId_o(BMinIdIn), .numMicroOps_o(BnumMicroOpsIn),
        .is64Bit_o(Bis64BitIn),
        .instPid_o(BPidIn),
        .instTid_o(BTidIn),
        .modifiesCR_o(BmodifiesCRIn),
        .instructionBody_o(BBodyIn)
);

    ///D format
    wire DenableIn;
    wire [0:opcodeSize-1] DOpcodeIn;
    wire [0:addressWidth-1] DAddressIn;
    wire [0:funcUnitCodeSize-1] DUnitTypeIn;
    wire [0:instructionCounterWidth] DMajIdIn;
    wire [0:instMinIdWidth-1] DMinIdIn, DnumMicroOpsIn;
    wire Dis64BitIn;
    wire [0:PidSize-1] DPidIn;
    wire [0:TidSize-1] DTidIn;
    wire [0:regAccessPatternSize-1] Dop1rwIn, Dop2rwIn;
    wire Dop1isRegIn, Dop2isRegIn, immIsExtendedIn, immIsShiftedIn;
    wire [0:2] DisShiftedByIn;
    wire DmodifiesCRIn;
    wire [0:(2 * regSize) + DimmediateSize - 1] DBodyIn;
    DFormatDecoder #()
    dFormatDecoder
    (
        .clock_i(clock_i),
        `ifdef DEBUG_PRINT .reset_i(reset_i), `endif
        .enable_i(stage1EnableOut), .stall_i(!stage1EnableOut),
        .instFormat_i(stage1instFormatOut),
        .instructionOpcode_i(stage1OpcodeOut),
        .instruction_i(stage1instructionOut),
        .instructionAddress_i(stage1instructionAddressOut),
        .is64Bit_i(stage1is64BitOut),
        .instructionPid_i(stage1instructionPidOut),
        .instructionTid_i(stage1instructionTidOut),
        .instructionMajId_i(stage1instructionMajIdOut),

        .enable_o(DenableIn),
        .opcode_o(DOpcodeIn),
        .instructionAddress_o(DAddressIn),
        .functionalUnitType_o(DUnitTypeIn),
        .instMajId_o(DMajIdIn),
        .instMinId_o(DMinIdIn), .numMicroOps_o(DnumMicroOpsIn),
        .is64Bit_o(Dis64BitIn),
        .instPid_o(DPidIn),
        .instTid_o(DTidIn),
        .op1rw_o(Dop1rwIn), .op2rw_o(Dop2rwIn),
        .op1isReg_o(Dop1isRegIn), .op2isReg_o(Dop2isRegIn), .immIsExtended_o(immIsExtendedIn), .immIsShifted_o(immIsShiftedIn),
        .shiftedBy_o(DisShiftedByIn),
        .modifiesCR_o(DmodifiesCRIn),
        .instructionBody_o(DBodyIn)
    );

    ////Decode stage 3 - Instruction mux to output 

    DecodeMux #(
    )
    decodeMux
    (
        ////Inputs
        ///Command
        .clock_i(clock_i),    
    `ifdef DEBUG_PRINT 
        .reset_i(reset_i),
    `endif
        ///A format
        .Aenable_i(AenableIn),
        .AOpcode_i(AOpcodeIn),
        .AAddress_i(AAddressIn),
        .AUnitType_i(AUnitTypeIn),
        .AMajId_i(AMajIdIn),
        .AMinId_i(AMinIdIn),
        .Ais64Bit_i(Ais64BitIn),
        .APid_i(APidIn),
        .ATid_i(ATidIn),
        .Aop1rw_i(Aop1rwIn), .Aop2rw_i(Aop2rwIn), .Aop3rw_i(Aop3rwIn), .Aop4rw_i(Aop4rwIn),
        .Aop1IsReg_i(Aop1IsRegIn), .Aop2IsReg_i(Aop2IsRegIn), .Aop3IsReg_i(Aop3IsRegIn), .Aop4IsReg_i(Aop4IsRegIn),
        .AmodifiesCR_i(AmodifiesCRIn),
        .ABody_i(ABodyIn),

        ///B format
        .Benable_i(BenableIn),
        .BOpcode_i(BOpcodeIn),
        .BAddress_i(BAddressIn),
        .BUnitType_i(BUnitTypeIn),
        .BMajId_i(BMajIdIn),
        .BMinId_i(BMinIdIn),
        .Bis64Bit_i(Bis64BitIn),
        .BPid_i(BPidIn),
        .BTid_i(BTidIn),
        .BmodifiesCR_i(BmodifiesCRIn),
        .BBody_i(BBodyIn),

        ///D format
        .Denable_i(DenableIn),
        .DOpcode_i(DOpcodeIn),
        .DAddress_i(DAddressIn),
        .DUnitType_i(DUnitTypeIn),
        .DMajId_i(DMajIdIn),
        .DMinId_i(DMinIdIn),
        .Dis64Bit_i(Dis64BitIn),
        .DPid_i(DPidIn),
        .DTid_i(DTidIn),
        .Dop1rw_i(Dop1rwIn), .Dop2rw_i(Dop2rwIn),
        .Dop1isReg_i(Dop1isRegIn), .Dop2isReg_i(Dop2isRegIn), .immIsExtended_i(immIsExtendedIn), .immIsShifted_i(immIsShiftedIn),
        .DisShiftedBy_i(DisShiftedByIn),
        .DmodifiesCR_i(DmodifiesCRIn),
        .DBody_i(DBodyIn),

        ///output
        .enable_o(enable_o),
        .instFormat_o(instFormat_o),
        .opcode_o(opcode_o),
        .address_o(address_o),
        .funcUnitType_o(funcUnitType_o),
        .majID_o(majID_o),
        .minID_o(minID_o),
        .numMicroOps_o(numMicroOps_o),
        .is64Bit_o(is64Bit_o),
        .pid_o(pid_o),
        .tid_o(tid_o),
        .op1rw_o(op1rw_o), .op2rw_o(op2rw_o), .op3rw_o(op3rw_o), .op4rw_o(op4rw_o),
        .op1IsReg_o(op1IsReg_o), .op2IsReg_o(op2IsReg_o), .op3IsReg_o(op3IsReg_o), .op4IsReg_o(op4IsReg_o),
        .modifiesCR_o(modifiesCR_o),
        .body_o(body_o)
    );

    always @(posedge clock_i)
    begin
        if(reset_i)
            $display("Resetting decode unit");
    end

endmodule