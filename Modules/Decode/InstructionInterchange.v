`timescale 1ns / 1ps
`define DEBUG
`define DEBUG_PRINT

/*///////////////Interchance////////////////////////////
Writen by Josh "Hakaru" Cantwell - 24.01.2023

The interchange is the hardware implementing the global OoO hardware. This includes the in order instruction queue similar to the dispatch queue for a standard OoO implementation.
This queue is 4 instructions wide, these instructions' global register operands (EG CR) are then evaluated and renamed if needed.
The instructions are then recorded in the global ROB.
They are then dispatched individually to the seperate instruction-specific OoO backends via a backend unique dispatch queue. This allows the interchange
to track the load on each of the OoO units by tracking the number of instructions in the queue therefore it may take action to shutdown unloaded units thus saving power
or down clock the OoO unit to keep it running at a lower power consumption.

Cycle 1)
    Generate entry for each instruction into the Global ROB.



*//////////////////////////////////////////////////////

module instructionInterchange
#(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 32, parameter TidSize = 64,
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter instMinIdWidth = 5,//width of inst minor ID
    parameter primOpcodeSize = 6,
    parameter opcodeSize = 12,
    parameter regSize = 5,
    parameter regAccessPatternSize = 2,//2 bit field, [0] == is read, [1] == is writen. Both can be true EG: (A = A + B)
    parameter funcUnitCodeSize = 3,

    ///ROB Params
    parameter robIndexWidth = 7,

)
(
    input wire clock_i, reset_i, 
    input wire enable1_i, enable2_i, enable3_i, enable3_i, 
    input wire [0:25-1] instFormat1_i, instFormat2_i, instFormat3_i, instFormat4_i, 
    input wire [0:opcodeSize-1] opcode1_i, opcode2_i, opcode3_i, opcode4_i, 
    input wire [0:addressWidth-1] address2_i, address2_i, address3_i, address4_i, 
    input wire [0:funcUnitCodeSize-1] funcUnitType1_i, funcUnitType2_i, funcUnitType3_i, funcUnitType4_i, 
    input wire [0:instructionCounterWidth-1] majID1_i, majID2_i, majID3_i, majID4_i, 
    input wire [0:instMinIdWidth-1] minID1_i, minID2_i, minID3_i, minID4_i, 
    input wire [0:instMinIdWidth-1] numMicroOps1_i, numMicroOps2_i, numMicroOps3_i, numMicroOps4_i, 
    input wire is64Bit1_i, is64Bit2_i, is64Bit3_i, is64Bit4_i, 
    input wire [0:PidSize-1] pid1_i, pid2_i, pid3_i, pid4_i, 
    input wire [0:TidSize-1] tid1_i, tid2_i, tid3_i, tid4_i, 
    input wire [0:regAccessPatternSize-1] op1rw1_i, op2rw1_i, op3rw1_i, op4rw1_i,
    input wire [0:regAccessPatternSize-1] op1rw2_i, op2rw2_i, op3rw2_i, op4rw2_i,
    input wire [0:regAccessPatternSize-1] op1rw3_i, op2rw3_i, op3rw3_i, op4rw3_i,
    input wire [0:regAccessPatternSize-1] op1rw4_i, op2rw4_i, op3rw4_i, op4rw4_i,
    input wire op1IsReg1_i, op2IsReg1_i, op3IsReg1_i, op4IsReg1_i,
    input wire op1IsReg2_i, op2IsReg2_i, op3IsReg2_i, op4IsReg2_i,
    input wire op1IsReg3_i, op2IsReg3_i, op3IsReg3_i, op4IsReg3_i,
    input wire op1IsReg4_i, op2IsReg4_i, op3IsReg4_i, op4IsReg4_i,
    input wire modifiesCR1_o, modifiesCR2_o, modifiesCR3_o, modifiesCR4_o, 
    input wire [0:64-1] body1_i,
    input wire [0:64-1] body2_i,
    input wire [0:64-1] body3_i,
    input wire [0:64-1] body4_i,

    ///ROB IO
    //input - recieve the ROB ID's back from the ROB for the issued instructions

    //output - issue instructions to the ROB
    output reg robEn1_o, robEn2_o, robEn3_o, robEn4_o, 
    output reg [0:PidSize-1] robpid1_o, robpid2_o, robpid3_o, robpid4_o, 
    output reg [0:TidSize-1] robtid1_o, robtid2_o, robtid3_o, robtid4_o, 
    output reg [0:instMinIdWidth-1] numMicroOps1_o, numMicroOps2_o, numMicroOps3_o, numMicroOps4_o,

);





always @(posedge clock_i)
begin
    if(reset_i)
    begin
    end
    else
    begin

    end
end




endmodule