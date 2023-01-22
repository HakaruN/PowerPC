`timescale 1ns / 1ps
`include "../../Modules/Fetch/FetchUnit.v"

module L1ICacheTest #(
    parameter fetchingAddressWidth = 64, //addresses are 64 bits wide
    parameter cacheLineWith = 64 * 8, //cachelines are 64 bytes wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter offsetWidth = 6, //allows all 16 instructions in the cache to be addresses (for a 64 byte wide cache)
    parameter indexWidth = 8, //256 cachelines
    parameter tagWidth = fetchingAddressWidth - indexWidth - offsetWidth, //the tag is composed of the remaining parts of the address
    parameter bundleSize = 4 * instructionWidth, //A bundle is the collection of instructions fetched per cycle.
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
reg [0:PidSize-1] cacheUpdatePidIn;
reg [0:TidSize-1] cacheUpdateTidIn;
reg [0:cacheLineWith-1] cacheUpdateLineIn1;
//Natural writes in - used to write data to the cache during non cache-miss situations
reg naturalWriteEnIn;
reg [0:fetchingAddressWidth-1] naturalWriteAddressIn;
reg [0:cacheLineWith-1] naturalWriteLineIn;
reg [0:PidSize-1] naturalPidIn;
reg [0:TidSize-1] naturalTidIn;
//Fetch out
wire outputEnableOut;
//Bundle output
wire [0:bundleSize-1] outputBundleOut;
wire [0:fetchingAddressWidth-1] bundleAddressOut;
wire [0:cacheLineWith-1] bundleLenOut;
wire [0:PidSize-1] bundlePidOut;
wire [0:TidSize-1] bundleTidOut;
wire [0:instructionCounterWidth-1] bundleStartMajIdOut;
//Update out
wire cacheMissOut;
wire [0:fetchingAddressWidth-1] missedAddressOut;
wire [0:instructionCounterWidth-1] missedInstMajorIdOut;
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
    .cacheUpdateLine1_i(cacheUpdateLineIn1),
    //Natural writes in - used to write data to the cache during non cache-miss situations
    .naturalWriteEn_i(naturalWriteEnIn),
    .naturalWriteAddress_i(naturalWriteAddressIn),
    .naturalWriteLine_i(naturalWriteLineIn),
    .naturalPid_i(naturalPidIn),
    .naturalTid_i(naturalTidIn),
    //Fetch out
    .outputEnable_o(outputEnableOut), .outputBundle_o(outputBundleOut),
    .bundleAddress_o(bundleAddressOut),.bundleLen_o(bundleLenOut),
    .bundlePid_o(bundlePidOut),.bundleTid_o(bundleTidOut),
    .bundleStartMajId_o(bundleStartMajIdOut),
    //Update out
    .cacheMiss_o(cacheMissOut), .missedAddress_o(missedAddressOut),
    .missedInstMajorId_o(missedInstMajorIdOut),
    .missedPid_o(missedPidOut), .missedTid_o(missedTidOut)
);

reg [0:7] loopCtr;

initial begin
    $dumpfile("fetchTest.vcd");
    $dumpvars(0,l1ICache);
    //init vars
    clockIn = 0; fetchEnableIn = 0;
    resetIn = 0; fetchStallIn = 0;
    PidIn = 0; TidIn = 0;
    OffsetIn = 0; IndexIn = 0;
    TagIn = 0;
    //update/resolve miss
    cacheUpdateIn = 0; updateAddressIn = 0; 
    cacheUpdateLineIn1 = 0;
    cacheUpdatePidIn = 0; cacheUpdateTidIn = 0;
    #2;

    //reset
    resetIn = 1; clockIn = 1;
    #1;
    resetIn = 0; clockIn = 0;
    #1;

    //Start writing data to the cahe
    naturalWriteEnIn = 1;
    naturalWriteAddressIn = 0;
    naturalPidIn = 0; naturalTidIn = 0;
    for(loopCtr = 0; loopCtr < 10; loopCtr = loopCtr + 1)//write 10 cache lines
    begin
        $display("asd");
        naturalWriteLineIn = 512'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_AAAA_BBBB;
        naturalWriteAddressIn = loopCtr * 64;
        clockIn = 1;
        #1;
        clockIn = 0;
        #1;
    end
    naturalWriteEnIn = 0;

    //Start fetching
    TagIn = 0; IndexIn = 0; OffsetIn = 0;//Start fetching at addr 0
    

    fetchEnableIn = 1;
    for(loopCtr = 0; loopCtr < 10; loopCtr = loopCtr + 1)
    begin
        
        clockIn = 1;
        #1;
        clockIn = 0; 
        #1; 
    end
    fetchEnableIn = 0;

/*
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
    TagIn = 0; IndexIn = 0;//Start fetching at addr 0
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
    updateAddressIn = {TagIn, IndexIn, OffsetIn}; 
    cacheUpdateLineIn1 = 512'hAAAAAAAA_BBBBBBBB_CCCCCCCC_DDDDDDDD__EEEEEEEE_FFFFFFFF_AAAAAAAA_BBBBBBBB__CCCCCCCC_DDDDDDDD_EEEEEEEE_FFFFFFFF__AAAAAAAA_BBBBBBBB_CCCCCCCC_DDDDDDDD;
    cacheUpdatePidIn = 0; cacheUpdateTidIn = 0;
    clockIn = 1;
    #1;
    cacheUpdateIn = 0;
    clockIn = 0;
    #1;

    //Start fetching again
    clockIn = 1; fetchEnableIn = 1;
    TagIn = 0; IndexIn = 0; OffsetIn = OffsetIn + 4;//Start fetching at addr 0
    #1;
    clockIn = 0;
    #1;
    clockIn = 1;
    TagIn = 0; IndexIn = 0; OffsetIn = OffsetIn + 8;//Start fetching at addr 0
    #1;
    clockIn = 0;
    #1;
    clockIn = 1;
    TagIn = 0; IndexIn = 0; OffsetIn = OffsetIn + 8;//Start fetching at addr 0
    #1;
    clockIn = 0;
    #1;
    clockIn = 1;
    TagIn = 0; IndexIn = 0; OffsetIn = OffsetIn + 8;//Start fetching at addr 0
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
    */
end

endmodule