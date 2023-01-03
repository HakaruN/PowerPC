`timescale 1ns / 1ps
`define DEBUG
`define DEBUG_PRINT

/*/////////Format decode/////////////
Writen by Josh "Hakaru" Cantwell - 02.12.2022

The instruction format is composed of 2 register operands (with one exceptions) and a single 16 bit immediate value. This immediate value can be of type D, SI or UI.
The first register operand contains the exception mentioned above. This operand may be types as BF + L, FRS, RS, RT and TO. The second operand is always of the type RA.


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

This is the decoder for D format instructions.
D format instructions are:
*/

module DFormat_Decoder
#(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter instMinIdWidth = 7,
    parameter opcodeSize = 6, parameter regSize = 5,
    parameter regAccessPatternSize = 2,//2 bit field, [0] == is read, [1] == is writen. Both can be true EG: (A = A + B)
    parameter regRead = 2'b10, parameter regWrite = 2'b01, 
    parameter isImmediateSize = 1, parameter immediateSize = 16,
    parameter funcUnitCodeSize = 3, //can have up to 8 types of func unit.
    parameter Op1Pos = 6, parameter RAPos = 11, parameter ImmPos = 16;//positions in the instruction
    parameter immWidth = 16,
    //FX = int, FP = float, VX = vector, CR = condition, LS = load/store
    parameter FXUnitId = 0, parameter FPUnitId = 1, parameter VXUnitId = 2, parameter CRUnitId = 3, parameter LSUnitId = 4,  parameter BranchUnitID = 6,   
    parameter D = 2**05,
    parameter DDecoderInstance = 0
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
    output reg [0:regAccessPatternSize-1] op1rw_o, op2rw_o,//how are the operands accessed, are they writen to and/or read from [0] write flag, [1] write flag.
    output reg op1isReg_o, op2isReg_o, immIsExtended_o, immIsShifted_o,//if imm is shifted, its shifted up 2 bytes
    //Instruction body - data contents are 26 bits wide. There are also flags to include
    output reg [0:(2 * regSize) + immediateSize - 1] instructionBody_o,
);

//Generate the log file
integer debugFID = DDecoderInstance;
`ifdef DEBUG_PRINT
initial begin
    case(DDecoderInstance)//If we have multiple decoders, they each get different files. The second number indicates the decoder# log file.
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
    if(enable_i && (instFormat_i | D) && !stall_i)
    begin
        `ifdef DEBUG $display("D format instruction recieved"); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "D format instruction recieved"); `endif
        //Parse the instruction agnostic parts of the instruction
        instructionOpcode_o <= instructionOpcode_i;
        instructionAddress_o <= instructionAddress_i;
        instMajId_o <= instructionMajId_i;
        instPid_o <= instructionPid_i; instTid_o <= instructionTid_i;
        is64Bit_o <= is64Bit_i;
        //parse the instruction
        instructionBody_o[0+:(2*regSize)+immediateSize] <= instruction_i[Op1Pos:31];//copy the instruction operands accross to the buffer

        case(instructionOpcode_i)
        34: begin //Load Byte and Zero - RT,RA,D
            `ifdef DEBUG $display("Decode 2 D-form: Load Byte and Zero"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): Load Byte and Zero", instructionMajId_i); `endif
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

            op1rw_o[0] <= 0; op1rw_o[1] <= 1;//Write not read
            op2rw_o[0] <= 1; op2rw_o[1] <= 0;//Read not write
        end
        35: begin //Load Byte and Zero with update - RT,RA,D
            `ifdef DEBUG $display("Decode 2 D-form: Load Byte and Zero with update"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): Load Byte and Zero with update", instructionMajId_i); `endif
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1; op2isReg_o <= 1;

            op1rw_o[0] <= 0; op1rw_o[1] <= 1;//Write not read
            op2rw_o[0] <= 1; op2rw_o[1] <= 1;//Read and write
        end
        40: begin //Load Half word and Zero - RT,RA,D
            `ifdef DEBUG $display("Decode 2 D-form: Load Half word and Zero"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): Load Half word and Zero", instructionMajId_i); `endif
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

            op1rw_o[0] <= 0; op1rw_o[1] <= 1;//Write not read
            op2rw_o[0] <= 1; op2rw_o[1] <= 0;//Read not write
        end
        41: begin //Load Half word and Zero with update - RT,RA,D
            `ifdef DEBUG $display("Decode 2 D-form: Load Half word and Zero with update"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): Load Half word and Zero with update", instructionMajId_i); `endif
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1; op2isReg_o <= 1;

            op1rw_o[0] <= 0; op1rw_o[1] <= 1;//Write not read
            op2rw_o[0] <= 1; op2rw_o[1] <= 1;//Read and write
        end
        42: begin //Load Half word algebraic - RT,RA,D - load contents sign extended to fill the reg
            `ifdef DEBUG $display("Decode 2 D-form: Load Half word algebraic"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): Load Half word algebraic", instructionMajId_i); `endif
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

            op1rw_o[0] <= 0; op1rw_o[1] <= 1;//Write not read
            op2rw_o[0] <= 1; op2rw_o[1] <= 0;//Read not write
        end
        43: begin //Load Half word algebraic with update - RT,RA,D
            `ifdef DEBUG $display("Decode 2 D-form: Load Half word algebraic with update"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): Load Half word algebraic with update", instructionMajId_i); `endif
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1; op2isReg_o <= 1;

            op1rw_o[0] <= 0; op1rw_o[1] <= 1;//Write not read
            op2rw_o[0] <= 1; op2rw_o[1] <= 1;//Read and write
        end
        32: begin //Load word and zero - RT,RA,D
            `ifdef DEBUG $display("Decode 2 D-form (Inst: %h): D-form: Load word and zero", instructionMajId_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): D-form: Load word and zero", instructionMajId_i); `endif
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

            op1rw_o[0] <= 0; op1rw_o[1] <= 1;//Write not read
            op2rw_o[0] <= 1; op2rw_o[1] <= 0;//Read not write
        end
        33: begin //Load word and zero with update - RT,RA,D
            `ifdef DEBUG $display("Decode 2 D-form (Inst: %h): D-form: Load word and zero with update", instructionMajId_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): D-form: Load word and zero with update", instructionMajId_i); `endif
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1; op2isReg_o <= 1;

            op1rw_o[0] <= 0; op1rw_o[1] <= 1;//Write not read
            op2rw_o[0] <= 1; op2rw_o[1] <= 1;//Read and write
        end
        38: begin //Store byte - RS,RA,D
            `ifdef DEBUG $display("Decode 2 D-form (Inst: %h): D-form: Store byte", instructionMajId_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): D-form: Store byte", instructionMajId_i); `endif
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

            op1rw_o[0] <= 0; op1rw_o[1] <= 1;//Write not read
            op2rw_o[0] <= 1; op2rw_o[1] <= 0;//Read not write
        end
        39: begin //Store byte with update - RS,RA,D
            `ifdef DEBUG $display("Decode 2 D-form (Inst: %h): D-form: Store byte with update", instructionMajId_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): D-form: Store byte with update", instructionMajId_i); `endif
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1; op2isReg_o <= 1;

            op1rw_o[0] <= 0; op1rw_o[1] <= 1;//Write not read
            op2rw_o[0] <= 1; op2rw_o[1] <= 1;//Read and write
        end
        44: begin //Store halfword - RS,RA,D
            `ifdef DEBUG $display("Decode 2 D-form (Inst: %h): D-form: Store halfword", instructionMajId_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): D-form: Store halfword", instructionMajId_i); `endif
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

            op1rw_o[0] <= 0; op1rw_o[1] <= 1;//Write not read
            op2rw_o[0] <= 1; op2rw_o[1] <= 0;//Read not write
        end
        45: begin //Store halfword with update - RS,RA,D
            `ifdef DEBUG $display("Decode 2 D-form (Inst: %h): D-form: store halfword with update", instructionMajId_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): D-form: store halfword with update", instructionMajId_i); `endif
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1; op2isReg_o <= 1;

            op1rw_o[0] <= 0; op1rw_o[1] <= 1;//Write not read
            op2rw_o[0] <= 1; op2rw_o[1] <= 1;//Read and write
        end
        36: begin //Store word - RS,RA,D
            `ifdef DEBUG $display("Decode 2 D-form (Inst: %h): D-form: Store word", instructionMajId_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): D-form: Store word", instructionMajId_i); `endif
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

            op1rw_o[0] <= 0; op1rw_o[1] <= 1;//Write not read
            op2rw_o[0] <= 1; op2rw_o[1] <= 0;//Read not write
        end
        37: begin //Store word with update - RS,RA,D
            `ifdef DEBUG $display("Decode 2 D-form (Inst: %h): D-form: Store word with update", instructionMajId_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): D-form: Store word with update", instructionMajId_i); `endif
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 1; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1; op2isReg_o <= 1;

            op1rw_o[0] <= 0; op1rw_o[1] <= 1;//Write not read
            op2rw_o[0] <= 1; op2rw_o[1] <= 1;//Read and write
        end
        46: begin //Load multiple word - RT,RA,D
            `ifdef DEBUG $display("Decode 2 D-form (Inst: %h): D-form: Load multiple word", instructionMajId_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): D-form: Load multiple word", instructionMajId_i); `endif
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

            op1rw_o[0] <= 1; op1rw_o[1] <= 1;//Read and Write
            op2rw_o[0] <= 1; op2rw_o[1] <= 0;//Read not write

            //If little endian, error. Also if RA == 0 || RA is in the range of register to be loaded. Error.
        end
        47: begin //Store multiple word - RS,RA,D
            `ifdef DEBUG $display("Decode 2 D-form (Inst: %h): D-form: Store multiple word", instructionMajId_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): D-form: Store multiple word", instructionMajId_i); `endif
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

            op1rw_o[0] <= 1; op1rw_o[1] <= 1;//Read and Write
            op2rw_o[0] <= 1; op2rw_o[1] <= 0;//Read not write

            //If little endian, error. Also if RA == 0 || RA is in the range of register to be loaded. Error.
        end
        14: begin //Add immediate - RT,RA,SI
            `ifdef DEBUG $display("Decode 2 D-form (Inst: %h): D-form: Add immediate", instructionMajId_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): D-form: Add immediate", instructionMajId_i); `endif
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

            op1rw_o[0] <= 0; op1rw_o[1] <= 1;//Write not read
            op2rw_o[0] <= 1; op2rw_o[1] <= 0;//Read not write
        end
        15: begin //Add immediate shifted - RT,RA,SI
            `ifdef DEBUG $display("Decode 2 D-form (Inst: %h): D-form: Add immediate shifted", instructionMajId_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): D-form: Add immediate shifted", instructionMajId_i); `endif
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

            op1rw_o[0] <= 1; op1rw_o[1] <= 1;//Read and Write
            op2rw_o[0] <= 1; op2rw_o[1] <= 0;//Read not write
        end
        12: begin //Add immediate carrying - RT,RA,SI
            `ifdef DEBUG $display("Decode 2 D-form (Inst: %h): D-form: Add immediate carrying", instructionMajId_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): D-form: Add immediate carrying", instructionMajId_i); `endif
            //Special Regs: CA CA32
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;
            op1rw_o[0] <= 0; op1rw_o[1] <= 1;//Write not read
            op2rw_o[0] <= 1; op2rw_o[1] <= 0;//Read not write
        end
        13: begin //Add immediate carrying and record - RT,RA,SI
            `ifdef DEBUG $display("Decode 2 D-form (Inst: %h): D-form: Add immediate carrying and record", instructionMajId_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): D-form: Add immediate carrying and record", instructionMajId_i); `endif
            //Special Regs: CR0 CA CA32
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;
            op1rw_o[0] <= 0; op1rw_o[1] <= 1;//Write not read
            op2rw_o[0] <= 1; op2rw_o[1] <= 0;//Read not write
        end
        8: begin //Subtract from immediate carrying - RT,RA,SI  
            `ifdef DEBUG $display("Decode 2 D-form (Inst: %h): D-form: Subtract from immediate carrying", instructionMajId_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): D-form: Subtract from immediate carrying", instructionMajId_i); `endif
            //Special Regs: CA CA32
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;
            op1rw_o[0] <= 0; op1rw_o[1] <= 1;//Write not read
            op2rw_o[0] <= 1; op2rw_o[1] <= 0;//Read not write
        end
        7: begin //Multiply low immediate - RT,RA,SI
            `ifdef DEBUG $display("Decode 2 D-form (Inst: %h): D-form: Multiply low immediate", instructionMajId_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): D-form: Multiply low immediate", instructionMajId_i); `endif
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;
            op1rw_o[0] <= 0; op1rw_o[1] <= 1;//Write not read
            op2rw_o[0] <= 1; op2rw_o[1] <= 0;//Read not write
        end
        11: begin //Compare immediate - BF+L, RA, SI
            `ifdef DEBUG $display("Decode 2 D-form (Inst: %h): D-form: Compare immediate", instructionMajId_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): D-form: Compare immediate", instructionMajId_i); `endif
            //Special Regs: CR, BF
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 0;
            functionalUnitType_o <= CRUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;
            op1rw_o[0] <= 0; op1rw_o[1] <= 0;//Neither read or write, treat as imm.
            op2rw_o[0] <= 1; op2rw_o[1] <= 0;//Read not write
        end
        10: begin //Compare logical immediate - BF+L, RA, SI
            `ifdef DEBUG $display("Decode 2 D-form (Inst: %h): D-form: Compare logical immediate", instructionMajId_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): D-form: Compare logical immediate", instructionMajId_i); `endif
            //Special Regs: CR, BF
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 0;
            functionalUnitType_o <= CRUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;
            op1rw_o[0] <= 0; op1rw_o[1] <= 0;//Neither read or write, treat as imm.
            op2rw_o[0] <= 1; op2rw_o[1] <= 0;//Read not write
        end
        3: begin //Trap word immediate - TO, RA, SI
            `ifdef DEBUG $display("Decode 2 D-form (Inst: %h): D-form: Trap word immediate", instructionMajId_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): D-form: Trap word immediate", instructionMajId_i); `endif
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;
            op1rw_o[0] <= 0; op1rw_o[1] <= 0;//Neither read or write, treat as imm.
            op2rw_o[0] <= 1; op2rw_o[1] <= 0;//Read not write
        end
        2: begin //Trap doubleword immediate - TO, RA, SI
            `ifdef DEBUG $display("Decode 2 D-form (Inst: %h): D-form: Trap doubleword immediate", instructionMajId_i); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): D-form: Trap doubleword immediate", instructionMajId_i); `endif
            //Special Regs: Na
            enable_o <= 1;
            immIsExtended_o <= 0; immIsShifted_o <= 0;
            functionalUnitType_o <= FXUnitId; instMinId_o <= 0;
            op1isReg_o <= 1;
            op2isReg_o <= 1;
            op1rw_o[0] <= 0; op1rw_o[1] <= 0;//Neither read or write, treat as imm.
            op2rw_o[0] <= 1; op2rw_o[1] <= 0;//Read not write
        end

        default: begin
            `ifdef DEBUG $display("Decode 2 D-form: Invalid instruction recieved");`endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode 2 D-form (Inst: %h): D-form: Invalid instruction recieved", instructionMajId_i); `endif
            enable_o <= 0; 
        end
        endcase
    end
end


endmodule