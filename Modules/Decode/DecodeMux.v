`timescale 1ns / 1ps
`define DEBUG
`define DEBUG_PRINT

/*/////////Format decode/////////////
Writen by Josh "Hakaru" Cantwell - 04.01.2023

This is the third stage of the decode unit, it is responsible for multiplexing the outputs of the second stage (format specific decoders) into a single output.

*////////////////////////////////////

module DecodeMux
#(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 32, parameter TidSize = 64,
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

    ////Format Specific
    parameter BimmediateSize = 14,
    parameter DimmediateSize = 16,    

    //Each format has a unique bit, this means that I can or multiple formats together into a single variable to pass to
    //the next stage for the format-specific decoders to look at for the instruction opcodes with multiple possible formats
    parameter I = 2**00, parameter B = 2**01, parameter XL = 2**02, parameter DX = 2**03, parameter SC = 2**04,
    parameter D = 2**05, parameter X = 2**06, parameter XO = 2**07, parameter Z23 = 2**08, parameter A = 2**09,
    parameter XS = 2**10, parameter XFX = 2**11, parameter DS = 2**12, parameter DQ = 2**13, parameter VA = 2**14,
    parameter VX = 2**15, parameter VC = 2**16, parameter MD = 2**17, parameter MDS = 2**18, parameter XFL = 2**19,
    parameter Z22 = 2**20, parameter XX2 = 2**21, parameter XX3 = 2**22,
    parameter DecoderMuxInstance = 0
)
(
    ////Inputs
    ///Command
    input wire clock_i,    
`ifdef DEBUG_PRINT 
    input wire reset_i,
`endif
    ///A format
    input wire Aenable_i,
    input wire [0:opcodeSize-1] AOpcode_i,
    input wire [0:addressWidth-1] AAddress_i,
    input wire [0:funcUnitCodeSize-1] AUnitType_i,
    input wire [0:instructionCounterWidth] AMajId_i,
    input wire [0:instMinIdWidth-1] AMinId_i, AnumMicroOps_i,
    input wire Ais64Bit_i,
    input wire [0:PidSize-1] APid_i,
    input wire [0:TidSize-1] ATid_i,
    input wire [0:regAccessPatternSize-1] Aop1rw_i, Aop2rw_i, Aop3rw_i, Aop4rw_i,
    input wire Aop1IsReg_i, Aop2IsReg_i, Aop3IsReg_i, Aop4IsReg_i,
    input wire AmodifiesCR_i,
    input wire [0:4 * regSize] ABody_i,

    ///B format
    input wire Benable_i,
    input wire [0:opcodeSize-1] BOpcode_i,
    input wire [0:addressWidth-1] BAddress_i,
    input wire [0:funcUnitCodeSize-1] BUnitType_i,
    input wire [0:instructionCounterWidth] BMajId_i,
    input wire [0:instMinIdWidth-1] BMinId_i, BnumMicroOps_i,
    input wire Bis64Bit_i,
    input wire [0:PidSize-1] BPid_i,
    input wire [0:TidSize-1] BTid_i,
    input wire BmodifiesCR_i,
    input wire [0:(2 * regSize) + BimmediateSize + 3] BBody_i,

    ///D format
    input wire Denable_i,
    input wire [0:opcodeSize-1] DOpcode_i,
    input wire [0:addressWidth-1] DAddress_i,
    input wire [0:funcUnitCodeSize-1] DUnitType_i,
    input wire [0:instructionCounterWidth] DMajId_i,
    input wire [0:instMinIdWidth-1] DMinId_i, DnumMicroOps_i,
    input wire Dis64Bit_i,
    input wire [0:PidSize-1] DPid_i,
    input wire [0:TidSize-1] DTid_i,
    input wire [0:regAccessPatternSize-1] Dop1rw_i, Dop2rw_i,
    input wire Dop1isReg_i, Dop2isReg_i, immIsExtended_i, immIsShifted_i,
    input wire [0:2] DisShiftedBy_i,
    input wire DmodifiesCR_i,
    input wire [0:(2 * regSize) + DimmediateSize - 1] DBody_i,

    ///output
    output reg enable_o,
    output reg [0:25-1] instFormat_o,
    output reg [0:opcodeSize-1] opcode_o,
    output reg [0:addressWidth-1] address_o,
    output reg [0:funcUnitCodeSize-1] funcUnitType_o,
    output reg [0:instructionCounterWidth-1] majID_o,
    output reg [0:instMinIdWidth-1] minID_o, numMicroOps_o,
    output reg is64Bit_o,
    output reg [0:PidSize-1] pid_o,
    output reg [0:TidSize-1] tid_o,
    output reg [0:regAccessPatternSize-1] op1rw_o, op2rw_o, op3rw_o, op4rw_o,
    output reg op1IsReg_o, op2IsReg_o, op3IsReg_o, op4IsReg_o,
    output reg modifiesCR_o,
    output reg [0:64-1] body_o//contains all operands. Large enough for 4 reg operands and a 32bit imm assuming the unified reg space has reg addresses of 8 bits
);

`ifdef DEBUG_PRINT
integer debugFID;
`endif

always @(posedge clock_i)
begin
    `ifdef DEBUG_PRINT
    if(reset_i)
    begin
        case(DecoderMuxInstance)//If we have multiple decoders, they each get different files. The second number indicates the decoder# log file.
        0: begin 
            debugFID = $fopen("DecodeMux0.log", "w");
        end
        1: begin 
            debugFID = $fopen("DecodeMux1.log", "w");
        end
        2: begin 
            debugFID = $fopen("DecodeMux2.log", "w");
        end
        3: begin 
            debugFID = $fopen("DecodeMux3.log", "w");
        end
        4: begin 
            debugFID = $fopen("DecodeMux4.log", "w");
        end
        5: begin 
            debugFID = $fopen("DecodeMux5.log", "w");
        end
        6: begin 
            debugFID = $fopen("DecodeMux6.log", "w");
        end
        7: begin 
            debugFID = $fopen("DecodeMux7.log", "w");
        end
        endcase
        
    end
    else `endif if(Aenable_i)
    begin
        `ifdef DEBUG $display("Decode Mux Inst: %d: A format instruction", AMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode Mux Inst: %d: A format instruction", AMajId_i); `endif
        enable_o <= 1; instFormat_o <= A;
        opcode_o <= AOpcode_i;
        address_o <= AAddress_i;
        funcUnitType_o <= A;
        majID_o <= AMajId_i; minID_o <= AMinId_i; numMicroOps_o <= AnumMicroOps_i;//inst IDs
        is64Bit_o <= Ais64Bit_i;//32/64b mode
        pid_o <= APid_i; tid_o <= ATid_i;//Process and Thread ID
        //Operand reg flags
        op1rw_o <= Aop1rw_i;        op2rw_o <= Aop2rw_i;        op3rw_o <= Aop3rw_i;        op4rw_o <= Aop4rw_i;
        op1IsReg_o <= Aop1IsReg_i;  op2IsReg_o <= Aop2IsReg_i;  op3IsReg_o <= Aop3IsReg_i;  op4IsReg_o <= Aop4IsReg_i;
        modifiesCR_o <= AmodifiesCR_i;
        //operand data
        body_o[0:20] <= ABody_i;
        body_o[21:64-1] <= 0;//zero out top of buffer
    end
    else if(Benable_i)
    begin
        `ifdef DEBUG $display("Decode Mux Inst: %d: B format instruction", BMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode Mux Inst: %d: B format instruction", BMajId_i); `endif
        enable_o <= 1;instFormat_o <= B;
        opcode_o <= BOpcode_i;
        address_o <= BAddress_i;
        funcUnitType_o <= B;
        majID_o <= BMajId_i; minID_o <= BMinId_i; numMicroOps_o <= BnumMicroOps_i;//inst IDs
        is64Bit_o <= Bis64Bit_i;//32/64b mode
        pid_o <= BPid_i; tid_o <= BTid_i;//Process and Thread ID
        //Operand reg flags - none used
        op1rw_o <= 0;       op2rw_o <= 0;       op3rw_o <= 0;   op4rw_o <= 0;
        op1IsReg_o <= 0;    op2IsReg_o <= 0;    op3IsReg_o <= 0;    op4IsReg_o <= 0;
        modifiesCR_o <= BmodifiesCR_i;
        body_o[0:27] <= BBody_i;
        body_o[28:64-1] <= 0;//zero out top of buffer
    end
    else if(Denable_i)
    begin
        `ifdef DEBUG $display("Decode Mux Inst: %d: D format instruction", DMajId_i); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode Mux Inst: %d: D format instruction", DMajId_i); `endif
        enable_o <= 1;instFormat_o <= D;
        opcode_o <= DOpcode_i;
        address_o <= DAddress_i;
        funcUnitType_o <= D;
        majID_o <= DMajId_i; minID_o <= DMinId_i; numMicroOps_o <= DnumMicroOps_i;//inst IDs
        is64Bit_o <= Dis64Bit_i;//32/64b mode
        pid_o <= DPid_i; tid_o <= DTid_i;//Process and Thread ID
        //Operand reg flags - none used
        op1rw_o <= Dop1rw_i;        op2rw_o <= Dop2rw_i;        op3rw_o <= 0;       op4rw_o <= 0;
        op1IsReg_o <= Dop1isReg_i;  op2IsReg_o <= Dop2isReg_i;  op3IsReg_o <= 0;    op4IsReg_o <= 0;
        modifiesCR_o <= DmodifiesCR_i;
        //Copy the registers across to buffer
        body_o[0+:10] <= DBody_i[0+:10];//copy regs
        //If the immediate is to be shifted, perform the shift here then sign extend to 64 bits and copy to buffer
        //$display("%b", DBody_i[10+:16]);
        if(immIsShifted_i)
        begin
            case(DisShiftedBy_i)
                1: begin 
                    body_o[10+:32] <= {8'h00, DBody_i[10+:16], 8'h00};//copy and extend the imm
                end
                2: begin 
                    body_o[10+:32] <= {DBody_i[10+:16], 16'b0000};//copy and extend the imm
                end
            endcase
        end
        else
        begin
            body_o[10+:32] <= {16'h0000, DBody_i[10+:16]};//copy and extend the imm
        end
        body_o[42:64-1] <= 0;//zero out top of buffer
    end
    else
    begin
        `ifndef QUIET_INVALID
        `ifdef DEBUG $display("Decode Mux: Unsupported instruction"); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "Decode Mux: Unsupported instruction"); `endif
        `endif
        enable_o <= 0;
    end

end

endmodule