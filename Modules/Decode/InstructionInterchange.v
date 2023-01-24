`timescale 1ns / 1ps
`define DEBUG
`define DEBUG_PRINT

/*///////////////Fetch Unit////////////////////////////
Writen by Josh "Hakaru" Cantwell - 24.01.2023
*//////////////////////////////////////////////////////

module instructionInterchange
#(

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
    input wire [0:64-1] body1_i,
    input wire [0:64-1] body2_i,
    input wire [0:64-1] body3_i,
    input wire [0:64-1] body4_i,
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