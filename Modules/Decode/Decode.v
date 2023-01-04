`timescale 1ns / 1ps
`define DEBUG

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


TODO:
Replace POWER opcodes & Xopcodes with unified optype-specific opcodes and implement unified register space.
*/
module Decode_Unit
#(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter opcodeSize = 6,

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
    input wire [0:PidSize-1] instructionPid_i,
    input wire [0:TidSize-1] instructionTid_i,
    input wire [0:instructionCounterWidth-1] instructionMajId_i,

    //output
);


////Decode stage 1 - Format decode
wire stage1EnableOut;
wire [0:4] stage1instFormatOut;
wire [0:instructionWidth-1] stage1instructionOut;
wire [0:addressWidth-1] stage1instructionAddressOut;
wire [0:PidSize-1] stage1instructionPidOut;
wire [0:TidSize-1] stage1instructionTidOut;
wire [0:instructionCounterWidth-1] stage1instructionMajIdOut;
Format_Decoder #(
    //Sizes
    .addressWidth(addressWidth),
    .instructionWidth(instructionWidth),
    .PidSize(PidSize), .TidSize(TidSize),
    .instructionCounterWidth(instructionCounterWidth),
    .opcodeSize(opcodeSize),
    //Formats
    .I(I), .B(B), .XL(XL), .DX(DX), .SC(SC),
    .D(D), .X(X), .XO(XO), .Z23(Z23), .A(A),
    .XS(XS), .XFX(XFX), .DS(DS), .DQ(DQ), .VA(VA),
    .VX(VX), .VC(VC), .MD(MD), .MDS(MDS), .XFL(XFL),
    .Z22(Z22), .XX2(XX2), .XX3(XX3)
)
stage1Decode
(
    ///Input
    //command
    .clock_i(clock_i),
    .enable_i(enable_i), .stall_i(stall_i),
    //data
    .instruction_i(instruction_i),
    .instructionAddress_i(instructionAddress_i),
    .instructionPid_i(instructionPid_i),
    .instructionTid_i(instructionTid_i),
    .instructionMajId_i(instructionMajId_i),
    ///Output
    .outputEnable_o(outputEnable_o),
    .instFormat_o(instFormat_o),
    .instruction_o(instruction_o),
    .instructionAddress_o(instructionAddress_o),
    .instructionPid_o(instructionPid_o),
    .instructionTid_o(instructionTid_o),
    .instructionMajId_o(instructionMajId_o)
);

////Decode stage 2 - Format specific decode


////Decode stage 3 - Instruction mux to output

DecodeMux #(
)
decodeMux
(
    ////Inputs
    ///Command
    .clock_i(clockIn),
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


endmodule