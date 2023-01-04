`timescale 1ns / 1ps
`include "../../../../Modules/Decode/FormatSpecificDecoders/DFormatDecoder.v"

module DFormatDecoderTest #(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter instMinIdWidth = 7,
    parameter opcodeSize = 12,
    parameter PrimOpcodeSize = 6, parameter regSize = 5,
    parameter regAccessPatternSize = 2,//2 bit field, [0] == is read, [1] == is writen. Both can be true EG: (A = A + B)
    parameter regRead = 2'b10, parameter regWrite = 2'b01, 
    parameter isImmediateSize = 1, parameter immediateSize = 16,
    parameter funcUnitCodeSize = 3, //can have up to 8 types of func unit.
    parameter Op1Pos = 6, parameter RAPos = 11, parameter ImmPos = 16,//positions in the instruction
    parameter immWidth = 16,
    //FX = int, FP = float, VX = vector, CR = condition, LS = load/store
    parameter FXUnitId = 0, parameter FPUnitId = 1, parameter VXUnitId = 2, parameter CRUnitId = 3, parameter LSUnitId = 4,  parameter BranchUnitID = 6,   
    parameter D = 2**05,
    parameter DDecoderInstance = 0
)
(
);

    ///Input
    //command
    reg clockIn, resetIn;
    reg enableIn, stallIn;
    //Data
    reg [0:25] instFormatIn;
    reg [0:PrimOpcodeSize-1] instructionOpcodeIn;
    reg [0:instructionWidth-1] instructionIn;
    reg [0:addressWidth-1] instructionAddressIn;
    reg is64BitIn;
    reg [0:PidSize-1] instructionPidIn;
    reg [0:TidSize-1] instructionTidIn;
    reg [0:instructionCounterWidth-1] instructionMajIdIn;
    ///Output
    wire enableOut;
    ///Instrution components
    //Instruction header
    wire [0:opcodeSize-1] opcodeOut;//decoded opcode
    wire [0:addressWidth-1] instructionAddressOut;//address of the instruction
    wire [0:funcUnitCodeSize-1] functionalUnitTypeOut;//tells the backend what type of func unit to use
    wire [0:instructionCounterWidth] instMajIdOut;//major ID - the IDs are used to determine instruction order for reordering after execution
    wire [0:instMinIdWidth-1] instMinIdOut;//minor ID - minor ID's are generated in decode if an instruction generated micro ops, these are differentiated by the minor ID, they will have the same major ID
    wire is64BitOut;
    wire [0:PidSize-1] instPidOut;//process ID
    wire [0:TidSize-1] instTidOut;//Thread ID
    wire [0:regAccessPatternSize-1] op1rwOut, op2rwOut;//how are the operands accessed, are they writen to and/or read from [0] write flag, [1] write flag.
    wire op1isRegOut, op2isRegOut, immIsExtendedOut, immIsShiftedOut;//if imm is shifted, its shifted up 2 bytes
    //Instruction body - data contents are 26 bits wide. There are also flags to include
    wire [0:(2 * regSize) + immediateSize - 1] instructionBodyOut;



DFormatDecoder #(
)
dFormatDecoder
(
    .clock_i(clockIn), .reset_i(resetIn),
    .enable_i(enableIn), .stall_i(stallIn),
    .instFormat_i(instFormatIn),
    .instructionOpcode_i(instructionOpcodeIn),
    .instruction_i(instructionIn),
    .instructionAddress_i(instructionAddressIn),
    .is64Bit_i(is64BitIn),
    .instructionPid_i(instructionPidIn),
    .instructionTid_i(instructionTidIn),
    .instructionMajId_i(instructionMajIdIn),

    .enable_o(enableOut),
    .opcode_o(opcodeOut),
    .instructionAddress_o(instructionAddressOut),
    .functionalUnitType_o(functionalUnitTypeOut),
    .instMajId_o(instMajIdOut),
    .instMinId_o(instMinIdOut),
    .is64Bit_o(is64BitOut),
    .instPid_o(instPidOut),
    .instTid_o(instTidOut),
    .op1rw_o(op1rwOut), .op2rw_o(op2rwOut),
    .op1isReg_o(op1isRegOut), .op2isReg_o(op2isRegOut), .immIsExtended_o(immIsExtendedOut), .immIsShifted_o(immIsShiftedOut),

    .instructionBody_o(instructionBodyOut)
);

reg [0:5] opcode;
reg [6:10] operand1;
reg [11:15] operand2;
reg [16:31] immediate;

//Test stage
integer validInstCtrTmp = 0;
integer numValidInstr = 40;
integer OpLoopCtr = 0;

initial begin
    $dumpfile("DFormatDecodeTest.vcd");
    $dumpvars(0,dFormatDecoder);
    //init vars
    clockIn = 0; enableIn = 0;
    stallIn = 0;
    instFormatIn = D;
    instructionOpcodeIn = 0;

    opcode = 0;
    operand1 = 0;
    operand2 = 0;
    immediate = 0;

    instructionIn = {opcode, operand1, operand2, immediate};

    instructionAddressIn = 0;
    is64BitIn = 1;
    instructionPidIn = 0;
    instructionTidIn = 0;
    instructionMajIdIn = 0;

    //reset
    resetIn = 1;
    clockIn = 1;
    #1;
    clockIn = 0;
    resetIn = 0;
    #1;

    for(OpLoopCtr = 0; OpLoopCtr <= 6'b111111; OpLoopCtr = OpLoopCtr + 1)
    begin
    //test inst:
    #1;
    opcode = OpLoopCtr;
    instructionIn = {opcode, operand1, operand2, immediate};
    instructionOpcodeIn = opcode; instructionMajIdIn = opcode; instructionAddressIn = opcode;
    enableIn = 1;
    clockIn = 1;
    #1;
    clockIn = 0;
    enableIn = 0;
    if(enableOut)
        validInstCtrTmp = validInstCtrTmp + 1;
    #1;
    end

    if(validInstCtrTmp == numValidInstr)
    $display("PASS: %d out of %d instructions correctly detected", validInstCtrTmp, numValidInstr);
    else
    $display("FAIL: %d out of %d instructions correctly detected", validInstCtrTmp, numValidInstr);

end

endmodule