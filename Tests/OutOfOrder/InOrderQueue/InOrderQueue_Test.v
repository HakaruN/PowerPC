`timescale 1ns / 1ps
`include "../../../Modules/OutOfOrder/InOrderQueue.v"
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
`define DEBUG
module CircularQueue_Test #(
	parameter queueIndexBits = 3,//8 entries (2**3 == 8) as we have a 3 bit address
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
    parameter Z22 = 2**20, parameter XX2 = 2**21, parameter XX3 = 2**22
);
	// Inputs
	reg clock;
	reg reset;
	//write - enqueue
	reg writeEnableIn;
    reg [0:25-1] instFormatIn;
    reg [0:opcodeSize-1] opcodeIn;
    reg [0:addressWidth-1] addressIn;
    reg [0:funcUnitCodeSize-1] funcUnitTypeIn;
    reg [0:instructionCounterWidth-1] majIDIn;
    reg [0:instMinIdWidth-1] minIDIn;
    reg is64BitIn;
    reg [0:PidSize-1] pidIn;
    reg [0:TidSize-1] tidIn;
    reg [0:(regAccessPatternSize*4)-1] operandRWIn;
    reg [0:3] operandIsRegIn;
    reg [0:84-1] bodyIn;
	//read - dequeue
	reg readEnable;
	wire [0:25-1] IntstFormatOut;
    wire [0:opcodeSize-1] opcodeOut;
    wire [0:addressWidth-1] addressOut;
    wire [0:funcUnitCodeSize-1] funcUnitTypeOut;
    wire [0:instructionCounterWidth-1] majIDOut;
    wire [0:instMinIdWidth-1] minIDOut;
    wire is64BitOut;
    wire [0:PidSize-1] pidOut;
    wire [0:TidSize-1] tidOut;
    wire [0:(regAccessPatternSize*4)-1] operandRWOut;
    wire [0:3] operandIsRegOut;
    wire [0:84-1] bodyOut;
	// Outputs
	wire [0:queueIndexBits-1] head, tail;
	wire isEmpty;
	wire isFull;

	// Instantiate the Unit Under Test (UUT)
	CircularQueue #(
		.queueIndexBits(queueIndexBits)
    ) inOrderQueue (
    //command in
    .clock_i(clock), 
    .reset_i(reset), 
    //write - enqueue
    .writeEnable_i(writeEnableIn), 
    .instFormat_i(instFormatIn),
    .opcode_i(opcodeIn),
    .address_i(addressIn),
    .funcUnitType_i(funcUnitTypeIn),
    .majID_i(majIDIn),
    .minID_i(minIDIn),
    .is64Bit_i(is64BitIn),
    .pid_i(pidIn),
    .tid_i(tidIn),
    .operandRW_i(operandRWIn),
    .operandIsReg_i(operandIsRegIn),
    .body_i(bodyIn),
    //read - dequeue
    .readEnable_i(readEnable), 
    .instFormat_o(IntstFormatOut),
    .opcode_o(opcodeOut),
    .address_o(addressOut),
    .funcUnitType_o(funcUnitTypeOut),
    .majID_o(majIDOut),
    .minID_o(minIDOut),
    .is64Bit_o(is64BitOut),
    .pid_o(pidOut),
    .tid_o(tidOut),
    .operandRW_o(operandRWOut),
    .operandIsReg_o(operandIsRegOut),
    .body_o(bodyOut),
    //command out
    .head_o(head), .tail_o(tail),
    .isEmpty_o(isEmpty), 
    .isFull_o(isFull)
	);

integer i;
integer wasFull;
	initial begin
        $dumpfile("InOrderQueueTest.vcd");
        $dumpvars(0,inOrderQueue);
        // Initialize Inputs
        clock = 0;
        reset = 0;
        writeEnableIn = 0;
        instFormatIn = 0;
        opcodeIn = 0;
        addressIn = 0;
        funcUnitTypeIn = 0;
        majIDIn = 0;
        minIDIn = 0;
        is64BitIn = 0;
        pidIn = 0;
        tidIn = 0;
        operandRWIn = 0;
        operandIsRegIn = 0;
        bodyIn = 0;
        readEnable = 0;
		#10;
		
		reset = 1;
		clock = 1;
		#1;
		reset = 0;
		clock = 0;
		#1;
        
		//TEST 1 - write 1 entrys (have to add two for it to clear the empty state):
		
		writeEnableIn = 1;
        instFormatIn = B;
        opcodeIn = 0;
        addressIn = 0;
        funcUnitTypeIn = FXUnitId;
        majIDIn = 0; minIDIn = 0; is64BitIn = 1;
        pidIn = 0; tidIn = 0;
        operandRWIn = 8'b11111111;
        operandIsRegIn = 4'b1111;
        bodyIn = 84'hFFFF_0000_0000_FFFF_0000_F;
		clock = 1;
		#1;
		clock = 0;
		#1;
        writeEnableIn = 1;
        instFormatIn = D;
        opcodeIn = 1;
        addressIn = 4;
        funcUnitTypeIn = FPUnitId;
        majIDIn = 1; minIDIn = 0; is64BitIn = 1;
        pidIn = 0; tidIn = 0;
        operandRWIn = 8'b10101010;
        operandIsRegIn = 4'b1001;
        bodyIn = 84'hFFFF_0000_FFFF_0000_FFFF_F;
		clock = 1;
		#1;
		clock = 0;
		#1;

        //Read the instructions back
        writeEnableIn = 0;
        readEnable = 1;
        clock = 1;
        #1;
        clock = 0;
        #1;
        clock = 1;
        #1;
        clock = 0;
        #1;


        //Write till full
        writeEnableIn = 1;
        readEnable = 0;
        for(i = 0; i < 2**queueIndexBits; i = i + 1)
        begin
            instFormatIn = D;
            opcodeIn = i;
            addressIn = (i*4);
            funcUnitTypeIn = FXUnitId;
            majIDIn = i; minIDIn = 0; is64BitIn = 1;
            pidIn = 0; tidIn = 0;
            operandRWIn = 8'b10101010;
            operandIsRegIn = 4'b1001;
            bodyIn = 84'hFFFF_0000_FFFF_0000_FFFF_F;
            clock = 1;
            #1;
            clock = 0;
            #1; 
        end
        if(isFull)
        begin
            $display("queue filled correctly");
        end
        wasFull = isFull;
        //Now unload the queue
        writeEnableIn = 0;
        readEnable = 1;
        for(i = 0; i < 2**queueIndexBits; i = i + 1)
        begin
            clock = 1;
            #1;
            clock = 0;
            #1; 
        end

        if(isEmpty && wasFull)
        begin
            $display("Queue filled and emptied correctly");
        end
	end
      
endmodule
