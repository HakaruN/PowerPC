`timescale 1ns / 1ps
`include "../../../Modules/Decode/BundleParser.v"
`define DEBUG_PRINT
`define DEBUG

module BundleParserTest #(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter bundleSize = 4 * instructionWidth, //A bundle is the collection of instructions fetched per cycle.
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter BundlParserInstance = 0
)
(

);

    reg clockIn;
`ifdef DEBUG_PRINT 
    reg resetIn;
`endif
    reg enableIn;
    //Bundle output
    reg [0:bundleSize-1] bundleIn;
    reg [0:addressWidth-1] bundleAddressIn;
    reg [0:1] bundleLenIn;
    reg [0:PidSize-1] bundlePidIn;
    reg [0:TidSize-1] bundleTidIn;
    reg [0:instructionCounterWidth-1] bundleStartMajIdIn;
    ///outputs - one for each decoder
    //command
    wire enable1Out, enable2Out, enable3Out, enable4Out;
    //data/instruction
    wire [0:instructionWidth-1] instr1Out, instr2Out, instr3Out, instr4Out;
    wire [0:addressWidth-1] addr1Out, addr2Out, addr3Out, addr4Out;
    wire is64b1Out, is64b2Out, is64b3Out, is64b4Out;
    wire [0:PidSize-1] pid1Out, pid2Out, pid3Out, pid4Out;
    wire [0:TidSize-1] tid1Out, tid2Out, tid3Out, tid4Out;
    wire [0:instructionCounterWidth-1] majID1Out, majID2Out, majID3Out, majID4Out;

    BundleParser #(
    .addressWidth(addressWidth),
    .instructionWidth(instructionWidth),
    .bundleSize(bundleSize),
    .PidSize(PidSize), .TidSize(TidSize),
    .instructionCounterWidth(instructionCounterWidth),
    .BundlParserInstance(BundlParserInstance)
    )
    bundleParser
    (
    .clock_i(clockIn),
`ifdef DEBUG_PRINT 
    .reset_i(resetIn),
`endif
    .enable_i(enableIn),
    .bundle_i(bundleIn),
    .bundleAddress_i(bundleAddressIn),
    .bundleLen_i(bundleLenIn),
    .bundlePid_i(bundlePidIn),
    .bundleTid_i(bundleTidIn),
    .bundleStartMajId_i(bundleStartMajIdIn),
    .enable1_o(enable1Out), .enable2_o(enable2Out), .enable3_o(enable3Out), .enable4_o(enable4Out),
    .instr1_o(instr1Out), .instr2_o(instr2Out), .instr3_o(instr3Out), .instr4_o(instr4Out),
    .addr1_o(addr1Out), .addr2_o(addr2Out), .addr3_o(addr3Out), .addr4_o(addr4Out),
    .is64b1_o(is64b1Out), .is64b2_o(is64b2Out), .is64b3_o(is64b3Out), .is64b4_o(is64b4Out), 
    .pid1_o(pid1Out), .pid2_o(pid2Out), .pid3_o(pid3Out), .pid4_o(pid4Out), 
    .tid1_o(tid4Out), .tid2_o(tid2Out), .tid3_o(tid3Out), .tid4_o(tid4Out), 
    .majID1_o(majID1Out), .majID2_o(majID2Out), .majID3_o(majID3Out), .majID4_o(majID4Out)
    );


    initial begin
        $dumpfile("bundleTest.vcd");
        $dumpvars(0,bundleParser);
        //Init vars
        clockIn = 0; resetIn = 0; enableIn = 0;
        bundleIn = 0; bundleAddressIn = 0; bundleLenIn = 0;
        bundlePidIn = 0; bundleTidIn = 0; bundleStartMajIdIn = 0;

        //Reset (Just brings up the log file when DEBUG_PRINT is defined)
        clockIn = 1; resetIn = 1;
        #1;
        clockIn = 0; resetIn = 0;
        #1;

        //Supply a full bundle and see if it gets outputted correctly
        enableIn = 1;
        bundleIn = 128'hAAAAAAAA_BBBBBBBB_CCCCCCCC_DDDDDDDD;
        bundleAddressIn = 0; bundleLenIn = 2'b11;
        bundlePidIn = 0; bundleTidIn = 0; bundleStartMajIdIn = 0;
        clockIn = 1;
        #1;
        clockIn = 0;
        #1;
        if(enable1Out + enable2Out + enable3Out + enable4Out == 4)
            $display("Test pass");
        else
            $display("Test fail");


        //Supply a 3 inst bundle and see if it gets outputted correctly
        enableIn = 1;
        bundleIn = 128'hAAAAAAAA_BBBBBBBB_CCCCCCCC_DDDDDDDD;
        bundleAddressIn = 16; bundleLenIn = 2'b10;
        bundlePidIn = 0; bundleTidIn = 0; bundleStartMajIdIn = 4;
        clockIn = 1;
        #1;
        clockIn = 0;
        #1;
        if(enable1Out + enable2Out + enable3Out + enable4Out == 3)
            $display("Test pass");
        else
            $display("Test fail");

        //Supply a 2 inst bundle and see if it gets outputted correctly
        enableIn = 1;
        bundleIn = 128'hAAAAAAAA_BBBBBBBB_CCCCCCCC_DDDDDDDD;
        bundleAddressIn = 28; bundleLenIn = 2'b01;
        bundlePidIn = 0; bundleTidIn = 0; bundleStartMajIdIn = 7;
        clockIn = 1;
        #1;
        clockIn = 0;
        #1;
        if(enable1Out + enable2Out + enable3Out + enable4Out == 2)
            $display("Test pass");
        else
            $display("Test fail");

        //Supply a 1 inst bundle and see if it gets outputted correctly
        enableIn = 1;
        bundleIn = 128'hAAAAAAAA_BBBBBBBB_CCCCCCCC_DDDDDDDD;
        bundleAddressIn = 36; bundleLenIn = 2'b00;
        bundlePidIn = 0; bundleTidIn = 0; bundleStartMajIdIn = 9;
        clockIn = 1;
        #1;
        clockIn = 0;
        #1;
        if(enable1Out + enable2Out + enable3Out + enable4Out == 1)
            $display("Test pass");
        else
            $display("Test fail");

        //Supply no bundle and see if it gets outputted correctly
        enableIn = 0;
        bundleIn = 128'hAAAAAAAA_BBBBBBBB_CCCCCCCC_DDDDDDDD;
        bundleAddressIn = 36; bundleLenIn = 2'b11;
        bundlePidIn = 0; bundleTidIn = 0; bundleStartMajIdIn = 9;
        clockIn = 1;
        #1;
        clockIn = 0;
        #1;
        if(enable1Out + enable2Out + enable3Out + enable4Out == 0)
            $display("Test pass");
        else
            $display("Test fail");

    end

endmodule