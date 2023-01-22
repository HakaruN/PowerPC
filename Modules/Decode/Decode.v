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
    


TODO:
Replace POWER opcodes & Xopcodes with unified optype-specific opcodes and implement unified register space.
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
    output wire enableOut,
    ///Total output size is 302 bits (37.75B)
    output wire [0:25-1] instFormat_o,
    output wire [0:opcodeSize-1] opcodeOut,
    output wire [0:addressWidth-1] addressOut,
    output wire [0:funcUnitCodeSize-1] funcUnitTypeOut,
    output wire [0:instructionCounterWidth-1] majIDOut,
    output wire [0:instMinIdWidth-1] minIDOut,
    output wire is64BitOut,
    output wire [0:PidSize-1] pidOut,
    output wire [0:TidSize-1] tidOut,
    output wire [0:regAccessPatternSize-1] op1rwOut, op2rwOut, op3rwOut, op4rwOut,
    output wire op1IsRegOut, op2IsRegOut, op3IsRegOut, op4IsRegOut,
    output wire [0:84-1] bodyOut//contains all operands. Large enough for 4 reg operands and a 64bit imm
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
    wire [0:instMinIdWidth-1] AMinIdIn;
    wire Ais64BitIn;
    wire [0:PidSize-1] APidIn;
    wire [0:TidSize-1] ATidIn;
    wire [0:regAccessPatternSize-1] Aop1rwOut, Aop2rwOut, Aop3rwOut, Aop4rwOut;
    wire Aop1IsRegOut, Aop2IsRegOut, Aop3IsRegOut, Aop4IsRegOut;
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
        .instMinId_o(AMinIdIn),
        .is64Bit_o(Ais64BitIn),
        .instPid_o(APidIn),
        .instTid_o(ATidIn),
        .op1rw_o(Aop1rwOut), .op2rw_o(Aop2rwOut), .op3rw_o(Aop3rwOut), .op4rw_o(Aop4rwOut),//reg operand are read/write flags
        .op1IsReg_o(Aop1IsRegOut), .op2IsReg_o(Aop2IsRegOut), .op3IsReg_o(Aop3IsRegOut), .op4IsReg_o(Aop4IsRegOut),//Reg operands isReg flags
        .instructionBody_o(ABodyIn)
    );

    ///B format
    wire BenableIn;
    wire [0:opcodeSize-1] BOpcodeIn;
    wire [0:addressWidth-1] BAddressIn;
    wire [0:funcUnitCodeSize-1] BUnitTypeIn;
    wire [0:instructionCounterWidth] BMajIdIn;
    wire [0:instMinIdWidth-1] BMinIdIn;
    wire Bis64BitIn;
    wire [0:PidSize-1] BPidIn;
    wire [0:TidSize-1] BTidIn;
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
        .instMinId_o(BMinIdIn),
        .is64Bit_o(Bis64BitIn),
        .instPid_o(BPidIn),
        .instTid_o(BTidIn),
        .instructionBody_o(BBodyIn)
);

    ///D format
    wire DenableIn;
    wire [0:opcodeSize-1] DOpcodeIn;
    wire [0:addressWidth-1] DAddressIn;
    wire [0:funcUnitCodeSize-1] DUnitTypeIn;
    wire [0:instructionCounterWidth] DMajIdIn;
    wire [0:instMinIdWidth-1] DMinIdIn;
    wire Dis64BitIn;
    wire [0:PidSize-1] DPidIn;
    wire [0:TidSize-1] DTidIn;
    wire [0:regAccessPatternSize-1] Dop1rwIn, Dop2rwIn;
    wire Dop1isRegIn, Dop2isRegIn, immIsExtendedIn, immIsShiftedIn;
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
        .instMinId_o(DMinIdIn),
        .is64Bit_o(Dis64BitIn),
        .instPid_o(DPidIn),
        .instTid_o(DTidIn),
        .op1rw_o(Dop1rwIn), .op2rw_o(Dop2rwIn),
        .op1isReg_o(Dop1isRegIn), .op2isReg_o(Dop2isRegIn), .immIsExtended_o(immIsExtendedIn), .immIsShifted_o(immIsShiftedIn),
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
        .Aop1rw_o(Aop1rwOut), .Aop2rw_o(Aop2rwOut), .Aop3rw_o(Aop3rwOut), .Aop4rw_o(Aop4rwOut),
        .Aop1IsReg_o(Aop1IsRegOut), .Aop2IsReg_o(Aop2IsRegOut), .Aop3IsReg_o(Aop3IsRegOut), .Aop4IsReg_o(Aop4IsRegOut),
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
        .DBody_i(DBodyIn),

        ///output
        .enable_o(enableOut),
        .instFormat_o(instFormat_o),
        .opcode_o(opcodeOut),
        .address_o(addressOut),
        .funcUnitType_o(funcUnitTypeOut),
        .majID_o(majIDOut),
        .minID_o(minIDOut),
        .is64Bit_o(is64BitOut),
        .pid_o(pidOut),
        .tid_o(tidOut),
        .op1rw_o(op1rwOut), .op2rw_o(op2rwOut), .op3rw_o(op3rwOut), .op4rw_o(op4rwOut),
        .op1IsReg_o(op1IsRegOut), .op2IsReg_o(op2IsRegOut), .op3IsReg_o(op3IsRegOut), .op4IsReg_o(op4IsRegOut),
        .body_o(bodyOut)
    );

    always @(posedge clock_i)
    begin
        if(reset_i)
            $display("Resetting decode unit");
    end

endmodule