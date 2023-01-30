`timescale 1ns / 1ps
//`define DEBUG
//`define DEBUG_PRINT
`define QUIET_INVALID
/*/////////Format decode/////////////
Writen by Josh "Hakaru" Cantwell - 19.12.2022

The Power ISA specifies 25 different instruction formats, this decode unit operates in 3 stages, these are decribed below:
This stage takes the instruction from the fetch unit and performs a quick scan on the instruction to determine 
the instruction's format. It then provides the instruction to the format specific decoder.
*/

module FormatScanner
#(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 32, parameter TidSize = 64,
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter primOpcodeSize = 6,
    parameter formatScannerInstance = 0,

    //Each format has a unique bit, this means that I can or multiple formats together into a single variable to pass to
    //the next stage for the format-specific decoders to look at for the instruction opcodes with multiple possible formats

    parameter A = 2**00, parameter B = 2**01, parameter D = 2**02, parameter DQ = 2**03, parameter DS = 2**04, parameter DX = 2**05,
    parameter I = 2**06, parameter M = 2**07, parameter MD = 2**08, parameter MDS = 2**09, parameter SC = 2**10, parameter VA = 2**11,
    parameter VC = 2**12, parameter VX = 2**13, parameter X = 2**14, parameter XFL = 2**15, parameter XFX = 2**16, parameter XL = 2**17,
    parameter XO = 2**18, parameter XS = 2**19, parameter XX2 = 2**20, parameter XX3 = 2**21, parameter XX4 = 2**22,
    parameter Z22 = 2**23, parameter Z23 = 2**24     
)
(
    ///Input
    //command
    input wire clock_i,
    `ifdef DEBUG_PRINT 
    input wire reset_i,
`endif
    input wire enable_i, stall_i,
    //data
    input wire [0:instructionWidth-1] instruction_i,
    input wire [0:addressWidth-1] instructionAddress_i,
    input wire is64Bit_i,
    input wire [0:PidSize-1] instructionPid_i,
    input wire [0:TidSize-1] instructionTid_i,
    input wire [0:instructionCounterWidth-1] instructionMajId_i,
    ///Output
    output reg outputEnable_o,
    output reg [0:25-1] instFormat_o,
    output reg [0:primOpcodeSize-1] instOpcode_o,
    output reg [0:instructionWidth-1] instruction_o,
    output reg [0:addressWidth-1] instructionAddress_o,
    output reg is64Bit_o,
    output reg [0:PidSize-1] instructionPid_o,
    output reg [0:TidSize-1] instructionTid_o,
    output reg [0:instructionCounterWidth-1] instructionMajId_o
);

`ifdef DEBUG_PRINT
integer debugFID;
`endif

always @(posedge clock_i)
begin
    `ifdef DEBUG_PRINT
    if(reset_i)
    begin
        $display("Format scanner reset");
        case(formatScannerInstance)//If we have multiple decoders, they each get different files. The second number indicates the decoder# log file.
        0: begin 
            debugFID = $fopen("DecodeFormatScan0.log", "w");
        end
        1: begin 
            debugFID = $fopen("DecodeFormatScan1.log", "w");
        end
        2: begin 
            debugFID = $fopen("DecodeFormatScan2.log", "w");
        end
        3: begin 
            debugFID = $fopen("DecodeFormatScan3.log", "w");
        end
        4: begin 
            debugFID = $fopen("DecodeFormatScan4.log", "w");
        end
        5: begin 
            debugFID = $fopen("DecodeFormatScan5.log", "w");
        end
        6: begin 
            debugFID = $fopen("DecodeFormatScan6.log", "w");
        end
        7: begin 
            debugFID = $fopen("DecodeFormatScan7.log", "w");
        end
        endcase
        
    end
    else `endif if(enable_i && !stall_i)
    begin
        //pass through the format agnostic data
        instruction_o <= instruction_i;
        instructionAddress_o <= instructionAddress_i;
        is64Bit_o <= is64Bit_i;
        instructionPid_o <= instructionPid_i;
        instructionTid_o <= instructionTid_i;
        instructionMajId_o <= instructionMajId_i;
        instOpcode_o <= instruction_i[0+:primOpcodeSize];
        //determine the instructino format
        case(instruction_i[0+:primOpcodeSize])
        18: begin outputEnable_o <= 1; instFormat_o <= I;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction I Format", instructionMajId_i); `endif 
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction I Format", instructionMajId_i); `endif 
        end //I-form
        16: begin outputEnable_o <= 1; instFormat_o <= B;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction B Format", instructionMajId_i); `endif 
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction B Format", instructionMajId_i); `endif 
        end //B-form
        19: begin outputEnable_o <= 1; instFormat_o <= XL | DX;     
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction XL | DX Format", instructionMajId_i); `endif 
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction XL | DX Format", instructionMajId_i); `endif 
        end //XL-form | DX-form
        17: begin outputEnable_o <= 1; instFormat_o <= SC;          
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction SC Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction SC Format", instructionMajId_i); `endif 
         end //SC-form
        34: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction F Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction F Format", instructionMajId_i); `endif 
         end //D-form
        35: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction F Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction F Format", instructionMajId_i); `endif 
         end //D-form
        31: begin outputEnable_o <= 1; instFormat_o <= X | XO | Z23 | A | XS | XFX; 
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction X | XO | Z23 | A | XS | XFX Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction X | XO | Z23 | A | XS | XFX Format", instructionMajId_i); `endif 
         end //X-form | XO-form | Z23-form | A-form | XS-form | XFX-form
        40: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        41: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        42: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        43: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        32: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        33: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        58: begin outputEnable_o <= 1; instFormat_o <= DS;          
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction DS Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction DS Format", instructionMajId_i); `endif 
         end //DS-form
        38: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        39: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        44: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        45: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        36: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        37: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        62: begin outputEnable_o <= 1; instFormat_o <= DS;          
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction DS Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction DS Format", instructionMajId_i); `endif 
         end //DS-form
        56: begin outputEnable_o <= 1; instFormat_o <= DQ;          
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction DQ Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction DQ Format", instructionMajId_i); `endif 
         end //DQ-form
        62: begin outputEnable_o <= 1; instFormat_o <= DS;          
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction DS Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction DS Format", instructionMajId_i); `endif 
         end //DS-form
        46: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        47: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        14: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        15: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        12: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        13: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        08: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        07: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        04: begin outputEnable_o <= 1; instFormat_o <= VA | VX | VC;                
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction VA | VX | VC Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction VA | VX | VC Format", instructionMajId_i); `endif 
        end //VA-form | VX-form | VC-form
        11: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        10: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        03: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        02: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        28: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        29: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        24: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        25: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        26: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        27: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        21: begin outputEnable_o <= 1; instFormat_o <= M;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction M Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction M Format", instructionMajId_i); `endif 
         end //M-form
        23: begin outputEnable_o <= 1; instFormat_o <= M;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction M Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction M Format", instructionMajId_i); `endif 
         end //M-form
        20: begin outputEnable_o <= 1; instFormat_o <= M;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction M Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction M Format", instructionMajId_i); `endif 
         end //M-form
        30: begin outputEnable_o <= 1; instFormat_o <= MD;          
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction MD Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction MD Format", instructionMajId_i); `endif 
         end //MD-form
        30: begin outputEnable_o <= 1; instFormat_o <= MDS;         
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction MDS Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction MDS Format", instructionMajId_i); `endif 
         end //MDS-form
        48: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        49: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        50: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        51: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        52: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        53: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        54: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        55: begin outputEnable_o <= 1; instFormat_o <= D;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction D Format", instructionMajId_i); `endif 
         end //D-form
        57: begin outputEnable_o <= 1; instFormat_o <= DS;          
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction DS Format", instructionMajId_i); `endif 
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction DS Format", instructionMajId_i); `endif 
        end //DS-form
        61: begin outputEnable_o <= 1; instFormat_o <= DS;          
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction DS Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction DS Format", instructionMajId_i); `endif 
         end //DS-form
        63: begin outputEnable_o <= 1; instFormat_o <= A | X | XFL | Z22 | Z23;     
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction A | X | XFL | Z22 | Z23 Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction A | X | XFL | Z22 | Z23 Format", instructionMajId_i); `endif 
        end //A-form | X-form | XFL-form | Z22-form | Z23-form
        59: begin outputEnable_o <= 1; instFormat_o <= A | X | Z22 | Z23;           
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction A | X | Z22 | Z23 Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction A | X | Z22 | Z23 Format", instructionMajId_i); `endif 
        end //A-form | X-form | Z22-form | Z23-form
        60: begin outputEnable_o <= 1; instFormat_o <= XX2 | XX3;   
        `ifdef DEBUG $display("FormatScan Inst: %d: Instruction XX2 | XX3 Format", instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "FormatScan Inst: %d: Instruction XX2 | XX3 Format", instructionMajId_i); `endif 
        end //XX2-form | XX3-form
        default: begin outputEnable_o <= 0;         
        `ifndef QUIET_INVALID                
        `ifdef DEBUG $display("Fetch stage 1: Invalid instruction: %h. Opcode: %d", instruction_i, instructionMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fetch stage 1: Invalid instruction: %h. Opcode: %d", instructionMajId_i); `endif 
        `endif
        end //Error, invalid instruction
        endcase
    end
    else
        outputEnable_o <= 0; 

end

endmodule