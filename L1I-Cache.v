`timescale 1ns / 1ps
`define DEBUG

/*/////////L1 instruction cache/////////////
Writen by Josh "Hakaru" Cantwell - 16.12.2022

//////Signal groups
The cache has a 3 cycle latency and has 4 groups of signals, one pair of sinal groups are inputs and the other pair are outputs.
The signal groups perform one of two tasks: Fetching and cache miss resolution. These are described below:
1) Fetch input
This group of signals is used as the input to the cache/fetch unit for the purpose of fetching an instruction. These consist of control signals
and an address to fetch among other things.

2) Fetch output
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
The fetch unit operates in 3 stages with 4 blocks of hardware. It can fetch up to 2 instructions per cycle, when the address to fetch is not aligned to an even instruction
address, it will fetch just 1 instruction that cycle and then continue on 2 per cycle after that. The reason is because if it's on an odd instruction there will be a time at
the end of the cacheline when the first instruction in the pair is on one cacheline and the second instruction is on the next cacheline which i cba handling.
///Reset
During startup or re-initialisation/cache clear the fetch unit has a reser behaviour/hardware block.
This hardware initialises the cache's valid bits for each cacheline to zero, resets the instruction ID counter to zero and dissables the outputs.

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
During this cycle, the missed cacheline is proveded to the fetch unit, it is written into the cache, the missing instruction is outputted to the fetch output and the fetch buffer
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
    parameter fetchingAddressWidth = 64, //addresses are 64 bits wide
    parameter cacheLineWith = 64 * 8, //cachelines are 64 bytes wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter offsetWidth = 6, //allows all 16 instructions in the cache to be addresses (for a 64 byte wide cache)
    parameter indexWidth = 8, //256 cachelines
    parameter tagWidth = fetchingAddressWidth - (indexWidth - offsetWidth), //the tag is composed of the remaining parts of the address
    //Processes ID and thread ID size
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
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
    input wire [0:offsetWidth-1] offset_i,
    input wire [0:indexWidth-1] index_i,
    input wire [0:tagWidth-1] tag_i,

    /////Cache update:
    //command
    input wire cacheUpdate_i,
    //data
    input wire [0:fetchingAddressWidth-1] cacheUpdateAddress_i,
    input wire [0:PidSize-1] cacheUpdatePid_i,
    input wire [0:TidSize-1] cacheUpdateTid_i,
    input wire [0:cacheLineWith-1] cacheUpdateLine1_i,
    input wire [0:cacheLineWith-1] cacheUpdateLine2_i,

    //////Outputs:    
    ////Fetch:
    //command
    output reg fetchEnable1_o, fetchEnable2_o,
    //data
    output reg [0:instructionWidth-1] fetchedInstruction1_o, fetchedInstruction2_o,
    output reg [0:fetchingAddressWidth-1] fetchedAddress1_o, fetchedAddress2_o,
    output reg [0:PidSize-1] fetchedPid1_o, fetchedPid2_o,
    output reg [0:TidSize-1] fetchedTid1_o, fetchedTid2_o,
    output reg [0:instructionCounterWidth-1] fetchedInstMajorId1_o, fetchedInstMajorId2_o,

    ////Cache update:
    //command
    output reg cacheMiss_o,
    //data
    output reg [0:fetchingAddressWidth-1] missedAddress_o,
    output reg [0:instructionCounterWidth-1] missedInstMajorId_o,
    output reg [0:PidSize-1] missedPid_o,
    output reg [0:TidSize-1] missedTid_o
);

//loop counter
integer i;
//The actual cache memory
///Cacheline at idx i is at memory block tagTable[i] and is part of process processIdTable[i] and thread threadIdTable[i]
reg [0:cacheLineWith-1] ICache [0:indexWidth-1];//Stores the instructions
reg [0:tagWidth-1] tagTable [0:indexWidth-1];//Stores the tag for the associated cacheline
reg tagIsValidTable [0:indexWidth-1]; //indicates if the value is valid or not for the associated cacheline
reg [0:PidSize-1] processIdTable [0:indexWidth-1];//Stores the Pid for the associated cacheline
reg [0:TidSize-1] threadIdTable [0:indexWidth-1];//Stores the Tid for the associated cacheline
reg [0:instructionCounterWidth-1] instCtr;//uniquly identify instructions

//bypass buffers
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
        `ifdef DEBUG $display("Resetting cache"); `endif  
        instCtr <= 0;   
        readLineIsValid <= 0;
        //fetchEnable_1 <= 0; fetchEnable_2 <= 0;
        fetchEnables[0] <= 0; fetchEnables[1] <= 0;
        cacheMiss_o <= 0;
        for(i = 0; i < 256; i = i + 1)
        begin
            ICache[i] <= 512'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_AAAA_BBBB;
            tagTable[i] <= 0;
            tagIsValidTable[i] <= 0;
            processIdTable[i] <= 0;
            threadIdTable[i] <= 0;
        end
    end

    //Fetch in (cylce 1)
    else if(fetchEnable_i && !cacheMiss_o)
    begin
    `ifdef DEBUG $display("Fetching instruction ID:%d at address %d.", instCtr, {tag_i, index_i, offset_i}); `endif
         //This cache assumes a hit and therefore begins fetching from the Icache, it later checks for a hit/miss
         //and takes the apropriate action. This allows the tag and the ICache to be interogated in parallel saving cycles.
        fetchOffsets[0] <= offset_i;//assign the offset to the cycle 1 bypass
        fetchIndexs[0] <= index_i;//This is the input to one of the memories therefore not a bypass
        fetchTags[0] <= tag_i;//assign the tag to the cycle 1 bypass
        fetchPids[0] <= Pid_i;//assign the Pid to the cycle 1 bypass
        fetchTids[0] <= Tid_i;//assign the Tid to the cycle 1 bypass
        fetchInstIds[0] <= instCtr;//assign the inst ID to the cycle 1 bypass

        if(offset_i % 8)//odd address
        begin
            `ifdef DEBUG $display("Fetching 1 instruction"); `endif
            instCtr <= instCtr + 1;//only fetch 1 inst to make it even next time
        end
        else//even address
        begin
            `ifdef DEBUG $display("Fetching 2 instructions"); `endif
            instCtr <= instCtr + 2;
        end
    end
    else if(cacheMiss_o)   
    `ifdef DEBUG $display("Cycle 1 stalling due to cache miss"); `endif

    ///Buffer reload check(cyle 2)
    if(fetchEnables[0] && !cacheMiss_o) 
    begin
        if( readLineIsValid && //buffer is valid
            fetchTags[1] == fetchTags[0] && //If we're fetching to the same block as last cycle
            fetchIndexs[1] == fetchIndexs[0]) //and the same cacheline then don't reload the cacheline
        begin
            //Fetch from the buffers as we're still on the same cacheline
            //so we'll do nothing here
            `ifdef DEBUG $display("Instruction on previously fetched line. Not refetching"); `endif
        end
        else
        begin
            `ifdef DEBUG $display("Instruction on new line. Refetching line."); `endif
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
    `ifdef DEBUG $display("Cycle 2 stalling due to cache miss"); `endif

    fetchOffsets[1] <= fetchOffsets[0];
    fetchEnables[1] <= fetchEnables[0];
    fetchInstIds[1] <= fetchInstIds[0];

    ///Cycle 3 - check for cache hit or miss
    if(fetchEnables[1]) begin
        if(!cacheMiss_o) begin
            if(fetchTags[1] == fetchedTag && fetchedTagIsValid)//hit
            begin
                //check if the index is an even number (if so we can do 2 inst per cycle withought inst pairs wrapping onto the next line)
                //if not we shall do 1 inst this cycle to make is even.
                if(fetchOffsets[1] % 8)//odd - 1 inst
                begin
                    `ifdef DEBUG $display("Outputting 1 instruction"); `endif
                    fetchEnable1_o <= 1; fetchEnable2_o <= 0;
                    fetchedInstruction1_o <= fetchedBuffer[(fetchOffsets[1]*8)+:32];
                    fetchedAddress1_o <= {fetchTags[1], fetchIndexs[1], fetchOffsets[1]};
                    fetchedInstMajorId1_o <= fetchInstIds[1];
                    fetchedPid1_o <= fetchPids[1]; fetchedTid1_o <= fetchTids[1];
                end 
                else//even - 2 insts
                begin
                    `ifdef DEBUG $display("Outputting 2 instructions"); `endif
                    fetchEnable1_o <= 1; fetchEnable2_o <= 1;
                    fetchedInstruction1_o <= fetchedBuffer[(fetchOffsets[1]*8)+:32];
                    fetchedInstruction2_o <= fetchedBuffer[((fetchOffsets[1]+4)*8)+:32];
                    fetchedAddress1_o <= {fetchTags[1], fetchIndexs[1], fetchOffsets[1]};
                    fetchedAddress2_o <= ({fetchTags[1], fetchIndexs[1], fetchOffsets[1]}) + 4;
                    fetchedInstMajorId1_o <= fetchInstIds[1];
                    fetchedInstMajorId2_o <= fetchInstIds[1]+1;
                    fetchedPid1_o <= fetchPids[1]; fetchedTid1_o <= fetchTids[1];
                    fetchedPid2_o <= fetchPids[1]; fetchedTid2_o <= fetchTids[1];
                end
                `ifdef DEBUG $display("Cache hit."); `endif 
                
            end
            else//miss
            begin
                `ifdef DEBUG $display("Cache miss."); `endif
                fetchEnable1_o <= 0; fetchEnable2_o <= 0;
                cacheMiss_o <= 1; missedAddress_o <= {fetchTags[1], fetchIndexs[1], fetchOffsets[1]};
                missedInstMajorId_o <= fetchInstIds[1];
                missedPid_o <= fetchPids[1]; missedTid_o <= fetchTids[1];
            end 
        end
        else
            `ifdef DEBUG $display("Cycle 3 stalling due to cache miss"); `endif
    end
    else
    begin //If the last cycle had it's enables disabled, then disable it here
        fetchEnable1_o <= 0; fetchEnable2_o <= 0;
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
                `ifdef DEBUG $display("Resolving cache miss as addr %h", cacheUpdateAddress_i); `endif
                `ifdef DEBUG $display("Writing line:\n%h\n%h", cacheUpdateLine1_i, cacheUpdateLine2_i); `endif
            end
            //NOTE: cacheUpdateAddress_i[tagWidth+:indexWidth] == index
            //update the memory
            ICache[cacheUpdateAddress_i[tagWidth+:indexWidth]] <= cacheUpdateLine1_i;//write the new line1
            ICache[cacheUpdateAddress_i[tagWidth+:indexWidth]+1] <= cacheUpdateLine2_i;//write the new line2
            tagTable[cacheUpdateAddress_i[tagWidth+:indexWidth]] <= cacheUpdateAddress_i[0+:tagWidth];
            tagIsValidTable[cacheUpdateAddress_i[tagWidth+:indexWidth]] <= 1;
            processIdTable[cacheUpdateAddress_i[tagWidth+:indexWidth]] <= cacheUpdatePid_i;
            threadIdTable[cacheUpdateAddress_i[tagWidth+:indexWidth]] <= cacheUpdateTid_i;

            //check if the index is an even number (if so we can do 2 inst per cycle withought inst pairs wrapping onto the next line)
            //if not we shall do 1 inst this cycle to make is even.
            readLineIsValid <= 0;
            if(cacheUpdateAddress_i % 8)//odd - 1 inst
            begin            
            `ifdef DEBUG $display("Updating cache at an odd address, fetching 1 inst"); `endif
            fetchEnable1_o <= 1; fetchEnable2_o <= 0;
            fetchedInstruction1_o <= cacheUpdateLine1_i[cacheUpdateAddress_i[tagWidth+indexWidth+:offsetWidth]+:32];
            fetchedAddress1_o <= cacheUpdateAddress_i;
            fetchedPid1_o <= cacheUpdatePid_i; fetchedTid1_o <= cacheUpdateTid_i;
            fetchedInstMajorId1_o <= missedInstMajorId_o;  
            end
            else
            begin
            `ifdef DEBUG $display("Updating cache at an even address, fetching 2 insts"); `endif
            fetchEnable1_o <= 1; fetchEnable2_o <= 1;
            fetchedInstruction1_o <= cacheUpdateLine1_i[cacheUpdateAddress_i[tagWidth+indexWidth+:offsetWidth]+:32];
            fetchedInstruction2_o <= cacheUpdateLine1_i[(cacheUpdateAddress_i[tagWidth+indexWidth+:offsetWidth]+32)+:32];
            fetchedAddress1_o <= cacheUpdateAddress_i;
            fetchedAddress2_o <= cacheUpdateAddress_i+4;
            fetchedPid1_o <= cacheUpdatePid_i; fetchedTid1_o <= cacheUpdateTid_i;
            fetchedPid2_o <= cacheUpdatePid_i; fetchedTid2_o <= cacheUpdateTid_i;
            fetchedInstMajorId1_o <= missedInstMajorId_o; fetchedInstMajorId2_o <= missedInstMajorId_o; 
            end
        end
    end

end

endmodule