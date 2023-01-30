`timescale 1ns / 1ps
`define DEBUG
`define DEBUG_PRINT

/*///////////////Bundle Parser/////////////////
Written by Josh "Hakaru" Cantwell - 23.01.2023

This hardware module takes the fetched bundle from the fetch unit and looks at how man instructions
are in the bundle, it then assigns/cracks the instructions out into one of the decoders.

A bundle can be uo to 4 instructions (16) bytes wide which is then parsed off to one of the 4 decoders

TODO: Implement the is64 bit functionality. This requires the is64bit state being passed from the fetch unit. 
TODO: Investigate is the PIDs and TIDS need to be handled indivilualy.
*///////////////////////////////////////////////

module BundleParser
#(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter bundleSize = 4 * instructionWidth, //A bundle is the collection of instructions fetched per cycle.
    parameter PidSize = 32, parameter TidSize = 64,
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter BundlParserInstance = 0
)
(
    ///inputs
    //command
    input wire clock_i,
`ifdef DEBUG_PRINT 
    input wire reset_i,
`endif
    input wire enable_i,
    //Bundle output
    input wire [0:bundleSize-1] bundle_i,
    input wire [0:addressWidth-1] bundleAddress_i,
    input wire [0:1] bundleLen_i,
    input wire [0:PidSize-1] bundlePid_i,
    input wire [0:TidSize-1] bundleTid_i,
    input wire [0:instructionCounterWidth-1] bundleStartMajId_i,
    ///outputs - one for each decoder
    //command
    output reg enable1_o, enable2_o, enable3_o, enable4_o,
    //data/instruction
    output reg [0:instructionWidth-1] instr1_o, instr2_o, instr3_o, instr4_o,
    output reg [0:addressWidth-1] addr1_o, addr2_o, addr3_o, addr4_o,
    output reg is64b1_o, is64b2_o, is64b3_o, is64b4_o, 
    output reg [0:PidSize-1] pid1_o, pid2_o, pid3_o, pid4_o, 
    output reg [0:TidSize-1] tid1_o, tid2_o, tid3_o, tid4_o, 
    output reg [0:instructionCounterWidth-1] majID1_o, majID2_o, majID3_o, majID4_o
);


`ifdef DEBUG_PRINT
integer debugFID;
`endif

always @(posedge clock_i)
begin

    `ifdef DEBUG_PRINT
    if(reset_i)
    begin
        case(BundlParserInstance)//If we have bundle parser, they each get different files. The second number indicates the decoder# log file.
        0: begin 
            debugFID = $fopen("BundleParser0.log", "w");
        end
        1: begin 
            debugFID = $fopen("BundleParser1.log", "w");
        end
        2: begin 
            debugFID = $fopen("BundleParser2.log", "w");
        end
        3: begin 
            debugFID = $fopen("BundleParser3.log", "w");
        end
        4: begin 
            debugFID = $fopen("BundleParser4.log", "w");
        end
        4: begin 
            debugFID = $fopen("BundleParser5.log", "w");
        end
        endcase
    end
    else `endif if(enable_i)
    begin
        `ifdef DEBUG $display("Bundle Parser %d recieved %d instruction(s)", BundlParserInstance, bundleLen_i+1); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "Bundle Parser %d recieved %d instruction(s)", BundlParserInstance, bundleLen_i+1); `endif
        case(bundleLen_i)
        2'b00: begin //Bundle has 1 instruction
            enable1_o <= 1; enable2_o <= 0; enable3_o <= 0; enable4_o <= 0;
            instr1_o <= bundle_i[(0*instructionWidth)+:instructionWidth];
            addr1_o <= bundleAddress_i + 0;
            is64b1_o <= 1;
            pid1_o <= bundlePid_i;
            tid1_o <= bundleTid_i;
            majID1_o <= bundleStartMajId_i + 0;
        end
        2'b01: begin //Bundle has 2 instructions
            enable1_o <= 1; enable2_o <= 1; enable3_o <= 0; enable4_o <= 0;
            instr1_o <= bundle_i[(0*instructionWidth)+:instructionWidth];
            instr2_o <= bundle_i[(1*instructionWidth)+:instructionWidth];
            addr1_o <= bundleAddress_i + 0; addr2_o <= bundleAddress_i + 4;
            is64b1_o <= 1; is64b2_o <= 1;
            pid1_o <= bundlePid_i; pid2_o <= bundlePid_i;
            tid1_o <= bundleTid_i; tid2_o <= bundleTid_i;
            majID1_o <= bundleStartMajId_i + 0; majID2_o <= bundleStartMajId_i + 1;
        end
        2'b10: begin //Bundle has 3 instructions
            enable1_o <= 1; enable2_o <= 1; enable3_o <= 1; enable4_o <= 0;
            instr1_o <= bundle_i[(0*instructionWidth)+:instructionWidth];
            instr2_o <= bundle_i[(1*instructionWidth)+:instructionWidth];
            instr3_o <= bundle_i[(2*instructionWidth)+:instructionWidth];
            addr1_o <= bundleAddress_i + 0; addr2_o <= bundleAddress_i + 4; addr3_o <= bundleAddress_i + 8;
            is64b1_o <= 1; is64b2_o <= 1; is64b3_o <= 1;
            pid1_o <= bundlePid_i; pid2_o <= bundlePid_i; pid3_o <= bundlePid_i;
            tid1_o <= bundleTid_i; tid2_o <= bundleTid_i; tid3_o <= bundleTid_i;
            majID1_o <= bundleStartMajId_i + 0; majID2_o <= bundleStartMajId_i + 1; majID3_o <= bundleStartMajId_i + 2;
        end
        2'b11: begin //Bundle has 4 instructions
            enable1_o <= 1; enable2_o <= 1; enable3_o <= 1; enable4_o <= 1;
            instr1_o <= bundle_i[(0*instructionWidth)+:instructionWidth];
            instr2_o <= bundle_i[(1*instructionWidth)+:instructionWidth];
            instr3_o <= bundle_i[(2*instructionWidth)+:instructionWidth];
            instr4_o <= bundle_i[(3*instructionWidth)+:instructionWidth];
            addr1_o <= bundleAddress_i + 0; addr2_o <= bundleAddress_i + 4;
            addr3_o <= bundleAddress_i + 8; addr4_o <= bundleAddress_i + 12;
            is64b1_o <= 1; is64b2_o <= 1; is64b3_o <= 1; is64b4_o <= 1;
            pid1_o <= bundlePid_i; pid2_o <= bundlePid_i; pid3_o <= bundlePid_i; pid4_o <= bundlePid_i;
            tid1_o <= bundleTid_i; tid2_o <= bundleTid_i; tid3_o <= bundleTid_i; tid4_o <= bundleTid_i;
            majID1_o <= bundleStartMajId_i + 0; majID2_o <= bundleStartMajId_i + 1; majID3_o <= bundleStartMajId_i + 2; majID4_o <= bundleStartMajId_i + 3;
        end
        endcase
    end
    else
    begin
        `ifdef DEBUG $display("Bundle Parser %d not enabled or in reset", BundlParserInstance); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "Bundle Parser %d not enabled or in reset", BundlParserInstance); `endif
        enable1_o <= 0; enable2_o <= 0; enable3_o <= 0; enable4_o <= 0;
    end
end

endmodule