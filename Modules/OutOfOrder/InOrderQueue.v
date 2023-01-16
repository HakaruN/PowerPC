`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//Writen by Josh "Hakaru" Cantwell - sometime in 2021 I can't remember.
//This is old code that I wrote, its just a circular queue that takes a param for the num bits wide the structure is
//Here the code is used for the inOrder instruction queue (between decode and OoO hardware)
//////////////////////////////////////////////////////////////////////////////////
`define DEBUG
module CircularQueue #(
    ///Total output size is 302 bits (37.75B)
	parameter queueWidth = 302/*how wide each entry in the queue is (bits)*/, parameter queueIndexBits = 9/*how many bits are used to address the addresses (2=4 entry queue)*/
)(
	//command in
	input wire clock_i,
	input wire reset_i,
	
	//write - enqueue
	input wire writeEnable_i,
	input wire [0:queueWidth-1] newEntry_i,
	
	//read - dequeue
	input wire readEnable_i,
	output reg [0:queueWidth-1] ReadEntry_o,
	
	//read - random access
	input wire readRandomEnable_i,
	input wire [0:queueIndexBits-1] readPosition_i,
	output reg [0:queueWidth-1] readRandomEntry_o,
	
	//command out
	output reg [0:queueIndexBits-1] head_o, tail_o,
	output reg isEmpty_o,
	output reg isFull_o
);

	reg [0:queueWidth-1] queue [0:(2**queueIndexBits)-1];
	reg [0:queueIndexBits-1] head, tail;//dequeue from head, enqueue to tail
	reg isEmpty, isFull;
	
	
	
	always @(posedge clock_i)
	begin
		if(reset_i == 1)
		begin
			head <= 0; tail <= 0;
			head_o <= 0; tail_o <= 0;
			isEmpty <= 1;
			`ifdef DEBUG $display("Resetting in-order queue"); `endif
		end
		else
		begin
			if(isFull) begin//if queue full
				isFull_o <= 1;
				`ifdef DEBUG $display("In-order queue full"); `endif
			end
			else if(writeEnable_i == 1)
			begin
				isFull_o <= 0;
				queue[tail] <= newEntry_i;
				tail <= (tail + 1) % (2**queueIndexBits);
				tail_o <= (tail + 1) % (2**queueIndexBits);
				`ifdef DEBUG $display("In-order queue enquing data %h to position %d", newEntry_i, tail); `endif
				
				isEmpty <= 0;
				//check if were now full
				if((tail + 1) % (2**queueIndexBits) == head)
				begin//we've just filled up
					`ifdef DEBUG $display("In-order queue filled"); `endif
					isFull_o <= 1; isFull <= 1;
				end
			end
			else
				isFull_o <= 0;
			
			if(isEmpty) begin//if queue empty
				isEmpty_o <= 1;
				`ifdef DEBUG $display("In-order queue empty"); `endif
			end
			else if(readEnable_i == 1)
			begin
				isEmpty_o <= 0;
				ReadEntry_o <= queue[head];
				head <= (head + 1) % (2**queueIndexBits);
				head_o <= (head + 1) % (2**queueIndexBits);
				`ifdef DEBUG $display("In-order queue dequing data %h from ", queue[head], head); `endif
				
				isFull <= 0;
				//check if were now empty
				if((head + 1) % (2**queueIndexBits) == tail)
				begin//we've just emptied
					`ifdef DEBUG $display("In-order queue emtpied"); `endif
					isEmpty_o <= 1; isEmpty <= 1;
				end				
			end
			else
				isEmpty_o <= 0;
			
			if(readRandomEnable_i == 1)
			begin
				 readRandomEntry_o <= queue[readPosition_i % (2**queueIndexBits)];
				 `ifdef DEBUG $display("In-order queue reading random entry %b at pos %d", queue[readPosition_i % (2**queueIndexBits)], readPosition_i % (2**queueIndexBits)); `endif
			end
		end
	end

endmodule