`timescale 1ns / 1ps
`define DEBUG
`define DEBUG_PRINT

/*///////////////Fetch Unit////////////////////////////
Writen by Josh "Hakaru" Cantwell - 23.01.2023
TODO: implement an address input from the branch unit and the branch prediction
*//////////////////////////////////////////////////////

module FetchUnit
#(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter cacheLineWith = 64 * 8, //cachelines are 64 bytes wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter offsetWidth = 6, //allows all 16 instructions in the cache to be addresses (for a 64 byte wide cache)
    parameter indexWidth = 8, //256 cachelines
    parameter tagWidth = fetchingAddressWidth - (indexWidth - offsetWidth), //the tag is composed of the remaining parts of the address
    parameter bundleSize = 4 * instructionWidth, //A bundle is the collection of instructions fetched per cycle.
    //Processes ID and thread ID size
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter ICacheInstance = 0
)
(
    //////Inputs:
    input wire clock_i,
    input wire reset_i,
    ////Fetch:
    //command
    input wire fetchEnable_i, cacheReset_i, fetchStall_i,
    //data
    input wire [0:PidSize-1] Pid_i,
    input wire [0:TidSize-1] Tid_i,
    input wire [0:fetchingAddressWidth-1] fetchAddress_i,
    /////Cache update (cache miss resolution):
    //command
    input wire cacheUpdate_i,
    //data
    input wire [0:fetchingAddressWidth-1] cacheUpdateAddress_i,
    input wire [0:PidSize-1] cacheUpdatePid_i,
    input wire [0:TidSize-1] cacheUpdateTid_i,
    input wire [0:instructionCounterWidth-1] missedInstMajorId_i,
    input wire [0:cacheLineWith-1] cacheUpdateLine_i,
    /////Cache update (natural writes):
    //command
    input wire naturalWriteEn_i,
    //data
    input wire [0:fetchingAddressWidth-1] naturalWriteAddress_i,
    input wire [0:cacheLineWith-1] naturalWriteLine_i,
    input wire [0:PidSize-1] naturalPid_i,
    input wire [0:TidSize-1] naturalTid_i,
    //////Outputs:    
    ////Fetch:
    //command
    output wire outputEnable_o,
    //Bundle output
    output wire [0:bundleSize-1] outputBundle_o,
    output wire [0:fetchingAddressWidth-1] bundleAddress_o,
    output wire [0:1] bundleLen_o,
    output wire [0:PidSize-1] bundlePid_o,
    output wire [0:TidSize-1] bundleTid_o,
    output wire [0:instructionCounterWidth-1] bundleStartMajId_o,
    ////Cache update:
    //command
    output wire cacheMiss_o,
    //data
    output wire [0:fetchingAddressWidth-1] missedAddress_o,
    output wire [0:instructionCounterWidth-1] missedInstMajorId_o,
    output wire [0:PidSize-1] missedPid_o,
    output wire [0:TidSize-1] missedTid_o 
);

reg [0:addressWidth-1] PC;//Program counter
wire icachePCIncEnableOut;
wire [0:2] iCachePCIncValOut;

//L1i Cache
L1I_Cache #(
    .fetchingAddressWidth(fetchingAddressWidth), .cacheLineWith(cacheLineWith), 
    .instructionWidth(instructionWidth), .offsetWidth(offsetWidth), 
    .indexWidth(indexWidth), .tagWidth(tagWidth), 
    .PidSize(PidSize), .TidSize(TidSize), 
    .instructionCounterWidth(instructionCounterWidth)
)
l1ICache
(
    .clock_i(clock_i), .reset_i(reset_i),
    //Fetch in 
    .fetchEnable_i(fetchEnable_i), .cacheReset_i(cacheReset_i), .fetchStall_i(fetchStall_i), 
    .Pid_i(Pid_i), .Tid_i(Tid_i), .fetchAddress_i(PC), 
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

always @(posedge clock_i)
begin



    if(icachePCIncEnableOut)
    begin//When the I cache can't do a full bundle/group it will tell us how many to increment by
        PC <= PC + iCachePCIncValOut;
    end
    else
    begin//otherwise increment the PC by an entire bundle
        PC <= PC + bundleSize;
    end

end


endmodule