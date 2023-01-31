`timescale 1ns / 1ps
`define DEBUG
`define DEBUG_PRINT
`include "../../../Modules/Decode/InOrderInstructionQueue.v"

module IOQTest
#(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 32, parameter TidSize = 64,
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter instMinIdWidth = 5,//width of inst minor ID
    parameter primOpcodeSize = 6,
    parameter opcodeSize = 12,
    parameter regSize = 5,
    parameter regAccessPatternSize = 2,//2 bit field, [0] == is read, [1] == is writen. Both can be true EG: (A = A + B)
    parameter funcUnitCodeSize = 3,

    parameter queueIndexWidth = 10,//1024 instructions long queue
    parameter numQueueEntries = 2**queueIndexWidth
)
(
);
    reg clockIn, resetIn;
    //Inputs of the 4 instructions coming in from the decoders
    reg instr1EnIn, instr2EnIn, instr3EnIn, instr4EnIn;
    reg [0:25-1] inst1FormatIn, inst2FormatIn, inst3FormatIn, inst4FormatIn;
    reg [0:opcodeSize-1] inst1OpcodeIn, inst2OpcodeIn, inst3OpcodeIn, inst4OpcodeIn;
    reg [0:addressWidth-1] inst1addressIn, inst2addressIn, inst3addressIn, inst4addressIn;
    reg [0:funcUnitCodeSize-1] inst1funcUnitTypeIn, inst2funcUnitTypeIn, inst3funcUnitTypeIn, inst4funcUnitTypeIn;
    reg [0:instructionCounterWidth-1] inst1MajIDIn, inst2MajIDIn, inst3MajIDIn, inst4MajIDIn;
    reg [0:instMinIdWidth-1] inst1MinIDIn, inst2MinIDIn, inst3MinIDIn, inst4MinIDIn;
    reg [0:instMinIdWidth-1] inst1NumMicroOpsIn, inst2NumMicroOpsIn, inst3NumMicroOpsIn, inst4NumMicroOpsIn;
    reg inst1Is64BitIn, inst2Is64BitIn, inst3Is64BitIn, inst4Is64BitIn;
    reg [0:PidSize-1] inst1PidIn, inst2PidIn, inst3PidIn, inst4PidIn;
    reg [0:TidSize-1] inst1TidIn, inst2TidIn, inst3TidIn, inst4TidIn;
    reg [0:regAccessPatternSize-1] inst1op1rwIn, inst1op2rwIn, inst1op3rwIn, inst1op4rwIn;
    reg [0:regAccessPatternSize-1] inst2op1rwIn, inst2op2rwIn, inst2op3rwIn, inst2op4rwIn;
    reg [0:regAccessPatternSize-1] inst3op1rwIn, inst3op2rwIn, inst3op3rwIn, inst3op4rwIn;
    reg [0:regAccessPatternSize-1] inst4op1rwIn, inst4op2rwIn, inst4op3rwIn, inst4op4rwIn;
    reg inst1op1IsRegIn, inst1op2IsRegIn, inst1op3IsRegIn, inst1op4IsRegIn;
    reg inst2op1IsRegIn, inst2op2IsRegIn, inst2op3IsRegIn, inst2op4IsRegIn;
    reg inst3op1IsRegIn, inst3op2IsRegIn, inst3op3IsRegIn, inst3op4IsRegIn;
    reg inst4op1IsRegIn, inst4op2IsRegIn, inst4op3IsRegIn, inst4op4IsRegIn;
    reg inst1ModifiesCRIn, inst2ModifiesCRIn, inst3ModifiesCRIn, inst4ModifiesCRIn;
    reg [0:64-1] inst1BodyIn, inst2BodyIn, inst3BodyIn, inst4BodyIn;

    //Outputs to the OoO backend
    reg readEnableIn;
    wire outputEnableOut;
    wire [0:1] numInstructionsOutOut;
    wire [0:25-1] inst1FormatOut, inst2FormatOut, inst3FormatOut, inst4FormatOut;
    wire [0:opcodeSize-1] inst1OpcodeOut, inst2OpcodeOut, inst3OpcodeOut, inst4OpcodeOut;
    wire [0:addressWidth-1] inst1AddressOut, inst2AddressOut, inst3AddressOut, inst4AddressOut;
    wire [0:funcUnitCodeSize-1] inst1FuncUnitOut, inst2FuncUnitOut, inst3FuncUnitOut, inst4FuncUnitOut;
    wire [0:instructionCounterWidth-1] inst1MajIdOut, inst2MajIdOut, inst3MajIdOut, inst4MajIdOut;
    wire [0:instMinIdWidth-1] inst1MinIDOut, inst2MinIDOut, inst3MinIDOut, inst4MinIDOut;
    wire [0:instMinIdWidth-1] inst1NumUOpsOut, inst2NumUOpsOut, inst3NumUOpsOut, inst4NumUOpsOut;
    wire inst1Is64BitOut, inst2Is64BitOut, inst3Is64BitOut, inst4Is64BitOut;
    wire [0:PidSize-1] inst1PidOut, inst2PidOut, inst3PidOut, inst4PidOut;
    wire [0:TidSize-1] inst1TidOut, inst2TidOut, inst3TidOut, inst4TidOut;
    wire [0:regAccessPatternSize-1] inst1op1rwOut, inst1op2rwOut, inst1op3rwOut, inst1op4rwOut;
    wire [0:regAccessPatternSize-1] inst2op1rwOut, inst2op2rwOut, inst2op3rwOut, inst2op4rwOut;
    wire [0:regAccessPatternSize-1] inst3op1rwOut, inst3op2rwOut, inst3op3rwOut, inst3op4rwOut;
    wire [0:regAccessPatternSize-1] inst4op1rwOut, inst4op2rwOut, inst4op3rwOut, inst4op4rwOut;
    wire inst1op1IsRegOut, inst1op2IsRegOut, inst1op3IsRegOut, inst1op4IsRegOut;
    wire inst2op1IsRegOut, inst2op2IsRegOut, inst2op3IsRegOut, inst2op4IsRegOut;
    wire inst3op1IsRegOut, inst3op2IsRegOut, inst3op3IsRegOut, inst3op4IsRegOut;
    wire inst4op1IsRegOut, inst4op2IsRegOut, inst4op3IsRegOut, inst4op4IsRegOut;
    wire inst1ModifiesCROut, inst2ModifiesCROut, inst3ModifiesCROut, inst4ModifiesCROut;
    wire [0:64-1] inst1BodyOut, inst2BodyOut, inst3BodyOut, inst4BodyOut;

    //generic state outputs
	wire [0:queueIndexWidth-1] headOut, tailOut;//dequeue from head, enqueue to tail
	wire isEmptyOut, isFullOut;


InOrderInstQueue
#()
inOrderInstQueue
(
    .clock_i(clockIn), .reset_i(resetIn),
    .instr1En_i(instr1EnIn), .instr2En_i(instr2EnIn), .instr3En_i(instr3EnIn), .instr4En_i(instr4EnIn),
    .inst1Format_i(inst1FormatIn), .inst2Format_i(inst2FormatIn), .inst3Format_i(inst3FormatIn), .inst4Format_i(inst4FormatIn),
    .inst1Opcode_i(inst1OpcodeIn), .inst2Opcode_i(inst2OpcodeIn), .inst3Opcode_i(inst3OpcodeIn), .inst4Opcode_i(inst4OpcodeIn),
    .inst1address_i(inst1addressIn), .inst2address_i(inst2addressIn), .inst3address_i(inst3addressIn), .inst4address_i(inst4addressIn),
    .inst1funcUnitType_i(inst1funcUnitTypeIn), .inst2funcUnitType_i(inst2funcUnitTypeIn), .inst3funcUnitType_i(inst3funcUnitTypeIn), .inst4funcUnitType_i(inst4funcUnitTypeIn),
    .inst1MajID_i(inst1MajIDIn), .inst2MajID_i(inst2MajIDIn), .inst3MajID_i(inst3MajIDIn), .inst4MajID_i(inst4MajIDIn),
    .inst1MinID_i(inst1MinIDIn), .inst2MinID_i(inst2MinIDIn), .inst3MinID_i(inst3MinIDIn), .inst4MinID_i(inst4MinIDIn),
    .inst1NumMicroOps_i(inst1NumMicroOpsIn), .inst2NumMicroOps_i(inst2NumMicroOpsIn), .inst3NumMicroOps_i(inst3NumMicroOpsIn), .inst4NumMicroOps_i(inst4NumMicroOpsIn),
    .inst1Is64Bit_i(inst1Is64BitIn), .inst2Is64Bit_i(inst2Is64BitIn), .inst3Is64Bit_i(inst3Is64BitIn), .inst4Is64Bit_i(inst4Is64BitIn),
    .inst1Pid_i(inst1PidIn), .inst2Pid_i(inst2PidIn), .inst3Pid_i(inst3PidIn), .inst4Pid_i(inst4PidIn),
    .inst1Tid_i(inst1TidIn), .inst2Tid_i(inst2TidIn), .inst3Tid_i(inst3TidIn), .inst4Tid_i(inst4TidIn),
    .inst1op1rw_i(inst1op1rwIn), .inst1op2rw_i(inst1op2rwIn), .inst1op3rw_i(inst1op3rwIn), .inst1op4rw_i(inst1op4rwIn),
    .inst2op1rw_i(inst2op1rwIn), .inst2op2rw_i(inst2op2rwIn), .inst2op3rw_i(inst2op3rwIn), .inst2op4rw_i(inst2op4rwIn),
    .inst3op1rw_i(inst3op1rwIn), .inst3op2rw_i(inst3op2rwIn), .inst3op3rw_i(inst3op3rwIn), .inst3op4rw_i(inst3op4rwIn),
    .inst4op1rw_i(inst4op1rwIn), .inst4op2rw_i(inst4op2rwIn), .inst4op3rw_i(inst4op3rwIn), .inst4op4rw_i(inst4op4rwIn),
    .inst1op1IsReg_i(inst1op1IsRegIn), .inst1op2IsReg_i(inst1op2IsRegIn), .inst1op3IsReg_i(inst1op3IsRegIn), .inst1op4IsReg_i(inst1op4IsRegIn),
    .inst2op1IsReg_i(inst2op1IsRegIn), .inst2op2IsReg_i(inst2op2IsRegIn), .inst2op3IsReg_i(inst2op3IsRegIn), .inst2op4IsReg_i(inst2op4IsRegIn),
    .inst3op1IsReg_i(inst3op1IsRegIn), .inst3op2IsReg_i(inst3op2IsRegIn), .inst3op3IsReg_i(inst3op3IsRegIn), .inst3op4IsReg_i(inst3op4IsRegIn),
    .inst4op1IsReg_i(inst4op1IsRegIn), .inst4op2IsReg_i(inst4op2IsRegIn), .inst4op3IsReg_i(inst4op3IsRegIn), .inst4op4IsReg_i(inst4op4IsRegIn),
    .inst1ModifiesCR_i(inst1ModifiesCRIn), .inst2ModifiesCR_i(inst2ModifiesCRIn), .inst3ModifiesCR_i(inst3ModifiesCRIn), .inst4ModifiesCR_i(inst4ModifiesCRIn),
    .inst1Body_i(inst1BodyIn), .inst2Body_i(inst2BodyIn), .inst3Body_i(inst3BodyIn), .inst4Body_i(inst4BodyIn),

    .readEnable_i(readEnableIn),
    .outputEnable_o(outputEnableOut),
    .numInstructionsOut_o(numInstructionsOutOut),
    .inst1Format_o(inst1FormatOut), .inst2Format_o(inst2FormatOut), .inst3Format_o(inst3FormatOut), .inst4Format_o(inst4FormatOut),
    .inst1Opcode_o(inst1OpcodeOut), .inst2Opcode_o(inst2OpcodeOut), .inst3Opcode_o(inst3OpcodeOut), .inst4Opcode_o(inst4OpcodeOut),
    .inst1Address_o(inst1AddressOut), .inst2Address_o(inst2AddressOut), .inst3Address_o(inst3AddressOut), .inst4Address_o(inst4AddressOut),
    .inst1FuncUnit_o(inst1FuncUnitOut), .inst2FuncUnit_o(inst2FuncUnitOut), .inst3FuncUnit_o(inst3FuncUnitOut), .inst4FuncUnit_o(inst4FuncUnitOut),
    .inst1MajId_o(inst1MajIdOut), .inst2MajId_o(inst2MajIdOut), .inst3MajId_o(inst2MajIdOut), .inst4MajId_o(inst4MajIdOut),
    .inst1MinID_o(inst1MinIDOut), .inst2MinID_o(inst2MinIDOut), .inst3MinID_o(inst2MinIDOut), .inst4MinID_o(inst4MinIDOut),
    .inst1NumUOps_o(inst1NumUOpsOut), .inst2NumUOps_o(inst2NumUOpsOut), .inst3NumUOps_o(inst3NumUOpsOut), .inst4NumUOps_o(inst4NumUOpsOut),
    .inst1Is64Bit_o(inst1Is64BitOut), .inst2Is64Bit_o(inst2Is64BitOut), .inst3Is64Bit_o(inst3Is64BitOut), .inst4Is64Bit_o(inst4Is64BitOut),
    .inst1Pid_o(inst1PidOut), .inst2Pid_o(inst2PidOut), .inst3Pid_o(inst3PidOut), .inst4Pid_o(inst4PidOut),
    .inst1Tid_o(inst1TidOut), .inst2Tid_o(inst2TidOut), .inst3Tid_o(inst3TidOut), .inst4Tid_o(inst4TidOut),
    .inst1op1rw_o(inst1op1rwOut), .inst1op2rw_o(inst1op2rwOut), .inst1op3rw_o(inst1op3rwOut), .inst1op4rw_o(inst1op4rwOut),
    .inst2op1rw_o(inst2op1rwOut), .inst2op2rw_o(inst2op2rwOut), .inst2op3rw_o(inst2op3rwOut), .inst2op4rw_o(inst2op4rwOut),
    .inst3op1rw_o(inst3op1rwOut), .inst3op2rw_o(inst3op2rwOut), .inst3op3rw_o(inst3op3rwOut), .inst3op4rw_o(inst3op4rwOut),
    .inst4op1rw_o(inst4op1rwOut), .inst4op2rw_o(inst4op2rwOut), .inst4op3rw_o(inst4op3rwOut), .inst4op4rw_o(inst4op4rwOut),
    .inst1op1IsReg_o(inst1op1IsRegOut), .inst1op2IsReg_o(inst1op2IsRegOut), .inst1op3IsReg_o(inst1op3IsRegOut), .inst1op4IsReg_o(inst1op4IsRegOut),
    .inst2op1IsReg_o(inst2op1IsRegOut), .inst2op2IsReg_o(inst2op2IsRegOut), .inst2op3IsReg_o(inst2op3IsRegOut), .inst2op4IsReg_o(inst2op4IsRegOut),
    .inst3op1IsReg_o(inst3op1IsRegOut), .inst3op2IsReg_o(inst3op2IsRegOut), .inst3op3IsReg_o(inst3op3IsRegOut), .inst3op4IsReg_o(inst3op4IsRegOut),
    .inst4op1IsReg_o(inst4op1IsRegOut), .inst4op2IsReg_o(inst4op2IsRegOut), .inst4op3IsReg_o(inst4op3IsRegOut), .inst4op4IsReg_o(inst4op4IsRegOut),
    .inst1ModifiesCR_o(inst1ModifiesCROut), .inst2ModifiesCR_o(inst2ModifiesCROut), .inst3ModifiesCR_o(inst3ModifiesCROut), .inst4ModifiesCR_o(inst4ModifiesCROut),
    .inst1Body_o(inst1BodyOut), .inst2Body_o(inst2BodyOut), .inst3Body_o(inst3BodyOut), .inst4Body_o(inst4BodyOut),
	.head_o(headOut), .tail_o(tailOut),
	.isEmpty_o(isEmptyOut), .isFull_o(isFullOut)
);


initial begin
    $dumpfile("InOrderInstQueue.vcd");
    $dumpvars(0,inOrderInstQueue);
    clockIn = 0; resetIn = 0;
    instr1EnIn = 0; instr2EnIn = 0; instr3EnIn = 0; instr4EnIn = 0; 
    inst1FormatIn = 0; inst2FormatIn = 0; inst3FormatIn = 0; inst4FormatIn = 0;
    inst1OpcodeIn = 0; inst2OpcodeIn = 0; inst3OpcodeIn = 0; inst4OpcodeIn = 0;
    inst1addressIn = 0; inst2addressIn = 0; inst3addressIn = 0; inst4addressIn = 0;
    inst1funcUnitTypeIn = 0; inst2funcUnitTypeIn = 0; inst3funcUnitTypeIn = 0; inst4funcUnitTypeIn = 0;
    inst1MajIDIn = 0; inst2MajIDIn = 0; inst3MajIDIn = 0; inst4MajIDIn = 0;
    inst1MinIDIn = 0; inst2MinIDIn = 0; inst3MinIDIn = 0; inst4MinIDIn = 0;
    inst1NumMicroOpsIn = 0; inst2NumMicroOpsIn = 0; inst3NumMicroOpsIn = 0; inst4NumMicroOpsIn = 0;
    inst1Is64BitIn = 0; inst2Is64BitIn = 0; inst3Is64BitIn = 0; inst4Is64BitIn = 0;
    inst1PidIn = 0; inst2PidIn = 0; inst3PidIn = 0; inst4PidIn = 0;
    inst1TidIn = 0; inst2TidIn = 0; inst3TidIn = 0; inst4TidIn = 0;
    inst1op1rwIn = 0; inst1op2rwIn = 0; inst1op3rwIn = 0; inst1op4rwIn = 0;
    inst2op1rwIn = 0; inst2op2rwIn = 0; inst2op3rwIn = 0; inst2op4rwIn = 0;
    inst3op1rwIn = 0; inst3op2rwIn = 0; inst3op3rwIn = 0; inst3op4rwIn = 0;
    inst4op1rwIn = 0; inst4op2rwIn = 0; inst4op3rwIn = 0; inst4op4rwIn = 0;
    inst1op1IsRegIn = 0; inst1op2IsRegIn = 0; inst1op3IsRegIn = 0; inst1op4IsRegIn = 0;
    inst2op1IsRegIn = 0; inst2op2IsRegIn = 0; inst2op3IsRegIn = 0; inst2op4IsRegIn = 0;
    inst3op1IsRegIn = 0; inst3op2IsRegIn = 0; inst3op3IsRegIn = 0; inst3op4IsRegIn = 0;
    inst4op1IsRegIn = 0; inst4op2IsRegIn = 0; inst4op3IsRegIn = 0; inst4op4IsRegIn = 0;
    inst1ModifiesCRIn = 0; inst2ModifiesCRIn = 0; inst3ModifiesCRIn = 0; inst4ModifiesCRIn = 0;
    inst1BodyIn = 0; inst2BodyIn = 0; inst3BodyIn = 0; inst4BodyIn = 0;
    readEnableIn = 0;

    #1;
    clockIn = 1; resetIn = 1;
    #1;
    clockIn = 0; resetIn = 0;
    #1;
    $display("-----------------");
    //Write 4 single uop instructions
    instr1EnIn = 1; instr2EnIn = 1; instr3EnIn = 1; instr4EnIn = 1; 
    inst1MajIDIn = 0; inst2MajIDIn = 1; inst3MajIDIn = 2; inst4MajIDIn = 3;
    inst1MinIDIn = 0; inst2MinIDIn = 0; inst3MinIDIn = 0; inst4MinIDIn = 0;
    inst1NumMicroOpsIn = 1; inst2NumMicroOpsIn = 1; inst3NumMicroOpsIn = 1; inst4NumMicroOpsIn = 1;
    inst1addressIn = 0; inst2addressIn = 4; inst3addressIn = 8; inst4addressIn = 12;
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    $display("-----------------");

    //Dont do anything, check that it's not full but still empty
    instr1EnIn = 0; instr2EnIn = 0; instr3EnIn = 0; instr4EnIn = 0; 
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    $display("-----------------");

    //Write one 1-uop inst to the queue
    instr1EnIn = 1; instr2EnIn = 0; instr3EnIn = 0; instr4EnIn = 0; 
    inst1MajIDIn = 4; inst1MinIDIn = 0; inst1NumMicroOpsIn = 1; inst1addressIn = 16;
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    $display("-----------------");

    //Read some instructions
    instr1EnIn = 0; instr2EnIn = 0; instr3EnIn = 0; instr4EnIn = 0; 
    readEnableIn = 1;
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    $display("-----------------");
end


endmodule