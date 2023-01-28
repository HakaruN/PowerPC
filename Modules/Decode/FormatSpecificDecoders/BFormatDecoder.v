`timescale 1ns / 1ps
`define DEBUG
`define DEBUG_PRINT
`define QUIET_INVALID
/*/////////Format decode/////////////
Writen by Josh "Hakaru" Cantwell - 02.12.2022

This decoder implements all D format instruction specified in the POWER ISA version 3.0B.
This decoder implements the opcode 25.

TODO:
Implement outputs for special registers access

B format instructions are composed of 2 register-sized operands, 1 14 bit immediate operand and a pair of single bit flags.
These are described as below:
Operand 1 [6:10]
BO - indicates the branch condition (Figure 40, page 33 POWER ISA 3.0B)

Operand 2 [11:15]
BI - (BI + 32) specifies the CR reg bit to be tested.

Operand 3 [16:29]
BD - Immediate field used to specify a 14-bit signed twos compliment address component. This then has 2 zeroes appended as lsb's to bring it to 16 bits
and allows only 4 byte aligned addresses (which is fine as power instructions may only exist on b byte boundaries). This is then sign extended to 64 bits.

Operand 4 [30]
AA - If this is zero, the branch is relative to the instruction, if AA == 1 then it's an absalute address.

Operand 5 [31]
LK - If this is set then the addres of the instruction following the branch is placed into the link register

This is the decoder for B format instructions.
B format instructions are:
Branch Conditional
*/

module BFormatDecoder
#(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter instMinIdWidth = 7,
    parameter opcodeSize = 12,
    parameter PrimOpcodeSize = 6, parameter regSize = 5,
    parameter regAccessPatternSize = 2,//2 bit field, [0] == is read, [1] == is writen. Both can be true EG: (A = A + B)
    parameter regRead = 2'b10, parameter regWrite = 2'b01, 
    parameter immediateSize = 14,
    parameter funcUnitCodeSize = 3, //can have up to 8 types of func unit.
    parameter operand1Pos = 6, parameter immPos = 16,
    //FX = int, FP = float, VX = vector, CR = condition, LS = load/store
    parameter FXUnitId = 0, parameter FPUnitId = 1, parameter VXUnitId = 2, parameter CRUnitId = 3, parameter LSUnitId = 4,  parameter BranchUnitID = 6,   
    parameter B = 2**01,
    parameter BDecoderInstance = 0
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
    output reg modifiesCR_o,//tells the backend if this instruction is going to need a copy of the CR to modify and writeback
    //Instruction body - data contents are 26 bits wide. There are also flags to include
    output reg [0:(2 * regSize) + immediateSize + 3] instructionBody_o//the +3 is because there are an aditional 2 bits in the inst for the flags and then an aditional 2 bits for the imm.
);

`ifdef DEBUG_PRINT
integer debugFID;
`endif

always @(posedge clock_i)
begin
    `ifdef DEBUG_PRINT
    if(reset_i)
    begin
        case(BDecoderInstance)//If we have multiple decoders, they each get different files. The second number indicates the decoder# log file.
        0: begin 
            debugFID = $fopen("BDecode0.log", "w");
        end
        1: begin 
            debugFID = $fopen("BDecode1.log", "w");
        end
        2: begin 
            debugFID = $fopen("BDecode2.log", "w");
        end
        3: begin 
            debugFID = $fopen("BDecode3.log", "w");
        end
        4: begin 
            debugFID = $fopen("BDecode4.log", "w");
        end
        5: begin 
            debugFID = $fopen("BDecode5.log", "w");
        end
        6: begin 
            debugFID = $fopen("BDecode6.log", "w");
        end
        7: begin 
            debugFID = $fopen("BDecode7.log", "w");
        end
        endcase
    end
    else `endif if(enable_i && (instFormat_i | B) && !stall_i)
    begin
        `ifndef QUIET_INVALID
        `ifdef DEBUG $display("B format instruction recieved"); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "B format instruction recieved"); `endif
        `endif
        //Parse the instruction agnostic parts of the instruction
        instructionAddress_o <= instructionAddress_i;
        instMajId_o <= instructionMajId_i;
        instPid_o <= instructionPid_i; instTid_o <= instructionTid_i;
        is64Bit_o <= is64Bit_i;        
        //parse the instruction
        instructionBody_o[0+:((2*regSize) + immediateSize)] <= instruction_i[6:29];//Copy the regs and the imms
        instructionBody_o[24:25] <= 2'b00;//append the bits onto the imm in the buffer
        instructionBody_o[26:27] <= instruction_i[30:31];//copy the flags

        case(instructionOpcode_i)
        16: begin //Branch Conditional - BO, BI, BD, AA, LK
            `ifdef DEBUG $display("Decode 2 B-form Inst: %d. Opcode: %b (%d). Branch Conditional", instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 B-form Inst: %d. Opcode: %b (%d). Branch Conditional", instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 25;//set the decocde opcode
            //Special Regs: CTR if BO[2] == 0, LR if LK  == 1
            enable_o <= 1;
            functionalUnitType_o <= BranchUnitID; instMinId_o <= 0; numMicroOps_o <= 0;

            end
            default: begin
                `ifndef QUIET_INVALID
                `ifdef DEBUG $display("Decode 2 B-form Inst: Invalid instruction recieved");`endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 B-form Inst: %d. Opcode: %b (%d). D-form Inst: Invalid instruction recieved", instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
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


endmodule