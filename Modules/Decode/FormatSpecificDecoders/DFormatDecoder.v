`timescale 1ns / 1ps
//`define DEBUG
//`define DEBUG_PRINT
`define QUIET_INVALID

/*/////////Format decode/////////////
Writen by Josh "Hakaru" Cantwell - 02.12.2022

This decoder implements all D format instruction specified in the POWER ISA version 3.0B.
This decoder implements the opcodes 25-64.

TODO:
Implement outputs for special registers access
Implement error cases.

D format instructions are for the most part composed of 2 register operands and a single immediate operand. There is 1 exception to this however. The formats for these operands are
described below.

///Operand number 1 [6-10]:
BF + L: This is the operand format expection as previously described.
BF is a 3 bit value which specifies one of the CR fields or FPCR fields to be used as a target. The L bit within the first register field indicates whether a fx-point cmp is to
compare 64 bit numbers or 32 bit numbers. The BF + L combination always come together whre bits 0-2 of the operand are the BF bits, bit 3 are unused and bit 4 is the L bit.

FRS:
This operand specifies a FP register used as a source.

RS:
This operand specifies a FX/GPR register used as a source

RT:
This operand specifies a FX/GPR register used as a target

TO:
This operand specifies the consitions on which to trap.


///Operand number 2 [11-15]:
This operand specifies a FX/GPR register to be used as a source or a target.

///Operand number 3 [16-31]:
D represents a 16 bit signed two's complement integer which is sign-extended to 64 bits.
SI represents just a 16 bit signed integer.
UI represents just a 16 bit unsigned integer.

///Supported D format instructions are:
Load Byte and Zero
Load Byte and Zero with update
Load Half word and Zero
Load Half word and Zero with update
Load Half word algebraic
Load Half word algebraic with update
Load word and zero
Load word and zero with update
Store byte
Store byte with update
Store halfword
Store halfword with update
Store word
Store word with update
Load multiple word
Store multiple word
Add immediate
Add immediate shifted
Add immediate carrying
Add immediate carrying and record
Subtract from immediate carrying
Multiply low immediate
Compare immediate
Compare logical immediate
Trap word immediate
Trap doubleword immediate
AND immediate
AND immediate shifted
OR immediate
OR immediate shifted
XOR immediate
XOR immediate shifted
Load floating point single
Load floating point single with update
Load floating point double
Load floating point double with update
Store floating point single
Store floating point single with update
Store floating point double
Store floating point double with update
*/

module DFormatDecoder
#(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter instMinIdWidth = 7,
    parameter PrimOpcodeSize = 6,
    parameter opcodeSize = 12,
    parameter regSize = 5,
    parameter regAccessPatternSize = 2,//2 bit field, [0] == is read, [1] == is writen. Both can be true EG: (A = A + B)
    parameter regRead = 2'b10, parameter regWrite = 2'b01, 
    parameter immediateSize = 16,
    parameter funcUnitCodeSize = 3, //can have up to 8 types of func unit.
    parameter Op1Pos = 6,
    //FX = int, FP = float, VX = vector, CR = condition, LS = load/store
    parameter FXUnitId = 0, parameter FPUnitId = 1, parameter VXUnitId = 2, parameter CRUnitId = 3, parameter LSUnitId = 4,  parameter BranchUnitID = 6,   
    parameter D = (2**05),
    parameter DDecoderInstance = 0
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
    output reg [0:instMinIdWidth-1] instMinId_o,//minor ID - minor ID's are generated in decode if an instruction generated micro ops, these are differentiated by the minor ID, they will have the same major ID
    output reg is64Bit_o,
    output reg [0:PidSize-1] instPid_o,//process ID
    output reg [0:TidSize-1] instTid_o,//Thread ID
    output reg [0:regAccessPatternSize-1] op1rw_o, op2rw_o,//how are the operands accessed, are they writen to and/or read from [0] read flag, [1] write flag.
    output reg op1isReg_o, op2isReg_o, immIsExtended_o, immIsShifted_o,//if imm is shifted, its shifted up 2 bytes
    //Instruction body - data contents are 26 bits wide. There are also flags to include
    output reg [0:(2 * regSize) + immediateSize - 1] instructionBody_o
);

`ifdef DEBUG_PRINT
integer debugFID;
`endif

always @(posedge clock_i)
begin
    `ifdef DEBUG_PRINT
    if(reset_i)
    begin
        case(DDecoderInstance)//If we have multiple decoders, they each get different files. The second number indicates the decoder# log file.
        0: begin 
            debugFID = $fopen("DDecode0.log", "w");
        end
        1: begin 
            debugFID = $fopen("DDecode1.log", "w");
        end
        2: begin 
            debugFID = $fopen("DDecode2.log", "w");
        end
        3: begin 
            debugFID = $fopen("DDecode3.log", "w");
        end
        4: begin 
            debugFID = $fopen("DDecode4.log", "w");
        end
        5: begin 
            debugFID = $fopen("DDecode5.log", "w");
        end
        6: begin 
            debugFID = $fopen("DDecode6.log", "w");
        end
        7: begin 
            debugFID = $fopen("DDecode7.log", "w");
        end
        endcase
        
    end
    else `endif if(enable_i && (instFormat_i | D) && !stall_i)
    begin
        `ifndef QUIET_INVALID
        `ifdef DEBUG $display("D format instruction recieved. Opcode: ", instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "D format instruction recieved. Opcode: ", instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
        `endif
        //Parse the instruction agnostic parts of the instruction
        instructionAddress_o <= instructionAddress_i;
        instMajId_o <= instructionMajId_i;
        instPid_o <= instructionPid_i; instTid_o <= instructionTid_i;
        is64Bit_o <= is64Bit_i;
        //parse the instruction
        instructionBody_o[0+:(2*regSize)+immediateSize] <= instruction_i[Op1Pos:31];//copy the instruction operands accross to the buffer

        case(instructionOpcode_i)
        34: begin //Load Byte and Zero - RT,RA,D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). Load Byte and Zero", instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). Load Byte and Zero", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 25;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            //is val or zero - if RA is zero, we treat it like an imm with zero val. Realistically we can just not use it at all if zeroed
            if(instruction_i[11:15] == 0)
                op1isReg_o <= 0;
            else
                op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= regWrite;
            op2rw_o <= regRead;
        end
        35: begin //Load Byte and Zero with update - RT,RA,D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). Load Byte and Zero with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). Load Byte and Zero with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 26;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1; op2isReg_o <= 1;

            op1rw_o <= regWrite;
            op2rw_o <= regRead | regWrite;
        end
        40: begin //Load Half word and Zero - RT,RA,D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). Load Half word and Zero", instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). Load Half word and Zero", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 27;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            //is val or zero - if RA is zero, we treat it like an imm with zero val. Realistically we can just not use it at all if zeroed
            if(instruction_i[11:15] == 0)
                op1isReg_o <= 0;
            else
                op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= regWrite;
            op2rw_o <= regRead;
        end
        41: begin //Load Half word and Zero with update - RT,RA,D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). Load Half word and Zero with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). Load Half word and Zero with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 28;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1; op2isReg_o <= 1;

            op1rw_o <= regWrite;
            op2rw_o <= regRead | regWrite;
        end
        42: begin //Load Half word algebraic - RT,RA,D - load contents sign extended to fill the reg
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). Load Half word algebraic", instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). Load Half word algebraic", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 29;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            //is val or zero - if RA is zero, we treat it like an imm with zero val. Realistically we can just not use it at all if zeroed
            if(instruction_i[11:15] == 0)
                op1isReg_o <= 0;
            else
                op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= regWrite;
            op2rw_o <= regRead;
        end
        43: begin //Load Half word algebraic with update - RT,RA,D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). Load Half word algebraic with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). Load Half word algebraic with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 30;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1; op2isReg_o <= 1;

            op1rw_o <= regWrite;
            op2rw_o <= regRead | regWrite;
        end
        32: begin //Load word and zero - RT,RA,D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Load word and zero", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Load word and zero", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 31;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            //is val or zero - if RA is zero, we treat it like an imm with zero val. Realistically we can just not use it at all if zeroed
            if(instruction_i[11:15] == 0)
                op1isReg_o <= 0;
            else
                op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= regWrite;
            op2rw_o <= regRead;
        end
        33: begin //Load word and zero with update - RT,RA,D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Load word and zero with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Load word and zero with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 32;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1; op2isReg_o <= 1;

            op1rw_o <= regWrite;
            op2rw_o <= regRead | regWrite;
        end
        38: begin //Store byte - RS,RA,D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Store byte", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Store byte", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 33;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            //is val or zero - if RA is zero, we treat it like an imm with zero val. Realistically we can just not use it at all if zeroed
            if(instruction_i[11:15] == 0)
                op1isReg_o <= 0;
            else
                op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= regWrite;
            op2rw_o <= regRead;
        end
        39: begin //Store byte with update - RS,RA,D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Store byte with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Store byte with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 34;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1; op2isReg_o <= 1;

            op1rw_o <= regWrite;
            op2rw_o <= regRead | regWrite;
        end
        44: begin //Store halfword - RS,RA,D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Store halfword", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Store halfword", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 35;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            //is val or zero - if RA is zero, we treat it like an imm with zero val. Realistically we can just not use it at all if zeroed
            if(instruction_i[11:15] == 0)
                op1isReg_o <= 0;
            else
                op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= regWrite;
            op2rw_o <= regRead;
        end
        45: begin //Store halfword with update - RS,RA,D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: store halfword with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: store halfword with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 36;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1; op2isReg_o <= 1;

            op1rw_o <= regRead;
            op2rw_o <= regRead | regWrite;
        end
        36: begin //Store word - RS,RA,D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Store word", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Store word", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 37;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            //is val or zero - if RA is zero, we treat it like an imm with zero val. Realistically we can just not use it at all if zeroed
            if(instruction_i[11:15] == 0)
                op1isReg_o <= 0;
            else
                op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= regWrite;
            op2rw_o <= regRead;
        end
        37: begin //Store word with update - RS,RA,D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Store word with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Store word with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 38;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1; op2isReg_o <= 1;

            op1rw_o <= regWrite;
            op2rw_o <= regRead | regWrite;
        end
        46: begin //Load multiple word - RT,RA,D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Load multiple word", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Load multiple word", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 39;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            //is val or zero - if RA is zero, we treat it like an imm with zero val. Realistically we can just not use it at all if zeroed
            if(instruction_i[11:15] == 0)
                op1isReg_o <= 0;
            else
                op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= regRead | regWrite;
            op2rw_o <= regRead;

            //If little endian, error. Also if RA == 0 || RA is in the range of register to be loaded. Error.
        end
        47: begin //Store multiple word - RS,RA,D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Store multiple word", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Store multiple word", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 40;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            //is val or zero - if RA is zero, we treat it like an imm with zero val. Realistically we can just not use it at all if zeroed
            if(instruction_i[11:15] == 0)
                op1isReg_o <= 0;
            else
                op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= regRead | regWrite;
            op2rw_o <= regRead;

            //If little endian, error. Also if RA == 0 || RA is in the range of register to be loaded. Error.
        end
        14: begin //Add immediate - RT,RA,SI
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Add immediate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Add immediate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 41;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 1;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            //is val or zero - if RA is zero, we treat it like an imm with zero val. Realistically we can just not use it at all if zeroed
            if(instruction_i[11:15] == 0)
                op1isReg_o <= 0;
            else
                op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= regWrite;
            op2rw_o <= regRead;
        end
        15: begin //Add immediate shifted - RT,RA,SI
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Add immediate shifted", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Add immediate shifted", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 42;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 1;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            //is val or zero - if RA is zero, we treat it like an imm with zero val. Realistically we can just not use it at all.
            if(instruction_i[11:15] == 0)
                op1isReg_o <= 0;
            else
                op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= regRead | regWrite;
            op2rw_o <= regRead;
        end
        12: begin //Add immediate carrying - RT,RA,SI
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Add immediate carrying", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Add immediate carrying", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 43;
            //Special Regs: CA CA32
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= regWrite;
            op2rw_o <= regRead;
        end
        13: begin //Add immediate carrying and record - RT,RA,SI
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Add immediate carrying and record", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Add immediate carrying and record", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 44;
            //Special Regs: CR0 CA CA32
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= regWrite;
            op2rw_o <= regRead;
        end
        8: begin //Subtract from immediate carrying - RT,RA,SI  
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Subtract from immediate carrying", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Subtract from immediate carrying", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 45;
            //Special Regs: CA CA32
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= regWrite;
            op2rw_o <= regRead;
        end
        7: begin //Multiply low immediate - RT,RA,SI
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Multiply low immediate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Multiply low immediate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 46;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= regWrite;
            op2rw_o <= regRead;
        end
        11: begin //Compare immediate - BF+L, RA, SI
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Compare immediate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Compare immediate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 47;
            //Special Regs: CR, BF
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 0;
            functionalUnitType_o <= CRUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= 2'b00;//Neither read or write, treat as imm.
            op2rw_o <= regRead;
        end
        10: begin //Compare logical immediate - BF+L, RA, SI
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Compare logical immediate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Compare logical immediate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 48;
            //Special Regs: CR, BF
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 0;
            functionalUnitType_o <= CRUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= 2'b00;
            op2rw_o <= regRead;
        end
        3: begin //Trap word immediate - TO, RA, SI
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Trap word immediate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Trap word immediate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 49;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= 2'b00;
            op2rw_o <= regRead;
        end
        2: begin //Trap doubleword immediate - TO, RA, SI
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Trap doubleword immediate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Trap doubleword immediate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 50;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;
            op1rw_o <= 2'b00;
            op2rw_o <= regRead;
        end
        28: begin //AND immediate - RA, RS, UI
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: AND immediate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: AND immediate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 51;
            //Special Regs: CR0
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= regRead;
            op2rw_o <= regWrite;
        end
        29: begin //AND immediate shifted - RA, RS, UI
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: AND immediate shifted", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: AND immediate shifted", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 52;
            //Special Regs: CR0
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 1;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= regRead;
            op2rw_o <= regWrite;
        end
        24: begin //OR immediate - RA, RS, UI
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: OR immediate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: OR immediate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 53;
            //Special Regs: CR0
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= regRead;
            op2rw_o <= regWrite;
        end
        25: begin //OR immediate shifted - RA, RS, UI
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: OR immediate shifted", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: OR immediate shifted", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 54;
            //Special Regs: CR0
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 1;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;
            op1rw_o <= regRead;
            op2rw_o <= regWrite;
        end
        26: begin //XOR immediate - RA, RS, UI
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: XOR immediate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). XD-form Inst: OR immediate", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 55;
            //Special Regs: CR0
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;
            op1rw_o <= regRead;
            op2rw_o <= regWrite;
        end
        27: begin //XOR immediate shifted - RA, RS, UI
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: XOR immediate shifted", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: XOR immediate shifted", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 56;
            //Special Regs: CR0
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 1;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;
            op1rw_o <= regRead;
            op2rw_o <= regWrite;
        end
        48: begin //Load floating point single - FRT, RA, D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Load floating point single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Load floating point single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 57;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FPUnitId; instMinId_o <= 0;
            //is val or zero - if RA is zero, we treat it like an imm with zero val. Realistically we can just not use it at all if zeroed
            if(instruction_i[11:15] == 0)
                op1isReg_o <= 0;
            else
                op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= regWrite;
            op2rw_o <= regRead;
        end
        49: begin //Load floating point single with update - FRT, RA, D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Load floating point single with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Load floating point single with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 58;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FPUnitId; instMinId_o <= 0;
            //is val or zero - if RA is zero, we treat it like an imm with zero val. Realistically we can just not use it at all if zeroed
            op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= regWrite;
            op2rw_o <= regRead | regWrite;
            //If operand 2 is 0, instruction invalid
        end
        50: begin //Load floating point double - FRT, RA, D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Load floating point double", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Load floating point double", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 59;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FPUnitId; instMinId_o <= 0;
            //is val or zero - if RA is zero, we treat it like an imm with zero val. Realistically we can just not use it at all if zeroed
            if(instruction_i[11:15] == 0)
                op1isReg_o <= 0;
            else
                op1isReg_o <= 1;
            op2isReg_o <= 1;

            op1rw_o <= regWrite;
            op2rw_o <= regRead;
        end
        51: begin //Load floating point double with update - FRT, RA, D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Load floating point double with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Load floating point double with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 60;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FPUnitId; instMinId_o <= 0;
            //is val or zero - if RA is zero, we treat it like an imm with zero val. Realistically we can just not use it at all if zeroed
            op1isReg_o <= 1;
            op2isReg_o <= 1;
            op1rw_o <= regWrite;
            op2rw_o <= regRead | regWrite;
            //If operand 2 is 0, instruction invalid
        end

        52: begin //Store floating point single - FRS, RA, D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Store floating point single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: LStore floating point single", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 61;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FPUnitId; instMinId_o <= 0;
            //is val or zero - if RA is zero, we treat it like an imm with zero val. Realistically we can just not use it at all if zeroed
            if(instruction_i[11:15] == 0)
                op1isReg_o <= 0;
            else
                op1isReg_o <= 1;
            op2isReg_o <= 1;
            op1rw_o <= regWrite;
            op2rw_o <= regRead;
        end
        53: begin //Store floating point single with update - FRS, RA, D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Store floating point single with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Store floating point single with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 62;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FPUnitId; instMinId_o <= 0;
            //is val or zero - if RA is zero, we treat it like an imm with zero val. Realistically we can just not use it at all if zeroed
            op1isReg_o <= 1;
            op2isReg_o <= 1;
            op1rw_o <= regWrite;
            op2rw_o <= regRead | regWrite;
            //If operand 2 is 0, instruction invalid
        end
        54: begin //Store floating point double - FRS, RA, D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Store floating point double", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: LStore floating point double", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 63;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FPUnitId; instMinId_o <= 0;
            //is val or zero - if RA is zero, we treat it like an imm with zero val. Realistically we can just not use it at all if zeroed
            if(instruction_i[11:15] == 0)
                op1isReg_o <= 0;
            else
                op1isReg_o <= 1;
            op2isReg_o <= 1;
            op1rw_o <= regWrite;
            op2rw_o <= regRead;
        end
        55: begin //Store floating point double with update - FRS, RA, D
            `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Store floating point double with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Store floating point double with update", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
            opcode_o <= 64;
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FPUnitId; instMinId_o <= 0;
            //is val or zero - if RA is zero, we treat it like an imm with zero val. Realistically we can just not use it at all if zeroed
            op1isReg_o <= 1;
            op2isReg_o <= 1;
            op1rw_o <= regWrite;
            op2rw_o <= regRead | regWrite;
            //If operand 2 is 0, instruction invalid
        end
        default: begin
            `ifndef QUIET_INVALID
                `ifdef DEBUG $display("Decode 2 D-form Inst: %d. Opcode: %b (%d). Invalid instruction recieved");`endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form Inst: %d. Opcode: %b (%d). %d. Opcode: %b (%d). D-form Inst: Invalid instruction recieved", instructionMajId_i, instructionOpcode_i, instructionOpcode_i, instructionMajId_i, instructionOpcode_i, instructionOpcode_i); `endif
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