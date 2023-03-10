`timescale 1ns / 1ps
`define DEBUG
`define DEBUG_PRINT
/*/////////L1 instruction cache/////////////
Writen by Josh "Hakaru" Cantwell - 16.12.2022

TODO: Implement an error condition for fetch alignment errors since they are being detected but nothing is done.
Also remove the PID and TID lines from the cache and put the table in the control unit.

//////Signal groups
The cache has a 3 cycle latency and has 6 groups of signals, one pair of sinal groups are inputs and the other pair are outputs.
The signal groups perform one of two tasks: Fetching and cache miss resolution. These are described below:

1) Fetch input
This group of signals is used as the input to the cache/fetch unit for the purpose of fetching an instruction. These consist of control signals
and an address to fetch among other things.

2) PC value update
This group of signals tells the begining of the fetch unit how many bytes/instructions to advance by. During fetch a variable number of instructions may be fetched
therefore the fetch unit must know how many instructions were fetched in order to advance the PC by that number of instructions.

2) Natural write
This group of signals is responsible for recieving new instructions into the cache. This is used by the prefetched to populate the cache.

3) Fetch output
This signal group is used for outputting the fetched instruction to the decode unit. It includes control signals, address, instruction ID,
fetched instruction(s) and more.

3) Miss output
This signal group is responsble for telling the core/memory hierarchy about a cache miss, essentialy it's a request for the cache to be
reloaded with a new cacheline therefore resolving the cache miss. This groups includes control signals and an address of the missed instruction
plus more.

4) Miss input
This signal groups is responsible for recieving the new cacheline from the core/memory hierarchy therefore allowing the cache miss to be resolved.
This groups of signals includes an control signals, address, and the missing cacheline etc.

//////Operation
The I-Cache operates in 3 stages with 4 blocks of hardware. It can fetch up to 4 instructions per cycle, instructions are grouped into bundles of 4 instructions. These groups are
4-byte aligned in memory which is how their position and size is located. The Cache can fetch a single group/bundle per cycle. If a branch is made which causes fetching to begin at
an address part way though a group, the rest of the group is fetched causing less than the maximum possible number of instructions to be fetched for this cycle, this however means that
the PC is then advanced to the boundary of the next group meaning for following cycles the maximum number of instructions per cycle will be fetched.

The operation of the hardware in the cache are described below:

///Reset
During startup or re-initialisation/cache clear the fetch unit has a reser behaviour/hardware block.
This hardware initialises the cache's valid bits for each cacheline to zero, resets the instruction ID counter to zero and dissables the outputs.


///Natural writes
Natural writes are writes to the I-Cache that can happen at any time, this is used for prefetching operations as it does not effect the output of the 
fetch unit (unline cache miss writes).

///PC value update (Cycle 1)
As the PC is located in the pevious stage (Fetch stage 1) and not in the I-Cache, it must be told how much to advance by. This is determined by how many instructions are being fetched this cycle.

///Fetch in (cylce 1)
During normal operation when the core is running and instructions are being fetched, this hardware is recieving fetch requests from the core.
It takes the index from the address provided and uses it as the input of the tag and cache memory of which will output the data in the next cycle.
It also takes the other provided information used during the next cycles and puts it in the bypass buffers which are buffers used to hold data for
a cycle where not needed in the current cycle.

///Buffer reload check(cyle 2)
During this cycle, the fetched cacheline's address is inspected and if it matches the address from the previous cycle then there is no need to reload
the cacheline buffer from the memory which saves a trip to the cache memory block therefore saving power. If the previous cycle accessed a different cacheline
then the buffer is reloaded from the cache. As each cacheline holds 16 instructions, I cache only has to be read once per 16 instructions and is idle of the remaining 15.

///Hit/Miss check (cycle 3)
During this cycle, the tag from the fetch buffer is known to contain the correct line and the tag from the tag memory for the associated instruction has been fetched,
this can now be used to check against the supplied tag in order to detect a cache hit or miss. On cache hit the instruction and associated data is ouputted from the fetch
unit for the decoders input. On a cache miss the fetch output is dissabled and the Miss output is enabled to tell the core that it needs to grab the missing cacheline.

///Miss resolution
During this cycle, the missed cacheline is proveded to the fetch unit (Actually both the missed cacheline and the next cacheline after it are writen into the cache), it is written into the cache, the missing instruction is outputted to the fetch output and the fetch buffer
is reloaded.

//////Addressing a cache:
To retrieve a piece of data from a cache, an address must be provided to the cache in order for a search 
and hit/miss resolution to be made. The addres is broken down into three components (described below) of
which is required to fulfill three operations required to correctly search a cache. These are described below.

////Offset:
The offset is composed of the addresses least significant bits and is used to indicate where within a cacheline 
the accessing data is found therefore this value only needs to be able to count as high at to the end of the cacheline.
EG: to access the eighth byte on a cacheline, the offset should be set to seven given zeroeth indexing.
Offset size = log_base2(#Uniquely addressable entries in a cacheline)
EG: 64 byte wide cache has 6 bits when each byte may be addressed uniquely.
NOTE: Power has fixed size 4 byte instructions therefore there are only 16 uniquely addressable entries
(isntructions) that we really need to read therefore the 2 lsbs of the address may be ommited with the values being
implicitley zeroed out therefore providing a 4 byte aligned offset for a 64 byte cacheline using only 4 bits.

////Index:
The index is used to locate which cacheline the requested data is found within. This starts on the bit just above the 
offset and is sized to cover the range of cachelines in the cache.
EG to access the fith cacheline, the index should be set to four.
Index size = log_base2(#cachelines)
EG a cache with 256 cachelines will have an index 8 bits wide.

////Tag:
The tag composes of all bits above the index up to the msb of the address, this is used to resolve cache hit/misses.
As many addresses share the same index and offsets, the tag indicates what cache-sized block of memory the index and
offset is associated with. This is stored in the tag memory and compared against the incoming address's tag. If they 
match then the cache is hit, otherwise it's a miss.
//////////////////////////////////////////*/
module L1I_Cache
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
    parameter ICacheInstance = 0
)
(
    //////Inputs:
    input wire clock_i,
    ////Fetch:
    //command
    input wire fetchEnable_i, cacheReset_i, fetchStall_i,
    //data
    input wire [0:PidSize-1] Pid_i,
    input wire [0:TidSize-1] Tid_i,
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

    //////Outputs:    
    ////PC update
    output reg icachePCIncEnable_o,//Do we increment the PC in the FU
    output reg [0:2] iCachePCIncVal_o,//if so how much we increment by
    ////Fetch:
    //command
    output reg outputEnable_o,
    //Bundle output
    output reg [0:bundleSize-1] outputBundle_o,
    output reg [0:addressWidth-1] bundleAddress_o,
    output reg [0:1] bundleLen_o,
    output reg [0:PidSize-1] bundlePid_o,
    output reg [0:TidSize-1] bundleTid_o,
    output reg [0:instructionCounterWidth-1] bundleStartMajId_o,

    ////Cache update:
    //command
    output reg cacheMiss_o,
    //data
    output reg [0:addressWidth-1] missedAddress_o,
    output reg [0:instructionCounterWidth-1] missedInstMajorId_o,
    output reg [0:PidSize-1] missedPid_o,
    output reg [0:TidSize-1] missedTid_o
);

//File handle to the debug output
`ifdef DEBUG_PRINT
integer debugFID;
`endif

//loop counter
integer i;
//The actual cache memory
///Cacheline at idx i is at memory block tagTable[i] and is part of process processIdTable[i] and thread threadIdTable[i]
reg [0:cacheLineWith-1] ICache [0:(2**indexWidth)-1];//Stores the instructions
reg [0:tagWidth-1] tagTable [0:(2**indexWidth)-1];//Stores the tag for the associated cacheline
reg tagIsValidTable [0:(2**indexWidth)-1]; //indicates if the value is valid or not for the associated cacheline
reg [0:PidSize-1] processIdTable [0:(2**indexWidth)-1];//Stores the Pid for the associated cacheline
reg [0:TidSize-1] threadIdTable [0:(2**indexWidth)-1];//Stores the Tid for the associated cacheline
reg [0:instructionCounterWidth-1] instCtr;//uniquly identify instructions

//bypass buffers
reg [0:1] numInstsFetcheds [0:1];
reg fetchEnables [0:1];
reg [0:offsetWidth-1] fetchOffsets [0:1];
reg [0:indexWidth-1] fetchIndexs [0:1];
reg [0:tagWidth-1] fetchTags [0:1];
reg [0:PidSize-1] fetchPids [0:1];
reg [0:TidSize-1] fetchTids [0:1];
reg [0:instructionCounterWidth-1] fetchInstIds [0:1];

//Block memory output buffers
reg [0:cacheLineWith-1] fetchedBuffer;//holds the cacheline of the fetched instruction, if we can tell the instruction is on the same cacheline as last time we don't need to refetch the line from I-cache therefore saving power.
reg readLineIsValid;//indicates that the buffer is valid, will be inited to invalid
reg fetchedTagIsValid;//Indicates that the entry in the cache is valid, might be uninited or invalidated
reg [0:tagWidth-1] fetchedTag;//This is the tag that was fetched from tag memory and compared against the tag of the addr to fetch


always @(posedge clock_i)
begin
    fetchEnables[0] <= fetchEnable_i;//buffer the enable signal
    if(cacheReset_i)//Reset
    begin
        `ifdef DEBUG_PRINT
        case(ICacheInstance)//If we have multiple fetch units, they each get different files.
        0: begin 
            debugFID = $fopen("ICache0.log", "w");
        end
        1: begin 
            debugFID = $fopen("ICache1.log", "w");
        end
        2: begin 
            debugFID = $fopen("ICache2.log", "w");
        end
        3: begin 
            debugFID = $fopen("ICache3.log", "w");
        end
        endcase
        `endif
        `ifdef DEBUG $display("ICache: %d: Resetting", ICacheInstance); `endif  
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Resetting", ICacheInstance); `endif  

        instCtr <= 0;
        readLineIsValid <= 0;
        fetchEnables[0] <= 0; fetchEnables[1] <= 0;
        outputEnable_o <= 0; cacheMiss_o <= 0;
        icachePCIncEnable_o <= 0;
        for(i = 0; i < 256; i = i + 1)
        begin
            tagIsValidTable[i] <= 0;
        end
    end
    //Fetch in (cylce 1)
    else if(fetchEnable_i && !cacheMiss_o)
    begin
    `ifdef DEBUG $write("ICache: %d: Cycle 1 fetching instruction ID:%d at address %d. ", ICacheInstance, instCtr, fetchAddress_i); `endif
    `ifdef DEBUG_PRINT $fwrite(debugFID, "ICache: %d: Cycle 1 fetching instruction ID:%d at address %d. ", ICacheInstance, instCtr, fetchAddress_i); `endif  
         //This cache assumes a hit and therefore begins fetching from the Icache, it later checks for a hit/miss
         //and takes the apropriate action. This allows the tag and the ICache to be interogated in parallel saving cycles.
        
        fetchOffsets[0] <= fetchAddress_i[tagWidth+indexWidth+:offsetWidth];//assign the offset to the cycle 1 bypass
        fetchIndexs[0] <= fetchAddress_i[tagWidth+:indexWidth];//This is the input to one of the memories therefore not a bypass
        fetchTags[0] <= fetchAddress_i[0+:tagWidth];//assign the tag to the cycle 1 bypass
        fetchPids[0] <= Pid_i;//assign the Pid to the cycle 1 bypass
        fetchTids[0] <= Tid_i;//assign the Tid to the cycle 1 bypass
        fetchInstIds[0] <= instCtr;//assign the inst ID to the cycle 1 bypass

        ///Figure out if were on a bundle boundary, if not then how far away from a one we are:
        ///Figure out where in bundle group 1 we are:
        case(fetchAddress_i[tagWidth+indexWidth+:offsetWidth])
        0: begin 
            instCtr <= instCtr + 4;//Increment the instruction ctr by 4
            icachePCIncEnable_o <= 1; iCachePCIncVal_o <= (4 * instructionWidth);
            numInstsFetcheds[0] <= 2'b11;
            `ifdef DEBUG $display("Fetching 4 instructions"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID,"Fetching 4 instructions"); `endif
        end//At the begining of the bundle group, fetch the whole group
        4: begin 
            instCtr <= instCtr + 3;//Increment the instruction ctr by 3
            icachePCIncEnable_o <= 1; iCachePCIncVal_o <= (3 * instructionWidth);
            numInstsFetcheds[0] <= 2'b10;
            `ifdef DEBUG $display("Fetching 3 instructions"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID,"Fetching 3 instructions"); `endif
        end//Past the first instruction of the bundle group, fetch the last 3 instructions in the group
        8: begin 
            instCtr <= instCtr + 2;//Increment the instruction ctr by 2
            icachePCIncEnable_o <= 1; iCachePCIncVal_o <= (2 * instructionWidth);
            numInstsFetcheds[0] <= 2'b01;
            `ifdef DEBUG $display("Fetching 2 instructions"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID,"Fetching 2 instructions"); `endif
        end//Past the second instruction of the bundle group, fetch the last 2 instructions in the group
        12: begin 
            instCtr <= instCtr + 1;//Increment the instruction ctr by 1
            icachePCIncEnable_o <= 1; iCachePCIncVal_o <= (1 * instructionWidth);
            numInstsFetcheds[0] <= 2'b00;
            `ifdef DEBUG $display("Fetching 1 instruction"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID,"Fetching 1 instruction"); `endif
        end//At the last instruction in the bundle group, fetch the last instruction in the group
        
        ///Figure out where in bundle group 2 we are:
        16: begin 
            instCtr <= instCtr + 4;//Increment the instruction ctr by 4
            icachePCIncEnable_o <= 1; iCachePCIncVal_o <= (4 * instructionWidth);
            numInstsFetcheds[0] <= 2'b11;
            `ifdef DEBUG $display("Fetching 4 instructions"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID,"Fetching 4 instructions"); `endif
        end//At the begining of the bundle group, fetch the whole group
        20: begin 
            instCtr <= instCtr + 3;//Increment the instruction ctr by 3
            icachePCIncEnable_o <= 1; iCachePCIncVal_o <= (3 * instructionWidth);
            numInstsFetcheds[0] <= 2'b10;
            `ifdef DEBUG $display("Fetching 3 instructions"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID,"Fetching 3 instructions"); `endif
        end//Past the first instruction of the bundle group, fetch the last 3 instructions in the group
        24: begin 
            instCtr <= instCtr + 2;//Increment the instruction ctr by 2
            icachePCIncEnable_o <= 1; iCachePCIncVal_o <= (2 * instructionWidth);
            numInstsFetcheds[0] <= 2'b01;
            `ifdef DEBUG $display("Fetching 2 instructions"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID,"Fetching 2 instructions"); `endif
        end//Past the second instruction of the bundle group, fetch the last 2 instructions in the group
        28: begin 
            instCtr <= instCtr + 1;//Increment the instruction ctr by 1
            icachePCIncEnable_o <= 1; iCachePCIncVal_o <= (1 * instructionWidth);
            numInstsFetcheds[0] <= 2'b00;
            `ifdef DEBUG $display("Fetching 1 instruction"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID,"Fetching 41 instruction"); `endif
        end//At the last instruction in the bundle group, fetch the last instruction in the group
        
        ///Figure out where in bundle group 3 we are:
        32: begin 
            instCtr <= instCtr + 4;//Increment the instruction ctr by 4
            icachePCIncEnable_o <= 1; iCachePCIncVal_o <= (4 * instructionWidth);
            numInstsFetcheds[0] <= 2'b11;
            `ifdef DEBUG $display("Fetching 4 instructions"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID,"Fetching 4 instructions"); `endif
        end//At the begining of the bundle group, fetch the whole group
        36: begin 
            instCtr <= instCtr + 3;//Increment the instruction ctr by 3
            icachePCIncEnable_o <= 1; iCachePCIncVal_o <= (3 * instructionWidth);
            numInstsFetcheds[0] <= 2'b10;
            `ifdef DEBUG $display("Fetching 3 instructions"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID,"Fetching 3 instructions"); `endif
        end//Past the first instruction of the bundle group, fetch the last 3 instructions in the group
        40: begin 
            instCtr <= instCtr + 2;//Increment the instruction ctr by 2
            icachePCIncEnable_o <= 1; iCachePCIncVal_o <= (2 * instructionWidth);
            numInstsFetcheds[0] <= 2'b01;
            `ifdef DEBUG $display("Fetching 2 instructions"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID,"Fetching 2 instructions"); `endif
        end//Past the second instruction of the bundle group, fetch the last 2 instructions in the group
        44: begin 
            instCtr <= instCtr + 1;//Increment the instruction ctr by 1
            icachePCIncEnable_o <= 1; iCachePCIncVal_o <= (1 * instructionWidth);
            numInstsFetcheds[0] <= 2'b00;
            `ifdef DEBUG $display("Fetching 1 instruction"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID,"Fetching 1 instruction"); `endif
        end//At the last instruction in the bundle group, fetch the last instruction in the group

        ///Figure out where in bundle group 4 we are:
        48: begin 
            instCtr <= instCtr + 4;//Increment the instruction ctr by 4
            icachePCIncEnable_o <= 1; iCachePCIncVal_o <= (4 * instructionWidth);
            numInstsFetcheds[0] <= 2'b11;
            `ifdef DEBUG $display("          Fetching 4 instructions"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID,"          Fetching 4 instructions"); `endif
        end//At the begining of the bundle group, fetch the whole group
        52: begin 
            instCtr <= instCtr + 3;//Increment the instruction ctr by 3
            icachePCIncEnable_o <= 1; iCachePCIncVal_o <= (3 * instructionWidth);
            numInstsFetcheds[0] <= 2'b10;
            `ifdef DEBUG $display("          Fetching 3 instructions"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID,"          Fetching 3 instructions"); `endif
        end//Past the first instruction of the bundle group, fetch the last 3 instructions in the group
        56: begin 
            instCtr <= instCtr + 2;//Increment the instruction ctr by 2
            icachePCIncEnable_o <= 1; iCachePCIncVal_o <= (2 * instructionWidth);
            numInstsFetcheds[0] <= 2'b01;
            `ifdef DEBUG $display("          Fetching 2 instructions"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID,"          Fetching 2 instructions"); `endif
        end//Past the second instruction of the bundle group, fetch the last 2 instructions in the group
        60: begin 
            instCtr <= instCtr + 1;//Increment the instruction ctr by 1
            icachePCIncEnable_o <= 1; iCachePCIncVal_o <= (1 * instructionWidth);
            numInstsFetcheds[0] <= 2'b00;
            `ifdef DEBUG $display("          Fetching 1 instruction"); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID,"          Fetching 1 instruction"); `endif
        end//At the last instruction in the bundle group, fetch the last instruction in the group
        default: begin 
            `ifdef DEBUG $display("ICache: %d: Cycle 1 fetch (Group 4) alignment error at offset %h", ICacheInstance, fetchAddress_i[tagWidth+indexWidth+:offsetWidth]); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 1 fetch (Group 4) alignment error at offset %h", ICacheInstance, fetchAddress_i[tagWidth+indexWidth+:offsetWidth]); `endif
        end//Alignment error
        endcase
    end
    else if(cacheMiss_o) 
    begin  
        `ifdef DEBUG $display("ICache: %d: Cycle 1 stalled due to cache miss", ICacheInstance); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 1 stalled due to cache miss", ICacheInstance); `endif
    end

    //Natural cache writes - This allows lines to be naturaly written to the cache, this allows prefetching withought intefering with the output (as cache-miss resolution writeback does)
    if(naturalWriteEn_i)
    begin
        `ifdef DEBUG $display("ICache: %d: Natural write at address %d (%h)", ICacheInstance, naturalWriteAddress_i, naturalWriteAddress_i); `endif  
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Natural write at address %d (%h)", ICacheInstance, naturalWriteAddress_i, naturalWriteAddress_i); `endif  
        ICache[naturalWriteAddress_i[tagWidth+:indexWidth]] <= naturalWriteLine_i;//write the line to the cache
        tagTable[naturalWriteAddress_i[tagWidth+:indexWidth]] <= naturalWriteAddress_i[0+:tagWidth];//write the tag to the cache
        tagIsValidTable[naturalWriteAddress_i[tagWidth+:indexWidth]] <= 1;//set the isvalid bit
        processIdTable[naturalWriteAddress_i[tagWidth+:indexWidth]] <= naturalPid_i;
        threadIdTable[naturalWriteAddress_i[tagWidth+:indexWidth]] <= naturalTid_i;
    end

    ///Buffer reload check(cyle 2)
    if(fetchEnables[0] && !cacheMiss_o) 
    begin
        if( readLineIsValid && //buffer is valid
            fetchTags[1] == fetchTags[0] && //If we're fetching to the same block as last cycle
            fetchIndexs[1] == fetchIndexs[0]) //and the same cacheline then don't reload the cacheline
        begin
            //Fetch from the buffers as we're still on the same cacheline
            //so we'll do nothing here
            `ifdef DEBUG $display("ICache: %d: Cycle 2 Instruction on previously fetched line. Not refetching", ICacheInstance); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 2 Instruction on previously fetched line. Not refetching", ICacheInstance); `endif
        end
        else
        begin
            `ifdef DEBUG $display("ICache: %d: Cycle 2 Instruction not on previously fetched line. Refetching", ICacheInstance); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 2 Instruction not on previously fetched line. Refetching", ICacheInstance); `endif
            //Update the buffers and then fetch from the buffers
            fetchedBuffer <= ICache[fetchIndexs[0]]; 
            readLineIsValid <= 1;
            fetchedTag <= tagTable[fetchIndexs[0]];
            fetchedTagIsValid <= tagIsValidTable[fetchIndexs[0]];
            fetchPids[1] <= processIdTable[fetchIndexs[0]]; fetchTids[1] <= threadIdTable[fetchIndexs[0]];
            fetchTags[1] <= fetchTags[0]; fetchIndexs[1] <= fetchIndexs[0];            
        end 
    end  
    else if(cacheMiss_o)   
    begin
        `ifdef DEBUG $display("ICache: %d: Cycle 2 stalled due to cache miss", ICacheInstance); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 2 stalled due to cache miss", ICacheInstance); `endif
    end

    //Cycle 2 outputs
    fetchOffsets[1] <= fetchOffsets[0];
    fetchEnables[1] <= fetchEnables[0];
    fetchInstIds[1] <= fetchInstIds[0];
    numInstsFetcheds[1] <= numInstsFetcheds[0];

    ///Cycle 3 - check for cache hit or miss and output bundle
    if(fetchEnables[1]) begin
        if(!cacheMiss_o) begin
            if(fetchTags[1] == fetchedTag && fetchedTagIsValid)//cache hit
            begin
                `ifdef DEBUG $write("ICache: %d: Cycle 3 cache hit. Fetching %d instruction(s). ", ICacheInstance, (numInstsFetcheds[1]+1)); `endif
                `ifdef DEBUG_PRINT $fwrite(debugFID, "ICache: %d: Cycle 3 cache hit. Fetching %d instruction(s). ", ICacheInstance, (numInstsFetcheds[1]+1)); `endif  
                //Check how many instructions are going into the bundle and then output the bundle
                case(numInstsFetcheds[1])
                2'b00: begin//1 instruction in bundle
                    outputEnable_o <= 1;
                    bundleLen_o <= 2'b00;//1 instruction in the bundle
                    bundlePid_o <= fetchPids[1]; bundleTid_o <= fetchTids[1];
                    bundleStartMajId_o <= fetchInstIds[1];
                    outputBundle_o <= fetchedBuffer[(fetchOffsets[1]*8)+:(1 * instructionWidth)];
                    `ifdef DEBUG $display("Outputting %h", fetchedBuffer[(fetchOffsets[1]*8)+:(1 * instructionWidth)]); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "Outputting %h", fetchedBuffer[(fetchOffsets[1]*8)+:(1 * instructionWidth)]);`endif
                end
                2'b01: begin//2 instructions in bundle
                    outputEnable_o <= 1;
                    bundleLen_o <= 2'b01;//2 instruction in the bundle
                    bundlePid_o <= fetchPids[1]; bundleTid_o <= fetchTids[1];
                    bundleStartMajId_o <= fetchInstIds[1];
                    outputBundle_o <= fetchedBuffer[(fetchOffsets[1]*8)+:(2 * instructionWidth)];
                    `ifdef DEBUG $display("Outputting %h", fetchedBuffer[(fetchOffsets[1]*8)+:(2 * instructionWidth)]); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "Outputting %h", fetchedBuffer[(fetchOffsets[1]*8)+:(2 * instructionWidth)]);`endif
                end
                2'b10: begin//3 instructions in bundle
                    outputEnable_o <= 1;
                    bundleLen_o <= 2'b10;//3 instruction in the bundle
                    bundlePid_o <= fetchPids[1]; bundleTid_o <= fetchTids[1];
                    bundleStartMajId_o <= fetchInstIds[1];
                    outputBundle_o <= fetchedBuffer[(fetchOffsets[1]*8)+:(3 * instructionWidth)];
                    `ifdef DEBUG $display("Outputting %h", fetchedBuffer[(fetchOffsets[1]*8)+:(3 * instructionWidth)]); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "Outputting %h", fetchedBuffer[(fetchOffsets[1]*8)+:(3 * instructionWidth)]);`endif
                end
                2'b11: begin//4 instructions in bundle
                    outputEnable_o <= 1;
                    bundleLen_o <= 2'b11;//2 instruction in the bundle
                    bundlePid_o <= fetchPids[1]; bundleTid_o <= fetchTids[1];
                    bundleStartMajId_o <= fetchInstIds[1];
                    outputBundle_o <= fetchedBuffer[(fetchOffsets[1]*8)+:(4 * instructionWidth)];
                    `ifdef DEBUG $display("Outputting %h", fetchedBuffer[(fetchOffsets[1]*8)+:(4 * instructionWidth)]); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "Outputting %h", fetchedBuffer[(fetchOffsets[1]*8)+:(4 * instructionWidth)]);`endif
                end
                endcase
                bundleAddress_o <= {fetchTags[1], fetchIndexs[1], fetchOffsets[1]};
            end
            else//miss
            begin
                `ifdef DEBUG $display("ICache: %d: Cycle 3 cache miss. Requesting reload at address %d (%h).", ICacheInstance, {fetchTags[1], fetchIndexs[1], fetchOffsets[1]}, {fetchTags[1], fetchIndexs[1], fetchOffsets[1]}); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 cache miss. Requesting reload %d (%h).", ICacheInstance, {fetchTags[1], fetchIndexs[1], fetchOffsets[1]}, {fetchTags[1], fetchIndexs[1], fetchOffsets[1]}); `endif  
                outputEnable_o <= 0;
                cacheMiss_o <= 1; missedAddress_o <= {fetchTags[1], fetchIndexs[1], fetchOffsets[1]};
                missedInstMajorId_o <= fetchInstIds[1];
                missedPid_o <= fetchPids[1]; missedTid_o <= fetchTids[1];
            end 
        end
        else
        begin
            `ifdef DEBUG $display("ICache: %d: Cycle 3 stalled due to cache miss", ICacheInstance); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 stalled due to cache miss", ICacheInstance); `endif  
        end
    end
    else
    begin //If the last cycle had it's enables disabled, then disable it here
        outputEnable_o <= 0;
    end

    ///Cache update/miss clear
    if(cacheUpdate_i)
    begin
        if(cacheMiss_o)//if we're currently stalled from a cache miss
        begin
            if(missedAddress_o[0+:tagWidth+indexWidth] == cacheUpdateAddress_i[0+:tagWidth+indexWidth] && //if were writing the cacheline that had caused the miss (Not checking the offset)
            cacheUpdatePid_i == missedPid_o && cacheUpdateTid_i == missedTid_o//and the process/thread is the same as the one causing the cache miss
            )
            begin
                cacheMiss_o <= 0; //clear the cache miss
                `ifdef DEBUG $display("ICache: %d: Resolving cache miss as addr %h", ICacheInstance, cacheUpdateAddress_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Resolving cache miss as addr %h", ICacheInstance, cacheUpdateAddress_i); `endif
            end
            //NOTE: cacheUpdateAddress_i[tagWidth+:indexWidth] == index
            //update the memory
            ICache[cacheUpdateAddress_i[tagWidth+:indexWidth]] <= cacheUpdateLine_i;//write the new line1
            tagTable[cacheUpdateAddress_i[tagWidth+:indexWidth]] <= cacheUpdateAddress_i[0+:tagWidth];
            tagIsValidTable[cacheUpdateAddress_i[tagWidth+:indexWidth]] <= 1;
            processIdTable[cacheUpdateAddress_i[tagWidth+:indexWidth]] <= cacheUpdatePid_i;
            threadIdTable[cacheUpdateAddress_i[tagWidth+:indexWidth]] <= cacheUpdateTid_i;


            //Output the newly aquired line
            readLineIsValid <= 0;
            bundleAddress_o <= cacheUpdateAddress_i;
            bundlePid_o <= cacheUpdatePid_i; bundleTid_o <= cacheUpdateTid_i;
            bundleStartMajId_o <= missedInstMajorId_i;
            if(cacheUpdateAddress_i[addressWidth-:offsetWidth] < 16)//Check the offset to find if it's in bundle group 1
            begin
                //Figure out where in bundle group 1 we are
                case(cacheUpdateAddress_i[addressWidth-:offsetWidth])
                0: begin 
                    outputEnable_o <= 1;
                    bundleLen_o <= 2'b00;            
                    outputBundle_o <= fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(1 * instructionWidth)];
                    `ifdef DEBUG $display("ICache: %d: Cycle 3 Outputting 1 instruction in group 1: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(1 * instructionWidth)]); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 Outputting 1 instruction in group 1: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(1 * instructionWidth)]); `endif  
                end//At the begining of the bundle group, fetch the whole group
                4: begin 
                    outputEnable_o <= 1;
                    bundleLen_o <= 2'b01;
                    outputBundle_o <= fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(2 * instructionWidth)];
                    `ifdef DEBUG $display("ICache: %d: Cycle 3 Outputting 2 instructions in group 1: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(2 * instructionWidth)]); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 Outputting 2 instructions in group 1: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(2 * instructionWidth)]); `endif  
                end//Past the first instruction of the bundle group, fetch the last 3 instructions in the group
                8: begin 
                    outputEnable_o <= 1;
                    bundleLen_o <= 2'b10;
                    outputBundle_o <= fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(3 * instructionWidth)];
                    `ifdef DEBUG $display("ICache: %d: Cycle 3 Outputting 3 instructions in group 1: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(3 * instructionWidth)]); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 Outputting 3 instructions in group 1: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(3 * instructionWidth)]); `endif  
                end//Past the second instruction of the bundle group, fetch the last 2 instructions in the group
                12: begin 
                    outputEnable_o <= 1;
                    bundleLen_o <= 2'b11;
                    outputBundle_o <= fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(4 * instructionWidth)];
                    `ifdef DEBUG $display("ICache: %d: Cycle 3 Outputting 4 instructions in group 1: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(4 * instructionWidth)]); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 Outputting 4 instructions in group 1: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(4 * instructionWidth)]); `endif  
                end//At the last instruction in the bundle group, fetch the last instruction in the group
                default: begin 
                    `ifdef DEBUG $display("ICache: %d: Cycle 3 Cache miss resolution alignment error", ICacheInstance); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 Cache miss resolution alignment error", ICacheInstance); `endif  
                end//Alignment error
                endcase
            end
            else if(cacheUpdateAddress_i[addressWidth-:offsetWidth] < 32)//Check the offset to find if it's in bundle group 2
            begin
                //Figure out where in bundle group 2 we are
                case(cacheUpdateAddress_i[addressWidth-:offsetWidth])
                16: begin 
                    outputEnable_o <= 1;
                    bundleLen_o <= 2'b00;
                    outputBundle_o <= fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(1 * instructionWidth)];
                    `ifdef DEBUG $display("ICache: %d: Cycle 3 Outputting 1 instruction in group 2: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(1 * instructionWidth)]); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 Outputting 1 instruction in group 2: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(1 * instructionWidth)]); `endif  
                end//At the begining of the bundle group, fetch the whole group
                20: begin 
                    outputEnable_o <= 1;
                    bundleLen_o <= 2'b01;
                    outputBundle_o <= fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(2 * instructionWidth)];
                    `ifdef DEBUG $display("ICache: %d: Cycle 3 Outputting 2 instructions in group 2: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(2 * instructionWidth)]); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 Outputting 2 instructions in group 2: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(2 * instructionWidth)]); `endif  
                end//Past the first instruction of the bundle group, fetch the last 3 instructions in the group
                24: begin 
                    outputEnable_o <= 1;
                    bundleLen_o <= 2'b10;
                    outputBundle_o <= fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(3 * instructionWidth)];
                    `ifdef DEBUG $display("ICache: %d: Cycle 3 Outputting 3 instructions in group 2: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(3 * instructionWidth)]); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 Outputting 3 instructions in group 2: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(3 * instructionWidth)]); `endif  
                end//Past the second instruction of the bundle group, fetch the last 2 instructions in the group
                28: begin 
                    outputEnable_o <= 1;
                    bundleLen_o <= 2'b11;
                    outputBundle_o <= fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(4 * instructionWidth)];
                    `ifdef DEBUG $display("ICache: %d: Cycle 3 Outputting 4 instructions in group 2: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(4 * instructionWidth)]); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 Outputting 4 instructions in group 2: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(4 * instructionWidth)]); `endif  
                end//At the last instruction in the bundle group, fetch the last instruction in the group
                default: begin 
                    `ifdef DEBUG $display("ICache: %d: Cycle 3 Cache miss resolution alignment error", ICacheInstance); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 Cache miss resolution alignment error", ICacheInstance); `endif  
                end//Alignment error
                endcase
            end
            else if(cacheUpdateAddress_i[addressWidth-:offsetWidth] < 48)//Check the offset to find if it's in bundle group 3
            begin
                //Figure out where in bundle group 3 we are
                case(cacheUpdateAddress_i[addressWidth-:offsetWidth])
                32: begin //At the begining of the bundle group, fetch the whole group
                    outputEnable_o <= 1;
                    bundleLen_o <= 2'b00;
                    outputBundle_o <= fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(1 * instructionWidth)];
                    `ifdef DEBUG $display("ICache: %d: Cycle 3 Outputting 1 instruction in group 3: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(1 * instructionWidth)]); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 Outputting 1 instruction in group 3: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(1 * instructionWidth)]); `endif  
                end
                36: begin //Past the first instruction of the bundle group, fetch the last 3 instructions in the group
                    outputEnable_o <= 1;
                    bundleLen_o <= 2'b01;
                    outputBundle_o <= fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(2 * instructionWidth)];
                    `ifdef DEBUG $display("ICache: %d: Cycle 3 Outputting 2 instructions in group 3: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(2 * instructionWidth)]); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 Outputting 2 instructions in group 3: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(2 * instructionWidth)]); `endif  
                end
                40: begin //Past the second instruction of the bundle group, fetch the last 2 instructions in the group
                    outputEnable_o <= 1;
                    bundleLen_o <= 2'b10;
                    outputBundle_o <= fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(3 * instructionWidth)];
                    `ifdef DEBUG $display("ICache: %d: Cycle 3 Outputting 3 instructions in group 3: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(3 * instructionWidth)]); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 Outputting 3 instructions in group 3: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(3 * instructionWidth)]); `endif  
                end
                44: begin //At the last instruction in the bundle group, fetch the last instruction in the group
                    outputEnable_o <= 1;
                    bundleLen_o <= 2'b11;
                    outputBundle_o <= fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(4 * instructionWidth)];
                    `ifdef DEBUG $display("ICache: %d: Cycle 3 Outputting 4 instructions in group 3: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(4 * instructionWidth)]); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 Outputting 4 instructions in group 3: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(4 * instructionWidth)]); `endif  
                end
                default: begin //Alignment error
                    `ifdef DEBUG $display("ICache: %d: Cycle 3 Cache miss resolution alignment error", ICacheInstance); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 Cache miss resolution alignment error", ICacheInstance); `endif  
                end
                endcase
            end
            else//Bundle group 4
            begin
                //Figure out where in bundle group 4 we are
                case(cacheUpdateAddress_i[addressWidth-:offsetWidth])
                48: begin //At the begining of the bundle group, fetch the whole group
                    outputEnable_o <= 1;
                    bundleLen_o <= 2'b00;
                    outputBundle_o <= fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(1 * instructionWidth)];
                    `ifdef DEBUG $display("ICache: %d: Cycle 3 Outputting 1 instruction in group 4: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(1 * instructionWidth)]); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 Outputting 1 instruction in group 4: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(1 * instructionWidth)]); `endif  
                end
                52: begin //Past the first instruction of the bundle group, fetch the last 3 instructions in the group
                    outputEnable_o <= 1;
                    bundleLen_o <= 2'b01;
                    outputBundle_o <= fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(2 * instructionWidth)];
                    `ifdef DEBUG $display("ICache: %d: Cycle 3 Outputting 2 instructions in group 4: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(2 * instructionWidth)]); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 Outputting 2 instructions in group 4: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(2 * instructionWidth)]); `endif  
                end
                56: begin //Past the second instruction of the bundle group, fetch the last 2 instructions in the group
                    outputEnable_o <= 1;
                    bundleLen_o <= 2'b10;
                    outputBundle_o <= fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(3 * instructionWidth)];
                    `ifdef DEBUG $display("ICache: %d: Cycle 3 Outputting 3 instructions in group 3: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(3 * instructionWidth)]); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 Outputting 3 instructions in group 3: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(3 * instructionWidth)]); `endif  
                end
                60: begin //At the last instruction in the bundle group, fetch the last instruction in the group
                    outputEnable_o <= 1;
                    bundleLen_o <= 2'b11;
                    outputBundle_o <= fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(4 * instructionWidth)];
                    `ifdef DEBUG $display("ICache: %d: Cycle 3 Outputting 4 instructions in group 4: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(4 * instructionWidth)]); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 Outputting 4 instructions in group 4: %h", ICacheInstance, fetchedBuffer[((cacheUpdateAddress_i[addressWidth-:offsetWidth])*8)+:(4 * instructionWidth)]); `endif  
                end
                default: begin //Alignment error
                    `ifdef DEBUG $display("ICache: %d: Cycle 3 Cache miss resolution alignment error", ICacheInstance); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Cycle 3 Cache miss resolution alignment error", ICacheInstance); `endif  
                end
                endcase
            end
        end
    end
    `ifdef DEBUG $display("\n"); `endif
    `ifdef DEBUG_PRINT $fdisplay(debugFID, "\n"); `endif  
end

endmodule