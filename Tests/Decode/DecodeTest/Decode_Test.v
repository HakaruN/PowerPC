`timescale 1ns / 1ps
`include "../../../Modules/Decode/Decode.v"
`define DEBUG
`define DEBUG_PRINT

module DecodeTest #(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter instMinIdWidth = 7,//width of inst minor ID
    parameter primOpcodeSize = 6,
    parameter opcodeSize = 12,
    parameter regSize = 5,
    parameter regAccessPatternSize = 2,//2 bit field, [0] == is read, [1] == is writen. Both can be true EG: (A = A + B)
    parameter funcUnitCodeSize = 3,

    ////Format Specific
    parameter BimmediateSize = 14,
    parameter DimmediateSize = 16,
    //Each format has a unique bit, this means that I can or multiple formats together into a single variable to pass to
    //the next stage for the format-specific decoders to look at for the instruction opcodes with multiple possible formats
    parameter I = 2**00, parameter B = 2**01, parameter XL = 2**02, parameter DX = 2**03, parameter SC = 2**04,
    parameter D = 2**05, parameter X = 2**06, parameter XO = 2**07, parameter Z23 = 2**08, parameter A = 2**09,
    parameter XS = 2**10, parameter XFX = 2**11, parameter DS = 2**12, parameter DQ = 2**13, parameter VA = 2**14,
    parameter VX = 2**15, parameter VC = 2**16, parameter MD = 2**17, parameter MDS = 2**18, parameter XFL = 2**19,
    parameter Z22 = 2**20, parameter XX2 = 2**21, parameter XX3 = 2**22
)
(
);

    ///inputs to the uut
    reg clockIn;
    reg enableIn;
    reg resetIn;
    reg stallIn;
    reg [0:instructionWidth-1] instructionIn;
    reg [0:addressWidth-1] addressIn;
    reg is64BitIn;
    reg [0:PidSize-1] PidIn;
    reg [0:TidSize-1] TidIn;
    reg [0:instructionCounterWidth-1] instMajIdIn;

    ///outputs
    wire enableOut;
    wire [0:25-1] instFormatOut;
    wire [0:opcodeSize-1] opcodeOut;
    wire [0:addressWidth-1] addressOut;
    wire [0:funcUnitCodeSize-1] funcUnitTypeOut;
    wire [0:instructionCounterWidth-1] majIDOut;
    wire [0:instMinIdWidth-1] minIDOut;
    wire is64BitOut;
    wire [0:PidSize-1] pidOut;
    wire [0:TidSize-1] tidOut;
    wire [0:regAccessPatternSize-1] op1rwOut, op2rwOut, op3rwOut, op4rwOut;
    wire op1IsRegOut, op2IsRegOut, op3IsRegOut, op4IsRegOut;
    wire [0:84-1] bodyOut;//contains all operands. Large enough for 4 reg operands and a 64bit imm

    DecodeUnit
    #()
    decodeUnit
    (
    //////Inputs:
    .clock_i(clockIn),    
    //command
    .enable_i(enableIn), .reset_i(resetIn), .stall_i(stallIn),
    //data
    .instruction_i(instructionIn),
    .instructionAddress_i(addressIn),
    .is64Bit_i(is64BitIn),
    .instructionPid_i(PidIn),
    .instructionTid_i(TidIn),
    .instructionMajId_i(instMajIdIn),
    //output
    .enableOut(enableOut),
    .instFormat_o(instFormatOut),
    .opcodeOut(opcodeOut),
    .addressOut(addressOut),
    .funcUnitTypeOut(funcUnitTypeOut),
    .majIDOut(majIDOut),
    .minIDOut(minIDOut),
    .is64BitOut(is64BitOut),
    .pidOut(pidOut),
    .tidOut(tidOut),
    .op1rwOut(op1rwOut), .op2rwOut(op2rwOut), .op3rwOut(op3rwOut), .op4rwOut(op4rwOut),
    .op1IsRegOut(op1IsRegOut), .op2IsRegOut(op2IsRegOut), .op3IsRegOut(op3IsRegOut), .op4IsRegOut(op4IsRegOut),
    .bodyOut(bodyOut)
    );

integer instCtr;
integer opcode;
integer xopcode;
integer numInstTested;
integer decodedInsts;
integer i;

`ifdef DEBUG_PRINT
integer debugFile;
`endif

initial begin
    $dumpfile("DecodeTest.vcd");
    $dumpvars(0,decodeUnit);
    //debugFile = $fopen("DecodeTest", "w");

    /////init vars
    clockIn = 0;
    enableIn = 0;
    resetIn = 0;
    stallIn = 0;
    instructionIn = 0;
    addressIn = 0;
    is64BitIn = 0;
    PidIn = 0;
    TidIn = 0;
    instMajIdIn = 0;
    #1;

    //reset
    clockIn = 1;
    resetIn = 1;
    #1;
    clockIn = 0;
    resetIn = 0;
    #1; 

    is64BitIn = 1;


    ///Test A format instructions:
    instCtr = 0; numInstTested = 24; decodedInsts = 0;
    //Iterate all possible opcodes
    $display("Testing A format instructions:");
    for(opcode = 0; opcode <= 6'b111111; opcode = opcode + 1)
    begin
        //Iterate all possible xopcodes
        for(xopcode = 0; xopcode <= 5'b11111; xopcode = xopcode + 1)
        begin
            instMajIdIn = instCtr;
            instructionIn[0:primOpcodeSize-1] = opcode;
            instructionIn[26:30] = xopcode;
            enableIn = 1;

            //present ints to pipeline
            clockIn = 1;
            #1;
            clockIn = 0;
            #1; 

            //run the inst through the pipe and let it dry
            enableIn = 0;
            for(i = 0; i < 2; i = i + 1) 
            begin
            clockIn = 1;
            #1;
            clockIn = 0;
            #1;
            end 

            if(enableOut == 1 && instFormatOut == A)
                decodedInsts = decodedInsts + 1;

            addressIn = addressIn + 4;
            instCtr = instCtr + 1;
        end
    end
    $display("Decoded %d of %d total supported instructions", decodedInsts, numInstTested);
    if(decodedInsts == numInstTested)
        $display("PASS");
    else
        $display("FAIL");
    $display();


    ///Test B format instructions:
    instCtr = 0; numInstTested = 1; decodedInsts = 0;
    //Iterate all possible opcodes
    $display("Testing B format instructions:");
    for(opcode = 0; opcode <= 6'b111111; opcode = opcode + 1)
    begin
            instMajIdIn = instCtr;
            instructionIn[0:primOpcodeSize-1] = opcode;
            enableIn = 1;

            //present ints to pipeline
            clockIn = 1;
            #1;
            clockIn = 0;
            #1; 

            //run the inst through the pipe and let it dry
            enableIn = 0;
            for(i = 0; i < 2; i = i + 1) 
            begin
            clockIn = 1;
            #1;
            clockIn = 0;
            #1;
            end 

            if(enableOut == 1 && instFormatOut == B)
                decodedInsts = decodedInsts + 1;

            addressIn = addressIn + 4;
            instCtr = instCtr + 1;
    end
    $display("Decoded %d of %d total supported instructions", decodedInsts, numInstTested);
    if(decodedInsts == numInstTested)
        $display("PASS");
    else
        $display("FAIL");
    $display();

    ///Test D format instructions:
    instCtr = 0; numInstTested = 40; decodedInsts = 0;
    //Iterate all possible opcodes
    $display("Testing D format instructions:");
    for(opcode = 0; opcode <= 6'b111111; opcode = opcode + 1)
    begin
            instMajIdIn = instCtr;
            instructionIn[0:primOpcodeSize-1] = opcode;
            enableIn = 1;

            //present ints to pipeline
            clockIn = 1;
            #1;
            clockIn = 0;
            #1; 

            //run the inst through the pipe and let it dry
            enableIn = 0;
            for(i = 0; i < 2; i = i + 1) 
            begin
            clockIn = 1;
            #1;
            clockIn = 0;
            #1;
            end 

            if(enableOut == 1 && instFormatOut == D)
                decodedInsts = decodedInsts + 1;

            addressIn = addressIn + 4;
            instCtr = instCtr + 1;
    end
    $display("Decoded %d of %d total supported instructions", decodedInsts, numInstTested);
    if(decodedInsts == numInstTested)
        $display("PASS");
    else
        $display("FAIL");
    $display();


end

endmodule