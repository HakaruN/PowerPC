`timescale 1ns / 1ps
//`define DEBUG
//`define DEBUG_PRINT
//`define QUIET_INVALID
/*/////////Format decode/////////////
Writen by Josh "Hakaru" Cantwell - 02.12.2022

This decoder implements all A format instruction specified in the POWER ISA version 3.0B.
This decoder implements opcodes 1-24

TODO:
Implement outputs for special registers access

A format instructions are composed of 4 register sized operands and a single 1 bit flag however not all are used for every instruction, in that case they are ignored.
These are described as below:
Operand 1 [6:11]
FRT - Field used to specify a FPR to be used as a target
RT - Field used o specify a GPR to be used as a target

Operand 2 [11:15]
Na - Not used
FRA - Field used to specify a FPR to be used as a source
RA - Field used to specify a GTP to be used as a source or a target

Operand 3 [16:20]
FRB - Field used to specify a FPR to be used as a source
Na - Not used
RB - Field used to specify a GTP to be used as a source

operand 4 [21:25]
Na - Not used
FRC - Field used to specify a FPR to be used as a source
BC - Used to specify a bit in the CR to be used as a source

operand 5 [31]
RC - Record bit, if RC == 0, do not alter CR, if RC == 1, set teh CR field 0 or field 1 as described in section 2.3.1 on page 30 of POWER ISA version 3.0B

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
    parameter PidSize = 32, parameter TidSize = 64,
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter instMinIdWidth = 5,
    parameter opcodeSize = 12,
    parameter PrimOpcodeSize = 6, parameter regSize = 5, parameter XOSize = 5,
    parameter regAccessPatternSize = 2,//2 bit field, [0] == is read, [1] == is writen. Both can be true EG: (A = A + B)
    parameter regRead = 2'b10, parameter regWrite = 2'b01, 
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
    input wire [0:25-1] instFormat_i,
    input wire [0:PrimOpcodeSize-1] instructionOpcode_i,
    input wire [0:instructionWidth-1] instruction_i,
    input wire [0:addressWidth-1] instructionAddress_i,
    input wire is64Bit_i,
    input wire [0:PidSize-1] instructionPid_i,
    input wire [0:TidSize-1] instructionTid_i,
    input wire [0:instructionCounterWidth-1] instructionMajId_i,
    ///Output
    output reg enable_o,
    ///Instrution components
    //Instruction header
    output reg [0:opcodeSize-1] opcode_o,
    output reg [0:addressWidth-1] instructionAddress_o,//address of the instruction
    output reg [0:funcUnitCodeSize-1] functionalUnitType_o,//tells the backend what type of func unit to use
    output reg [0:instructionCounterWidth] instMajId_o,//major ID - the IDs are used to determine instruction order for reordering after execution
    output reg [0:instMinIdWidth-1] instMinId_o, numMicroOps_o,//minor ID - minor ID's are generated in decode. If an instruction generates multiple micro ops they are uniquely identified by the instMinId val. numMicroOps tells the OoO hardware how many uops were generated for the instruction so it can allocate space in the reorder buffer ahead of time
    output reg is64Bit_o,
    output reg [0:PidSize-1] instPid_o,//process ID
    output reg [0:TidSize-1] instTid_o,//Thread ID
    output reg [0:regAccessPatternSize-1] op1rw_o, op2rw_o, op3rw_o, op4rw_o,//reg operand are read/write flags
    output reg op1IsReg_o, op2IsReg_o, op3IsReg_o, op4IsReg_o,//Reg operands isReg flags
    output reg modifiesCR_o,//tells the backend if this instruction is going to need a copy of the CR to modify and writeback
    //Instruction body - data contents are 26 bits wide. There are also flags to include
    output reg [0:4 * regSize] instructionBody_o
);

`ifdef DEBUG_PRINT
integer debugFID;
`endif

always @(posedge clock_i)
begin
    `ifdef DEBUG_PRINT
    if(reset_i)
    begin
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
    end
    else `endif if(enable_i == 1 && (instFormat_i | A))
    begin
        `ifndef QUIET_INVALID
        `ifdef DEBUG $display("A format instruction recieved"); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "A format instruction recieved"); `endif
        `endif
        //Parse the instruction agnostic parts of the instruction
        instructionAddress_o <= instructionAddress_i;
        instMajId_o <= instructionMajId_i;
        instPid_o <= instructionPid_i; instTid_o <= instructionTid_i;
        is64Bit_o <= is64Bit_i;
        //parse the instruction
        instructionBody_o[0+:4 * regSize] <= instruction_i[6:25];//Copy the reg sized fields
        instructionBody_o[4*regSize] <= instruction_i[31];//copy the RC flag

        if(instructionOpcode_i == 31)
        begin
            case(instruction_i[26+:XOSize])
            15: begin//Integer select
                opcode_o <= 1;
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Integer Select instruction", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Integer Select instruction", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                //Special Regs: Na
                instMinId_o <= 0;
                numMicroOps_o <= 0;
                functionalUnitType_o <= CRUnitId;

                //Operand isReg and read/write:
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                if(instruction_i[11+:regSize] == 0)//if RA == 0
                begin
                    op2IsReg_o <= 0; op2rw_o <= 2'b00;//treat as imm
                end
                else
                begin
                    op2IsReg_o <= 1; op2rw_o <= regRead;
                end
                
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 0; op4rw_o <= regRead;
                modifiesCR_o <= 0;
                //set the functional unit to handle the instruction
                enable_o <= 1;
            end
            default: begin
                `ifndef QUIET_INVALID//invalid instructions are not reported to clean up output
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Invalid instrution revieved", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Invalid instrution revieved", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `endif
                enable_o <= 0; 
            end
            endcase
        end
        else if(instructionOpcode_i == 63)
        begin
            case(instruction_i[26+:XOSize])
            21: begin//Floating Add
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Add", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Add", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                //Special regs: FPRF FR FI FX OX UX XX VXSNAN VXISI CR1
                opcode_o <= 2;
                instMinId_o <= 0; numMicroOps_o <= 0;

                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 1; op2rw_o <= regRead;
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 0; op4rw_o <= 2'b00;//Not used
                functionalUnitType_o <= FPUnitId;    
                modifiesCR_o <= 1; 
                enable_o <= 1;      
            end
            20: begin//Floating Subtract
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Subtract", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Subtract", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                //Special regs: FPRF FR FI FX OX UX XX VXSNAN VXISI CR1
                opcode_o <= 3;
                instMinId_o <= 0; numMicroOps_o <= 0;
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 1; op2rw_o <= regRead;
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 0; op4rw_o <= 2'b00;//Not used

                functionalUnitType_o <= FPUnitId;   
                modifiesCR_o <= 1;
                enable_o <= 1;        
            end
            25: begin//Floating Multiply
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating multiply", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating multiply", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                //Special regs: FPRF FR FI FX OX UX XX VXSNAN VXIMZ CR1
                opcode_o <= 4;
                instMinId_o <= 0; numMicroOps_o <= 0;

                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 1; op2rw_o <= regRead;
                op3IsReg_o <= 0; op3rw_o <= 2'b00;//Not used
                op4IsReg_o <= 1; op4rw_o <= regRead;

                functionalUnitType_o <= FPUnitId;   
                modifiesCR_o <= 1;
                enable_o <= 1;        
            end
            18: begin//Floating Divide
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating divide", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating divide", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                //Special regs: FPRF FR FI FX OX UX XX VXSNAN VXIDI VXZDZ CR1
                opcode_o <= 5;
                instMinId_o <= 0; numMicroOps_o <= 0;
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 1; op2rw_o <= regRead;
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 0; op4rw_o <= 2'b00;//Not used
                
                functionalUnitType_o <= FPUnitId;   
                modifiesCR_o <= 1;
                enable_o <= 1;        
            end
            22: begin//Floating Square Root
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating square root", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating square root", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                //Special regs: FPRF FR FI FX OX UX XX VXSNAN VXSQRT CR1
                opcode_o <= 6;
                instMinId_o <= 0; numMicroOps_o <= 0;
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 0; op2rw_o <= 2'b00;//Not used
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 0; op4rw_o <= 2'b00;//Not used
                
                functionalUnitType_o <= FPUnitId;
                modifiesCR_o <= 1;
                enable_o <= 1;           
            end
            24: begin//Floating Reciprocal Estimate
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Reciprocal Estimate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Reciprocal Estimate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                //Special regs: FPRF FR (undefined) FI (undefined) FX OX UX XX (undefined) VXSNAN CR1
                opcode_o <= 7;
                instMinId_o <= 0; numMicroOps_o <= 0;
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 0; op2rw_o <= 2'b00;//Not used
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 0; op4rw_o <= 2'b00;//Not used
                functionalUnitType_o <= FPUnitId;  
                modifiesCR_o <= 1;
                enable_o <= 1;         
            end
            26: begin//Floating Reciprocal Square Root Estimate
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating reciprocal Square Root Estimate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating reciprocal Square Root Estimate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                //Special regs: FPRF FR (undefined) FI (undefined) FX OX UX ZX XX (undefined) VXSNAN VXSQRT CR1
                opcode_o <= 8;
                instMinId_o <= 0; numMicroOps_o <= 0;
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 0; op2rw_o <= 2'b00;//Not used
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 0; op4rw_o <= 2'b00;//Not used
                functionalUnitType_o <= FPUnitId; 
                modifiesCR_o <= 1;
                enable_o <= 1;          
            end
            29: begin//Floating Multiply-Add
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Multiply-Add", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Multiply-Add", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                //Special regs: FPRF FR FI FX OX UX XX VXSNAN VXISI VXIMZ CR1
                opcode_o <= 9;
                instMinId_o <= 0; numMicroOps_o <= 0;
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 1; op2rw_o <= regRead;
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 1; op4rw_o <= regRead;
                functionalUnitType_o <= FPUnitId;   
                modifiesCR_o <= 1; 
                enable_o <= 1;      
            end
            28: begin//Floating Multiply-Subtract
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Multiply-Subtract", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Multiply-Subtract", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                //Special regs: FPRF FR FI FX OX UX XX VXSNAN VXISI VXIMZ CR1
                opcode_o <= 10;
                instMinId_o <= 0; numMicroOps_o <= 0;
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 1; op2rw_o <= regRead;
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 1; op4rw_o <= regRead;
                functionalUnitType_o <= FPUnitId;     
                modifiesCR_o <= 1;
                enable_o <= 1;      
            end
            31: begin//Floating Negative Multiply-Add
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Negative Multiply-Add", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Negative Multiply-Add", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                //Special regs: FPRF FR FI FX OX UX XX VXSNAN VXISI VXIMZ CR1
                opcode_o <= 11;
                instMinId_o <= 0; numMicroOps_o <= 0;
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 1; op2rw_o <= regRead;
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 1; op4rw_o <= regRead;
                functionalUnitType_o <= FPUnitId;       
                modifiesCR_o <= 1;
                enable_o <= 1;    
            end
            30: begin//Floating Negative Multiply-Subtract
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Negative Multiply-Subtract", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID,
                 "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Negative Multiply-Subtract", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                 //Special regs: FPRF FR FI FX OX UX XX VXSNAN VXISI VXIMZ CR1
                opcode_o <= 12;
                instMinId_o <= 0; numMicroOps_o <= 0;
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 1; op2rw_o <= regRead;
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 1; op4rw_o <= regRead;
                functionalUnitType_o <= FPUnitId;      
                modifiesCR_o <= 1;
                enable_o <= 1;     
            end
            23: begin//Floating Select
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Select", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Select", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                //Special regs: CR1
                opcode_o <= 13;
                instMinId_o <= 0; numMicroOps_o <= 0;
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 1; op2rw_o <= regRead;
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 1; op4rw_o <= regRead;
                functionalUnitType_o <= FPUnitId;     
                modifiesCR_o <= 1; 
                enable_o <= 1;     
            end
            default: begin
                `ifndef QUIET_INVALID//invalid instructions are not reported to clean up output
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Invalid instrution revieved", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Invalid instrution revieved", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `endif
                enable_o <= 0;
            end
            endcase
        end
        else if(instructionOpcode_i == 59)//11 instructions
        begin
            case(instruction_i[26+:XOSize])
            21: begin//Floating Add Single
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Add Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Add Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                //Special regs: FPRF FR FI FX OX UX XX VXSNAN VXISI CR1
                opcode_o <= 14;
                instMinId_o <= 0; numMicroOps_o <= 0;
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 1; op2rw_o <= regRead;
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 0; op4rw_o <= 2'b00;//Not used
                functionalUnitType_o <= FPUnitId; 
                modifiesCR_o <= 1;
                enable_o <= 1;          
            end
            20: begin//Floating Subtract Single
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Subtract Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Subtract Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                //Special regs: FPRF FR FI FX OX UX XX VXSNAN VXISI CR1
                opcode_o <= 15;
                instMinId_o <= 0; numMicroOps_o <= 0;
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 1; op2rw_o <= regRead;
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 0; op4rw_o <= 2'b00;//Not used
                functionalUnitType_o <= FPUnitId; 
                modifiesCR_o <= 1;         
                enable_o <= 1; 
            end
            25: begin//Floating Multiply Single
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Multiply Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Multiply Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                //Special regs: FPRF FR FI FX OX UX XX VXSNAN VXIMZ CR1
                opcode_o <= 16;
                instMinId_o <= 0; numMicroOps_o <= 0;
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 1; op2rw_o <= regRead;
                op3IsReg_o <= 0; op3rw_o <= 2'b00;//Not used
                op4IsReg_o <= 1; op4rw_o <= regRead;
                functionalUnitType_o <= FPUnitId;   
                modifiesCR_o <= 1;  
                enable_o <= 1;      
            end
            18: begin//Floating Divide Single
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Divide Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Divide Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                //Special regs: FPRF FR FI FX OX UX XX VXSNAN VXIDI VXZDZ CR1
                opcode_o <= 17;
                instMinId_o <= 0; numMicroOps_o <= 0;
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 1; op2rw_o <= regRead;
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 0; op4rw_o <= 2'b00;//Not used
                functionalUnitType_o <= FPUnitId;
                modifiesCR_o <= 1;     
                enable_o <= 1;      
            end
            22: begin//Floating Square Root Single
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Square Root Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Square Root Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                //Special regs: FPRF FR FI FX OX UX XX VXSNAN VXSQRT CR1
                opcode_o <= 18;
                instMinId_o <= 0; numMicroOps_o <= 0;
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 0; op2rw_o <= 2'b00;//Not used
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 0; op4rw_o <= 2'b00;//Not used
                functionalUnitType_o <= FPUnitId; 
                modifiesCR_o <= 1;   
                enable_o <= 1;       
            end
            24: begin//Floating Reciprocal Estimate Single
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Reciprocal Estimate Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Reciprocal Estimate Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                //Special regs: FPRF FR (undefined) FI (undefined) FX OX UX XX (undefined) VXSNAN CR1
                opcode_o <= 19;
                instMinId_o <= 0; numMicroOps_o <= 0;
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 0; op2rw_o <= 2'b00;//Not used
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 0; op4rw_o <= 2'b00;//Not used
                functionalUnitType_o <= FPUnitId;    
                modifiesCR_o <= 1;
                enable_o <= 1;       
            end
            26: begin//Floating Reciprocal Square Root Estimate Single
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Reciprocal Square Root Estimate Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Reciprocal Square Root Estimate Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif                
                //Special regs: FPRF FR (undefined) FI (undefined) FX OX UX ZX XX (undefined) VXSNAN VXSQRT CR1
                opcode_o <= 20;
                instMinId_o <= 0; numMicroOps_o <= 0;
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 0; op2rw_o <= 2'b00;//Not used
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 0; op4rw_o <= 2'b00;//Not used
                functionalUnitType_o <= FPUnitId;     
                modifiesCR_o <= 1;    
                enable_o <= 1;  
            end
            29: begin//Floating Multiply-Add Single
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Multiply-Add Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Multiply-Add Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif                
                //Special regs: FPRF FR FI FX OX UX XX VXSNAN VXISI VXIMZ CR1
                opcode_o <= 21;
                instMinId_o <= 0; numMicroOps_o <= 0;
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 1; op2rw_o <= regRead;
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 1; op4rw_o <= regRead;
                functionalUnitType_o <= FPUnitId;   
                modifiesCR_o <= 1;     
                enable_o <= 1;   
            end
            28: begin//Floating Multiply-Subtract Single
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Multiply-Subtract Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Multiply-Subtract Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif    
                //Special regs: FPRF FR FI FX OX UX XX VXSNAN VXISI VXIMZ CR1
                opcode_o <= 22;
                instMinId_o <= 0; numMicroOps_o <= 0;
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 1; op2rw_o <= regRead;
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 1; op4rw_o <= regRead;
                functionalUnitType_o <= FPUnitId;        
                modifiesCR_o <= 1;  
                enable_o <= 1;
            end
            31: begin//Floating Negative Multiply-Add Single - not Hit
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Negative Multiply-Add Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Negative Multiply-Add Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif    
                //Special regs: FPRF FR FI FX OX UX XX VXSNAN VXISI VXIMZ CR1
                opcode_o <= 23;
                instMinId_o <= 0; numMicroOps_o <= 0;
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 1; op2rw_o <= regRead;
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 1; op4rw_o <= regRead;
                functionalUnitType_o <= FPUnitId;      
                modifiesCR_o <= 1;
                enable_o <= 1;     
            end
            30: begin//Floating Negative Multiply-Subtract Single
                `ifdef DEBUG $display("Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Negative Multiply-Subtract Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst: %d. Opcode: %b (%d), Xopcode: %b (%d). Floating Negative Multiply-Subtract Single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif    
                //Special regs: FPRF FR FI FX OX UX XX VXSNAN VXISI VXIMZ CR1
                opcode_o <= 24;
                instMinId_o <= 0; numMicroOps_o <= 0;
                op1IsReg_o <= 1; op1rw_o <= regWrite;
                op2IsReg_o <= 1; op2rw_o <= regRead;
                op3IsReg_o <= 1; op3rw_o <= regRead;
                op4IsReg_o <= 1; op4rw_o <= regRead;
                functionalUnitType_o <= FPUnitId;   
                modifiesCR_o <= 1;     
                enable_o <= 1;  
            end
            default: begin
                `ifndef QUIET_INVALID//invalid instructions are not reported to clean up output
                `ifdef DEBUG $display("Decode 2 A-form Inst:: %d. Opcode: %b (%d), Xopcode: %b (%d). Invalid instrution revieved", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 A-form Inst:: %d. Opcode: %b (%d), Xopcode: %b (%d). Invalid instrution revieved", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instruction_i[26+:XOSize], instruction_i[26+:XOSize]); `endif
                `endif
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