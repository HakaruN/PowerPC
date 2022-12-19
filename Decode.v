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
*/
module Decode_Unit
#(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
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


////Decode stage 2 - Format specific decode


////Decode stage 3 - Instruction mux to output


endmodule