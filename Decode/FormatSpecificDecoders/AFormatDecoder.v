`timescale 1ns / 1ps
`define DEBUG
`define DEBUG_PRINT
/*/////////Format decode/////////////
Writen by Josh "Hakaru" Cantwell - 02.12.2022

This is the decoder for A format instructions.
This decoder implements opcodes 1-23

A format instructions are:
Integer select
Floating Add
Floating Subtract
Floating Multiply
Floating Divide
Floating Square Root
Floating Reciprocal Estimate
Floating Reciprocal Square Root Estimate
Floating Multiply-Add
Floating Multiply-Subtract
Floating Negative Multiply-Add
Floating Negative Multiply-Subtract
Floating Select
Floating Add Single
Floating Subtract Single
Floating Multiply Single
Floating Divide Single
Floating Square Root Single
Floating Reciprocal Estimate Single
Floating Reciprocal Square Root Estimate Single
Floating Multiply-Add Single
Floating Multiply-Subtract Single
Floating Negative Multiply-Add Single
Floating Negative Multiply-Subtract Single
*/

module AFormatDecoder
#(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter instMinIdWidth = 7,
    parameter opcodeSize = 12,
    parameter PrimOpcodeSize = 6, parameter regSize = 5, parameter XOSize = 5,
    parameter regAccessPatternSize = 2,//2 bit field, [0] == is read, [1] == is writen. Both can be true EG: (A = A + B)
    parameter read = 2'b10, parameter write = 2'b01, 
    parameter immediateSize = 24,
    parameter funcUnitCodeSize = 3, //can have up to 8 types of func unit.
    //FX = int, FP = float, VX = vector, CR = condition, LS = load/store
    parameter FXUnitId = 0, parameter FPUnitId = 1, parameter VXUnitId = 2, parameter CRUnitId = 3, parameter LSUnitId = 4,     
    parameter A = 2**00, parameter ADecoderInstance = 0
)
(
    ///Input
    //command
    input wire clock_i,
    `ifdef DEBUG_PRINT 
    input wire reset_i,
`endif
    input wire enable_i, stall_i,
    //Data
    input wire [0:25] instFormat_i,
    input wire [0:PrimOpcodeSize-1] instructionOpcode_i,
    input wire [0:instructionWidth-1] instruction_i,
    input wire [0:addressWidth-1] instructionAddress_i,
    input wire [0:PidSize-1] instructionPid_i,
    input wire [0:TidSize-1] instructionTid_i,
    input wire [0:instructionCounterWidth-1] instructionMajId_i
    ///Output
    output reg enable_o,
    ///Instrution components
    //Instruction header
    output reg [0:opcodeSize-1] opcode_o,
    output reg [0:addressWidth-1] instructionAddress_o,//address of the instruction
    output reg [0:funcUnitCodeSize-1] functionalUnitType_o,//tells the backend what type of func unit to use
    output reg [0:instructionCounterWidth] instMajId_o,//major ID - the IDs are used to determine instruction order for reordering after execution
    output reg [0:instMinIdWidth-1] instMinId_o,//minor ID - minor ID's are generated in decode if an instruction generated micro ops, these are differentiated by the minor ID, they will have the same major ID
    output reg is64Bit_o,
    output reg [0:PidSize-1] instPid_o,//process ID
    output reg [0:TidSize-1] instTid_o,//Thread ID

    output reg [0:regAccessPatternSize-1] RTrw_o, RArw_o, RBrw_o, RCrw_o,//how are the operands accessed, are they writen to and/or read from [0] write flag, [1] write flag.
    output reg operandRTisReg_o, operandRAisReg_o, operandRBisReg_o, operandRCisReg_o,//Always a reg
    //Instruction body - data contents are 26 bits wide. There are also flags to include
    output reg [0:4 * regSize] instructionBody_o,
);

`ifdef DEBUG_PRINT
integer debugFID;
`endif

always @(posedge clock_i)
begin
    if(reset_i)
    begin
        `ifdef DEBUG_PRINT
        case(ADecoderInstance)//If we have multiple decoders, they each get different files. The second number indicates the decoder# log file.
        0: begin 
            debugFID = $fopen("ADecode0.log", "w");
        end
        1: begin 
            debugFID = $fopen("ADecode1.log", "w");
        end
        2: begin 
            debugFID = $fopen("ADecode2.log", "w");
        end
        3: begin 
            debugFID = $fopen("ADecode3.log", "w");
        end
        4: begin 
            debugFID = $fopen("ADecode4.log", "w");
        end
        5: begin 
            debugFID = $fopen("ADecode5.log", "w");
        end
        6: begin 
            debugFID = $fopen("ADecode6.log", "w");
        end
        7: begin 
            debugFID = $fopen("ADecode7.log", "w");
        end
        endcase
        `endif
    end
    else if(enable_i && instFormat_i || A)
    begin
        `ifdef DEBUG $display("A format instruction recieved"); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "A format instruction recieved"); `endif
        //Parse the instruction agnostic parts of the instruction
        XO_o <= instruction_i[26+:XOSize];
        instructionAddress_o <= instructionAddress_i;
        instMajId_o <= instructionMajId_i;
        instPid_o <= instructionPid_i; instTid_o <= instructionTid_i;
        instructionBody_o[0+:4 * regSize-1] <= instruction_i[6:25];
        instructionBody_o[4*regSize] <= instruction_i[31];

        if(instructionOpcode_i == 31)
        begin
            case(instruction_i[26+:XOSize])
            15: begin//Integer select
                opcode_o <= 1;
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Integer Seclect instruction", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Integer Seclect instruction", instructionMajId_i); `endif
                instMinId_o <= 0;
                functionalUnitType_o <= CRUnitId;

                //Operand isReg and read/write:
                operandRTisReg_o <= 1; RTrw_o <= write;
                if(instruction_i[11+:regSize] == 0)//if RA == 0
                    operandRAisReg_o <= 0; RArw_o <= read;
                else
                    operandRAisReg_o <= 1; RArw_o <= read;
                operandRBisReg_o <= 1; RBrw_o <= read;
                operandRCisReg_o <= 0; RCrw_o <= read;
                //set the functional unit to handle the instruction

                enable_o <= 1;
            end
            default: begin
                `ifdef DEBUG $display("Decode 2 A-form: (Inst: %h) Invalid instrution revieved", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form: (Inst: %h) Invalid instrution revieved", instructionMajId_i); `endif
                enable_o <= 0; 
            end
            endcase
        end
        else if(instructionOpcode_i == 63)
        begin
            case(instruction_i[26+:XOSize])
            21: begin//Floating Add
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating Add", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating Add", instructionMajId_i); `endif
                opcode_o <= 2;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId;     
                enable_o <= 1;      
            end
            20: begin//Floating Subtract
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating Subtract", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating Subtract", instructionMajId_i); `endif
                opcode_o <= 3;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId;   
                enable_o <= 1;        
            end
            25: begin//Floating Multiply
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating multiply", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating multiply", instructionMajId_i); `endif
                opcode_o <= 4;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 0; RBrw_o <= regRead;//Not used
                operandRCisReg_o <= 1; RCrw_o <= regRead;
                functionalUnitType_o <= FPUnitId;   
                enable_o <= 1;        
            end
            18: begin//Floating Divide
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating divide", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating divide", instructionMajId_i); `endif
                opcode_o <= 5;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId;   
                enable_o <= 1;        
            end
            22: begin//Floating Square Root
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating square root", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating square root", instructionMajId_i); `endif
                opcode_o <= 6;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 0; RArw_o <= regRead;//Not used
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId;
                enable_o <= 1;           
            end
            24: begin//Floating Reciprocal Estimate
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating Reciprocal Estimate", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating Reciprocal Estimate", instructionMajId_i); `endif
                opcode_o <= 7;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 0; RArw_o <= regRead;//Not used
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId;  
                enable_o <= 1;         
            end
            26: begin//Floating Reciprocal Square Root Estimate
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating reciprocal Square Root Estimate", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating reciprocal Square Root Estimate", instructionMajId_i); `endif
                opcode_o <= 8;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 0; RArw_o <= regRead;//Not used
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId; 
                enable_o <= 1;          
            end
            29: begin//Floating Multiply-Add
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating Multiply-Add", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating Multiply-Add", instructionMajId_i); `endif
                opcode_o <= 9;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 1; RCrw_o <= regRead;
                functionalUnitType_o <= FPUnitId;     
                enable_o <= 1;      
            end
            28: begin//Floating Multiply-Subtract
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating Multiply-Subtract", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating Multiply-Subtract", instructionMajId_i); `endif
                opcode_o <= 10;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 1; RCrw_o <= regRead;
                functionalUnitType_o <= FPUnitId;     
                enable_o <= 1;      
            end
            31: begin//Floating Negative Multiply-Add
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating Negative Multiply-Add", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating Negative Multiply-Add", instructionMajId_i); `endif
                opcode_o <= 11;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 1; RBrw_o <= regRead;
                functionalUnitType_o <= FPUnitId;       
                enable_o <= 1;    
            end
            30: begin//Floating Negative Multiply-Subtract
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating Negative Multiply-Subtract", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating Negative Multiply-Subtract", instructionMajId_i); `endif
                opcode_o <= 12;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 1; RBrw_o <= regRead;
                functionalUnitType_o <= FPUnitId;      
                enable_o <= 1;     
            end
            23: begin//Floating Select
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating Select", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating Select", instructionMajId_i); `endif
                opcode_o <= 13;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 1; RBrw_o <= regRead;
                functionalUnitType_o <= FPUnitId;      
                enable_o <= 1;     
            end
            default: begin
                `ifdef DEBUG $display("Decode 2 A-form: (Inst: %h) Invalid instrution revieved", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form: (Inst: %h) Invalid instrution revieved", instructionMajId_i); `endif
                enable_o <= 0; 
            end
            endcase
        end
        else if(instructionOpcode_i == 59)
        begin
            case(instruction_i[26+:XOSize])
            21: begin//Floating Add Single
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating Add Single", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating Add Single", instructionMajId_i); `endif
                opcode_o <= 14;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId; 
                enable_o <= 1;          
            end
            20: begin//Floating Subtract Single
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating Subtract Single", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating Subtract Single", instructionMajId_i); `endif
                opcode_o <= 15;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId;          
                enable_o <= 1; 
            end
            25: begin//Floating Multiply Single
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating Multiply Single", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating Multiply Single", instructionMajId_i); `endif
                opcode_o <= 15;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 0; RBrw_o <= regRead;//Not used
                operandRCisReg_o <= 1; RCrw_o <= regRead;
                functionalUnitType_o <= FPUnitId;     
                enable_o <= 1;      
            end
            18: begin//Floating Divide Single
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating Divide Single", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating Divide Single", instructionMajId_i); `endif
                opcode_o <= 16;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId;     
                enable_o <= 1;      
            end
            22: begin//Floating Square Root Single
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating Square Root Single", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating Square Root Single", instructionMajId_i); `endif
                opcode_o <= 17;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 0; RArw_o <= regRead;//Not used
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId;    
                enable_o <= 1;       
            end
            24: begin//Floating Reciprocal Estimate Single
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating Reciprocal Estimate Single", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating Reciprocal Estimate Single", instructionMajId_i); `endif
                opcode_o <= 18;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 0; RArw_o <= regRead;//Not used
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId;    
                enable_o <= 1;       
            end
            26: begin//Floating Reciprocal Square Root Estimate Single
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating Reciprocal Square Root Estimate Single", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating Reciprocal Square Root Estimate Single", instructionMajId_i); `endif                
                opcode_o <= 19;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 0; RArw_o <= regRead;//Not used
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId;         
                enable_o <= 1;  
            end
            29: begin//Floating Multiply-Add Single
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating Multiply-Add Single", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating Multiply-Add Single", instructionMajId_i); `endif                
                opcode_o <= 20;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 1; RCrw_o <= regRead;
                functionalUnitType_o <= FPUnitId;        
                enable_o <= 1;   
            end
            28: begin//Floating Multiply-Subtract Single
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating Multiply-Subtract Single", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating Multiply-Subtract Single", instructionMajId_i); `endif    
                opcode_o <= 21;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 1; RCrw_o <= regRead;
                functionalUnitType_o <= FPUnitId;           
                enable_o <= 1;
            end
            31: begin//Floating Negative Multiply-Add Single
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating Negative Multiply-Add Single", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating Negative Multiply-Add Single", instructionMajId_i); `endif    
                opcode_o <= 22;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 1; RCrw_o <= regRead;
                functionalUnitType_o <= FPUnitId;      
                enable_o <= 1;     
            end
            30: begin//Floating Negative Multiply-Subtract Single
                `ifdef DEBUG $display("Decode 2 A-form (Inst: %h): Floating Negative Multiply-Subtract Single", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form (Inst: %h): Floating Negative Multiply-Subtract Single", instructionMajId_i); `endif    
                opcode_o <= 23;
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 1; RCrw_o <= regRead;
                functionalUnitType_o <= FPUnitId;         
                enable_o <= 1;  
            end
            default: begin
                `ifdef DEBUG $display("Decode 2 A-form: (Inst: %h) Invalid instrution revieved", instructionMajId_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form: (Inst: %h) Invalid instrution revieved", instructionMajId_i); `endif
                enable_o <= 0; 
            end
            endcase            
        end
        else
        begin
            enable_o <= 0; 
        end
    end
    else
    begin
        enable_o <= 0; 
    end
end    

endmodule