`timescale 1ns / 1ps
`define DEBUG

/*/////////Format decode/////////////
Writen by Josh "Hakaru" Cantwell - 02.12.2022

This is the decoder for A format instructions.
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
    parameter opcodeSize = 6, parameter regSize = 5, parameter XOSize = 5,
    parameter regAccessPatternSize = 2,//2 bit field, [0] == is read, [1] == is writen. Both can be true EG: (A = A + B)
    parameter read = 2'b10, parameter write = 2'b01, 
    parameter immediateSize = 24,
    parameter funcUnitCodeSize = 3, //can have up to 8 types of func unit.
    //FX = int, FP = float, VX = vector, CR = condition, LS = load/store
    parameter FXUnitId = 0, parameter FPUnitId = 1, parameter VXUnitId = 2, parameter CRUnitId = 3, parameter LSUnitId = 4,     
    parameter A = 2**00, 
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
    output reg [0:XOSize-1] XO_o,//extended opcode
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

always @(posedge clock_i)
begin
    if(enable_i && instFormat_i || A)
    begin
        `ifdef DEBUG $display("A format instruction recieved"); `endif
        //Parse the instruction agnostic parts of the instruction
        instructionOpcode_o <= instructionOpcode_i;
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
                `ifdef DEBUG $display("Decode 2 A-form: Integer Seclect instruction");`endif
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
                `ifdef DEBUG $display("Decode 2 A-form: Invalid instrution revieved");`endif
                enable_o <= 0; 
            end
            endcase
        end
        else if(instructionOpcode_i == 63)
        begin
            case(instruction_i[26+:XOSize])
            21: begin//Floating Add
                `ifdef DEBUG $display("Decode 2 A-form: Floating Add");`endif
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId;     
                enable_o <= 1;      
            end
            20: begin//Floating Subtract
                `ifdef DEBUG $display("Decode 2 A-form: Floating Subtract");`endif
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId;   
                enable_o <= 1;        
            end
            25: begin//Floating Multiply
                `ifdef DEBUG $display("Decode 2 A-form: Floating Multiple");`endif
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 0; RBrw_o <= regRead;//Not used
                operandRCisReg_o <= 1; RCrw_o <= regRead;
                functionalUnitType_o <= FPUnitId;   
                enable_o <= 1;        
            end
            18: begin//Floating Divide
                `ifdef DEBUG $display("Decode 2 A-form: Floating Divide");`endif
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId;   
                enable_o <= 1;        
            end
            22: begin//Floating Square Root
                `ifdef DEBUG $display("Decode 2 A-form: Floating Square Root");`endif
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 0; RArw_o <= regRead;//Not used
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId;
                enable_o <= 1;           
            end
            24: begin//Floating Reciprocal Estimate
                `ifdef DEBUG $display("Decode 2 A-form: Floating Reciprocal Estimate");`endif
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 0; RArw_o <= regRead;//Not used
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId;  
                enable_o <= 1;         
            end
            26: begin//Floating Reciprocal Square Root Estimate
                `ifdef DEBUG $display("Decode 2 A-form: Floating Reciprocal Square Root Estimate");`endif
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 0; RArw_o <= regRead;//Not used
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId; 
                enable_o <= 1;          
            end
            29: begin//Floating Multiply-Add
                `ifdef DEBUG $display("Decode 2 A-form: Floating Multiply-Add");`endif
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
                `ifdef DEBUG $display("Decode 2 A-form: Floating Multiply-Subtract");`endif
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
                `ifdef DEBUG $display("Decode 2 A-form: Floating Negative Multiply-Add");`endif
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 1; RBrw_o <= regRead;
                functionalUnitType_o <= FPUnitId;       
                enable_o <= 1;    
            end
            30: begin//Floating Negative Multiply-Subtract
                `ifdef DEBUG $display("Decode 2 A-form: Floating Negative Multiply-Subtract");`endif
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 1; RBrw_o <= regRead;
                functionalUnitType_o <= FPUnitId;      
                enable_o <= 1;     
            end
            23: begin//Floating Select
                `ifdef DEBUG $display("Decode 2 A-form: Floating Select");`endif
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 1; RBrw_o <= regRead;
                functionalUnitType_o <= FPUnitId;      
                enable_o <= 1;     
            end
            default: begin
                `ifdef DEBUG $display("Decode 2 A-form: Invalid instrution revieved");`endif
                enable_o <= 0; 
            end
            endcase
        end
        else if(instructionOpcode_i == 59)
        begin
            case(instruction_i[26+:XOSize])
            21: begin//Floating Add Single
                `ifdef DEBUG $display("Decode 2 A-form: Floating Add Single");`endif
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId; 
                enable_o <= 1;          
            end
            20: begin//Floating Subtract Single
                `ifdef DEBUG $display("Decode 2 A-form: Floating Subtract Single");`endif
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId;          
                enable_o <= 1; 
            end
            25: begin//Floating Multiply Single
                `ifdef DEBUG $display("Decode 2 A-form: Floating Multiple Single");`endif
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 0; RBrw_o <= regRead;//Not used
                operandRCisReg_o <= 1; RCrw_o <= regRead;
                functionalUnitType_o <= FPUnitId;     
                enable_o <= 1;      
            end
            18: begin//Floating Divide Single
                `ifdef DEBUG $display("Decode 2 A-form: Floating Divide Single");`endif
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId;     
                enable_o <= 1;      
            end
            22: begin//Floating Square Root Single
                `ifdef DEBUG $display("Decode 2 A-form: Floating Square Root");`endif
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 0; RArw_o <= regRead;//Not used
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId;    
                enable_o <= 1;       
            end
            24: begin//Floating Reciprocal Estimate Single
                `ifdef DEBUG $display("Decode 2 A-form: Floating Reciprocal Estimate");`endif
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 0; RArw_o <= regRead;//Not used
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId;    
                enable_o <= 1;       
            end
            26: begin//Floating Reciprocal Square Root Estimate Single
                `ifdef DEBUG $display("Decode 2 A-form: Floating Reciprocal Square Root Estimate Single");`endif
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 0; RArw_o <= regRead;//Not used
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 0; RCrw_o <= regRead;//Not used
                functionalUnitType_o <= FPUnitId;         
                enable_o <= 1;  
            end
            29: begin//Floating Multiply-Add Single
                `ifdef DEBUG $display("Decode 2 A-form: Floating Multiply-Add Single");`endif
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 1; RCrw_o <= regRead;
                functionalUnitType_o <= FPUnitId;        
                enable_o <= 1;   
            end
            28: begin//Floating Multiply-Subtract Single
                `ifdef DEBUG $display("Decode 2 A-form: Floating Multiply-Subtract Single");`endif
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 1; RCrw_o <= regRead;
                functionalUnitType_o <= FPUnitId;           
                enable_o <= 1;
            end
            31: begin//Floating Negative Multiply-Add Single
                `ifdef DEBUG $display("Decode 2 A-form: Floating Negative Multiply-Add Single");`endif
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 1; RCrw_o <= regRead;
                functionalUnitType_o <= FPUnitId;      
                enable_o <= 1;     
            end
            30: begin//Floating Negative Multiply-Subtract Single
                `ifdef DEBUG $display("Decode 2 A-form: Floating Negative Multiply-Subtract Single");`endif
                instMinId_o <= 0;
                operandRTisReg_o <= 1; RTrw_o <= regWrite;
                operandRAisReg_o <= 1; RArw_o <= regRead;
                operandRBisReg_o <= 1; RBrw_o <= regRead;
                operandRCisReg_o <= 1; RCrw_o <= regRead;
                functionalUnitType_o <= FPUnitId;         
                enable_o <= 1;  
            end
            default: begin
                `ifdef DEBUG $display("Decode 2 A-form: Invalid instrution revieved");`endif
                enable_o <= 0; 
            end
            endcase            
        end
    end
end    

endmodule