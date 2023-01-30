`timescale 1ns / 1ps
`define DEBUG
`define DEBUG_PRINT

/*///////////////Interchange////////////////////////////
Writen by Josh "Hakaru" Cantwell - 28.01.2023

This is the ROB, it tracks instruction oder before they go into the OoO pipelines in order to allow them to complete in order
The RoB is implemented as a circular queue with random read capability.
The completed instructions are completed from the head of the queue and only complete in program order.
The issuing instructions adre added to the queue at the tail of the queue and are added to the queue in program order.
During OoO execution of instructions, instructions can complete out of program order therefore the RoB must be updatable in random order.

*///////////////////////////////////////////////////////

module ROB
#(
    parameter robIndexWidth = 7,
    parameter numRobEntries = 2**robIndexWidth,
    parameter regIdWidth = 5,
)
(
    input wire clock_i, reset_i,
    input wire inst1Write_i, inst2Write_i, inst3Write_i, inst4Write_i, //tells enable for the ROB to accept the instructions
    //Bring in the 2 destinations
    input wire inst1Operand1en_i, inst1Operand2en_i, inst2Operand1en_i, inst2Operand2en_i, inst3Operand1en_i, inst3Operand2en_i, inst4Operand1en_i, inst4Operand2en_i, 
    input wire [0:regIdWidth-1] isnt1Operand1_i, isnt1Operand2_i, isnt2Operand1_i, isnt2Operand2_i, isnt3Operand1_i, isnt3Operand2_i, isnt4Operand1_i, isnt4Operand2_i,  


    //Rob capacity output
	output reg [0:robIndexWidth-1] head_o, tail_o,//dequeue from head, enqueue to tail
	output reg isEmpty_o, isFull_o

)

reg [0:regIdWidth-1] robRegIDs [0:numRobEntries-1];//Holds the reg ids/addresses used as a desination by the instruction
reg robEntryIsCompleted [0:numRobEntries-1];//This flag goes high when the instruction associated to the entry is completed.

`ifdef DEBUG_PRINT
integer debugFID;
`endif
integer i;

always @(posedge clock_i)
begin
    if(reset_i)
    begin
        for(i = 0; i < numRobEntries; i = i + 1)
            robEntryIsCompleted <= 0;//under reset the isCompleted flags must be cleared

        //reset the queues head and tail 

    end
end



endmodule