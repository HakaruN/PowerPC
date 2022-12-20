`timescale 1ns / 1ps
`define DEBUG

/*/////////Format decode/////////////
Writen by Josh "Hakaru" Cantwell - 02.12.2022

This is the decoder for B format instructions.
A format instructions are:
Integer select
*/

module AFormat_Decoder
#(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter instMinIdWidth = 7,
    parameter opcodeSize = 6, parameter regSize = 5, parameter XOSize = 5,
    parameter regAccessPatternSize = 2,//2 bit field, [0] == is read, [1] == is writen. Both can be true EG: (A = A + B)
    parameter regRead = 2'b10, parameter regWrite = 2'b01, 
    parameter isImmediateSize = 1, parameter immediateSize = 14,
    parameter funcUnitCodeSize = 3, //can have up to 8 types of func unit.
    //FX = int, FP = float, VX = vector, CR = condition, LS = load/store
    parameter FXUnitId = 0, parameter FPUnitId = 1, parameter VXUnitId = 2, parameter CRUnitId = 3, parameter LSUnitId = 4,     
    parameter B = 2**01, 
)
(
    ///Input
    //command
    input wire clock_i,
    input wire enable_i, stall_i,
    //Data
    input wire [0:25] instFormat_i,
    input wire [0:opcodeSize-1] instructionOpcode_i,
    input wire [0:instructionWidth-1] instruction_i,
    input wire [0:addressWidth-1] instructionAddress_i,
    input wire [0:PidSize-1] instructionPid_i,
    input wire [0:TidSize-1] instructionTid_i,
    input wire [0:instructionCounterWidth-1] instructionMajId_i
    ///Output
    output reg enable_o,
    ///Instrution components
    //Instruction header
    output reg [0:opcodeSize-1] instructionOpcode_o,//primary opcode
    output reg [0:addressWidth-1] instructionAddress_o,//address of the instruction
    output reg [0:funcUnitCodeSize-1] functionalUnitType_o,//tells the backend what type of func unit to use
    output reg [0:instructionCounterWidth] instMajId_o,//major ID - the IDs are used to determine instruction order for reordering after execution
    output reg [0:instMinIdWidth-1] instMinId_o,//minor ID - minor ID's are generated in decode if an instruction generated micro ops, these are differentiated by the minor ID, they will have the same major ID
    output reg [0:PidSize-1] instPid_o,//process ID
    output reg [0:TidSize-1] instTid_o,//Thread ID
    output reg [0:]
    //Instruction body - data contents are 26 bits wide. There are also flags to include
    output reg [0:(2 * regSize) + immediateSize + 1] instructionBody_o,//the +1 is because there are actually an aditional 2 bits in the inst, which offets the -1 to be +1.
    output reg [0:regSize-1] operandO_o, operandI_o,//Operands (reg sized)
    output reg [0:immediateSize-1]operandD_o,//immediate capable operand
    output reg operandOisReg_o, operandIisReg_o
    output reg [0:regAccessPatternSize-1] operandOAccess_o, operandIAccess_o, operandDAccess_o//how are the operands accessed, are they writen to and/or read from
    output reg AA_o, LK_o;
);

always @(posedge clock_i)
begin
    if(enable_i && instFormat_i || B)
    begin
        `ifdef DEBUG $display("B format instruction recieved"); `endif
        //Parse the instruction agnostic parts of the instruction
        instructionOpcode_o <= instructionOpcode_i;
        instructionAddress_o <= instructionAddress_i;
        instMajId_o <= instructionMajId_i;
        instPid_o <= instructionPid_i; instTid_o <= instructionTid_i;
        operandT_o <= instruction_i[6+:regSize]; operandA_o <= instruction_i[11+:regSize];
        operandB_o <= instruction_i[16+:regSize]; operandC_o <= instruction_i[21+:regSize];
        Rc_o <= instruction_i[31];
    end
end


endmodule