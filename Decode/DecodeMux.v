`timescale 1ns / 1ps
`define DEBUG
`define DEBUG_PRINT

/*/////////Format decode/////////////
Writen by Josh "Hakaru" Cantwell - 04.01.2023

This is the third stage of the decode unit, it is responsible for multiplexing the outputs of the second stage (format specific decoders) into a single output.



*////////////////////////////////////

module DecodeMux
#(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter instMinIdWidth = 7,
    parameter opcodeSize = 6, parameter regSize = 5,
    parameter regAccessPatternSize = 2,//2 bit field, [0] == is read, [1] == is writen. Both can be true EG: (A = A + B)
    parameter regRead = 2'b10, parameter regWrite = 2'b01, 
    parameter immWidth = 64,
    ////Generic
    parameter funcUnitCodeSize = 3, //can have up to 8 types of func unit.
    //FX = int, FP = float, VX = vector, CR = condition, LS = load/store
    parameter FXUnitId = 0, parameter FPUnitId = 1, parameter VXUnitId = 2, parameter CRUnitId = 3, parameter LSUnitId = 4,  parameter BranchUnitID = 6,   

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
)
(
    ////Inputs
    ///Command
    input wire clock_i,    

    ///A format
    input wire Aenable_i,
    input wire [0:opcodeSize-1] AOpcode_i,
    input wire [0:XOSize-1] AXO_i,
    input wire [0:addressWidth-1] AAddress_i,
    input wire [0:funcUnitCodeSize-1] AUnitType_i,
    input wire [0:instructionCounterWidth] AMajId_i,
    input wire [0:instMinIdWidth-1] AMinId_i,
    input wire Ais64Bit_i,
    input wire [0:PidSize-1] APid_i,
    input wire [0:TidSize-1] ATid_i,
    input wire [0:regAccessPatternSize-1] ARTrw_i, ARArw_i, ARBrw_i, ARCrw_i,
    input wire AoperandRTisReg_i, AoperandRAisReg_i, AoperandRBisReg_i, AoperandRCisReg_i,
    input wire [0:4 * regSize] ABody_i,

    ///B format
    input wire Benable_i,
    input wire [0:opcodeSize-1] BOpcode_i,
    input wire [0:addressWidth-1] BAddress_i,
    input wire [0:funcUnitCodeSize-1] BUnitType_i,
    input wire [0:instructionCounterWidth] BMajId_i,
    input wire [0:instMinIdWidth-1] BMinId_i,
    input wire Bis64Bit_i,
    input wire [0:PidSize-1] BPid_i,
    input wire [0:TidSize-1] BTid_i,
    input wire [0:(2 * regSize) + BimmediateSize + 3] BBody_i,

    ///D format
    input wire Denable_i,
    input wire [0:opcodeSize-1] DOpcode_i,
    input wire [0:addressWidth-1] DAddress_i,
    input wire [0:funcUnitCodeSize-1] DUnitType_i,
    input wire [0:instructionCounterWidth] DMajId_i,
    input wire [0:instMinIdWidth-1] DMinId_i,
    input wire Dis64Bit_i,
    input wire [0:PidSize-1] DPid_i,
    input wire [0:TidSize-1] DTid_i,
    input wire [0:regAccessPatternSize-1] Dop1rw_i, Dop2rw_i,
    input wire op1isReg_i, op2isReg_i, immIsExtended_i, immIsShifted_i,
    input wire [0:(2 * regSize) + DimmediateSize - 1] DBody_i,

    ///output
    output wire enable_o,
    output wire [0:opcodeSize-1] opcode_o,
    output wire [0addressWidth-1] address_o,
    output wire [0:funcUnitCodeSize-1] funcUnitType_o,
    output wire [0:instructionCounterWidth-1] majID_o,
    output wire [0:instMinIdWidth-1] minID_o,
    output wire is64Bit_o,
    output wire [0:PidSize-1] pid_o,
    output wire [0:TidSize-1] tid_o,
    output wire [0:regSize-1] op1_o, op2_o, op3_o, op4_o,
    output wire [0:immWidth-1] imm_o
);

always @(posedge clock_i)
begin
    if(Aenable_i)
    begin
        enable_o <= 1;
        opcode_o <= AOpcode_i;
    end
    else if(Benable_i)
    begin
        enable_o <= 1;
    end
    else if(Denable_i)
    begin
        enable_o <= 1;
    end
    else
    begin
        enable_o <= 1;
    end

end

endmodule