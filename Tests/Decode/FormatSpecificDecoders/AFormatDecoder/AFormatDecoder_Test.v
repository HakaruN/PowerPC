`timescale 1ns / 1ps
`include "../../../../Modules/Decode/FormatSpecificDecoders/AFormatDecoder.v"

module AFormatDecoderTest #(
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
    parameter A = 2**01,
    parameter ADecoderInstance = 0
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
    wire [0:addressWidth-1] instructionAddressOut;//address of the instruction
    wire [0:funcUnitCodeSize-1] functionalUnitTypeOut;//tells the backend what type of func unit to use
    wire [0:instructionCounterWidth] instMajIdOut;//major ID - the IDs are used to determine instruction order for reordering after execution
    wire [0:instMinIdWidth-1] instMinIdOut;//minor ID - minor ID's are generated in decode if an instruction generated micro ops, these are differentiated by the minor ID, they will have the same major ID
    wire is64BitOut;
    wire [0:PidSize-1] instPidOut;//process ID
    wire [0:TidSize-1] instTidOut;//Thread ID
    wire [0:regAccessPatternSize-1] op1rwOut, op2rwOut, op3rwOut, op4rwOut;
    wire op1IsRegOut, op2IsRegOut, op3IsRegOut, op4IsRegOut;
    wire [0:4 * regSize] instructionBodyOut;



AFormatDecoder #(
)
aFormatDecoder
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
    .op1rw_o(op1rwOut), .op2rw_o(op2rwOut), .op3rw_o(op3rwOut), .op4rw_o(op4rwOut),//reg operand are read/write flags
    .op1IsReg_o(op1IsRegOut), .op2IsReg_o(op2IsRegOut), .op3IsReg_o(op3IsRegOut), .op4IsReg_o(op4IsRegOut),//Reg operands isReg flags
    .instructionBody_o(instructionBodyOut)
);

reg [0:5] opcode;
reg [0:4] operand1;
reg [0:4] operand2;
reg [0:4] operand3;
reg [0:4] operand4;
reg [0:4] xopcode;
reg RCflag;

integer validInstCtrTot = 0;
integer validInstCtrTmp = 0;
integer numValidInstr = 24;
integer OpLoopCtr = 0;
integer XopLoopCtr = 0;

initial begin
    $dumpfile("AFormatDecodeTest.vcd");
    $dumpvars(0,aFormatDecoder);
    //init vars
    clockIn = 0; enableIn = 0;
    stallIn = 0;
    instFormatIn = A;
    instructionOpcodeIn = 0;

    opcode = 0;
    operand1 = 5'b01110;
    operand2 = 5'b10101;
    operand3 = 5'b01010;
    operand4 = 5'b10001;
    xopcode = 0;
    RCflag = 0;

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


/*
    //Test opcode == 31 insts
    opcode = 31; validInstCtrTmp = 0;
    for(XopLoopCtr = 0; XopLoopCtr < 32; XopLoopCtr = XopLoopCtr + 1)
    begin
        //test inst:
        xopcode = XopLoopCtr;
        #1;
        instructionIn = {opcode, operand1, operand2, operand3, operand4, xopcode, RCflag};
        instructionOpcodeIn = opcode; instructionMajIdIn = opcode; instructionAddressIn = opcode;
        enableIn = 1;
        clockIn = 1;
        #1;
        clockIn = 0;
        enableIn = 0;
        #1;

        if(enableOut == 1)//count how many valid instructions are detected. Should be 24
        begin
            validInstCtrTmp = validInstCtrTmp + 1;
        end
    end
    $display("Detected %d valid instructions for opcode = 31. There shoule be 1.", validInstCtrTmp);

    //teset opcode == 63
    opcode = 63; validInstCtrTmp = 0;
    for(XopLoopCtr = 0; XopLoopCtr < 32; XopLoopCtr = XopLoopCtr + 1)
    begin
        //test inst:
        xopcode = XopLoopCtr;
        #1;
        instructionIn = {opcode, operand1, operand2, operand3, operand4, xopcode, RCflag};
        instructionOpcodeIn = opcode; instructionMajIdIn = opcode; instructionAddressIn = opcode;
        enableIn = 1;
        clockIn = 1;
        #1;
        clockIn = 0;
        enableIn = 0;
        #1;

        if(enableOut == 1)//count how many valid instructions are detected. Should be 24
        begin
            validInstCtrTmp = validInstCtrTmp + 1;
        end
    end
    $display("Detected %d valid instructions for opcode = 63. There shoule be 12.", validInstCtrTmp);

    //teset opcode == 59
    opcode = 59; validInstCtrTmp = 0;
    for(XopLoopCtr = 0; XopLoopCtr < 32; XopLoopCtr = XopLoopCtr + 1)
    begin
        //test inst:
        xopcode = XopLoopCtr;
        #1;
        instructionIn = {opcode, operand1, operand2, operand3, operand4, xopcode, RCflag};
        instructionOpcodeIn = opcode; instructionMajIdIn = opcode; instructionAddressIn = opcode;
        enableIn = 1;
        clockIn = 1;
        #1;
        clockIn = 0;
        enableIn = 0;
        #1;

        if(enableOut == 1)//count how many valid instructions are detected. Should be 24
        begin
            validInstCtrTmp = validInstCtrTmp + 1;
        end
    end
    $display("Detected %d valid instructions for opcode = 59. There shoule be 11.", validInstCtrTmp);
*/

    validInstCtrTmp = 0;
    for(OpLoopCtr = 0; OpLoopCtr < 64; OpLoopCtr = OpLoopCtr + 1)
    begin
        for(XopLoopCtr = 0; XopLoopCtr < 32; XopLoopCtr = XopLoopCtr + 1)
        begin
            //test inst:
            opcode = OpLoopCtr;
            xopcode = XopLoopCtr;
            #1;
            instructionIn = {opcode, operand1, operand2, operand3, operand4, xopcode, RCflag};
            instructionOpcodeIn = opcode; instructionMajIdIn = opcode; instructionAddressIn = opcode;
            enableIn = 1;
            clockIn = 1;
            #1;
            clockIn = 0;
            enableIn = 0;
            #1;
            if(enableOut == 1)//count how many valid instructions are detected. Should be 24
            begin
                validInstCtrTmp = validInstCtrTmp + 1;
            end
        end
    end

    $display("Detected %d valid instructions", validInstCtrTmp);
    if(numValidInstr != validInstCtrTmp)
        $display("Error: %d instructions correctly detected out of %d supposed to pass", validInstCtrTmp, numValidInstr);
        

end

endmodule