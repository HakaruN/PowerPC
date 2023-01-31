`timescale 1ns / 1ps
`define DEBUG
`define DEBUG_PRINT

/*///////////////In order instruction queue////////////////////
This queue takes instructions from the decoders and seriealises them all into a correct, program order instruction sequence.
This is needed because an instruction may end up generating multiple uops over a couple of cycles, whilst this is happening the
other decoders can be generating instructions that should be after the complex instruction has completed yet it would appear part way through.

When instructions come in, the hardware looks at the instructions and allocates space in the queue for the full instruction. This works by
checking if the instruction is the first instruction in the possible sequence of uops coming from a single macroop.

So if instNMinID == 0 then we know we need to allocate instNNumMicroOps worth of space in the queue.
If instNMinID > 0, we have already allocated the space and need to write the uop to the already allocated space.


On output up to 4 instructions per cycle (for now) can be read from the queue for dispatch to the OoO units. Because of the
above algoritm, this means that the OoO units will only see instructions coming in program order.
The way the queue is able to find previously allocated space 

TODO: Add buffering before this stage so we can fetch closer tothe limmit of the queue


*//////////////////////////////////////////////////////////////

module InOrderInstQueue
#(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 32, parameter TidSize = 64,
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter instMinIdWidth = 5,//width of inst minor ID
    parameter primOpcodeSize = 6,
    parameter opcodeSize = 12,
    parameter regSize = 5,
    parameter regAccessPatternSize = 2,//2 bit field, [0] == is read, [1] == is writen. Both can be true EG: (A = A + B)
    parameter funcUnitCodeSize = 3,

    parameter queueIndexWidth = 10,//1024 instructions long queue
    parameter numQueueEntries = 2**queueIndexWidth,
    parameter IOQInstance = 0
)
(
    input wire clock_i, reset_i, 
    //Inputs of the 4 instructions coming in from the decoders
    input wire instr1En_i, instr2En_i, instr3En_i, instr4En_i, 
    input wire [0:25-1] inst1Format_i, inst2Format_i, inst3Format_i, inst4Format_i, 
    input wire [0:opcodeSize-1] inst1Opcode_i, inst2Opcode_i, inst3Opcode_i, inst4Opcode_i, 
    input wire [0:addressWidth-1] inst1address_i, inst2address_i, inst3address_i, inst4address_i, 
    input wire [0:funcUnitCodeSize-1] inst1funcUnitType_i, inst2funcUnitType_i, inst3funcUnitType_i, inst4funcUnitType_i, 
    input wire [0:instructionCounterWidth-1] inst1MajID_i, inst2MajID_i, inst3MajID_i, inst4MajID_i, 
    input wire [0:instMinIdWidth-1] inst1MinID_i, inst2MinID_i, inst3MinID_i, inst4MinID_i, 
    input wire [0:instMinIdWidth-1] inst1NumMicroOps_i, inst2NumMicroOps_i, inst3NumMicroOps_i, inst4NumMicroOps_i, 
    input wire inst1Is64Bit_i, inst2Is64Bit_i, inst3Is64Bit_i, inst4Is64Bit_i,
    input wire [0:PidSize-1] inst1Pid_i, inst2Pid_i, inst3Pid_i, inst4Pid_i, 
    input wire [0:TidSize-1] inst1Tid_i, inst2Tid_i, inst3Tid_i, inst4Tid_i, 
    input wire [0:regAccessPatternSize-1] inst1op1rw_i, inst1op2rw_i, inst1op3rw_i, inst1op4rw_i,
    input wire [0:regAccessPatternSize-1] inst2op1rw_i, inst2op2rw_i, inst2op3rw_i, inst2op4rw_i,
    input wire [0:regAccessPatternSize-1] inst3op1rw_i, inst3op2rw_i, inst3op3rw_i, inst3op4rw_i,
    input wire [0:regAccessPatternSize-1] inst4op1rw_i, inst4op2rw_i, inst4op3rw_i, inst4op4rw_i,
    input wire inst1op1IsReg_i, inst1op2IsReg_i, inst1op3IsReg_i, inst1op4IsReg_i,
    input wire inst2op1IsReg_i, inst2op2IsReg_i, inst2op3IsReg_i, inst2op4IsReg_i,
    input wire inst3op1IsReg_i, inst3op2IsReg_i, inst3op3IsReg_i, inst3op4IsReg_i,
    input wire inst4op1IsReg_i, inst4op2IsReg_i, inst4op3IsReg_i, inst4op4IsReg_i,
    input wire inst1ModifiesCR_i, inst2ModifiesCR_i, inst3ModifiesCR_i, inst4ModifiesCR_i, 
    input wire [0:64-1] inst1Body_i, inst2Body_i, inst3Body_i, inst4Body_i, 

    //Outputs to the OoO backend
    input wire readEnable_i,
    output reg outputEnable_o,
    output reg [0:1] numInstructionsOut_o,
    output reg [0:25-1] inst1Format_o, inst2Format_o, inst3Format_o, inst4Format_o,
    output reg [0:opcodeSize-1] inst1Opcode_o, inst2Opcode_o, inst3Opcode_o, inst4Opcode_o,
    output reg [0:addressWidth-1] inst1Address_o, inst2Address_o, inst3Address_o, inst4Address_o,
    output reg [0:funcUnitCodeSize-1] inst1FuncUnit_o, inst2FuncUnit_o, inst3FuncUnit_o, inst4FuncUnit_o, 
    output reg [0:instructionCounterWidth-1] inst1MajId_o, inst2MajId_o, inst3MajId_o, inst4MajId_o, 
    output reg [0:instMinIdWidth-1] inst1MinID_o, inst2MinID_o, inst3MinID_o, inst4MinID_o, 
    output reg [0:instMinIdWidth-1] inst1NumUOps_o, inst2NumUOps_o, inst3NumUOps_o, inst4NumUOps_o, 
    output reg inst1Is64Bit_o, inst2Is64Bit_o, inst3Is64Bit_o, inst4Is64Bit_o, 
    output reg [0:PidSize-1] inst1Pid_o, inst2Pid_o, inst3Pid_o, inst4Pid_o, 
    output reg [0:TidSize-1] inst1Tid_o, inst2Tid_o, inst3Tid_o, inst4Tid_o, 
    output reg [0:regAccessPatternSize-1] inst1op1rw_o, inst1op2rw_o, inst1op3rw_o, inst1op4rw_o,
    output reg [0:regAccessPatternSize-1] inst2op1rw_o, inst2op2rw_o, inst2op3rw_o, inst2op4rw_o,
    output reg [0:regAccessPatternSize-1] inst3op1rw_o, inst3op2rw_o, inst3op3rw_o, inst3op4rw_o,
    output reg [0:regAccessPatternSize-1] inst4op1rw_o, inst4op2rw_o, inst4op3rw_o, inst4op4rw_o,
    output reg inst1op1IsReg_o, inst1op2IsReg_o, inst1op3IsReg_o, inst1op4IsReg_o,
    output reg inst2op1IsReg_o, inst2op2IsReg_o, inst2op3IsReg_o, inst2op4IsReg_o,
    output reg inst3op1IsReg_o, inst3op2IsReg_o, inst3op3IsReg_o, inst3op4IsReg_o,
    output reg inst4op1IsReg_o, inst4op2IsReg_o, inst4op3IsReg_o, inst4op4IsReg_o,
    output reg inst1ModifiesCR_o, inst2ModifiesCR_o, inst3ModifiesCR_o, inst4ModifiesCR_o, 
    output reg [0:64-1] inst1Body_o, inst2Body_o, inst3Body_o, inst4Body_o,

    //generic state outputs
	output reg [0:queueIndexWidth-1] head_o, tail_o,//dequeue from head, enqueue to tail
	output reg isEmpty_o, isFull_o
)


    reg isDone [0:numQueueEntries-1];
    //This tracks how many uops remain to write to the instruction. When it is zero, all uops in the instruction have been queued so can be issued.
    //numUopsRemaining[i] maps to instruction based at majIDMap[i] and *queue[i].
    reg [0:inst1MinID_i-1] numUopsRemaining [0:numQueueEntries-1];

    //Index I in this queue is high when index I in the queue contains the first uop (minId == 0). Otherwise index I is zero.
    //This allows us to find the begining of an instruction in the queue
    reg mapEntryIsValid [0:numQueueEntries-1];

    //When we have found the begining of the instruction
    reg [0:primOpcodeSize-1] majIDMap [0:numQueueEntries-1];//maps an entry in the queue to a macro instruction

    //Instruction queue
    reg [0:25-1] formatQueue [0:numQueueEntries-1];
    reg [0:opcodeSize-1] opcodeQueue [0:numQueueEntries-1];
    reg [0:addressWidth-1] addressQueue [0:numQueueEntries-1];
    reg [0:funcUnitCodeSize-1] funUnitCodeQueue [0:numQueueEntries-1];
    reg [0:instructionCounterWidth-1] majIDQueue [0:numQueueEntries-1];
    reg [0:instMinIdWidth-1] minIDQueue [0:numQueueEntries-1];
    reg [0:instMinIdWidth-1] numMicroOpsQueue [0:numQueueEntries-1];
    reg is64BitsQueue [0:numQueueEntries-1];
    reg [0:PidSize-1] pidQueue [0:numQueueEntries-1];
    reg [0:TidSize-1] tidQueue [0:numQueueEntries-1];
    reg [0:regAccessPatternSize] op1wrQueue [0:numQueueEntries-1];
    reg [0:regAccessPatternSize] op2wrQueue [0:numQueueEntries-1];
    reg [0:regAccessPatternSize] op3wrQueue [0:numQueueEntries-1];
    reg [0:regAccessPatternSize] op4wrQueue [0:numQueueEntries-1];
    reg op1IsRegQueue [0:numQueueEntries-1];
    reg op2IsRegQueue [0:numQueueEntries-1];
    reg op3IsRegQueue [0:numQueueEntries-1];
    reg op4IsRegQueue [0:numQueueEntries-1];
    reg modifiesCRQueue [0:numQueueEntries-1];
    reg [0:64-1] bodyQueue [0:numQueueEntries-1];

    integer i;//loop ctr

//Debuging output file handle
`ifdef DEBUG_PRINT
integer debugFID;
`endif

    always @(posedge clock_i)
    begin
        if(reset_i)
        begin
            `ifdef DEBUG_PRINT
            case(IOQInstance)//If we have multiple decoders, they each get different files. The second number indicates the decoder# log file.
            0: begin 
                debugFID = $fopen("IOInstQ0.log", "w");
            end
            1: begin 
                debugFID = $fopen("IOInstQ1.log", "w");
            end
            2: begin 
                debugFID = $fopen("IOInstQ2.log", "w");
            end
            3: begin 
                debugFID = $fopen("IOInstQ3.log", "w");
            end
            4: begin 
                debugFID = $fopen("IOInstQ4.log", "w");
            end
            5: begin 
                debugFID = $fopen("IOInstQ5.log", "w");
            end
            6: begin 
                debugFID = $fopen("IOInstQ6.log", "w");
            end
            7: begin 
                debugFID = $fopen("IOInstQ7.log", "w");
            end
            endcase
            `endif
            head_o <= 0; tail_o <= 0;
			isFull_o <= 0; isEmpty_o <= 1;

            for(i = 0; i < numQueueEntries; i = i + 1)
            begin//Reset the queue state
                isDone[i] <= 0;
                mapEntryIsValid[i] <= 0;
            end
            `ifdef DEBUG $display("IOQ %d Reseting.", IOQInstance); `endif
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "IOQ %d Reseting", IOQInstance); `endif
        end
        else
        begin

            if(isFull_o)//if queue full
            begin
				`ifdef DEBUG $display("In-order queue %d full", IOQInstance); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "In-order queue %d full", IOQInstance); `endif
			end
            else//not full, write to buffer from inputs and check if we could be full next cycle.
            begin
                //Find out how many instructions are coming in this cycle, because instructions are always aligned to the los ID decodes, we only have to check moving up from 1 up to 4
                if(instr1En_i == 0 && instr2En_i == 0 && instr3En_i == 0 && instr4En_i == 0)
                begin//0 instructions coming in                    
                end
                else if(instr1En_i == 1 && instr2En_i == 0 && instr3En_i == 0 && instr4En_i == 0)
                begin//1 instruction coming in
                    if(inst1MinID_i == 0)//This is the first uop from the macro op, so write the uop to the tail reserve space for the rest of inst
                    begin
                        //Copy inst
                        formatQueue[tail_o] <= inst1Format_i; opcodeQueue[tail_o] <= inst1Opcode_i;
                        addressQueue[tail_o] <= inst1address_i; funUnitCodeQueue[tail_o] <= inst1funcUnitType_i;
                        majIDQueue[tail_o] <= inst1MajID_i; minIDQueue[tail_o] <= inst1MinID_i;
                        numMicroOpsQueue[tail_o] <= inst1NumMicroOps_i; is64BitsQueue[tail_o] <= inst1Is64Bit_i;
                        pidQueue[tail_o] <= inst1Pid_i; tidQueue[tail_o] <= inst1Tid_i;
                        op1wrQueue[tail_o] <= inst1op1rw_i; op2wrQueue[tail_o] <= inst1op2rw_i;
                        op3wrQueue[tail_o] <= inst1op3rw_i; op4wrQueue[tail_o] <= inst1op4rw_i;
                        op1IsRegQueue[tail_o] <= inst1op1IsReg_i; op2IsRegQueue[tail_o] <= inst1op2IsReg_i;
                        op3IsRegQueue[tail_o] <= inst1op3IsReg_i; op4IsRegQueue[tail_o] <= inst1op4IsReg_i;
                        modifiesCRQueue[tail_o] <= inst1ModifiesCR_i; bodyQueue[tail_o] <= inst1Body_i;
                        //Record the Macro op (majID) ID base-uop (minID == 0) in the map to find when we come to write the later uops
                        majIDMap[tail_o] <= inst1MajID_i;
                        //Set the isValid bit for the entry
                        mapEntryIsValid[tail_o] <= 1;
                        //set is done
                        isDone[tail_o] <= 1;
                        //set the number of instructions remaining
                        numUopsRemaining[tail_o] <= inst1NumMicroOps_i-1;
                    end
                    else
                    begin//We need to look up where the uop needs to go
                        for(i = 0; i < numQueueEntries; i = i + 1)//Go through the map to find the base uop
                        begin
                            if(majIDMap[i] == inst1MajID_i && mapEntryIsValid[i] == 1)//we've found the base uop for the instruction, use it as a reference to find our uops reserved space and write to it
                            begin
                                formatQueue[i] <= inst1Format_i; opcodeQueue[i] <= inst1Opcode_i;
                                addressQueue[i] <= inst1address_i; funUnitCodeQueue[i] <= inst1funcUnitType_i;
                                majIDQueue[i] <= inst1MajID_i; minIDQueue[i] <= inst1MinID_i;
                                numMicroOpsQueue[i] <= inst1NumMicroOps_i; is64BitsQueue[i] <= inst1Is64Bit_i;
                                pidQueue[i] <= inst1Pid_i; tidQueue[i] <= inst1Tid_i;
                                op1wrQueue[i] <= inst1op1rw_i; op2wrQueue[i] <= inst1op2rw_i;
                                op3wrQueue[i] <= inst1op3rw_i; op4wrQueue[i] <= inst1op4rw_i;
                                op1IsRegQueue[i] <= inst1op1IsReg_i; op2IsRegQueue[i] <= inst1op2IsReg_i;
                                op3IsRegQueue[i] <= inst1op3IsReg_i; op4IsRegQueue[i] <= inst1op4IsReg_i;
                                modifiesCRQueue[i] <= inst1ModifiesCR_i; bodyQueue[i] <= inst1Body_i;
                                //set is done
                                isDone[i] <= 1;
                                //subtract a remaining uop from the counter
                                numUopsRemaining[i] <= numUopsRemaining[i] - 1;
                            end
                        end
                    end
                    //Reserve space for the entire instruction (inc tail by numMicoOps)
                    tail_o <= (tail_o + inst1NumMicroOps_i) % (2**queueIndexWidth);
                    //Check if we will then be full after 4 more max sized instructions are allocating next cycle (worst case)
                    if((tail_o + (inst1NumMicroOps_i) + (4*(2**instMinIdWidth))) % (2**queueIndexWidth) >= head_o)
                    begin
                        //Were full
                        `ifdef DEBUG $display("IOQ %d is full", IOQInstanc); `endif
                        `ifdef DEBUG_PRINT $fdisplay(debugFID, "IOQ %d is full", IOQInstanc); `endif
                        isFull_o <= 1;
                    end
                    isEmpty_o <= 0;
                    `ifdef DEBUG $display("IOQ %d Enqueing 1 instruction. Reservice space for a %d instructions.", IOQInstance, inst1NumMicroOps_i); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "IOQ %d Enqueing 1 instruction. Reservice space for a %d instructions.", IOQInstance, inst1NumMicroOps_i); `endif
                end
                else if(instr1En_i == 1 && instr2En_i == 1 && instr3En_i == 0 && instr4En_i == 0)
                begin//2 instructions coming in
                    ///inst 1:
                    if(inst1MinID_i == 0)//This is the first uop from the macro op, so write the uop to the tail reserve space for the rest of inst
                    begin
                        //Copy insts
                        formatQueue[tail_o]         <= inst1Format_i;       opcodeQueue[tail_o]         <= inst1Opcode_i;                 
                        addressQueue[tail_o]        <= inst1address_i;      funUnitCodeQueue[tail_o]    <= inst1funcUnitType_i;    
                        majIDQueue[tail_o]          <= inst1MajID_i;        minIDQueue[tail_o]          <= inst1MinID_i;                     
                        numMicroOpsQueue[tail_o]    <= inst1NumMicroOps_i;  is64BitsQueue[tail_o]       <= inst1Is64Bit_i;    
                        pidQueue[tail_o]            <= inst1Pid_i;          tidQueue[tail_o]            <= inst1Tid_i;                             
                        op1wrQueue[tail_o]          <= inst1op1rw_i;        op2wrQueue[tail_o]          <= inst1op2rw_i;                     
                        op3wrQueue[tail_o]          <= inst1op3rw_i;        op4wrQueue[tail_o]          <= inst1op4rw_i;                     
                        op1IsRegQueue[tail_o]       <= inst1op1IsReg_i;     op2IsRegQueue[tail_o]       <= inst1op2IsReg_i;         
                        op3IsRegQueue[tail_o]       <= inst1op3IsReg_i;     op4IsRegQueue[tail_o]       <= inst1op4IsReg_i;         
                        modifiesCRQueue[tail_o]     <= inst1ModifiesCR_i;   bodyQueue[tail_o]           <= inst1Body_i;                                        
                        //Record the Macro op (majID) ID base-uop (minID == 0) in the map to find when we come to write the later uops
                        majIDMap[tail_o] <= inst1MajID_i;
                        //Set the isValid bit for the entry
                        mapEntryIsValid[tail_o] <= 1;
                        //set is done
                        isDone[tail_o] <= 1
                        //set the number of instructions remaining
                        numUopsRemaining[tail_o] <= inst1NumMicroOps_i-1;
                    end
                    else
                    begin//We need to look up where the uop needs to go
                        for(i = 0; i < numQueueEntries; i = i + 1)//Go through the map to find the base uop
                        begin
                            if(majIDMap[i] == inst1MajID_i && mapEntryIsValid[i] == 1)//we've found the base uop for the instruction, use it as a reference to find our uops reserved space and write to it
                            begin
                                formatQueue[i] <=       inst1Format_i;      opcodeQueue[i] <=       inst1Opcode_i;             
                                addressQueue[i] <=      inst1address_i;     funUnitCodeQueue[i] <=  inst1funcUnitType_i;
                                majIDQueue[i] <=        inst1MajID_i;       minIDQueue[i] <=        inst1MinID_i;                 
                                numMicroOpsQueue[i] <=  inst1NumMicroOps_i; is64BitsQueue[i] <=     inst1Is64Bit_i;
                                pidQueue[i] <=          inst1Pid_i;         tidQueue[i] <=          inst1Tid_i;                         
                                op1wrQueue[i] <=        inst1op1rw_i;       op2wrQueue[i] <=        inst1op2rw_i;                 
                                op3wrQueue[i] <=        inst1op3rw_i;       op4wrQueue[i] <=        inst1op4rw_i;                 
                                op1IsRegQueue[i] <=     inst1op1IsReg_i;    op2IsRegQueue[i] <=     inst1op2IsReg_i;     
                                op3IsRegQueue[i] <=     inst1op3IsReg_i;    op4IsRegQueue[i] <=     inst1op4IsReg_i;     
                                modifiesCRQueue[i] <=   inst1ModifiesCR_i;  bodyQueue[i] <=         inst1Body_i;         
                                //set is done
                                isDone[i] <= 1;
                                //subtract a remaining uop from the counter
                                numUopsRemaining[i] <= numUopsRemaining[i] - 1;
                            end
                        end
                    end
                    ///inst 2:
                    if(inst2MinID_i == 0)//This is the first uop from the macro op, so write the uop to the tail reserve space for the rest of inst
                    begin
                        //Copy insts
                        formatQueue[tail_o + inst1NumMicroOps_i]            <= inst2Format_i;       opcodeQueue[tail_o + inst1NumMicroOps_i] <=         inst2Opcode_i;                 
                        addressQueue[tail_o + inst1NumMicroOps_i]           <= inst2address_i;      funUnitCodeQueue[tail_o + inst1NumMicroOps_i] <=    inst2funcUnitType_i;    
                        majIDQueue[tail_o + inst1NumMicroOps_i]             <= inst2MajID_i;        minIDQueue[tail_o + inst1NumMicroOps_i] <=          inst2MinID_i;                     
                        numMicroOpsQueue[tail_o + inst1NumMicroOps_i]       <= inst2NumMicroOps_i;  is64BitsQueue[tail_o + inst1NumMicroOps_i] <=       inst2Is64Bit_i;    
                        pidQueue[tail_o + inst1NumMicroOps_i]               <= inst2Pid_i;          tidQueue[tail_o + inst1NumMicroOps_i] <=            inst2Tid_i;                             
                        op1wrQueue[tail_o + inst1NumMicroOps_i]             <= inst2op1rw_i;        op2wrQueue[tail_o + inst1NumMicroOps_i] <=          inst2op2rw_i;                     
                        op3wrQueue[tail_o + inst1NumMicroOps_i]             <= inst2op3rw_i;        op4wrQueue[tail_o + inst1NumMicroOps_i] <=          inst2op4rw_i;                     
                        op1IsRegQueue[tail_o + inst1NumMicroOps_i]          <= inst2op1IsReg_i;     op2IsRegQueue[tail_o + inst1NumMicroOps_i] <=       inst2op2IsReg_i;         
                        op3IsRegQueue[tail_o + inst1NumMicroOps_i]          <= inst2op3IsReg_i;     op4IsRegQueue[tail_o + inst1NumMicroOps_i] <=       inst2op4IsReg_i;         
                        modifiesCRQueue[tail_o + inst1NumMicroOps_i]        <= inst2ModifiesCR_i;   bodyQueue[tail_o + inst1NumMicroOps_i] <=           inst2Body_i;                                        
                        //Record the Macro op (majID) ID base-uop (minID == 0) in the map to find when we come to write the later uops
                        majIDMap[tail_o + inst1NumMicroOps_i] <= inst2MajID_i;
                        //Set the isValid bit for the entry
                        mapEntryIsValid[tail_o + inst1NumMicroOps_i] <= 1;
                        //set is done
                        isDone[tail_o + inst1NumMicroOps_i] <= 1;
                        //set the number of instructions remaining
                        numUopsRemaining[tail_o + inst1NumMicroOps_i] <= inst2NumMicroOps_i-1;
                    end
                    else
                    begin//We need to look up where the uop needs to go
                        for(i = 0; i < numQueueEntries; i = i + 1)//Go through the map to find the base uop
                        begin
                            if(majIDMap[i] == inst2MajID_i && mapEntryIsValid[i] == 1)//we've found the base uop for the instruction, use it as a reference to find our uops reserved space and write to it
                            begin
                                formatQueue[i] <=       inst2Format_i;      opcodeQueue[i] <=       inst2Opcode_i;             
                                addressQueue[i] <=      inst2address_i;     funUnitCodeQueue[i] <=  inst2funcUnitType_i;
                                majIDQueue[i] <=        inst2MajID_i;       minIDQueue[i] <=        inst2MinID_i;                 
                                numMicroOpsQueue[i] <=  inst2NumMicroOps_i; is64BitsQueue[i] <=     inst2Is64Bit_i;
                                pidQueue[i] <=          inst2Pid_i;         tidQueue[i] <=          inst2Tid_i;                         
                                op1wrQueue[i] <=        inst2op1rw_i;       op2wrQueue[i] <=        inst2op2rw_i;                 
                                op3wrQueue[i] <=        inst2op3rw_i;       op4wrQueue[i] <=        inst2op4rw_i;                 
                                op1IsRegQueue[i] <=     inst2op1IsReg_i;    op2IsRegQueue[i] <=     inst2op2IsReg_i;     
                                op3IsRegQueue[i] <=     inst2op3IsReg_i;    op4IsRegQueue[i] <=     inst2op4IsReg_i;     
                                modifiesCRQueue[i] <=   inst2ModifiesCR_i;  bodyQueue[i] <=         inst2Body_i;         
                                numUopsRemaining[i] <=  numUopsRemaining[i] - 1;
                                //set is done
                                isDone[i] <= 1;
                                //subtract a remaining uop from the counter
                            end
                        end
                    end
                    //Reserve space for the entire instruction (inc tail by numMicoOps)                        
                    tail_o <= (tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i) % (2**queueIndexWidth); 
                    //Check if we will then be full after 4 more max sized instructions are allocating next cycle (worst case)
                    if((tail_o + (inst1NumMicroOps_i + inst2NumMicroOps_i) + (4*(2**instMinIdWidth))) % (2**queueIndexWidth) >= head_o)
                    begin
                        //Were full
                        `ifdef DEBUG $display("IOQ %d is full", IOQInstanc); `endif
                        `ifdef DEBUG_PRINT $fdisplay(debugFID, "IOQ %d is full", IOQInstanc); `endif
                        isFull_o <= 1;
                    end 
                    isEmpty_o <= 0;
                    `ifdef DEBUG $display("IOQ %d Enqueing 2 instructions. Reservice space for a %d instructions.", IOQInstance, inst1NumMicroOps_i+inst2NumMicroOps_i); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "IOQ %d Enqueing 2 instructions. Reservice space for a %d instructions.", IOQInstance, inst1NumMicroOps_i+inst2NumMicroOps_i); `endif
                end
                else if(instr1En_i == 1 && instr2En_i == 1 && instr3En_i == 1 && instr4En_i == 0)
                begin//3 instructions coming in
                    ///inst 1:
                    if(inst1MinID_i == 0)//This is the first uop from the macro op, so write the uop to the tail reserve space for the rest of inst
                    begin
                        //Copy insts
                        formatQueue[tail_o]         <= inst1Format_i;       opcodeQueue[tail_o]         <= inst1Opcode_i;                 
                        addressQueue[tail_o]        <= inst1address_i;      funUnitCodeQueue[tail_o]    <= inst1funcUnitType_i;    
                        majIDQueue[tail_o]          <= inst1MajID_i;        minIDQueue[tail_o]          <= inst1MinID_i;                     
                        numMicroOpsQueue[tail_o]    <= inst1NumMicroOps_i;  is64BitsQueue[tail_o]       <= inst1Is64Bit_i;    
                        pidQueue[tail_o]            <= inst1Pid_i;          tidQueue[tail_o]            <= inst1Tid_i;                             
                        op1wrQueue[tail_o]          <= inst1op1rw_i;        op2wrQueue[tail_o]          <= inst1op2rw_i;                     
                        op3wrQueue[tail_o]          <= inst1op3rw_i;        op4wrQueue[tail_o]          <= inst1op4rw_i;                     
                        op1IsRegQueue[tail_o]       <= inst1op1IsReg_i;     op2IsRegQueue[tail_o]       <= inst1op2IsReg_i;         
                        op3IsRegQueue[tail_o]       <= inst1op3IsReg_i;     op4IsRegQueue[tail_o]       <= inst1op4IsReg_i;         
                        modifiesCRQueue[tail_o]     <= inst1ModifiesCR_i;   bodyQueue[tail_o]           <= inst1Body_i;                                      
                        //Record the Macro op (majID) ID base-uop (minID == 0) in the map to find when we come to write the later uops
                        majIDMap[tail_o] <= inst1MajID_i;
                        //Set the isValid bit for the entry
                        mapEntryIsValid[tail_o] <= 1;
                        //set is done
                        isDone[tail_o] <= 1;
                        //set the number of instructions remaining
                        numUopsRemaining[tail_o] <= inst1NumMicroOps_i-1;
                    end
                    else
                    begin//We need to look up where the uop needs to go
                        for(i = 0; i < numQueueEntries; i = i + 1)//Go through the map to find the base uop
                        begin
                            if(majIDMap[i] == inst1MajID_i && mapEntryIsValid[i] == 1)//we've found the base uop for the instruction, use it as a reference to find our uops reserved space and write to it
                            begin
                                formatQueue[i] <=       inst1Format_i;      opcodeQueue[i] <=       inst1Opcode_i;             
                                addressQueue[i] <=      inst1address_i;     funUnitCodeQueue[i] <=  inst1funcUnitType_i;
                                majIDQueue[i] <=        inst1MajID_i;       minIDQueue[i] <=        inst1MinID_i;                 
                                numMicroOpsQueue[i] <=  inst1NumMicroOps_i; is64BitsQueue[i] <=     inst1Is64Bit_i;
                                pidQueue[i] <=          inst1Pid_i;         tidQueue[i] <=          inst1Tid_i;                         
                                op1wrQueue[i] <=        inst1op1rw_i;       op2wrQueue[i] <=        inst1op2rw_i;                 
                                op3wrQueue[i] <=        inst1op3rw_i;       op4wrQueue[i] <=        inst1op4rw_i;                 
                                op1IsRegQueue[i] <=     inst1op1IsReg_i;    op2IsRegQueue[i] <=     inst1op2IsReg_i;     
                                op3IsRegQueue[i] <=     inst1op3IsReg_i;    op4IsRegQueue[i] <=     inst1op4IsReg_i;     
                                modifiesCRQueue[i] <=   inst1ModifiesCR_i;  bodyQueue[i] <=         inst1Body_i;         
                                //set is done
                                isDone[i] <= 1;
                                //subtract a remaining uop from the counter
                                numUopsRemaining[i] <= numUopsRemaining[i] - 1;
                            end
                        end
                    end
                    ///inst 2:
                    if(inst2MinID_i == 0)//This is the first uop from the macro op, so write the uop to the tail reserve space for the rest of inst
                    begin
                        //Copy insts
                        formatQueue[tail_o + inst1NumMicroOps_i]            <= inst2Format_i;       opcodeQueue[tail_o + inst1NumMicroOps_i] <=         inst2Opcode_i;                 
                        addressQueue[tail_o + inst1NumMicroOps_i]           <= inst2address_i;      funUnitCodeQueue[tail_o + inst1NumMicroOps_i] <=    inst2funcUnitType_i;    
                        majIDQueue[tail_o + inst1NumMicroOps_i]             <= inst2MajID_i;        minIDQueue[tail_o + inst1NumMicroOps_i] <=          inst2MinID_i;                     
                        numMicroOpsQueue[tail_o + inst1NumMicroOps_i]       <= inst2NumMicroOps_i;  is64BitsQueue[tail_o + inst1NumMicroOps_i] <=       inst2Is64Bit_i;    
                        pidQueue[tail_o + inst1NumMicroOps_i]               <= inst2Pid_i;          tidQueue[tail_o + inst1NumMicroOps_i] <=            inst2Tid_i;                             
                        op1wrQueue[tail_o + inst1NumMicroOps_i]             <= inst2op1rw_i;        op2wrQueue[tail_o + inst1NumMicroOps_i] <=          inst2op2rw_i;                     
                        op3wrQueue[tail_o + inst1NumMicroOps_i]             <= inst2op3rw_i;        op4wrQueue[tail_o + inst1NumMicroOps_i] <=          inst2op4rw_i;                     
                        op1IsRegQueue[tail_o + inst1NumMicroOps_i]          <= inst2op1IsReg_i;     op2IsRegQueue[tail_o + inst1NumMicroOps_i] <=       inst2op2IsReg_i;         
                        op3IsRegQueue[tail_o + inst1NumMicroOps_i]          <= inst2op3IsReg_i;     op4IsRegQueue[tail_o + inst1NumMicroOps_i] <=       inst2op4IsReg_i;         
                        modifiesCRQueue[tail_o + inst1NumMicroOps_i]        <= inst2ModifiesCR_i;   bodyQueue[tail_o + inst1NumMicroOps_i] <=           inst2Body_i;                                       
                        //Record the Macro op (majID) ID base-uop (minID == 0) in the map to find when we come to write the later uops
                        majIDMap[tail_o + inst1NumMicroOps_i] <= inst2MajID_i;
                        //Set the isValid bit for the entry
                        mapEntryIsValid[tail_o + inst1NumMicroOps_i] <= 1;
                        //set is done
                        isDone[tail_o + inst1NumMicroOps_i] <= 1;
                        //set the number of instructions remaining
                        numUopsRemaining[tail_o + inst1NumMicroOps_i] <= inst2NumMicroOps_i-1;
                    end
                    else
                    begin//We need to look up where the uop needs to go
                        for(i = 0; i < numQueueEntries; i = i + 1)//Go through the map to find the base uop
                        begin
                            if(majIDMap[i] == inst2MajID_i && mapEntryIsValid[i] == 1)//we've found the base uop for the instruction, use it as a reference to find our uops reserved space and write to it
                            begin
                                formatQueue[i] <=       inst2Format_i;      opcodeQueue[i] <=       inst2Opcode_i;             
                                addressQueue[i] <=      inst2address_i;     funUnitCodeQueue[i] <=  inst2funcUnitType_i;
                                majIDQueue[i] <=        inst2MajID_i;       minIDQueue[i] <=        inst2MinID_i;                 
                                numMicroOpsQueue[i] <=  inst2NumMicroOps_i; is64BitsQueue[i] <=     inst2Is64Bit_i;
                                pidQueue[i] <=          inst2Pid_i;         tidQueue[i] <=          inst2Tid_i;                         
                                op1wrQueue[i] <=        inst2op1rw_i;       op2wrQueue[i] <=        inst2op2rw_i;                 
                                op3wrQueue[i] <=        inst2op3rw_i;       op4wrQueue[i] <=        inst2op4rw_i;                 
                                op1IsRegQueue[i] <=     inst2op1IsReg_i;    op2IsRegQueue[i] <=     inst2op2IsReg_i;     
                                op3IsRegQueue[i] <=     inst2op3IsReg_i;    op4IsRegQueue[i] <=     inst2op4IsReg_i;     
                                modifiesCRQueue[i] <=   inst2ModifiesCR_i;  bodyQueue[i] <=         inst2Body_i;         
                                //set is done
                                isDone[i] <= 1;
                                //subtract a remaining uop from the counter
                                numUopsRemaining[i] <= numUopsRemaining[i] - 1;
                            end
                        end
                    end
                    ///inst 3:
                    if(inst3MinID_i == 0)//This is the first uop from the macro op, so write the uop to the tail reserve space for the rest of inst
                    begin
                        //Copy insts
                        formatQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i]            <= inst3Format_i;       opcodeQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <=         inst3Opcode_i;                 
                        addressQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i]           <= inst3address_i;      funUnitCodeQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <=    inst3funcUnitType_i;    
                        majIDQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i]             <= inst3MajID_i;        minIDQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <=          inst3MinID_i;                     
                        numMicroOpsQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i]       <= inst3NumMicroOps_i;  is64BitsQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <=       inst3Is64Bit_i;    
                        pidQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i]               <= inst3Pid_i;          tidQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <=            inst3Tid_i;                             
                        op1wrQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i]             <= inst3op1rw_i;        op2wrQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <=          inst3op2rw_i;                     
                        op3wrQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i]             <= inst3op3rw_i;        op4wrQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <=          inst3op4rw_i;                     
                        op1IsRegQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i]          <= inst3op1IsReg_i;     op2IsRegQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <=       inst3op2IsReg_i;         
                        op3IsRegQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i]          <= inst3op3IsReg_i;     op4IsRegQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <=       inst3op4IsReg_i;         
                        modifiesCRQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i]        <= inst3ModifiesCR_i;   bodyQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <=           inst3Body_i;             
                           
                        //Record the Macro op (majID) ID base-uop (minID == 0) in the map to find when we come to write the later uops
                        majIDMap[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <= inst3MajID_i;
                        //Set the isValid bit for the entry
                        mapEntryIsValid[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <= 1;
                        //set is done
                        isDone[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <= 1;
                        //set the number of instructions remaining
                        numUopsRemaining[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <= inst3NumMicroOps_i-1;
                    end
                    else
                    begin//We need to look up where the uop needs to go
                        for(i = 0; i < numQueueEntries; i = i + 1)//Go through the map to find the base uop
                        begin
                            if(majIDMap[i] == inst3MajID_i && mapEntryIsValid[i] == 1)//we've found the base uop for the instruction, use it as a reference to find our uops reserved space and write to it
                            begin
                                formatQueue[i] <=       inst3Format_i;      opcodeQueue[i] <=       inst3Opcode_i;             
                                addressQueue[i] <=      inst3address_i;     funUnitCodeQueue[i] <=  inst3funcUnitType_i;
                                majIDQueue[i] <=        inst3MajID_i;       minIDQueue[i] <=        inst3MinID_i;                 
                                numMicroOpsQueue[i] <=  inst3NumMicroOps_i; is64BitsQueue[i] <=     inst3Is64Bit_i;
                                pidQueue[i] <=          inst3Pid_i;         tidQueue[i] <=          inst3Tid_i;                         
                                op1wrQueue[i] <=        inst3op1rw_i;       op2wrQueue[i] <=        inst3op2rw_i;                 
                                op3wrQueue[i] <=        inst3op3rw_i;       op4wrQueue[i] <=        inst3op4rw_i;                 
                                op1IsRegQueue[i] <=     inst3op1IsReg_i;    op2IsRegQueue[i] <=     inst3op2IsReg_i;     
                                op3IsRegQueue[i] <=     inst3op3IsReg_i;    op4IsRegQueue[i] <=     inst3op4IsReg_i;     
                                modifiesCRQueue[i] <=   inst3ModifiesCR_i;  bodyQueue[i] <=         inst3Body_i;         
                                //set is done
                                isDone[i] <= 1;
                                numUopsRemaining[i] <=  numUopsRemaining[i] - 1;
                            end
                        end
                    end
                    //Reserve space for the entire instruction (inc tail by numMicoOps)                        
                    tail_o <= (tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i) % (2**queueIndexWidth);  
                    //Check if we will then be full after 4 more max sized instructions are allocating next cycle (worst case)
                    if((tail_o + (inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i) + (4*(2**instMinIdWidth))) % (2**queueIndexWidth) >= head_o)
                    begin
                        //Were full
                        `ifdef DEBUG $display("IOQ %d is full", IOQInstanc); `endif
                        `ifdef DEBUG_PRINT $fdisplay(debugFID, "IOQ %d is full", IOQInstanc); `endif
                        isFull_o <= 1;
                    end
                    isEmpty_o <= 0;
                    `ifdef DEBUG $display("IOQ %d Enqueing 3 instructions. Reservice space for a %d instructions.", IOQInstance, inst1NumMicroOps_i+inst2NumMicroOps_i+inst3NumMicroOps_i); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "IOQ %d Enqueing 3 instructions. Reservice space for a %d instructions.", IOQInstance, inst1NumMicroOps_i+inst2NumMicroOps_i+inst3NumMicroOps_i); `endif
                end
                else
                begin//4 instructions coming in
                    ///inst 1:
                    if(inst1MinID_i == 0)//This is the first uop from the macro op, so write the uop to the tail reserve space for the rest of inst
                    begin
                        //Copy insts
                        formatQueue[tail_o]         <= inst1Format_i;       opcodeQueue[tail_o]         <= inst1Opcode_i;                 
                        addressQueue[tail_o]        <= inst1address_i;      funUnitCodeQueue[tail_o]    <= inst1funcUnitType_i;    
                        majIDQueue[tail_o]          <= inst1MajID_i;        minIDQueue[tail_o]          <= inst1MinID_i;                     
                        numMicroOpsQueue[tail_o]    <= inst1NumMicroOps_i;  is64BitsQueue[tail_o]       <= inst1Is64Bit_i;    
                        pidQueue[tail_o]            <= inst1Pid_i;          tidQueue[tail_o]            <= inst1Tid_i;                             
                        op1wrQueue[tail_o]          <= inst1op1rw_i;        op2wrQueue[tail_o]          <= inst1op2rw_i;                     
                        op3wrQueue[tail_o]          <= inst1op3rw_i;        op4wrQueue[tail_o]          <= inst1op4rw_i;                     
                        op1IsRegQueue[tail_o]       <= inst1op1IsReg_i;     op2IsRegQueue[tail_o]       <= inst1op2IsReg_i;         
                        op3IsRegQueue[tail_o]       <= inst1op3IsReg_i;     op4IsRegQueue[tail_o]       <= inst1op4IsReg_i;         
                        modifiesCRQueue[tail_o]     <= inst1ModifiesCR_i;   bodyQueue[tail_o]           <= inst1Body_i;                                      
                        //Record the Macro op (majID) ID base-uop (minID == 0) in the map to find when we come to write the later uops
                        majIDMap[tail_o] <= inst1MajID_i;
                        //Set the isValid bit for the entry
                        mapEntryIsValid[tail_o] <= 1;
                        //set is done
                        isDone[tail_o] <= 1;
                        //set the number of instructions remaining
                        numUopsRemaining[tail_o] <= inst1NumMicroOps_i-1;
                    end
                    else
                    begin//We need to look up where the uop needs to go
                        for(i = 0; i < numQueueEntries; i = i + 1)//Go through the map to find the base uop
                        begin
                            if(majIDMap[i] == inst1MajID_i && mapEntryIsValid[i] == 1)//we've found the base uop for the instruction, use it as a reference to find our uops reserved space and write to it
                            begin
                                formatQueue[i] <=       inst1Format_i;      opcodeQueue[i] <=       inst1Opcode_i;             
                                addressQueue[i] <=      inst1address_i;     funUnitCodeQueue[i] <=  inst1funcUnitType_i;
                                majIDQueue[i] <=        inst1MajID_i;       minIDQueue[i] <=        inst1MinID_i;                 
                                numMicroOpsQueue[i] <=  inst1NumMicroOps_i; is64BitsQueue[i] <=     inst1Is64Bit_i;
                                pidQueue[i] <=          inst1Pid_i;         tidQueue[i] <=          inst1Tid_i;                         
                                op1wrQueue[i] <=        inst1op1rw_i;       op2wrQueue[i] <=        inst1op2rw_i;                 
                                op3wrQueue[i] <=        inst1op3rw_i;       op4wrQueue[i] <=        inst1op4rw_i;                 
                                op1IsRegQueue[i] <=     inst1op1IsReg_i;    op2IsRegQueue[i] <=     inst1op2IsReg_i;     
                                op3IsRegQueue[i] <=     inst1op3IsReg_i;    op4IsRegQueue[i] <=     inst1op4IsReg_i;     
                                modifiesCRQueue[i] <=   inst1ModifiesCR_i;  bodyQueue[i] <=         inst1Body_i;         
                                //set is done
                                isDone[i] <= 1;
                                //subtract a remaining uop from the counter
                                numUopsRemaining[i] <= numUopsRemaining[i] - 1;
                            end
                        end
                    end
                    ///inst 2:
                    if(inst2MinID_i == 0)//This is the first uop from the macro op, so write the uop to the tail reserve space for the rest of inst
                    begin
                        //Copy insts
                        formatQueue[tail_o + inst1NumMicroOps_i]            <= inst2Format_i;       opcodeQueue[tail_o + inst1NumMicroOps_i] <=         inst2Opcode_i;                 
                        addressQueue[tail_o + inst1NumMicroOps_i]           <= inst2address_i;      funUnitCodeQueue[tail_o + inst1NumMicroOps_i] <=    inst2funcUnitType_i;    
                        majIDQueue[tail_o + inst1NumMicroOps_i]             <= inst2MajID_i;        minIDQueue[tail_o + inst1NumMicroOps_i] <=          inst2MinID_i;                     
                        numMicroOpsQueue[tail_o + inst1NumMicroOps_i]       <= inst2NumMicroOps_i;  is64BitsQueue[tail_o + inst1NumMicroOps_i] <=       inst2Is64Bit_i;    
                        pidQueue[tail_o + inst1NumMicroOps_i]               <= inst2Pid_i;          tidQueue[tail_o + inst1NumMicroOps_i] <=            inst2Tid_i;                             
                        op1wrQueue[tail_o + inst1NumMicroOps_i]             <= inst2op1rw_i;        op2wrQueue[tail_o + inst1NumMicroOps_i] <=          inst2op2rw_i;                     
                        op3wrQueue[tail_o + inst1NumMicroOps_i]             <= inst2op3rw_i;        op4wrQueue[tail_o + inst1NumMicroOps_i] <=          inst2op4rw_i;                     
                        op1IsRegQueue[tail_o + inst1NumMicroOps_i]          <= inst2op1IsReg_i;     op2IsRegQueue[tail_o + inst1NumMicroOps_i] <=       inst2op2IsReg_i;         
                        op3IsRegQueue[tail_o + inst1NumMicroOps_i]          <= inst2op3IsReg_i;     op4IsRegQueue[tail_o + inst1NumMicroOps_i] <=       inst2op4IsReg_i;         
                        modifiesCRQueue[tail_o + inst1NumMicroOps_i]        <= inst2ModifiesCR_i;   bodyQueue[tail_o + inst1NumMicroOps_i] <=           inst2Body_i;                                        
                        //Record the Macro op (majID) ID base-uop (minID == 0) in the map to find when we come to write the later uops
                        majIDMap[tail_o + inst1NumMicroOps_i] <= inst2MajID_i;
                        //Set the isValid bit for the entry
                        mapEntryIsValid[tail_o + inst1NumMicroOps_i] <= 1;
                        //set is done
                        isDone[tail_o + inst1NumMicroOps_i] <= 1;
                        //set the number of instructions remaining
                        numUopsRemaining[tail_o + inst1NumMicroOps_i] <= inst2NumMicroOps_i-1;
                    end
                    else
                    begin//We need to look up where the uop needs to go
                        for(i = 0; i < numQueueEntries; i = i + 1)//Go through the map to find the base uop
                        begin
                            if(majIDMap[i] == inst2MajID_i && mapEntryIsValid[i] == 1)//we've found the base uop for the instruction, use it as a reference to find our uops reserved space and write to it
                            begin
                                formatQueue[i] <=       inst2Format_i;      opcodeQueue[i] <=       inst2Opcode_i;             
                                addressQueue[i] <=      inst2address_i;     funUnitCodeQueue[i] <=  inst2funcUnitType_i;
                                majIDQueue[i] <=        inst2MajID_i;       minIDQueue[i] <=        inst2MinID_i;                 
                                numMicroOpsQueue[i] <=  inst2NumMicroOps_i; is64BitsQueue[i] <=     inst2Is64Bit_i;
                                pidQueue[i] <=          inst2Pid_i;         tidQueue[i] <=          inst2Tid_i;                         
                                op1wrQueue[i] <=        inst2op1rw_i;       op2wrQueue[i] <=        inst2op2rw_i;                 
                                op3wrQueue[i] <=        inst2op3rw_i;       op4wrQueue[i] <=        inst2op4rw_i;                 
                                op1IsRegQueue[i] <=     inst2op1IsReg_i;    op2IsRegQueue[i] <=     inst2op2IsReg_i;     
                                op3IsRegQueue[i] <=     inst2op3IsReg_i;    op4IsRegQueue[i] <=     inst2op4IsReg_i;     
                                modifiesCRQueue[i] <=   inst2ModifiesCR_i;  bodyQueue[i] <=         inst2Body_i;         
                                //set is done
                                isDone[i] <= 1;
                                numUopsRemaining[i] <=  numUopsRemaining[i] - 1;
                            end
                        end
                    end
                    ///inst 3:
                    if(inst3MinID_i == 0)//This is the first uop from the macro op, so write the uop to the tail reserve space for the rest of inst
                    begin
                        //Copy insts
                        formatQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i]            <= inst3Format_i;       opcodeQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <=         inst3Opcode_i;                 
                        addressQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i]           <= inst3address_i;      funUnitCodeQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <=    inst3funcUnitType_i;    
                        majIDQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i]             <= inst3MajID_i;        minIDQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <=          inst3MinID_i;                     
                        numMicroOpsQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i]       <= inst3NumMicroOps_i;  is64BitsQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <=       inst3Is64Bit_i;    
                        pidQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i]               <= inst3Pid_i;          tidQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <=            inst3Tid_i;                             
                        op1wrQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i]             <= inst3op1rw_i;        op2wrQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <=          inst3op2rw_i;                     
                        op3wrQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i]             <= inst3op3rw_i;        op4wrQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <=          inst3op4rw_i;                     
                        op1IsRegQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i]          <= inst3op1IsReg_i;     op2IsRegQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <=       inst3op2IsReg_i;         
                        op3IsRegQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i]          <= inst3op3IsReg_i;     op4IsRegQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <=       inst3op4IsReg_i;         
                        modifiesCRQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i]        <= inst3ModifiesCR_i;   bodyQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <=           inst3Body_i;                                       
                        //Record the Macro op (majID) ID base-uop (minID == 0) in the map to find when we come to write the later uops
                        majIDMap[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <= inst3MajID_i;
                        //Set the isValid bit for the entry
                        mapEntryIsValid[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <= 1;
                        //set is done
                        isDone[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <= 1;
                        //set the number of instructions remaining
                        numUopsRemaining[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i] <= inst3NumMicroOps_i-1;
                    end
                    else
                    begin//We need to look up where the uop needs to go
                        for(i = 0; i < numQueueEntries; i = i + 1)//Go through the map to find the base uop
                        begin
                            if(majIDMap[i] == inst3MajID_i && mapEntryIsValid[i] == 1)//we've found the base uop for the instruction, use it as a reference to find our uops reserved space and write to it
                            begin
                                formatQueue[i] <=       inst3Format_i;      opcodeQueue[i] <=       inst3Opcode_i;             
                                addressQueue[i] <=      inst3address_i;     funUnitCodeQueue[i] <=  inst3funcUnitType_i;
                                majIDQueue[i] <=        inst3MajID_i;       minIDQueue[i] <=        inst3MinID_i;                 
                                numMicroOpsQueue[i] <=  inst3NumMicroOps_i; is64BitsQueue[i] <=     inst3Is64Bit_i;
                                pidQueue[i] <=          inst3Pid_i;         tidQueue[i] <=          inst3Tid_i;                         
                                op1wrQueue[i] <=        inst3op1rw_i;       op2wrQueue[i] <=        inst3op2rw_i;                 
                                op3wrQueue[i] <=        inst3op3rw_i;       op4wrQueue[i] <=        inst3op4rw_i;                 
                                op1IsRegQueue[i] <=     inst3op1IsReg_i;    op2IsRegQueue[i] <=     inst3op2IsReg_i;     
                                op3IsRegQueue[i] <=     inst3op3IsReg_i;    op4IsRegQueue[i] <=     inst3op4IsReg_i;     
                                modifiesCRQueue[i] <=   inst3ModifiesCR_i;  bodyQueue[i] <=         inst3Body_i;         
                                //set is done
                                isDone[i] <= 1;
                                numUopsRemaining[i] <=  numUopsRemaining[i] - 1;
                            end
                        end
                    end
                    ///inst 4:
                    if(inst4MinID_i == 0)//This is the first uop from the macro op, so write the uop to the tail reserve space for the rest of inst
                    begin
                        //Copy insts
                        formatQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i]            <= inst4Format_i;       opcodeQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i] <=         inst4Opcode_i;                 
                        addressQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i]           <= inst4address_i;      funUnitCodeQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i] <=    inst4funcUnitType_i;    
                        majIDQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i]             <= inst4MajID_i;        minIDQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i] <=          inst4MinID_i;                     
                        numMicroOpsQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i]       <= inst4NumMicroOps_i;  is64BitsQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i] <=       inst4Is64Bit_i;    
                        pidQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i]               <= inst4Pid_i;          tidQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i] <=            inst4Tid_i;                             
                        op1wrQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i]             <= inst4op1rw_i;        op2wrQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i] <=          inst4op2rw_i;                     
                        op3wrQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i]             <= inst4op3rw_i;        op4wrQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i] <=          inst4op4rw_i;                     
                        op1IsRegQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i]          <= inst4op1IsReg_i;     op2IsRegQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i] <=       inst4op2IsReg_i;         
                        op3IsRegQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i]          <= inst4op3IsReg_i;     op4IsRegQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i] <=       inst4op4IsReg_i;         
                        modifiesCRQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i]        <= inst4ModifiesCR_i;   bodyQueue[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i] <=           inst4Body_i;                                         
                        //Record the Macro op (majID) ID base-uop (minID == 0) in the map to find when we come to write the later uops
                        majIDMap[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i] <= inst4MajID_i;
                        //Set the isValid bit for the entry
                        mapEntryIsValid[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i] <= 1;
                        //set is done
                        isDone[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i] <= 1
                        //set the number of instructions remaining
                        numUopsRemaining[tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i] <= inst4NumMicroOps_i-1;
                    end
                    else
                    begin//We need to look up where the uop needs to go
                        for(i = 0; i < numQueueEntries; i = i + 1)//Go through the map to find the base uop
                        begin
                            if(majIDMap[i] == inst3MajID_i && mapEntryIsValid[i] == 1)//we've found the base uop for the instruction, use it as a reference to find our uops reserved space and write to it
                            begin
                                formatQueue[i] <=       inst4Format_i;      opcodeQueue[i] <=       inst4Opcode_i;             
                                addressQueue[i] <=      inst4address_i;     funUnitCodeQueue[i] <=  inst4funcUnitType_i;
                                majIDQueue[i] <=        inst4MajID_i;       minIDQueue[i] <=        inst4MinID_i;                 
                                numMicroOpsQueue[i] <=  inst4NumMicroOps_i; is64BitsQueue[i] <=     inst4Is64Bit_i;
                                pidQueue[i] <=          inst4Pid_i;         tidQueue[i] <=          inst4Tid_i;                         
                                op1wrQueue[i] <=        inst4op1rw_i;       op2wrQueue[i] <=        inst4op2rw_i;                 
                                op3wrQueue[i] <=        inst4op3rw_i;       op4wrQueue[i] <=        inst4op4rw_i;                 
                                op1IsRegQueue[i] <=     inst4op1IsReg_i;    op2IsRegQueue[i] <=     inst4op2IsReg_i;     
                                op3IsRegQueue[i] <=     inst4op3IsReg_i;    op4IsRegQueue[i] <=     inst4op4IsReg_i;     
                                modifiesCRQueue[i] <=   inst4ModifiesCR_i;  bodyQueue[i] <=         inst4Body_i;         
                                //set is done
                                isDone[i] <= 1;
                                numUopsRemaining[i] <=  numUopsRemaining[i] - 1;
                            end
                        end
                    end     
                    //Reserve space for the entire instruction (inc tail by numMicoOps)                        
                    tail_o <= (tail_o + inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i + inst4NumMicroOps_i) % (2**queueIndexWidth);                
                    //Check if we will then be full after 4 more max sized instructions are allocating next cycle (worst case)
                    if((tail_o + (inst1NumMicroOps_i + inst2NumMicroOps_i + inst3NumMicroOps_i + inst4NumMicroOps_i) + (4*(2**instMinIdWidth))) % (2**queueIndexWidth) >= head_o)
                    begin
                        //Were full
                        `ifdef DEBUG $display("IOQ %d is full", IOQInstanc); `endif
                        `ifdef DEBUG_PRINT $fdisplay(debugFID, "IOQ %d is full", IOQInstanc); `endif                   
                    end
                    isEmpty_o <= 0;
                    `ifdef DEBUG $display("IOQ %d Enqueing 4 instructions. Reservice space for a %d instructions.", IOQInstance, inst1NumMicroOps_i+inst2NumMicroOps_i+inst3NumMicroOps_i+inst4NumMicroOps_i); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID, "IOQ %d Enqueing 4 instructions. Reservice space for a %d instructions.", IOQInstance, inst1NumMicroOps_i+inst2NumMicroOps_i+inst3NumMicroOps_i+inst4NumMicroOps_i); `endif
                end
            end

            if(isEmpty_o)//Queue is empty
            begin
				`ifdef DEBUG $display("In-order queue %d empty", IOQInstance); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "In-order queue %d empty", IOQInstance); `endi
            end
            else
            begin//Not empty, dequeue
                if(readEnable_i)
                begin
                    if(isDone[head_o+0] == 1 && isDone[head_o+1] == 1 && isDone[head_o+2] == 1 && isDone[head_o+3] == 1)
                    begin//4 instructions can be read
                        outputEnable_o <= 1; numInstructionsOut_o <= 2'b11; 
                        inst1Format_o <= formatQueue[head_o+0]; inst2Format_o <= formatQueue[head_o+1]; inst3Format_o <= formatQueue[head_o+2]; inst4Format_o <= formatQueue[head_o+3];
                        inst1Opcode_o <= opcodeQueue[head_o+0]; inst2Opcode_o <= opcodeQueue[head_o+1]; inst3Opcode_o <= opcodeQueue[head_o+2]; inst4Opcode_o <= opcodeQueue[head_o+3];
                        inst1Address_o <= addressQueue[head_o+0]; inst2Address_o <= addressQueue[head_o+1]; inst3Address_o <= addressQueue[head_o+2]; inst4Address_o <= addressQueue[head_o+3];
                        inst1FuncUnit_o <= funUnitCodeQueue[head_o+0]; inst2FuncUnit_o <= funUnitCodeQueue[head_o+1]; inst3FuncUnit_o <= funUnitCodeQueue[head_o+2]; inst4FuncUnit_o <= funUnitCodeQueue[head_o+3];
                        inst1MajId_o <= majIDQueue[head_o+0]; inst2MajId_o <= majIDQueue[head_o+1]; inst3MajId_o <= majIDQueue[head_o+2]; inst4MajId_o <= majIDQueue[head_o+3]; 
                        inst1MinID_o <= minIDQueue[head_o+0]; inst2MinID_o <= minIDQueue[head_o+1]; inst3MinID_o <= minIDQueue[head_o+2]; inst4MinID_o <= minIDQueue[head_o+3]; 
                        inst1NumUOps_o <= numMicroOpsQueue[head_o+0]; inst2NumUOps_o <= numMicroOpsQueue[head_o+1]; inst3NumUOps_o <= numMicroOpsQueue[head_o+3]; inst4NumUOps_o <= numMicroOpsQueue[head_o+4];
                        inst1Is64Bit_o <= is64BitsQueue[head_o+0]; inst2Is64Bit_o <= is64BitsQueue[head_o+1]; inst3Is64Bit_o <= is64BitsQueue[head_o+2]; inst4Is64Bit_o <= is64BitsQueue[head_o+3]; 
                        inst1Pid_o <= pidQueue[head_o+0]; inst2Pid_o <= pidQueue[head_o+1]; inst3Pid_o <= pidQueue[head_o+2]; inst4Pid_o <= pidQueue[head_o+3]; 
                        inst1Tid_o <= tidQueue[head_o+0]; inst2Tid_o <= tidQueue[head_o+1]; inst3Tid_o <= tidQueue[head_o+2]; inst4Tid_o <= tidQueue[head_o+3]; 
                        inst1op1rw_o <= op1wrQueue[head_o+0]; inst2op1rw_o <= op1wrQueue[head_o+1]; inst3op1rw_o <= op1wrQueue[head_o+2]; inst4op1rw_o <= op1wrQueue[head_o+3]; 
                        inst1op2rw_o <= op2wrQueue[head_o+0]; inst2op2rw_o <= op2wrQueue[head_o+1]; inst3op2rw_o <= op2wrQueue[head_o+2]; inst4op2rw_o <= op2wrQueue[head_o+3]; 
                        inst1op3rw_o <= op3wrQueue[head_o+0]; inst2op3rw_o <= op3wrQueue[head_o+1]; inst3op3rw_o <= op3wrQueue[head_o+2]; inst4op3rw_o <= op3wrQueue[head_o+3]; 
                        inst1op4rw_o <= op4wrQueue[head_o+0]; inst2op4rw_o <= op4wrQueue[head_o+1]; inst3op4rw_o <= op4wrQueue[head_o+2]; inst4op4rw_o <= op4wrQueue[head_o+3]; 
                        inst1op1IsReg_o <= op1IsRegQueue[head_o+0]; inst2op1IsReg_o <= op1IsRegQueue[head_o+1]; inst3op1IsReg_o <= op1IsRegQueue[head_o+2]; inst4op1IsReg_o <= op1IsRegQueue[head_o+3]; 
                        inst1op2IsReg_o <= op2IsRegQueue[head_o+0]; inst2op2IsReg_o <= op2IsRegQueue[head_o+1]; inst3op2IsReg_o <= op2IsRegQueue[head_o+2]; inst4op2IsReg_o <= op2IsRegQueue[head_o+3]; 
                        inst1op3IsReg_o <= op3IsRegQueue[head_o+0]; inst2op3IsReg_o <= op3IsRegQueue[head_o+1]; inst3op3IsReg_o <= op3IsRegQueue[head_o+2]; inst4op3IsReg_o <= op3IsRegQueue[head_o+3]; 
                        inst1op4IsReg_o <= op4IsRegQueue[head_o+0]; inst2op4IsReg_o <= op4IsRegQueue[head_o+1]; inst3op4IsReg_o <= op4IsRegQueue[head_o+2]; inst4op4IsReg_o <= op4IsRegQueue[head_o+3]; 
                        inst1ModifiesCR_o <= modifiesCRQueue[head_o+0]; inst2ModifiesCR_o <= modifiesCRQueue[head_o+1]; inst3ModifiesCR_o <= modifiesCRQueue[head_o+2]; inst4ModifiesCR_o <= modifiesCRQueue[head_o+3];
                        inst1Body_o <= bodyQueue[head_o+0]; inst2Body_o <= bodyQueue[head_o+1]; inst3Body_o <= bodyQueue[head_o+2]; inst4Body_o <= bodyQueue[head_o+3]; 
                        head_o <= head_o + 4;
                    end
                    else if(isDone[head_o+0] == 1 && isDone[head_o+1] == 1 && isDone[head_o+2] == 1 && isDone[head_o+3] == 0)
                    begin//3 instructions can be read
                        outputEnable_o <= 1; numInstructionsOut_o <= 2'b10; 
                        inst1Format_o <= formatQueue[head_o+0]; inst2Format_o <= formatQueue[head_o+1]; inst3Format_o <= formatQueue[head_o+2];
                        inst1Opcode_o <= opcodeQueue[head_o+0]; inst2Opcode_o <= opcodeQueue[head_o+1]; inst3Opcode_o <= opcodeQueue[head_o+2];
                        inst1Address_o <= addressQueue[head_o+0]; inst2Address_o <= addressQueue[head_o+1]; inst3Address_o <= addressQueue[head_o+2];
                        inst1FuncUnit_o <= funUnitCodeQueue[head_o+0]; inst2FuncUnit_o <= funUnitCodeQueue[head_o+1]; inst3FuncUnit_o <= funUnitCodeQueue[head_o+2];
                        inst1MajId_o <= majIDQueue[head_o+0]; inst2MajId_o <= majIDQueue[head_o+1]; inst3MajId_o <= majIDQueue[head_o+2];
                        inst1MinID_o <= minIDQueue[head_o+0]; inst2MinID_o <= minIDQueue[head_o+1]; inst3MinID_o <= minIDQueue[head_o+2];
                        inst1NumUOps_o <= numMicroOpsQueue[head_o+0]; inst2NumUOps_o <= numMicroOpsQueue[head_o+1]; inst3NumUOps_o <= numMicroOpsQueue[head_o+3];
                        inst1Is64Bit_o <= is64BitsQueue[head_o+0]; inst2Is64Bit_o <= is64BitsQueue[head_o+1]; inst3Is64Bit_o <= is64BitsQueue[head_o+2];
                        inst1Pid_o <= pidQueue[head_o+0]; inst2Pid_o <= pidQueue[head_o+1]; inst3Pid_o <= pidQueue[head_o+2];
                        inst1Tid_o <= tidQueue[head_o+0]; inst2Tid_o <= tidQueue[head_o+1]; inst3Tid_o <= tidQueue[head_o+2];
                        inst1op1rw_o <= op1wrQueue[head_o+0]; inst2op1rw_o <= op1wrQueue[head_o+1]; inst3op1rw_o <= op1wrQueue[head_o+2];
                        inst1op2rw_o <= op2wrQueue[head_o+0]; inst2op2rw_o <= op2wrQueue[head_o+1]; inst3op2rw_o <= op2wrQueue[head_o+2];
                        inst1op3rw_o <= op3wrQueue[head_o+0]; inst2op3rw_o <= op3wrQueue[head_o+1]; inst3op3rw_o <= op3wrQueue[head_o+2];
                        inst1op4rw_o <= op4wrQueue[head_o+0]; inst2op4rw_o <= op4wrQueue[head_o+1]; inst3op4rw_o <= op4wrQueue[head_o+2];
                        inst1op1IsReg_o <= op1IsRegQueue[head_o+0]; inst2op1IsReg_o <= op1IsRegQueue[head_o+1]; inst3op1IsReg_o <= op1IsRegQueue[head_o+2];
                        inst1op2IsReg_o <= op2IsRegQueue[head_o+0]; inst2op2IsReg_o <= op2IsRegQueue[head_o+1]; inst3op2IsReg_o <= op2IsRegQueue[head_o+2];
                        inst1op3IsReg_o <= op3IsRegQueue[head_o+0]; inst2op3IsReg_o <= op3IsRegQueue[head_o+1]; inst3op3IsReg_o <= op3IsRegQueue[head_o+2];
                        inst1op4IsReg_o <= op4IsRegQueue[head_o+0]; inst2op4IsReg_o <= op4IsRegQueue[head_o+1]; inst3op4IsReg_o <= op4IsRegQueue[head_o+2];
                        inst1ModifiesCR_o <= modifiesCRQueue[head_o+0]; inst2ModifiesCR_o <= modifiesCRQueue[head_o+1]; inst3ModifiesCR_o <= modifiesCRQueue[head_o+2];
                        inst1Body_o <= bodyQueue[head_o+0]; inst2Body_o <= bodyQueue[head_o+1]; inst3Body_o <= bodyQueue[head_o+2];
                        head_o <= head_o + 3;
                    end
                    else if(isDone[head_o+0] == 1 && isDone[head_o+1] == 1 && isDone[head_o+2] == 0 && isDone[head_o+3] == 0)
                    begin//2 instructions can be read
                        outputEnable_o <= 1; numInstructionsOut_o <= 2'b01; 
                        inst1Format_o <= formatQueue[head_o+0]; inst2Format_o <= formatQueue[head_o+1];
                        inst1Opcode_o <= opcodeQueue[head_o+0]; inst2Opcode_o <= opcodeQueue[head_o+1];
                        inst1Address_o <= addressQueue[head_o+0]; inst2Address_o <= addressQueue[head_o+1];
                        inst1FuncUnit_o <= funUnitCodeQueue[head_o+0]; inst2FuncUnit_o <= funUnitCodeQueue[head_o+1];
                        inst1MajId_o <= majIDQueue[head_o+0]; inst2MajId_o <= majIDQueue[head_o+1];
                        inst1MinID_o <= minIDQueue[head_o+0]; inst2MinID_o <= minIDQueue[head_o+1];
                        inst1NumUOps_o <= numMicroOpsQueue[head_o+0]; inst2NumUOps_o <= numMicroOpsQueue[head_o+1];
                        inst1Is64Bit_o <= is64BitsQueue[head_o+0]; inst2Is64Bit_o <= is64BitsQueue[head_o+1];
                        inst1Pid_o <= pidQueue[head_o+0]; inst2Pid_o <= pidQueue[head_o+1];
                        inst1Tid_o <= tidQueue[head_o+0]; inst2Tid_o <= tidQueue[head_o+1];
                        inst1op1rw_o <= op1wrQueue[head_o+0]; inst2op1rw_o <= op1wrQueue[head_o+1];
                        inst1op2rw_o <= op2wrQueue[head_o+0]; inst2op2rw_o <= op2wrQueue[head_o+1];
                        inst1op3rw_o <= op3wrQueue[head_o+0]; inst2op3rw_o <= op3wrQueue[head_o+1];
                        inst1op4rw_o <= op4wrQueue[head_o+0]; inst2op4rw_o <= op4wrQueue[head_o+1];
                        inst1op1IsReg_o <= op1IsRegQueue[head_o+0]; inst2op1IsReg_o <= op1IsRegQueue[head_o+1];
                        inst1op2IsReg_o <= op2IsRegQueue[head_o+0]; inst2op2IsReg_o <= op2IsRegQueue[head_o+1];
                        inst1op3IsReg_o <= op3IsRegQueue[head_o+0]; inst2op3IsReg_o <= op3IsRegQueue[head_o+1];
                        inst1op4IsReg_o <= op4IsRegQueue[head_o+0]; inst2op4IsReg_o <= op4IsRegQueue[head_o+1];
                        inst1ModifiesCR_o <= modifiesCRQueue[head_o+0]; inst2ModifiesCR_o <= modifiesCRQueue[head_o+1];
                        inst1Body_o <= bodyQueue[head_o+0]; inst2Body_o <= bodyQueue[head_o+1];
                        head_o <= head_o + 2;
                    end
                    else if(isDone[head_o+0] == 1 && isDone[head_o+1] == 0 && isDone[head_o+2] == 0 && isDone[head_o+3] == 0)
                    begin//1 instruction can be read
                        outputEnable_o <= 1; numInstructionsOut_o <= 2'b00; 
                        inst1Format_o <= formatQueue[head_o+0];
                        inst1Opcode_o <= opcodeQueue[head_o+0];
                        inst1Address_o <= addressQueue[head_o+0];
                        inst1FuncUnit_o <= funUnitCodeQueue[head_o+0];
                        inst1MajId_o <= majIDQueue[head_o+0];
                        inst1MinID_o <= minIDQueue[head_o+0];
                        inst1NumUOps_o <= numMicroOpsQueue[head_o+0];
                        inst1Is64Bit_o <= is64BitsQueue[head_o+0];
                        inst1Pid_o <= pidQueue[head_o+0];
                        inst1Tid_o <= tidQueue[head_o+0];
                        inst1op1rw_o <= op1wrQueue[head_o+0];
                        inst1op2rw_o <= op2wrQueue[head_o+0];
                        inst1op3rw_o <= op3wrQueue[head_o+0];
                        inst1op4rw_o <= op4wrQueue[head_o+0];
                        inst1op1IsReg_o <= op1IsRegQueue[head_o+0];
                        inst1op2IsReg_o <= op2IsRegQueue[head_o+0];
                        inst1op3IsReg_o <= op3IsRegQueue[head_o+0];
                        inst1op4IsReg_o <= op4IsRegQueue[head_o+0];
                        inst1ModifiesCR_o <= modifiesCRQueue[head_o+0];
                        inst1Body_o <= bodyQueue[head_o+0];
                        head_o <= head_o + 1;
                    end
                    else
                    begin//No instructions can be read. This should actually automatically handle is_empty situations
                        outputEnable_o <= 0;
                    end
                end
            end
        end
    end


endmodule