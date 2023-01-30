`define DEBUG
`define DEBUG_PRINT

/*/////////Reservation Station/////////////
Writen by Josh "Hakaru" Cantwell - 16.01.2022

This file implements the reservation station module for the power core.
*//////////////////////////////////////////


module ReservationStation
#(
    parameter RStationInstance = 0, parameter RSIdxBits = 6,
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter instMinIdWidth = 5,
    parameter opcodeSize = 12, parameter regSize = 5,
    parameter regAccessPatternSize = 2,//2 bit field, [0] == is read, [1] == is writen. Both can be true EG: (A = A + B)
    parameter regRead = 2'b10, parameter regWrite = 2'b01, 
    parameter immWidth = 64
)
(
    ///Input
    //command
    input wire clock_i,
    input wire reset_i,
    input wire enable_i, stall_i,
    //Data
    //Inst in
    input wire enable_i,
    input wire [0:25-1] instFormat_i,
    input wire [0:opcodeSize-1] opcode_i,
    input wire [0:addressWidth-1] address_i,
    input wire [0:funcUnitCodeSize-1] funcUnitType_i,
    input wire [0:instructionCounterWidth-1] majID_i,
    input wire [0:instMinIdWidth-1] minID_i,
    input wire is64Bit_i,
    input wire [0:PidSize-1] pid_i,
    input wire [0:TidSize-1] tid_i,
    input wire [0:regAccessPatternSize-1] op1rw_i, op2rw_i, op3rw_i, op4rw_i,
    input wire op1IsReg_i, op2IsReg_i, op3IsReg_i, op4IsReg_i,
    input wire [0:84-1] body_i//contains all operands. Large enough for 4 reg operands and a 64bit imm
    //read request in
    input wire 
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
                assign RSinstFormats[i] = instFormat_i;
                assign RSOpcodes[i] = opcode_i;
                assign RSOAddrs[i] = address_i;
                assign RSFuncUnitTypes[i] = funcUnitType_i;
                assign RSMajIDs[i] = majID_i;
                assign RSminIDs[i] = minID_i;
                assign RSis64Bits[i] = is64Bit_i;
                assign RSOPids[i] = pid_i;
                assign RSOTids[i] = tid_i;
                assign RSOregAccessPatterns[i] = {op1rw_i, op2rw_i, op3rw_i, op4rw_i};
                assign RSisRegs[i] = {op1IsReg_i, op2IsReg_i, op3IsReg_i, op4IsReg_i};
                assign RSBody[i] = body_i;
                //enable the output
                assign enable_o = 1;
            end
            else if(RSIsFree[i] == 1 && entryFound == 1)
            begin//found a second open entry
                assign notFull == 1;
            end
        end

        //if we are full for next cycle, output a stall
        if(notFull == 0)
            assign isFull_o = 1;
        else
            assign isFull_o = 0;

        //now were written, we can read


    end
    else
    begin//Neither enabled or resetting
        //disable the output
        assign enable_o = 0;
    end
end
endmodule