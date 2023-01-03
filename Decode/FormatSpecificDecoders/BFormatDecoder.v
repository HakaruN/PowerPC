`timescale 1ns / 1ps
`define DEBUG
`define DEBUG_PRINT

/*/////////Format decode/////////////
Writen by Josh "Hakaru" Cantwell - 02.12.2022

This is the decoder for B format instructions.
B format instructions are:
Branch Conditional
There are no other B format instructions in the ISA
*/

module BFormat_Decoder
#(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter instMinIdWidth = 7,
    parameter opcodeSize = 6, parameter regSize = 5,
    parameter regAccessPatternSize = 2,//2 bit field, [0] == is read, [1] == is writen. Both can be true EG: (A = A + B)
    parameter regRead = 2'b10, parameter regWrite = 2'b01, 
    parameter isImmediateSize = 1, parameter immediateSize = 14,
    parameter funcUnitCodeSize = 3, //can have up to 8 types of func unit.
    parameter BOPos = 6, parameter BIPos = 11, parameter BDPos = 16, parameter AAPos = 30, parameter LKPos = 31;//positions in the instruction
    //FX = int, FP = float, VX = vector, CR = condition, LS = load/store
    parameter FXUnitId = 0, parameter FPUnitId = 1, parameter VXUnitId = 2, parameter CRUnitId = 3, parameter LSUnitId = 4,  parameter BranchUnitID = 6,   
    parameter B = 2**01,
    parameter BDecoderInstance = 0
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
    input wire is64Bit_i,
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
    output reg is64Bit_o,
    output reg [0:PidSize-1] instPid_o,//process ID
    output reg [0:TidSize-1] instTid_o,//Thread ID
    output reg [0:regAccessPatternSize-1] BOrw_o, BIrw_o,//how are the operands accessed, are they writen to and/or read from [0] write flag, [1] write flag.
    output reg operandBOisReg_o, operandBIisReg_o
    //Instruction body - data contents are 26 bits wide. There are also flags to include
    output reg [0:(2 * regSize) + immediateSize + 1] instructionBody_o,//the +1 is because there are actually an aditional 2 bits in the inst, which offets the -1 to be +1.    
);

//Generate the log file
integer debugFID = BDecoderInstance;
`ifdef DEBUG_PRINT
initial begin
    case(BDecoderInstance)//If we have multiple decoders, they each get different files. The second number indicates the decoder# log file.
    0: begin 
        debugFID = $fopen("Decode2-0.log", "w");
    end
    1: begin 
        debugFID = $fopen("Decode2-1.log", "w");
    end
    2: begin 
        debugFID = $fopen("Decode2-2.log", "w");
    end
    3: begin 
        debugFID = $fopen("Decode2-3.log", "w");
    end
    4: begin 
        debugFID = $fopen("Decode2-4.log", "w");
    end
    5: begin 
        debugFID = $fopen("Decode2-5.log", "w");
    end
    6: begin 
        debugFID = $fopen("Decode2-6.log", "w");
    end
    7: begin 
        debugFID = $fopen("Decode2-7.log", "w");
    end
    endcase
end
`endif DEBUG_PRINT

always @(posedge clock_i)
begin
    if(enable_i && (instFormat_i | B) && !stall_i)
    begin
        `ifdef DEBUG $display("B format instruction recieved"); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "B format instruction recieved"); `endif
        //Parse the instruction agnostic parts of the instruction
        instructionOpcode_o <= instructionOpcode_i;
        instructionAddress_o <= instructionAddress_i;
        instMajId_o <= instructionMajId_i;
        instPid_o <= instructionPid_i; instTid_o <= instructionTid_i;
        is64Bit_o <= is64Bit_i;        
        //parse the instruction
        instructionBody_o[(0*regSize)+:regSize] <= instruction_i[BOPos:+regSize];
        instructionBody_o[(1*regSize)+:regSize] <= instruction_i[BIPos:+regSize];
        instructionBody_o[(2*regSize)+:immediateSize] <= instruction_i[BDPos:+immediateSize];
        instructionBody_o[(2*regSize)+immediateSize+] instruction_i[AAPos];
        instructionBody_o[(2*regSize)+immediateSize+1] instruction_i[LKPos];

        case(instructionOpcode_i)
        16: begin //Branch Conditional
            `ifdef DEBUG $display("Decode 2 B-form (Inst: %h): ranch Conditional", instructionMajId_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 B-form (Inst: %h): ranch Conditional", instructionMajId_i); `endif
            enable_o <= 1;
            functionalUnitType_o <= BranchUnitID; instMinId_o <= 0;
            operandBOisReg_o <= 0; operandBIisReg_o <= 0;
            BOrw_o[0] <= 1; BOrw_o[1] <= 0;
            BIrw_o[0] <= 1; BIrw_o[1] <= 0;
            end
            default: begin
                `ifdef DEBUG $display("Decode 2 B-form: Invalid instruction recieved");`endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 B-form (Inst: %h): D-form: Invalid instruction recieved", instructionMajId_i); `endif
                enable_o <= 0; 
            end
        endcase
    end
end


endmodule