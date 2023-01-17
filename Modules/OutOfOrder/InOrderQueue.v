`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//Writen by Josh "Hakaru" Cantwell - sometime in 2021 I can't remember.
//This is old code that I wrote, its just a circular queue that takes a param for the num bits wide the structure is
//Here the code is used for the inOrder instruction queue (between decode and OoO hardware)
//////////////////////////////////////////////////////////////////////////////////
`define DEBUG
module CircularQueue #(
    ///Total output size is 302 bits (37.75B)
	parameter queueIndexBits = 9,/*how many bits are used to address the addresses (2=4 entry queue)*/
	parameter RStationInstance = 0, parameter RSIdxBits = 6,
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter instMinIdWidth = 7,
    parameter opcodeSize = 12, parameter regSize = 5,
    parameter regAccessPatternSize = 2,//2 bit field, [0] == is read, [1] == is writen. Both can be true EG: (A = A + B)
    parameter regRead = 2'b10, parameter regWrite = 2'b01, 
    parameter immWidth = 64
)(
	//command in
	input wire clock_i,
	input wire reset_i,
	
	//write - enqueue
	input wire writeEnable_i,
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
    input wire [0:84-1] body_i,
	
	//read - dequeue
	output reg readEnable_o,
	output reg [0:25-1] instFormat_o,
    output reg [0:opcodeSize-1] opcode_o,
    output reg [0:addressWidth-1] address_o,
    output reg [0:funcUnitCodeSize-1] funcUnitType_o,
    output reg [0:instructionCounterWidth-1] majID_o,
    output reg [0:instMinIdWidth-1] minID_o,
    output reg is64Bit_o,
    output reg [0:PidSize-1] pid_o,
    output reg [0:TidSize-1] tid_o,
    output reg [0:(regAccessPatternSize*4)-1] operandRW_o,
    output reg [0:3] operandIsReg_o,
    output reg [0:84-1] body_o,
	
	//command out
	output reg [0:queueIndexBits-1] head_o, tail_o,//dequeue from head, enqueue to tail
	output reg isEmpty_o, isFull_o
);

	reg [0:queueWidth-1] queue [0:(2**queueIndexBits)-1];
	reg [0:25-1] instFormat  [0:(2**queueIndexBits)-1];
    reg [0:opcodeSize-1] opcode  [0:(2**queueIndexBits)-1];
    reg [0:addressWidth-1] address  [0:(2**queueIndexBits)-1];
    reg [0:funcUnitCodeSize-1] funcUnitType  [0:(2**queueIndexBits)-1];
    reg [0:instructionCounterWidth-1] majID  [0:(2**queueIndexBits)-1];
    reg [0:instMinIdWidth-1] minID  [0:(2**queueIndexBits)-1];
    reg is64Bit [0:(2**queueIndexBits)-1];
    reg [0:PidSize-1] pid  [0:(2**queueIndexBits)-1];
    reg [0:TidSize-1] tid  [0:(2**queueIndexBits)-1];
	reg [0:(regAccessPatternSize*4)-1] operandRW [0:(2**queueIndexBits)-1];
	reg [0:3] operandIsReg [0:(2**queueIndexBits)-1];
    reg [0:84-1] body [0:(2**queueIndexBits)-1];


	
	always @(posedge clock_i)
	begin
		if(reset_i == 1)
		begin
			head_o <= 0; tail_o <= 0;
			isFull_o <= 0; isEmpty_o <= 1;
			`ifdef DEBUG $display("Resetting in-order queue"); `endif
		end
		else
		begin
			if(isFull_o) begin//if queue full
				`ifdef DEBUG $display("In-order queue full"); `endif
			end
			else if(writeEnable_i == 1)
			begin
				isFull_o <= 0;
				//write the input instr to the queue
				instFormat[tail_o] <= instFormat_i;
				opcode[tail_o] <= opcode_i;
				address[tail_o] <= address_i;
				funcUnitType[tail_o] <= funcUnitType_i;
				majID[tail_o] <= majID_i;
				minID[tail_o] <= minID_i;
				is64Bit[tail_o] <= is64Bit_i;
				pid[tail_o] <= pid_i;
				tid[tail_o] <= tid_i;
				operandRW[tail_o] <= {op1rw_i, op2rw_i, op3rw_i, op4rw_i};
				operandIsReg[tail_o] <= {op1IsReg_i, op2IsReg_i, op3IsReg_i, op4IsReg_i};
				body[tail_o] <= body_i;
				//update the tail
				tail_o <= (tail_o + 1) % (2**queueIndexBits);
				`ifdef DEBUG $display("In-order queue enquing data %h to position %d", newEntry_i, tail); `endif
				
				isEmpty_o <= 0;
				//check if were now full
				if((tail_o + 1) % (2**queueIndexBits) == head_o)
				begin//we've just filled up
					`ifdef DEBUG $display("In-order queue filled"); `endif
					isFull_o <= 1;
				end
			end
			else
				isFull_o <= 0;
			
			if(isEmpty_o) begin//if queue empty
				`ifdef DEBUG $display("In-order queue empty"); `endif
			end
			else if(readEnable_i == 1)
			begin
				isEmpty_o <= 0;
				//read the instr from the queue
				instFormat_o <= instFormat[head_o]
				opcode_o <= opcode[head_o]
				address_o <= address[head_o]
				funcUnitType_o <= funcUnitType[head_o]
				majID_o <= majID[head_o]
				minID_o <= minID[head_o]
				is64Bit_o <= is64Bit[head_o]
				pid_o <= pid[head_o]
				tid_o <= tid[head_o]
				operandRW_o <= operandRW[head_o];
				operandIsReg_o <= operandIsReg[head_o];
				body_o <= body[head_o];
				//update the head
				head_o <= (head_o + 1) % (2**queueIndexBits);
				`ifdef DEBUG $display("In-order queue dequing data %h from ", queue[head_o], head_o); `endif
				
				isFull_o <= 0;
				//check if were now empty
				if((head_o + 1) % (2**queueIndexBits) == tail_o)
				begin//we've just emptied
					`ifdef DEBUG $display("In-order queue emtpied"); `endif
					isEmpty_o <= 1;
				end				
			end
			else
				isEmpty_o <= 0;
		end
	end

endmodule