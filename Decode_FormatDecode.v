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
    parameter opcodeSize = 6
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
);

always @(posedge clock_i)
begin
    if(enable_i)
    begin
        case(instruction_i[0+:opcodeSize])
        18: begin end //I-form
        16: begin end //B-form
        19: begin end //XL-form | DX-form
        17: begin end //SC-form
        34: begin end //D-form
        35: begin end //D-form
        31: begin end //X-form | XO-form | Z23-form | A-form | XS-form | XFX-form
        40: begin end //D-form
        41: begin end //D-form
        42: begin end //D-form
        43: begin end //D-form
        32: begin end //D-form
        33: begin end //D-form
        58: begin end //DS-form
        38: begin end //D-form
        39: begin end //D-form
        44: begin end //D-form
        45: begin end //D-form
        36: begin end //D-form
        37: begin end //D-form
        62: begin end //DS-form
        56: begin end //DQ-form
        62: begin end //DS-form
        46: begin end //D-form
        47: begin end //D-form
        14: begin end //D-form
        15: begin end //D-form
        12: begin end //D-form
        13: begin end //D-form
        08: begin end //D-form
        07: begin end //D-form
        04: begin end //VA-form | VX-form | VC-form
        11: begin end //D-form
        10: begin end //D-form
        03: begin end //D-form
        02: begin end //D-form
        28: begin end //D-form
        29: begin end //D-form
        24: begin end //D-form
        25: begin end //D-form
        26: begin end //D-form
        27: begin end //D-form
        21: begin end //M-form
        23: begin end //M-form
        20: begin end //M-form
        30: begin end //MD-form
        30: begin end //MDS-form
        48: begin end //D-form
        49: begin end //D-form
        50: begin end //D-form
        51: begin end //D-form
        52: begin end //D-form
        53: begin end //D-form
        54: begin end //D-form
        55: begin end //D-form
        57: begin end //DS-form
        61: begin end //DS-form
        63: begin end //A-form | X-form | XFL-form | Z22-form | Z23-form
        59: begin end //A-form | X-form | Z22-form | Z23-form
        60: begin end //XX2-form | XX3-form
        


        endcase
    end
end

endmodule