`timescale 1ns / 1ps
`define DEBUG

/*/////////Format decode/////////////
Writen by Josh "Hakaru" Cantwell - 19.12.2022

The Power ISA specifies 25 different instruction formats 25, this decode unit operates in 3 stages, these are decribed below:
This stage takes the instruction from the fetch unit and performs a quick scan on the instruction to determine 
the instruction's format. It then provides the instruction to the format specific decoder.
*/

module Format_Decoder
#(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter opcodeSize = 6,

    //Each format has a unique bit, this means that I can or multiple formats together into a single variable to pass to
    //the next stage for the format-specific decoders to look at for the instruction opcodes with multiple possible formats
    parameter I = 2**00, parameter B = 2**01, parameter XL = 2**02, parameter DX = 2**03, parameter SC = 2**04,
    parameter D = 2**05, parameter X = 2**06, parameter XO = 2**07, parameter Z23 = 2**08, parameter A = 2**09,
    parameter XS = 2**10, parameter XFX = 2**11, parameter DS = 2**12, parameter DQ = 2**13, parameter VA = 2**14,
    parameter VX = 2**15, parameter VC = 2**16, parameter MD = 2**17, parameter MDS = 2**18, parameter XFL = 2**19,
    parameter Z22 = 2**20, parameter XX2 = 2**21, parameter XX3 = 2**22
)
(
    ///Input
    //command
    input wire clock_i,
    input wire enable_i, stall_i,
    //data
    input wire [0:instructionWidth-1] instruction_i,
    input wire [0:addressWidth-1] instructionAddress_i,
    input wire [0:PidSize-1] instructionPid_i,
    input wire [0:TidSize-1] instructionTid_i,
    input wire [0:instructionCounterWidth-1] instructionMajId_i,
    ///Output
    output reg outputEnable_o,
    output reg [0:4] instFormat_o,
    output reg [0:instructionWidth-1] instruction_o,
    output reg [0:addressWidth-1] instructionAddress_o,
    output reg [0:PidSize-1] instructionPid_o,
    output reg [0:TidSize-1] instructionTid_o,
    output reg [0:instructionCounterWidth-1] instructionMajId_o
);

always @(posedge clock_i)
begin
    if(enable_i)
    begin

        //pass through the format agnostic data
        instruction_o <= instruction_i;
        instructionAddress_o <= instructionAddress_i;
        instructionPid_o <= instructionPid_i;
        instructionTid_o <= instructionTid_i;
        instructionMajId_o <= instructionMajId_i;

        //determine the instructino format
        case(instruction_i[0+:opcodeSize])
        18: begin outputEnable_o <= 1; instFormat_o <= I; `ifdef DEBUG $display("Fetch stage 1: Instruction I Format"); `endif end //I-form
        16: begin outputEnable_o <= 1; instFormat_o <= B; `ifdef DEBUG $display("Fetch stage 1: Instruction B Format"); `endif end //B-form
        19: begin outputEnable_o <= 1; instFormat_o <= XL | DX; `ifdef DEBUG $display("Fetch stage 1: Instruction XL | DX Format"); `endif end //XL-form | DX-form
        17: begin outputEnable_o <= 1; instFormat_o <= SC; `ifdef DEBUG $display("Fetch stage 1: Instruction SC Format"); `endif end //SC-form
        34: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction F Format"); `endif end //D-form
        35: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction F Format"); `endif end //D-form
        31: begin outputEnable_o <= 1; instFormat_o <= X | XO | Z23 | A | XS | XFX; `ifdef DEBUG $display("Fetch stage 1: Instruction X | XO | Z23 | A | XS | XFX Format"); `endif end //X-form | XO-form | Z23-form | A-form | XS-form | XFX-form
        40: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        41: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        42: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        43: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        32: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        33: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        58: begin outputEnable_o <= 1; instFormat_o <= DD; `ifdef DEBUG $display("Fetch stage 1: Instruction DS Format"); `endif end //DS-form
        38: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        39: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        44: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        45: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        36: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        37: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        62: begin outputEnable_o <= 1; instFormat_o <= DS; `ifdef DEBUG $display("Fetch stage 1: Instruction DS Format"); `endif end //DS-form
        56: begin outputEnable_o <= 1; instFormat_o <= DQ; `ifdef DEBUG $display("Fetch stage 1: Instruction DQ Format"); `endif end //DQ-form
        62: begin outputEnable_o <= 1; instFormat_o <= DS; `ifdef DEBUG $display("Fetch stage 1: Instruction DS Format"); `endif end //DS-form
        46: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        47: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        14: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        15: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        12: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        13: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        08: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        07: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        04: begin outputEnable_o <= 1; instFormat_o <= VA | VX | VC; `ifdef DEBUG $display("Fetch stage 1: Instruction VA | VX | VC Format"); `endif end //VA-form | VX-form | VC-form
        11: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        10: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        03: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        02: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        28: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        29: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        24: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        25: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        26: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        27: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        21: begin outputEnable_o <= 1; instFormat_o <= M; `ifdef DEBUG $display("Fetch stage 1: Instruction M Format"); `endif end //M-form
        23: begin outputEnable_o <= 1; instFormat_o <= M; `ifdef DEBUG $display("Fetch stage 1: Instruction M Format"); `endif end //M-form
        20: begin outputEnable_o <= 1; instFormat_o <= M; `ifdef DEBUG $display("Fetch stage 1: Instruction M Format"); `endif end //M-form
        30: begin outputEnable_o <= 1; instFormat_o <= MD; `ifdef DEBUG $display("Fetch stage 1: Instruction MD Format"); `endif end //MD-form
        30: begin outputEnable_o <= 1; instFormat_o <= MDS; `ifdef DEBUG $display("Fetch stage 1: Instruction MDS Format"); `endif end //MDS-form
        48: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        49: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        50: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        51: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        52: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        53: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        54: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        55: begin outputEnable_o <= 1; instFormat_o <= D; `ifdef DEBUG $display("Fetch stage 1: Instruction D Format"); `endif end //D-form
        57: begin outputEnable_o <= 1; instFormat_o <= DS; `ifdef DEBUG $display("Fetch stage 1: Instruction DS Format"); `endif end //DS-form
        61: begin outputEnable_o <= 1; instFormat_o <= DS; `ifdef DEBUG $display("Fetch stage 1: Instruction DS Format"); `endif end //DS-form
        63: begin outputEnable_o <= 1; instFormat_o <= A | X | XFL | Z22 | Z23; `ifdef DEBUG $display("Fetch stage 1: Instruction A | X | XFL | Z22 | Z23 Format"); `endif end //A-form | X-form | XFL-form | Z22-form | Z23-form
        59: begin outputEnable_o <= 1; instFormat_o <= A | X | Z22 | Z23; `ifdef DEBUG $display("Fetch stage 1: Instruction A | X | Z22 | Z23 Format"); `endif end //A-form | X-form | Z22-form | Z23-form
        60: begin outputEnable_o <= 1; instFormat_o <= XX2 | XX3; `ifdef DEBUG $display("Fetch stage 1: Instruction XX2 | XX3 Format"); `endif end //XX2-form | XX3-form
        default: begin outputEnable_o <= 0; `ifdef DEBUG $display("Fetch stage 1: Invalid instruction: %h", instruction_i); `endif end //Error, invalid instruction
        endcase
    end
end

endmodule