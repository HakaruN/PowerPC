`define DEBUG
`define DEBUG_PRINT

/*/////////Reservation Station/////////////
Writen by Josh "Hakaru" Cantwell - 16.01.2022

This file implements the reservation station module for the power core.
*//////////////////////////////////////////


module ReservationStation
#(
    parameter queueWidth = 302, parameter RStationInstance = 0, parameter RSIdxBits = 6
)
(
    ///Input
    //command
    input wire clock_i,
    input wire reset_i,
    input wire enable_i, stall_i,
    //Data
    //Inst in

    ///Output
    output reg enable_o,
    output reg isFull_o
);

`ifdef DEBUG_PRINT
integer debugFID;
`endif

//Reservation station data structures
reg RSIsFree [0:RSIdxBits-1];
reg [0:25-1] RSinstFormats [0:RSIdxBits-1];
reg [0:opcodeSize-1] RSOpcodes [0:RSIdxBits-1];
reg [0:addressWidth-1] RSOAddrs [0:RSIdxBits-1];
reg [0:funcUnitCodeSize-1] RSFuncUnitTypes [0:RSIdxBits-1];
reg [0:funcUnitCodeSize-1] RSMajIDs [0:RSIdxBits-1];
reg [0:instMinIdWidth-1] RSminIDs [0:RSIdxBits-1];
reg RSis64Bits [0:RSIdxBits-1];
reg [0:PidSize-1] RSOPids [0:RSIdxBits-1];
reg [0:TidSize-1] RSOTids [0:RSIdxBits-1];
reg [0:(regAccessPatternSize*4)-1] RSOregAccessPatterns [0:RSIdxBits-1];
reg [0:3] RSisRegs [0:RSIdxBits-1];
reg [0:84-1] RSBody [0:RSIdxBits-1];

reg notFull;
reg entryFound;//Goes high if we have found a free entry so we know not to write the inst to other free ones
reg freeIdx;//This takes the idx of the free res we found to take the instruction
reg notFull;



always @(posedge clock_i)
begin
    if(reset_i)
    begin//resetting
    `ifdef DEBUG_PRINT
    case(RStationInstance)//If we have multiple decoders, they each get different files. The second number indicates the decoder# log file.
        0: begin 
            debugFID = $fopen("ResStation0.log", "w");
        end
        1: begin 
            debugFID = $fopen("ResStation1.log", "w");
        end
        2: begin 
            debugFID = $fopen("ResStation2.log", "w");
        end
        3: begin 
            debugFID = $fopen("ResStation3.log", "w");
        end
        4: begin 
            debugFID = $fopen("ResStation4.log", "w");
        end
        5: begin 
            debugFID = $fopen("ResStation5.log", "w");
        end
        6: begin 
            debugFID = $fopen("ResStation6.log", "w");
        end
        7: begin 
            debugFID = $fopen("ResStation7.log", "w");
        end
        endcase
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "Reservation station %d resetting", RStationInstance); `endif
    `endif
    `ifdef DEBUG $display("Reservation station %d resetting", RStationInstance) `endif

        //Clear all the isFree bits such that all entries are available for use
        for(i = 0; i < 2**RSIdxBits; i = i + 1)
        begin
            assign RSIsFree[i] = 0;
        end
        assign enable_o = 0;
        assign notFull = 1;
        assign nextFreeEntry = 0;//start on RS entry 0
    end
    else if(enable_i)
    begin//Enabled and not resetting
        assign entryFound = 0;//reset the entry found signal

        //Try to find an empty entry in the RS, if there is then use it. If there isn't then stall.
        for(i = 0; i < 2**RSIdxBits; i = i + 1)
        begin
            if(RSIsFree[i] == 1 && entryFound == 0)
            begin
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Reservation station %d found a free entry", RStationInstance); `endif
                `ifdef DEBUG $display("Reservation station %d found a free entry", RStationInstance); `endif
                
                //found an entry, mark it so we don't allocate it again
                assign entryFound = 1;
                //allocate the instruction
                assign RSIsFree[i] = 0;
                assign RSinstFormats[i] = ;
                assign RSOpcodes[i] = ;
                assign RSOAddrs[i] = ;
                assign RSFuncUnitTypes[i] = ;
                assign RSMajIDs[i] = ;
                assign RSminIDs[i] = ;
                assign RSis64Bits[i] = ;
                assign RSOPids[i] = ;
                assign RSOTids[i] = ;
                assign RSOregAccessPatterns[i] = ;
                assign RSisRegs[i] = ;
                assign RSBody[i] = ;
                //enable the output
                assign enable_o = 1;
            end
            else if(RSIsFree[i] == 1 && entryFound == 1)
            begin//found a second open entry
                assign notFull == 1;
            end
            else
        end

        //if we are full, output a stall
        if(notFull == 0)
            assign isFull_o = 1;
        else
            assign isFull_o = 0;

            

    end
    else
    begin//Neither enabled or resetting
        //disable the output
        assign enable_o = 0;
    end
end
endmodule