`timescale 1ns / 1ps
`include "../../../../Decode/FormatSpecificDecoders/AFormatDecoder.v"

module BFormatDecoderTest #(
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
    wire [0:opcodeSize-1] opcodeOut;//decoded opcode
    wire [0:PrimOpcodeSize-1] instructionOpcodeOut;//primary opcode
    wire [0:addressWidth-1] instructionAddressOut;//address of the instruction
    wire [0:funcUnitCodeSize-1] functionalUnitTypeOut;//tells the backend what type of func unit to use
    wire [0:instructionCounterWidth] instMajIdOut;//major ID - the IDs are used to determine instruction order for reordering after execution
    wire [0:instMinIdWidth-1] instMinIdOut;//minor ID - minor ID's are generated in decode if an instruction generated micro ops, these are differentiated by the minor ID, they will have the same major ID
    wire is64BitOut;
    wire [0:PidSize-1] instPidOut;//process ID
    wire [0:TidSize-1] instTidOut;//Thread ID
    wire [0:(2 * regSize) + immediateSize + 3] instructionBodyOut;



BFormatDecoder #(
)
bFormatDecoder
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
    .instructionBody_o(instructionBodyOut)
);

reg [0:5] opcode;
reg [0:4] operand1;
reg [0:4] operand2;
reg [0:13] immediate;
reg AA;
reg LK;

initial begin
    $dumpfile("BFormatDecodeTest.vcd");
    $dumpvars(0,bFormatDecoder);
    //init vars
    clockIn = 0; enableIn = 0;
    stallIn = 0;
    instFormatIn = B;
    instructionOpcodeIn = 0;

    opcode = 0;
    operand1 = 5'b01110;
    operand2 = 5'b10001;
    immediate = 14'b0000_1111_1111_00;
    AA = 1;
    LK = 1;

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


    for(opcode = 0; opcode < 6'b111111; opcode = opcode + 1)
    begin
    //test inst:
    #1;
    LK = opcode % 2;
    AA = !LK;
    instructionIn = {opcode, operand1, operand2, immediate, AA, LK};
    instructionOpcodeIn = opcode; instructionMajIdIn = opcode; instructionAddressIn = opcode;
    enableIn = 1;
    clockIn = 1;
    #1;
    clockIn = 0;
    enableIn = 0;
    #1;
    end



end

endmodule