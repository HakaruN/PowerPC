`timescale 1ns / 1ps
`define DEBUG
`define DEBUG_PRINT
`include "ICacheUnit.v"
/*///////////////Fetch Unit////////////////////////////
Writen by Josh "Hakaru" Cantwell - 23.01.2023
This is the first stage in the fetch unit, it holds the program counter, the process ID reg and the program ID reg.
This stage recieves the inputs from branches if they are supplied and modifies the program counter to begin fetching at the new address
It also is responsible for updating the program counter during normal operation.

TODO: Add the is64bit reg, or more likely add is and the pid and tid regs to a control unit.
*//////////////////////////////////////////////////////

module FetchUnit
#(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter cacheLineWith = 64 * 8, //cachelines are 64 bytes wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter offsetWidth = 6, //allows all 16 instructions in the cache to be addresses (for a 64 byte wide cache)
    parameter indexWidth = 8, //256 cachelines
    parameter tagWidth = addressWidth - (indexWidth - offsetWidth), //the tag is composed of the remaining parts of the address
    parameter bundleSize = 4 * instructionWidth, //A bundle is the collection of instructions fetched per cycle.
    //Processes ID and thread ID size
    parameter PidSize = 32, parameter TidSize = 64,
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter fetchUnitInstance = 0,
    parameter resetVector = 0
)
(
    //////Inputs:
    input wire clock_i,
    input wire reset_i,
    ////Fetch:
    //command
    input wire fetchEnable_i, cacheReset_i, fetchStall_i,
    //data
    input wire [0:addressWidth-1] fetchAddress_i,

    /////Cache update (cache miss resolution):
    //command
    input wire cacheUpdate_i,
    //data
    input wire [0:addressWidth-1] cacheUpdateAddress_i,
    input wire [0:PidSize-1] cacheUpdatePid_i,
    input wire [0:TidSize-1] cacheUpdateTid_i,
    input wire [0:instructionCounterWidth-1] missedInstMajorId_i,
    input wire [0:cacheLineWith-1] cacheUpdateLine_i,

    /////Cache update (natural writes):
    //command
    input wire naturalWriteEn_i,
    //data
    input wire [0:addressWidth-1] naturalWriteAddress_i,
    input wire [0:cacheLineWith-1] naturalWriteLine_i,
    input wire [0:PidSize-1] naturalPid_i,
    input wire [0:TidSize-1] naturalTid_i,
    //////PID and TID updates
    input wire pidWriteEn_i, tidWriteEn_i,
    input wire [0:PidSize-1] pid_i,
    input wire [0:TidSize-1] tid_i,

    //////Outputs:    
    ////Fetch:
    //command
    output wire outputEnable_o,
    //Bundle output
    output wire [0:bundleSize-1] outputBundle_o,
    output wire [0:addressWidth-1] bundleAddress_o,
    output wire [0:1] bundleLen_o,
    output wire [0:PidSize-1] bundlePid_o,
    output wire [0:TidSize-1] bundleTid_o,
    output wire [0:instructionCounterWidth-1] bundleStartMajId_o,
    ////Cache update:
    //command
    output wire cacheMiss_o,
    //data
    output wire [0:addressWidth-1] missedAddress_o,
    output wire [0:instructionCounterWidth-1] missedInstMajorId_o,
    output wire [0:PidSize-1] missedPid_o,
    output wire [0:TidSize-1] missedTid_o 
);

reg [0:addressWidth-1] PC;//Program counter
reg [32+:PidSize] PID; reg [0:TidSize-1] TIR;//The pid and tid of the program
wire icachePCIncEnableOut;
wire [0:2] iCachePCIncValOut;

//L1i Cache
L1I_Cache #(
    .addressWidth(addressWidth), .cacheLineWith(cacheLineWith), 
    .instructionWidth(instructionWidth), .offsetWidth(offsetWidth), 
    .indexWidth(indexWidth), .tagWidth(tagWidth), 
    .PidSize(PidSize), .TidSize(TidSize), 
    .instructionCounterWidth(instructionCounterWidth)
)
l1ICache
(
    .clock_i(clock_i),
    //Fetch in 
    .fetchEnable_i(fetchEnable_i), .cacheReset_i(cacheReset_i), .fetchStall_i(fetchStall_i), 
    .Pid_i(PID), .Tid_i(TIR), .fetchAddress_i(PC), 
    //Update in
    .cacheUpdate_i(cacheUpdate_i), .cacheUpdateAddress_i(cacheUpdateAddress_i), 
    .cacheUpdatePid_i(cacheUpdatePid_i), .cacheUpdateTid_i(cacheUpdateTid_i),
    .missedInstMajorId_i(missedInstMajorId_i), .cacheUpdateLine_i(cacheUpdateLine_i),

    //Natural writes in - used to write data to the cache during non cache-miss situations
    .naturalWriteEn_i(naturalWriteEn_i),
    .naturalWriteAddress_i(naturalWriteAddress_i),
    .naturalWriteLine_i(naturalWriteLine_i),
    .naturalPid_i(naturalPid_i),
    .naturalTid_i(naturalTid_i),

    //PC updates
    .icachePCIncEnable_o(icachePCIncEnableOut),
    .iCachePCIncVal_o(iCachePCIncValOut),
    //Pid and Tid updates

    //Fetch out
    .outputEnable_o(outputEnable_o), .outputBundle_o(outputBundle_o),
    .bundleAddress_o(bundleAddress_o),.bundleLen_o(bundleLen_o),
    .bundlePid_o(bundlePid_o), .bundleTid_o(bundleTid_o),
    .bundleStartMajId_o(bundleStartMajId_o),
    //Update out
    .cacheMiss_o(cacheMiss_o), .missedAddress_o(missedAddress_o),
    .missedInstMajorId_o(missedInstMajorId_o),
    .missedPid_o(missedPid_o), .missedTid_o(missedTid_o)
);

//File handle to the debug output
`ifdef DEBUG_PRINT
integer debugFID;
`endif

always @(posedge clock_i)
begin
    if(reset_i)//Reset
    begin
        `ifdef DEBUG_PRINT
        case(fetchUnitInstance)//If we have multiple fetch units, they each get different files. The second number indicates the decoder# log file.
        0: begin 
            debugFID = $fopen("FetchUnit0.log", "w");
        end
        1: begin 
            debugFID = $fopen("FetchUnit1.log", "w");
        end
        2: begin 
            debugFID = $fopen("FetchUnit2.log", "w");
        end
        3: begin 
            debugFID = $fopen("FetchUnit3.log", "w");
        end
        4: begin 
            debugFID = $fopen("FetchUnit4.log", "w");
        end
        5: begin 
            debugFID = $fopen("FetchUnit5.log", "w");
        end
        6: begin 
            debugFID = $fopen("FetchUnit6.log", "w");
        end
        7: begin 
            debugFID = $fopen("FetchUnit7.log", "w");
        end
        endcase
        `endif
        `ifdef DEBUG $display("FetchUnit: %d: Resetting", fetchUnitInstance); `endif  
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FetchUnit: %d: Resetting", fetchUnitInstance); `endif  

        //Reset the PC and ids
        PC <= resetVector;
        PID <= 0; TID <= 0;
    end
    else//Not resetting
    begin        
        if(icachePCIncEnableOut)
        begin//When the I cache can't fetch a full bundle/group it will tell us how many to increment the PC by.
            PC <= PC + iCachePCIncValOut;
        end
        else
        begin//otherwise increment the PC by an entire bundle
            PC <= PC + bundleSize;
        end

        //Allow the pid and tid to be updated
        if(pidWriteEn_i)
        begin
            `ifdef DEBUG $display(); `endif
            `ifdef DEBUG_PRINT $fdisplay(, ); `endif
            PID <= pid_i;
        end
        if(tidWriteEn_i)
        begin
            TID <= tid_i;
        end
    end
end
endmodule