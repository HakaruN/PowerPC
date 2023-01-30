`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//Writen by Josh "Hakaru" Cantwell - sometime in 2021 I can't remember.
//This is old code that I wrote, its just a circular queue that takes a param for the num bits wide the structure is
//Here the code is used for the inOrder instruction queue (between decode and OoO hardware)
//////////////////////////////////////////////////////////////////////////////////
`define DEBUG
`define DEBUG_PRINT
module CircularQueue #(
    ///Total output size is 302 bits (37.75B)
	parameter queueIndexBits = 9,/*how many bits are used to address the addresses (2=4 entry queue)*/
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter instMinIdWidth = 5,
    parameter opcodeSize = 12, parameter regSize = 5,
    parameter regAccessPatternSize = 2,//2 bit field, [0] == is read, [1] == is writen. Both can be true EG: (A = A + B)
    parameter regRead = 2'b10, parameter regWrite = 2'b01, 
    parameter immWidth = 64,
    ////Generic
    parameter funcUnitCodeSize = 3, //can have up to 8 types of func unit.
    //FX = int, FP = float, VX = vector, CR = condition, LS = load/store
    parameter FXUnitId = 0, parameter FPUnitId = 1, parameter VXUnitId = 2, parameter CRUnitId = 3, parameter LSUnitId = 4,  parameter BranchUnitID = 6,   
    //Each format has a unique bit, this means that I can or multiple formats together into a single variable to pass to
    //the next stage for the format-specific decoders to look at for the instruction opcodes with multiple possible formats
    parameter I = 2**00, parameter B = 2**01, parameter XL = 2**02, parameter DX = 2**03, parameter SC = 2**04,
    parameter D = 2**05, parameter X = 2**06, parameter XO = 2**07, parameter Z23 = 2**08, parameter A = 2**09,
    parameter XS = 2**10, parameter XFX = 2**11, parameter DS = 2**12, parameter DQ = 2**13, parameter VA = 2**14,
    parameter VX = 2**15, parameter VC = 2**16, parameter MD = 2**17, parameter MDS = 2**18, parameter XFL = 2**19,
    parameter Z22 = 2**20, parameter XX2 = 2**21, parameter XX3 = 2**22,
	parameter IOQInstance = 0
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
    input wire [0:(regAccessPatternSize*4)-1] operandRW_i,
    input wire [0:3] operandIsReg_i,
    input wire [0:84-1] body_i,
	
	//read - dequeue
	input wire readEnable_i,
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

`ifdef DEBUG_PRINT
integer debugFID;
`endif

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
			`ifdef DEBUG $display("In order instruction queue %d resetting", IOQInstance); `endif
			`ifdef DEBUG_PRINT
			case(IOQInstance)
			0: begin debugFID = $fopen("IOQ0.log", "w"); end
			1: begin debugFID = $fopen("IOQ1.log", "w"); end
			2: begin debugFID = $fopen("IOQ2.log", "w"); end
			3: begin debugFID = $fopen("IOQ3.log", "w"); end
			4: begin debugFID = $fopen("IOQ4.log", "w"); end
			5: begin debugFID = $fopen("IOQ5.log", "w"); end
			6: begin debugFID = $fopen("IOQ6.log", "w"); end
			7: begin debugFID = $fopen("IOQ7.log", "w"); end
			endcase
			$fdisplay(debugFID, "In order instruction queue %d resetting", IOQInstance);
			`endif
		end
		else
		begin
			if(isFull_o) begin//if queue full
				`ifdef DEBUG $display("In-order queue %d full", IOQInstance); `endif
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
				operandRW[tail_o] <= operandRW_i;
				operandIsReg[tail_o] <= operandIsReg_i;
				body[tail_o] <= body_i;
				//update the tail
				tail_o <= (tail_o + 1) % (2**queueIndexBits);
				`ifdef DEBUG $display("In-order queue %d enquing instruction to position %d", IOQInstance, tail_o); `endif
				
				isEmpty_o <= 0;
				//check if were now full
				if((tail_o + 1) % (2**queueIndexBits) == head_o)
				begin//we've just filled up
					`ifdef DEBUG $display("In-order queue %d filled", IOQInstance); `endif
					isFull_o <= 1;
				end
			end
			else
				isFull_o <= 0;
			
			if(isEmpty_o) begin//if queue empty
				`ifdef DEBUG $display("In-order queue %d empty", IOQInstance); `endif
			end
			else if(readEnable_i == 1)
			begin
				isEmpty_o <= 0;
				//read the instr from the queue
				instFormat_o <= instFormat[head_o];
				opcode_o <= opcode[head_o];
				address_o <= address[head_o];
				funcUnitType_o <= funcUnitType[head_o];
				majID_o <= majID[head_o];
				minID_o <= minID[head_o];
				is64Bit_o <= is64Bit[head_o];
				pid_o <= pid[head_o];
				tid_o <= tid[head_o];
				operandRW_o <= operandRW[head_o];
				operandIsReg_o <= operandIsReg[head_o];
				body_o <= body[head_o];
				//update the head
				head_o <= (head_o + 1) % (2**queueIndexBits);
				`ifdef DEBUG $display("In-order queue %d dequing instruction from position %d", IOQInstance, head_o); `endif
				
				isFull_o <= 0;
				//check if were now empty
				if((head_o + 1) % (2**queueIndexBits) == tail_o)
				begin//we've just emptied
					`ifdef DEBUG $display("In-order queue %d emtpied", IOQInstance); `endif
					isEmpty_o <= 1;
				end				
			end
			else
				isEmpty_o <= 0;
		end
	end

endmodule