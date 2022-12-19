`timescale 1ns / 1ps
`include "L1I-Cache.v"

module L1ICacheTest #(
    parameter fetchingAddressWidth = 64, //addresses are 64 bits wide
    parameter cacheLineWith = 64 * 8, //cachelines are 64 bytes wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter offsetWidth = 6, //allows all 16 instructions in the cache to be addresses (for a 64 byte wide cache)
    parameter indexWidth = 8, //256 cachelines
    parameter tagWidth = fetchingAddressWidth - indexWidth - offsetWidth, //the tag is composed of the remaining parts of the address
    //Processes ID and thread ID size
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64// 64 bit counter to uniquly identify instructions
)
(

);

//Fetch in
reg clockIn, fetchEnableIn, resetIn, fetchStallIn;
reg [0:PidSize-1] PidIn; reg [0:TidSize-1] TidIn;
reg [0:offsetWidth-1] OffsetIn; 
reg [0:indexWidth-1] IndexIn;
reg [0:tagWidth-1] TagIn;
//Update in
reg cacheUpdateIn;
reg [0:fetchingAddressWidth-1] updateAddressIn;
reg [0:cacheLineWith-1] cacheUpdateLineIn;
reg [0:PidSize-1] cacheUpdatePidIn;
reg [0:TidSize-1] cacheUpdateTidIn;
//Fetch out
wire enableOut;
wire [0:instructionWidth-1] fetchedInstructionOut;
wire [0:fetchingAddressWidth-1] fetchedAddressOut;
//wire [0:offsetWidth-1] fetchedOffset;
//wire [0:indexWidth-1] fetchedIndex;
//wire [0:tagWidth-1] fetchedTag;
wire [0:PidSize-1] fetchedPid;
wire [0:TidSize-1] fetchedTid;
wire [0:instructionCounterWidth-1] fetchedInstMajorId;
//Update out
wire cacheMissOut;
wire [0:fetchingAddressWidth-1] missedAddressOut;
wire [0:instructionCounterWidth-1] missedInstMajorId;
wire [0:PidSize-1] missedPidOut;
wire [0:TidSize-1] missedTidOut;

L1I_Cache #(
    .fetchingAddressWidth(fetchingAddressWidth), .cacheLineWith(cacheLineWith), 
    .instructionWidth(instructionWidth), .offsetWidth(offsetWidth), 
    .indexWidth(indexWidth), .tagWidth(tagWidth), 
    .PidSize(PidSize), .TidSize(TidSize), 
    .instructionCounterWidth(instructionCounterWidth)
)
l1ICache
(
    .clock_i(clockIn),
    //Fetch in 
    .fetchEnable_i(fetchEnableIn), .cacheReset_i(resetIn), .fetchStall_i(fetchStallIn), 
    .Pid_i(PidIn), .Tid_i(TidIn), .offset_i(OffsetIn), .index_i(IndexIn), .tag_i(TagIn), 
    //Update in
    .cacheUpdate_i(cacheUpdateIn), .cacheUpdateAddress_i(updateAddressIn), 
    .cacheUpdatePid_i(cacheUpdatePidIn), .cacheUpdateTid_i(cacheUpdateTidIn),
    .cacheUpdateLine_i(cacheUpdateLineIn),
    //Fetch out
    .fetchEnable_o(enableOut), .fetchedInstruction_o(fetchedInstructionOut), 

    .fetchedAddress_o(fetchedAddressOut),
    .fetchedPid_o(fetchedPid), .fetchedTid_o(fetchedTid), .fetchedInstMajorId_o(fetchedInstMajorId),
    //Update out
    .cacheMiss_o(cacheMissOut), .missedAddress_o(missedAddressOut),
    .missedInstMajorId_o(missedInstMajorId),
    .missedPid_o(missedPidOut), .missedTid_o(missedTidOut)
);

initial begin
    $dumpfile("FetchTest.vcd");
    $dumpvars(0,l1ICache);
    //init vars
    clockIn = 0; fetchEnableIn = 0;
    resetIn = 0; fetchStallIn = 0;
    PidIn = 0; TidIn = 0;
    OffsetIn = 0; IndexIn = 0;
    TagIn = 0;
    //update/resolve miss
    cacheUpdateIn = 0;
    updateAddressIn = 0; cacheUpdateLineIn = 0;
    cacheUpdatePidIn = 0; cacheUpdateTidIn = 0;
    #2;

    //reset
    resetIn = 1; clockIn = 1;
    #1;
    resetIn = 0; clockIn = 0;
    #1;

    //Start fetching
    clockIn = 1; fetchEnableIn = 1;
    TagIn = 0; IndexIn = 0; OffsetIn = 0;//Start fetching at addr 0
    #1;
    clockIn = 0; fetchEnableIn = 0;
    #1;

    //read from memories and check if inst already exists in buffer
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;

    //Check for hit or miss
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;

    //Start fetching again to test correct stall behaviour
    clockIn = 1; fetchEnableIn = 1;
    TagIn = 0; IndexIn = 0; OffsetIn = 4;//Start fetching at addr 0
    #1;
    clockIn = 0; fetchEnableIn = 0;
    #1;

    //read from memories and check if inst already exists in buffer
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;

    //Check for hit or miss
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;

    //clear the stall/miss
    cacheUpdateIn = 1;
    OffsetIn = 0;
    updateAddressIn = {TagIn, IndexIn, OffsetIn}; cacheUpdateLineIn = 102345;
    cacheUpdatePidIn = 0; cacheUpdateTidIn = 0;
    clockIn = 1;
    #1;
    cacheUpdateIn = 0;
    clockIn = 0;
    #1;

    //Start fetching again
    clockIn = 1; fetchEnableIn = 1;
    TagIn = 0; IndexIn = 0; OffsetIn = 4;//Start fetching at addr 0
    #1;
    clockIn = 0;
    #1;
    clockIn = 1;
    TagIn = 0; IndexIn = 0; OffsetIn = 8;//Start fetching at addr 0
    #1;
    clockIn = 0;
    #1;
    clockIn = 1;
    TagIn = 0; IndexIn = 0; OffsetIn = 12;//Start fetching at addr 0
    #1;
    clockIn = 0;
    #1;
    clockIn = 1;
    TagIn = 0; IndexIn = 0; OffsetIn = 16;//Start fetching at addr 0
    #1;
    clockIn = 0; fetchEnableIn = 0;
    #1;
    
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
end

endmodule