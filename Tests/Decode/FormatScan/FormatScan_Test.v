`timescale 1ns / 1ps
`include "../../../Modules/Decode/DecodeFormatScan.v"

module DecodeStage1_Test
#(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter opcodeSize = 6,

    //Each format has a unique bit, this means that I can or multiple formats together into a single variable to pass to
    //the next stage for the format-specific decoders to look at for the instruction opcodes with multiple possible formats
    parameter A = 2**00, parameter B = 2**01, parameter D = 2**02, parameter DQ = 2**03, parameter DS = 2**04, parameter DX = 2**05,
    parameter I = 2**06, parameter M = 2**07, parameter MD = 2**08, parameter MDS = 2**09, parameter SC = 2**10, parameter VA = 2**11,
    parameter VC = 2**12, parameter VX = 2**13, parameter X = 2**14, parameter XFL = 2**15, parameter XFX = 2**16, parameter XL = 2**17,
    parameter XO = 2**18, parameter XS = 2**19, parameter XX2 = 2**20, parameter XX3 = 2**21, parameter XX4 = 2**22,
    parameter Z22 = 2**23, parameter Z23 = 2**24
)(
);

///inputs
reg clockIn;
reg enableIn, stallIn;
reg [0:instructionWidth-1] instructionIn;
reg [0:addressWidth-1] instructionAddressIn;
reg [0:PidSize-1] instructionPidIn;
reg [0:TidSize-1] instructionTidIn;
reg [0:instructionCounterWidth-1] instructionMajIdIn;
///output
wire stage1EnableOut;
wire [0:25] stage1instFormatOut;
wire [0:opcodeSize-1] stage1OpcodeOut;
wire [0:instructionWidth-1] stage1instructionOut;
wire [0:addressWidth-1] stage1instructionAddressOut;
wire [0:PidSize-1] stage1instructionPidOut;
wire [0:TidSize-1] stage1instructionTidOut;
wire [0:instructionCounterWidth-1] stage1instructionMajIdOut;

FormatScanner #(
    //Sizes
    .addressWidth(addressWidth),
    .instructionWidth(instructionWidth),
    .PidSize(PidSize), .TidSize(TidSize),
    .instructionCounterWidth(instructionCounterWidth),
    .opcodeSize(opcodeSize),
    //Formats
    .I(I), .B(B), .XL(XL), .DX(DX), .SC(SC),
    .D(D), .X(X), .XO(XO), .Z23(Z23), .A(A),
    .XS(XS), .XFX(XFX), .DS(DS), .DQ(DQ), .VA(VA),
    .VX(VX), .VC(VC), .MD(MD), .MDS(MDS), .XFL(XFL),
    .Z22(Z22), .XX2(XX2), .XX3(XX3)
)
formatScanDecode
(
    ///Input
    //command
    .clock_i(clockIn),
    .enable_i(enableIn), .stall_i(stallIn),
    //data
    .instruction_i(instructionIn),
    .instructionAddress_i(instructionAddressIn),
    .instructionPid_i(instructionPidIn),
    .instructionTid_i(instructionTidIn),
    .instructionMajId_i(instructionMajIdIn),
    ///Output
    .outputEnable_o(stage1EnableOut),
    .instFormat_o(stage1instFormatOut),
    .instOpcode_o(stage1OpcodeOut),
    .instruction_o(stage1instructionOut),
    .instructionAddress_o(stage1instructionAddressOut),
    .instructionPid_o(stage1instructionPidOut),
    .instructionTid_o(stage1instructionTidOut),
    .instructionMajId_o(stage1instructionMajIdOut)
);

integer i;

initial begin
    $dumpfile("FormatScanTest.vcd");
    $dumpvars(0,formatScanDecode);
    //init vars
    clockIn = 0;
    enableIn = 0; stallIn = 0;
    instructionIn = 0;
    instructionAddressIn = 0;
    instructionPidIn = 0;
    instructionTidIn = 0;
    instructionMajIdIn = 0;
    #2;

    $display("Running through all possible opcodes. NOTE: Not all are valid.");
    enableIn = 1;
    for(i = 0; i < 2**6; i = i + 1)
    begin
        instructionIn[0:5] = i;//Just running through all opcodes
        instructionMajIdIn = i;
        clockIn = 1;
        #1;
        clockIn = 0;
        //$display("Instruction opcode: %d", stage1OpcodeOut);
        //$display("      Instruction format bitfield: %b\n", stage1instFormatOut);
        #1;    
    end
    enableIn = 0;

end


endmodule