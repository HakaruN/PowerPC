`timescale 1ns / 1ps
`include "../../../Modules/Decode/DecodeMux.v"

module DecodeMuxTest #(
    parameter addressWidth = 64, //addresses are 64 bits wide
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter PidSize = 20, parameter TidSize = 16, //1048K processes uniquly identifiable and 64K threads per process.
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter instMinIdWidth = 7,
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
    parameter Z22 = 2**20, parameter XX2 = 2**21, parameter XX3 = 2**22
)
(
);
    ////Inputs
    ///Command
    reg clockIn;

    ///A format
    reg AenableIn;
    reg [0:opcodeSize-1] AOpcodeIn;
    reg [0:addressWidth-1] AAddressIn;
    reg [0:funcUnitCodeSize-1] AUnitTypeIn;
    reg [0:instructionCounterWidth] AMajIdIn;
    reg [0:instMinIdWidth-1] AMinIdIn;
    reg Ais64BitIn;
    reg [0:PidSize-1] APidIn;
    reg [0:TidSize-1] ATidIn;
    reg [0:regAccessPatternSize-1] Aop1rwOut, Aop2rwOut, Aop3rwOut, Aop4rwOut;
    reg Aop1IsRegOut, Aop2IsRegOut, Aop3IsRegOut, Aop4IsRegOut;
    reg [0:4 * regSize] ABodyIn;

    ///B format
    reg BenableIn;
    reg [0:opcodeSize-1] BOpcodeIn;
    reg [0:addressWidth-1] BAddressIn;
    reg [0:funcUnitCodeSize-1] BUnitTypeIn;
    reg [0:instructionCounterWidth] BMajIdIn;
    reg [0:instMinIdWidth-1] BMinIdIn;
    reg Bis64BitIn;
    reg [0:PidSize-1] BPidIn;
    reg [0:TidSize-1] BTidIn;
    reg [0:(2 * regSize) + BimmediateSize + 3] BBodyIn;

    ///D format
    reg DenableIn;
    reg [0:opcodeSize-1] DOpcodeIn;
    reg [0:addressWidth-1] DAddressIn;
    reg [0:funcUnitCodeSize-1] DUnitTypeIn;
    reg [0:instructionCounterWidth] DMajIdIn;
    reg [0:instMinIdWidth-1] DMinIdIn;
    reg Dis64BitIn;
    reg [0:PidSize-1] DPidIn;
    reg [0:TidSize-1] DTidIn;
    reg [0:regAccessPatternSize-1] Dop1rwIn, Dop2rwIn;
    reg Dop1isRegIn, Dop2isRegIn, immIsExtendedIn, immIsShiftedIn;
    reg [0:(2 * regSize) + DimmediateSize - 1] DBodyIn;

    ///output
    wire enableOut;
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


DecodeMux #(
)
decodeMux
(
    ////Inputs
    ///Command
    .clock_i(clockIn),    

    ///A format
    .Aenable_i(AenableIn),
    .AOpcode_i(AOpcodeIn),
    .AAddress_i(AAddressIn),
    .AUnitType_i(AUnitTypeIn),
    .AMajId_i(AMajIdIn),
    .AMinId_i(AMinIdIn),
    .Ais64Bit_i(Ais64BitIn),
    .APid_i(APidIn),
    .ATid_i(ATidIn),
    .Aop1rw_o(Aop1rwOut), .Aop2rw_o(Aop2rwOut), .Aop3rw_o(Aop3rwOut), .Aop4rw_o(Aop4rwOut),
    .Aop1IsReg_o(Aop1IsRegOut), .Aop2IsReg_o(Aop2IsRegOut), .Aop3IsReg_o(Aop3IsRegOut), .Aop4IsReg_o(Aop4IsRegOut),
    .ABody_i(ABodyIn),

    ///B format
    .Benable_i(BenableIn),
    .BOpcode_i(BOpcodeIn),
    .BAddress_i(BAddressIn),
    .BUnitType_i(BUnitTypeIn),
    .BMajId_i(BMajIdIn),
    .BMinId_i(BMinIdIn),
    .Bis64Bit_i(Bis64BitIn),
    .BPid_i(BPidIn),
    .BTid_i(BTidIn),
    .BBody_i(BBodyIn),

    ///D format
    .Denable_i(DenableIn),
    .DOpcode_i(DOpcodeIn),
    .DAddress_i(DAddressIn),
    .DUnitType_i(DUnitTypeIn),
    .DMajId_i(DMajIdIn),
    .DMinId_i(DMinIdIn),
    .Dis64Bit_i(Dis64BitIn),
    .DPid_i(DPidIn),
    .DTid_i(DTidIn),
    .Dop1rw_i(Dop1rwIn), .Dop2rw_i(Dop2rwIn),
    .Dop1isReg_i(Dop1isRegIn), .Dop2isReg_i(Dop2isRegIn), .immIsExtended_i(immIsExtendedIn), .immIsShifted_i(immIsShiftedIn),
    .DBody_i(DBodyIn),

    ///output
    .enable_o(enableOut),
    .opcode_o(opcodeOut),
    .address_o(addressOut),
    .funcUnitType_o(funcUnitTypeOut),
    .majID_o(majIDOut),
    .minID_o(minIDOut),
    .is64Bit_o(is64BitOut),
    .pid_o(pidOut),
    .tid_o(tidOut),
    .op1rw_o(op1rwOut), .op2rw_o(op2rwOut), .op3rw_o(op3rwOut), .op4rw_o(op4rwOut),
    .op1IsReg_o(op1IsRegOut), .op2IsReg_o(op2IsRegOut), .op3IsReg_o(op3IsRegOut), .op4IsReg_o(op4IsRegOut),
    .body_o(bodyOut)
);


initial begin
    $dumpfile("DecodeMuxTest.vcd");
    $dumpvars(0,decodeMux);
    /////init vars
    clockIn = 0;
    ///A format
    AenableIn = 0;
    AOpcodeIn = 0;
    AAddressIn = 0;
    AUnitTypeIn = 0;
    AMajIdIn = 0;
    AMinIdIn = 0;
    Ais64BitIn = 0;
    APidIn = 0;
    ATidIn = 0;
    Aop1rwOut = 0; Aop2rwOut = 0; Aop3rwOut = 0; Aop4rwOut = 0;
    Aop1IsRegOut = 0; Aop2IsRegOut = 0; Aop3IsRegOut = 0; Aop4IsRegOut = 0;
    ABodyIn = 0;
    ///B format
    BenableIn = 0;
    BOpcodeIn = 0;
    BAddressIn = 0;
    BUnitTypeIn = 0;
    BMajIdIn = 0;
    BMinIdIn = 0;
    Bis64BitIn = 0;
    BPidIn = 0;
    BTidIn = 0;
    BBodyIn = 0;
    ///D format
    DenableIn = 0;
    DOpcodeIn = 0;
    DAddressIn = 0;
    DUnitTypeIn = 0;
    DMajIdIn = 0;
    DMinIdIn = 0;
    Dis64BitIn = 0;
    DPidIn = 0;
    DTidIn = 0;
    Dop1rwIn = 0; Dop2rwIn = 0;
    Dop1isRegIn = 0; Dop2isRegIn = 0; immIsExtendedIn = 0; immIsShiftedIn = 0;
    DBodyIn = 0;


    //Start with A format
    AenableIn = 1;
    AOpcodeIn = 4;//Floating Multiply (double)
    AAddressIn = 0;
    AUnitTypeIn = FPUnitId;
    AMajIdIn = 0;
    AMinIdIn = 0;
    Ais64BitIn = 1;
    APidIn = 0;
    ATidIn = 0;
    Aop1rwOut = regWrite; Aop2rwOut = regRead; Aop3rwOut = 2'b00; Aop4rwOut = regRead;
    Aop1IsRegOut = 1; Aop2IsRegOut = 1; Aop3IsRegOut = 0; Aop4IsRegOut = 1;

    //ABodyIn = {5'b10001, 5'b01110, 5'b00000, 5'b11111, 1};
    ABodyIn = 21'b10001_01110_11111_00000_1;

    clockIn = 1;
    #1;
    clockIn = 0;
    #1;

/*
    //Test opcode == 31 insts
    opcode = 31; validInstCtrTmp = 0;
    for(XopLoopCtr = 0; XopLoopCtr < 32; XopLoopCtr = XopLoopCtr + 1)
    begin
        //test inst:
        xopcode = XopLoopCtr;
        #1;
        instructionIn = {opcode, operand1, operand2, operand3, operand4, xopcode, RCflag};
        instructionOpcodeIn = opcode; instructionMajIdIn = opcode; instructionAddressIn = opcode;
        enableIn = 1;
        clockIn = 1;
        #1;
        clockIn = 0;
        enableIn = 0;
        #1;

        if(enableOut == 1)//count how many valid instructions are detected. Should be 24
        begin
            validInstCtrTmp = validInstCtrTmp + 1;
        end
    end
    $display("Detected %d valid instructions for opcode = 31. There shoule be 1.", validInstCtrTmp);

    //teset opcode == 63
    opcode = 63; validInstCtrTmp = 0;
    for(XopLoopCtr = 0; XopLoopCtr < 32; XopLoopCtr = XopLoopCtr + 1)
    begin
        //test inst:
        xopcode = XopLoopCtr;
        #1;
        instructionIn = {opcode, operand1, operand2, operand3, operand4, xopcode, RCflag};
        instructionOpcodeIn = opcode; instructionMajIdIn = opcode; instructionAddressIn = opcode;
        enableIn = 1;
        clockIn = 1;
        #1;
        clockIn = 0;
        enableIn = 0;
        #1;

        if(enableOut == 1)//count how many valid instructions are detected. Should be 24
        begin
            validInstCtrTmp = validInstCtrTmp + 1;
        end
    end
    $display("Detected %d valid instructions for opcode = 63. There shoule be 12.", validInstCtrTmp);

    //teset opcode == 59
    opcode = 59; validInstCtrTmp = 0;
    for(XopLoopCtr = 0; XopLoopCtr < 32; XopLoopCtr = XopLoopCtr + 1)
    begin
        //test inst:
        xopcode = XopLoopCtr;
        #1;
        instructionIn = {opcode, operand1, operand2, operand3, operand4, xopcode, RCflag};
        instructionOpcodeIn = opcode; instructionMajIdIn = opcode; instructionAddressIn = opcode;
        enableIn = 1;
        clockIn = 1;
        #1;
        clockIn = 0;
        enableIn = 0;
        #1;

        if(enableOut == 1)//count how many valid instructions are detected. Should be 24
        begin
            validInstCtrTmp = validInstCtrTmp + 1;
        end
    end
    $display("Detected %d valid instructions for opcode = 59. There shoule be 11.", validInstCtrTmp);


    validInstCtrTmp = 0;
    for(OpLoopCtr = 0; OpLoopCtr < 64; OpLoopCtr = OpLoopCtr + 1)
    begin
        for(XopLoopCtr = 0; XopLoopCtr < 32; XopLoopCtr = XopLoopCtr + 1)
        begin
            //test inst:
            opcode = OpLoopCtr;
            xopcode = XopLoopCtr;
            #1;
            instructionIn = {opcode, operand1, operand2, operand3, operand4, xopcode, RCflag};
            instructionOpcodeIn = opcode; instructionMajIdIn = opcode; instructionAddressIn = opcode;
            enableIn = 1;
            clockIn = 1;
            #1;
            clockIn = 0;
            enableIn = 0;
            #1;
            if(enableOut == 1)//count how many valid instructions are detected. Should be 24
            begin
                validInstCtrTmp = validInstCtrTmp + 1;
            end
        end
    end

    if(validInstCtrTmp == numValidInstr)
    $display("PASS: %d out of %d instructions correctly detected", validInstCtrTmp, numValidInstr);
    else
    $display("FAIL: %d out of %d instructions correctly detected", validInstCtrTmp, numValidInstr);
    */
        

end

endmodule