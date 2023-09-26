`timescale 1ns / 1ps
`include "../../../Modules/OutOfOrder/FXRAT.v"

////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
`define DEBUG


module FXRAT_Test
    #(
    parameter regSize = 64,
    parameter ROBEntryWidth = 7,
    parameter numRegs = 32,
    parameter opcodeSize = 12,
    parameter PidSize = 20, parameter TidSize = 16,
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter instMinIdWidth = 5,
    parameter FXRATFileInstance = 0
    )
    (

    );


    ///inputs
    //command
    reg clockIn, resetIn, enableIn;
    reg [0:1] numInstIn;
    //Instr 1
    reg [0:regSize-1] inst1Param1In, inst1Param2In, inst1Param3In, inst1Param4In;
    reg inst1Param1EnIn, inst1Param2EnIn, inst1Param3EnIn, inst1Param4EnIn;
    reg inst1Param1IsRegIn, inst1Param2IsRegIn, inst1Param3IsRegIn, inst1Param4IsRegIn;
    reg [0:1] inst1Param1RWIn, inst1Param2RWIn, inst1Param3RWIn, inst1Param4RWIn;
    //Instr 2
    reg [0:regSize-1] inst2Param1In, inst2Param2In, inst2Param3In, inst2Param4In;
    reg inst2Param1EnIn, inst2Param2EnIn, inst2Param3EnIn, inst2Param4EnIn;
    reg inst2Param1IsRegIn, inst2Param2IsRegIn, inst2Param3IsRegIn, inst2Param4IsRegIn;
    reg [0:1] inst2Param1RWIn, inst2Param2RWIn, inst2Param3RWIn, inst2Param4RWIn;
    //Instr 3
    reg [0:regSize-1] inst3Param1In, inst3Param2In, inst3Param3In, inst3Param4In;
    reg inst3Param1EnIn, inst3Param2EnIn, inst3Param3EnIn, inst3Param4EnIn;
    reg inst3Param1IsRegIn, inst3Param2IsRegIn, inst3Param3IsRegIn, inst3Param4IsRegIn;
    reg [0:1] inst3Param1RWIn, inst3Param2RWIn, inst3Param3RWIn, inst3Param4RWIn;
    //Instr 4
    reg [0:regSize-1] inst4Param1In, inst4Param2In, inst4Param3In, inst4Param4In;
    reg inst4Param1EnIn, inst4Param2EnIn, inst4Param3EnIn, inst4Param4EnIn;
    reg inst4Param1IsRegIn, inst4Param2IsRegIn, inst4Param3IsRegIn, inst4Param4IsRegIn;
    reg [0:1] inst4Param1RWIn, inst4Param2RWIn, inst4Param3RWIn, inst4Param4RWIn;
    //bypass inputs
    reg [0:regSize-1] inst1AddrIn, inst2AddrIn, inst3AddrIn, inst4AddrIn;
    reg [0:instructionCounterWidth-1] inst1MajIdIn, inst2MajIdIn, inst3MajIdIn, inst4MajIdIn;
    reg [0:instMinIdWidth-1] inst1MinIdIn, inst2MinIdIn, inst3MinIdIn, inst4MinIdIn;
    reg [0:PidSize-1] inst1PidIn, inst2PidIn, inst3PidIn, inst4PidIn;
    reg [0:TidSize-1] inst1TidIn, inst2TidIn, inst3TidIn, inst4TidIn;
    reg [0:opcodeSize-1] inst1OpCodeIn, inst2OpCodeIn, inst3OpCodeIn, inst4OpCodeIn;
    reg clearName1In, clearName2In, clearName3In, clearName4In;
    reg [0:ROBEntryWidth-1] ROBName1In, ROBName2In, ROBName3In, ROBName4In;

    ///outputs
    //Instr 1
    wire [0:regSize-1] inst1Param1Out, inst1Param2Out, inst1Param3Out, inst1Param4Out;
    wire inst1Param1EnOut, inst1Param2EnOut, inst1Param3EnOut, inst1Param4EnOut;
    wire inst1Param1IsRegOut, inst1Param2IsRegOut, inst1Param3IsRegOut, inst1Param4IsRegOut;
    wire [0:1] inst1Param1RWOut, inst1Param2RWOut, inst1Param3RWOut, inst1Param4RWOut;
    //Instr 2
    wire [0:regSize-1] inst2Param1Out, inst2Param2Out, inst2Param3Out, inst2Param4Out;
    wire inst2Param1EnOut, inst2Param2EnOut, inst2Param3EnOut, inst2Param4EnOut;
    wire inst2Param1IsRegOut, inst2Param2IsRegOut, inst2Param3IsRegOut, inst2Param4IsRegOut;
    wire [0:1] inst2Param1RWOut, inst2Param2RWOut, inst2Param3RWOut, inst2Param4RWOut;
    //Instr 3
    wire [0:regSize-1] inst3Param1Out, inst3Param2Out, inst3Param3Out, inst3Param4Out;
    wire inst3Param1EnOut, inst3Param2EnOut, inst3Param3EnOut, inst3Param4EnOut;
    wire inst3Param1IsRegOut, inst3Param2IsRegOut, inst3Param3IsRegOut, inst3Param4IsRegOut;
    wire [0:1] inst3Param1RWOut, inst3Param2RWOut, inst3Param3RWOut, inst3Param4RWOut;
    //Instr 4
    wire [0:regSize-1] inst4Param1Out, inst4Param2Out, inst4Param3Out, inst4Param4Out;
    wire inst4Param1EnOut, inst4Param2EnOut, inst4Param3EnOut, inst4Param4EnOut;
    wire inst4Param1IsRegOut, inst4Param2IsRegOut, inst4Param3IsRegOut, inst4Param4IsRegOut;
    wire [0:1] inst4Param1RWOut, inst4Param2RWOut, inst4Param3RWOut, inst4Param4RWOut;
    //bypass outputs
    wire [0:1] numInstOut;
    wire [0:regSize-1] inst1AddrOut, inst2AddrOut, inst3AddrOut, inst4AddrOut;
    wire [0:instructionCounterWidth-1] inst1MajIdOut, inst2MajIdOut, inst3MajIdOut, inst4MajIdOut;
    wire [0:instMinIdWidth-1] inst1MinIdOut, inst2MinIdOut, inst3MinIdOut, inst4MinIdOut;
    wire [0:PidSize-1] inst1PidOut, inst2PidOut, inst3PidOut, inst4PidOut;
    wire [0:TidSize-1] inst1TidOut, inst2TidOut, inst3TidOut, inst4TidOut;
    wire [0:opcodeSize-1] inst1OpCodeOut, inst2OpCodeOut, inst3OpCodeOut, inst4OpCodeOut;


    FXRAT #(
        .regSize(regSize),
        .ROBEntryWidth(ROBEntryWidth),
        .numRegs(numRegs),
        .opcodeSize(opcodeSize),
        .PidSize(PidSize),
        .TidSize(TidSize),
        .instructionCounterWidth(instructionCounterWidth),
        .instMinIdWidth(instMinIdWidth),
        .FXRATFileInstance(FXRATFileInstance)
    )
    FXRAT(
    .clock_i(clockIn), .reset_i(resetIn), .enable_i(enableIn),
    .numInst_i(numInstIn),
    //Instr 1
    .inst1Param1_i(inst1Param1In), .inst1Param2_i(inst1Param2In), .inst1Param3_i(inst1Param3In), .inst1Param4_i(inst1Param4In),
    .inst1Param1En_i(inst1Param1EnIn), .inst1Param2En_i(inst1Param2EnIn), .inst1Param3En_i(inst1Param3EnIn), .inst1Param4En_i(inst1Param4EnIn),
    .inst1Param1IsReg_i(inst1Param1IsRegIn), .inst1Param2IsReg_i(inst1Param2IsRegIn), .inst1Param3IsReg_i(inst1Param3IsRegIn), .inst1Param4IsReg_i(inst1Param4IsRegIn),
    .inst1Param1RW_i(inst1Param1RWIn), .inst1Param2RW_i(inst1Param2RWIn), .inst1Param3RW_i(inst1Param3RWIn), .inst1Param4RW_i(inst1Param4RWIn),
    //Instr 2
    .inst2Param1_i(inst2Param1In), .inst2Param2_i(inst2Param2In), .inst2Param3_i(inst2Param3In), .inst2Param4_i(inst2Param4In),
    .inst2Param1En_i(inst2Param1EnIn), .inst2Param2En_i(inst2Param2EnIn), .inst2Param3En_i(inst2Param3EnIn), .inst2Param4En_i(inst2Param4EnIn),
    .inst2Param1IsReg_i(inst2Param1IsRegIn), .inst2Param2IsReg_i(inst2Param2IsRegIn), .inst2Param3IsReg_i(inst2Param3IsRegIn), .inst2Param4IsReg_i(inst2Param4IsRegIn),
    .inst2Param1RW_i(inst2Param1RWIn), .inst2Param2RW_i(inst2Param2RWIn), .inst2Param3RW_i(inst2Param3RWIn), .inst2Param4RW_i(inst2Param4RWIn),
    //Instr 3
    .inst3Param1_i(inst3Param1In), .inst3Param2_i(inst3Param2In), .inst3Param3_i(inst3Param3In), .inst3Param4_i(inst3Param4In),
    .inst3Param1En_i(inst3Param1EnIn), .inst3Param2En_i(inst3Param2EnIn), .inst3Param3En_i(inst3Param3EnIn), .inst3Param4En_i(inst3Param4EnIn),
    .inst3Param1IsReg_i(inst3Param1IsRegIn), .inst3Param2IsReg_i(inst3Param2IsRegIn), .inst3Param3IsReg_i(inst3Param3IsRegIn), .inst3Param4IsReg_i(inst3Param4IsRegIn),
    .inst3Param1RW_i(inst3Param1RWIn), .inst3Param2RW_i(inst3Param2RWIn), .inst3Param3RW_i(inst3Param3RWIn), .inst3Param4RW_i(inst3Param4RWIn),
    //Instr 4
    .inst4Param1_i(inst4Param1In), .inst4Param2_i(inst4Param2In), .inst4Param3_i(inst4Param3In), .inst4Param4_i(inst4Param4In),
    .inst4Param1En_i(inst4Param1EnIn), .inst4Param2En_i(inst4Param2EnIn), .inst4Param3En_i(inst4Param3EnIn), .inst4Param4En_i(inst4Param4EnIn),
    .inst4Param1IsReg_i(inst4Param1IsRegIn), .inst4Param2IsReg_i(inst4Param2IsRegIn), .inst4Param3IsReg_i(inst4Param3IsRegIn), .inst4Param4IsReg_i(inst4Param4IsRegIn),
    .inst4Param1RW_i(inst4Param1RWIn), .inst4Param2RW_i(inst4Param2RWIn), .inst4Param3RW_i(inst4Param3RWIn), .inst4Param4RW_i(inst4Param4RWIn),
    //bypass inputs
    .inst1Addr_i(inst1AddrIn), .inst2Addr_i(inst2AddrIn), .inst3Addr_i(inst3AddrIn), .inst4Addr_i(inst4AddrIn),
    .inst1MajId_i(inst1MajIdIn), .inst2MajId_i(inst2MajIdIn), .inst3MajId_i(inst3MajIdIn), .inst4MajId_i(inst4MajIdIn),
    .inst1MinId_i(inst1MinIdIn), .inst2MinId_i(inst2MinIdIn), .inst3MinId_i(inst3MinIdIn), .inst4MinId_i(inst4MinIdIn),
    .inst1Pid_i(inst1PidIn), .inst2Pid_i(inst2PidIn), .inst3Pid_i(inst3PidIn), .inst4Pid_i(inst4PidIn),
    .inst1Tid_i(inst1TidIn), .inst2Tid_i(inst2TidIn), .inst3Tid_i(inst3TidIn), .inst4Tid_i(inst4TidIn),
    .inst1OpCode_i(inst1OpCodeIn), .inst2OpCode_i(inst2OpCodeIn), .inst3OpCode_i(inst3OpCodeIn), .inst4OpCode_i(inst4OpCodeIn),
    //RAT Clear names
    .clearName1_i(clearName1In), .clearName2_i(clearName2In), .clearName3_i(clearName3In), .clearName4_i(clearName4In), 
    .ROBName1_i(ROBName1In), .ROBName2_i(ROBName2In), .ROBName3_i(ROBName3In), .ROBName4_i(ROBName4In), 

    ///outputs
    //Instr 1
    .inst1Param1_o(inst1Param1Out), .inst1Param2_o(inst1Param2Out), .inst1Param3_o(inst1Param3Out), .inst1Param4_o(inst1Param4Out),
    .inst1Param1En_o(inst1Param1EnOut), .inst1Param2En_o(inst1Param2EnOut), .inst1Param3En_o(inst1Param3EnOut), .inst1Param4En_o(inst1Param4EnOut),
    .inst1Param1IsReg_o(inst1Param1IsRegOut), .inst1Param2IsReg_o(inst1Param2IsRegOut), .inst1Param3IsReg_o(inst1Param3IsRegOut), .inst1Param4IsReg_o(inst1Param4IsRegOut),
    .inst1Param1RW_o(inst1Param1RWOut), .inst1Param2RW_o(inst1Param2RWOut), .inst1Param3RW_o(inst1Param3RWOut), .inst1Param4RW_o(inst1Param4RWOut),
    //Instr 2
    .inst2Param1_o(inst2Param1Out), .inst2Param2_o(inst2Param2Out), .inst2Param3_o(inst2Param3Out), .inst2Param4_o(inst2Param4Out),
    .inst2Param1En_o(inst2Param1EnOut), .inst2Param2En_o(inst2Param2EnOut), .inst2Param3En_o(inst2Param3EnOut), .inst2Param4En_o(inst2Param4EnOut),
    .inst2Param1IsReg_o(inst2Param1IsRegOut), .inst2Param2IsReg_o(inst2Param2IsRegOut), .inst2Param3IsReg_o(inst2Param3IsRegOut), .inst2Param4IsReg_o(inst2Param4IsRegOut),
    .inst2Param1RW_o(inst2Param1RWOut), .inst2Param2RW_o(inst2Param2RWOut), .inst2Param3RW_o(inst2Param3RWOut), .inst2Param4RW_o(inst2Param4RWOut),
    //Instr 3
    .inst3Param1_o(inst3Param1Out), .inst3Param2_o(inst3Param2Out), .inst3Param3_o(inst3Param3Out), .inst3Param4_o(inst3Param4Out),
    .inst3Param1En_o(inst3Param1EnOut), .inst3Param2En_o(inst3Param2EnOut), .inst3Param3En_o(inst3Param3EnOut), .inst3Param4En_o(inst3Param4EnOut),
    .inst3Param1IsReg_o(inst3Param1IsRegOut), .inst3Param2IsReg_o(inst3Param2IsRegOut), .inst3Param3IsReg_o(inst3Param3IsRegOut), .inst3Param4IsReg_o(inst3Param4IsRegOut),
    .inst3Param1RW_o(inst3Param1RWOut), .inst3Param2RW_o(inst3Param2RWOut), .inst3Param3RW_o(inst3Param3RWOut), .inst3Param4RW_o(inst3Param4RWOut),
    //Instr 4
    .inst4Param1_o(inst4Param1Out), .inst4Param2_o(inst4Param2Out), .inst4Param3_o(inst4Param3Out), .inst4Param4_o(inst4Param4Out),
    .inst4Param1En_o(inst4Param1EnOut), .inst4Param2En_o(inst4Param2EnOut), .inst4Param3En_o(inst4Param3EnOut), .inst4Param4En_o(inst4Param4EnOut),
    .inst4Param1IsReg_o(inst4Param1IsRegOut), .inst4Param2IsReg_o(inst4Param2IsRegOut), .inst4Param3IsReg_o(inst4Param3IsRegOut), .inst4Param4IsReg_o(inst4Param4IsRegOut),
    .inst4Param1RW_o(inst4Param1RWOut), .inst4Param2RW_o(inst4Param2RWOut), .inst4Param3RW_o(inst4Param3RWOut), .inst4Param4RW_o(inst4Param4RWOut),
    //bypass outputs
    .numInst_o(numInstOut),
    .inst1Addr_o(inst1AddrOut), .inst2Addr_o(inst2AddrOut), .inst3Addr_o(inst3AddrOut), .inst4Addr_o(inst4AddrOut),
    .inst1MajId_o(inst1MajIdOut), .inst2MajId_o(inst2MajIdOut), .inst3MajId_o(inst3MajIdOut), .inst4MajId_o(inst4MajIdOut),
    .inst1MinId_o(inst1MinIdOut), .inst2MinId_o(inst2MinIdOut), .inst3MinId_o(inst3MinIdOut), .inst4MinId_o(inst4MinIdOut),
    .inst1Pid_o(inst1PidOut), .inst2Pid_o(inst2PidOut), .inst3Pid_o(inst3PidOut), .inst4Pid_o(inst4PidOut),
    .inst1Tid_o(inst1TidOut), .inst2Tid_o(inst2TidOut), .inst3Tid_o(inst3TidOut), .inst4Tid_o(inst4TidOut),
    .inst1OpCode_o(inst1OpCodeOut), .inst2OpCode_o(inst2OpCodeOut), .inst3OpCode_o(inst3OpCodeOut), .inst4OpCode_o(inst4OpCodeOut)
    );


    initial begin
    $dumpfile("FxRATTest.vcd");
    $dumpvars(0,FXRAT_Test);

    clearName1In = 0; clearName2In = 0; clearName3In = 0; clearName4In = 0;

    #5;
    clockIn = 1;
    resetIn = 1;
    #1;
    clockIn = 0;
    resetIn = 0;
    #1;


    end


endmodule