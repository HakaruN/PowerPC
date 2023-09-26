`timescale 1ns / 1ps
`define DEBUG
`define DEBUG_PRINT

/*///////////////In order instruction queue////////////////////
//General registers
32 64-b Integer registers GPR[0:31]
64-b Exception reg XER 

//Special registers
32-b Processor Version Register PVR
32-b Chip Information Register CIR
32-b Processor Identification Register PIR


*//////////////////////////////////////////////////////////////



module FXRAT #(
    parameter regSize = 64,
    parameter ROBEntryWidth = 7,
    parameter numRegs = 32,
    parameter opcodeSize = 12,
    parameter PidSize = 20, parameter TidSize = 16,
    parameter instructionCounterWidth = 64,// 64 bit counter to uniquly identify instructions, this is known as the major ID as instructions may be broken into micro instructions which will have the same major ID yet unique minor IDs
    parameter instMinIdWidth = 5,
    parameter FXRATFileInstance = 0
)
(
    ///inputs
    //command
    input wire clock_i, reset_i, enable_i,
    input wire [0:1] numInst_i,
    //Instr 1
    input wire [0:regSize-1] inst1Param1_i, inst1Param2_i, inst1Param3_i, inst1Param4_i,
    input wire inst1Param1En_i, inst1Param2En_i, inst1Param3En_i, inst1Param4En_i, 
    input wire inst1Param1IsReg_i, inst1Param2IsReg_i, inst1Param3IsReg_i, inst1Param4IsReg_i, 
    input wire [0:1] inst1Param1RW_i, inst1Param2RW_i, inst1Param3RW_i, inst1Param4RW_i,
    //Instr 2
    input wire [0:regSize-1] inst2Param1_i, inst2Param2_i, inst2Param3_i, inst2Param4_i,
    input wire inst2Param1En_i, inst2Param2En_i, inst2Param3En_i, inst2Param4En_i, 
    input wire inst2Param1IsReg_i, inst2Param2IsReg_i, inst2Param3IsReg_i, inst2Param4IsReg_i, 
    input wire [0:1] inst2Param1RW_i, inst2Param2RW_i, inst2Param3RW_i, inst2Param4RW_i,
    //Instr 3
    input wire [0:regSize-1] inst3Param1_i, inst3Param2_i, inst3Param3_i, inst3Param4_i,
    input wire inst3Param1En_i, inst3Param2En_i, inst3Param3En_i, inst3Param4En_i,
    input wire inst3Param1IsReg_i, inst3Param2IsReg_i, inst3Param3IsReg_i, inst3Param4IsReg_i, 
    input wire [0:1] inst3Param1RW_i, inst3Param2RW_i, inst3Param3RW_i, inst3Param4RW_i,
    //Instr 4
    input wire [0:regSize-1] inst4Param1_i, inst4Param2_i, inst4Param3_i, inst4Param4_i,
    input wire inst4Param1En_i, inst4Param2En_i, inst4Param3En_i, inst4Param4En_i,
    input wire inst4Param1IsReg_i, inst4Param2IsReg_i, inst4Param3IsReg_i, inst4Param4IsReg_i, 
    input wire [0:1] inst4Param1RW_i, inst4Param2RW_i, inst4Param3RW_i, inst4Param4RW_i,
    //bypass inputs
    input wire [0:regSize-1] inst1Addr_i, inst2Addr_i, inst3Addr_i, inst4Addr_i, 
    input wire [0:instructionCounterWidth-1] inst1MajId_i, inst2MajId_i, inst3MajId_i, inst4MajId_i, 
    input wire [0:instMinIdWidth-1] inst1MinId_i, inst2MinId_i, inst3MinId_i, inst4MinId_i, 
    input wire [0:PidSize-1] inst1Pid_i, inst2Pid_i, inst3Pid_i, inst4Pid_i, 
    input wire [0:TidSize-1] inst1Tid_i, inst2Tid_i, inst3Tid_i, inst4Tid_i, 
    input wire [0:opcodeSize-1] inst1OpCode_i, inst2OpCode_i, inst3OpCode_i, inst4OpCode_i, 

    ///outputs
    //Instr 1
    output reg [0:regSize-1] inst1Param1_o, inst1Param2_o, inst1Param3_o, inst1Param4_o,
    output reg inst1Param1En_o, inst1Param2En_o, inst1Param3En_o, inst1Param4En_o, 
    output reg inst1Param1IsReg_o, inst1Param2IsReg_o, inst1Param3IsReg_o, inst1Param4IsReg_o, 
    output reg [0:1] inst1Param1RW_o, inst1Param2RW_o, inst1Param3RW_o, inst1Param4RW_o,
    //Instr 2
    output reg [0:regSize-1] inst2Param1_o, inst2Param2_o, inst2Param3_o, inst2Param4_o,
    output reg inst2Param1En_o, inst2Param2En_o, inst2Param3En_o, inst2Param4En_o, 
    output reg inst2Param1IsReg_o, inst2Param2IsReg_o, inst2Param3IsReg_o, inst2Param4IsReg_o, 
    output reg [0:1] inst2Param1RW_o, inst2Param2RW_o, inst2Param3RW_o, inst2Param4RW_o,
    //Instr 3
    output reg [0:regSize-1] inst3Param1_o, inst3Param2_o, inst3Param3_o, inst3Param4_o,
    output reg inst3Param1En_o, inst3Param2En_o, inst3Param3En_o, inst3Param4En_o,
    output reg inst3Param1IsReg_o, inst3Param2IsReg_o, inst3Param3IsReg_o, inst3Param4IsReg_o, 
    output reg [0:1] inst3Param1RW_o, inst3Param2RW_o, inst3Param3RW_o, inst3Param4RW_o,
    //Instr 4
    output reg [0:regSize-1] inst4Param1_o, inst4Param2_o, inst4Param3_o, inst4Param4_o,
    output reg inst4Param1En_o, inst4Param2En_o, inst4Param3En_o, inst4Param4En_o,
    output reg inst4Param1IsReg_o, inst4Param2IsReg_o, inst4Param3IsReg_o, inst4Param4IsReg_o, 
    output reg [0:1] inst4Param1RW_o, inst4Param2RW_o, inst4Param3RW_o, inst4Param4RW_o,
    //bypass outputs
    output reg [0:1] numInst_o,
    output reg [0:regSize-1] inst1Addr_o, inst2Addr_o, inst3Addr_o, inst4Addr_o, 
    output reg [0:instructionCounterWidth-1] inst1MajId_o, inst2MajId_o, inst3MajId_o, inst4MajId_o, 
    output reg [0:instMinIdWidth-1] inst1MinId_o, inst2MinId_o, inst3MinId_o, inst4MinId_o, 
    output reg [0:PidSize-1] inst1Pid_o, inst2Pid_o, inst3Pid_o, inst4Pid_o, 
    output reg [0:TidSize-1] inst1Tid_o, inst2Tid_o, inst3Tid_o, inst4Tid_o, 
    output reg [0:opcodeSize-1] inst1OpCode_o, inst2OpCode_o, inst3OpCode_o, inst4OpCode_o
);


    reg isEntryFree [0:numRegs-1];//is the rob entry renamed
    reg [0:ROBEntryWidth-1] FXRAT [0:numRegs-1];//what rob entry the reg is renamed to


    ///buffers
    //bypass
    reg [0:1] numInst; reg enabled;
    reg [0:regSize-1] inst1Addr, inst2Addr, inst3Addr, inst4Addr;
    reg [0:instructionCounterWidth-1] inst1MajId, inst2MajId, inst3MajId, inst4MajId;
    reg [0:instMinIdWidth-1] inst1MinId, inst2MinId, inst3MinId, inst4MinId;
    reg [0:PidSize-1] inst1Pid, inst2Pid, inst3Pid, inst4Pid;
    reg [0:TidSize-1] inst1Tid, inst2Tid, inst3Tid, inst4Tid; 
    reg [0:opcodeSize-1] inst1OpCode, inst2OpCode, inst3OpCode, inst4OpCode;
    //instruction 1
    reg [0:regSize-1] inst1Param1, inst1Param2, inst1Param3, inst1Param4;
    reg inst1Param1En, inst1Param2En, inst1Param3En, inst1Param4En;
    reg inst1Param1IsReg, inst1Param2IsReg, inst1Param3IsReg, inst1Param4IsReg;
    reg [0:1] inst1Param1RW, inst1Param2RW, inst1Param3RW, inst1Param4RW;
    //instruction 2
    reg [0:regSize-1] inst2Param1, inst2Param2, inst2Param3, inst2Param4;
    reg inst2Param1En, inst2Param2En, inst2Param3En, inst2Param4En;
    reg inst2Param1IsReg, inst2Param2IsReg, inst2Param3IsReg, inst2Param4IsReg;
    reg [0:1] inst2Param1RW, inst2Param2RW, inst2Param3RW, inst2Param4RW;
    //instruction 3
    reg [0:regSize-1] inst3Param1, inst3Param2, inst3Param3, inst3Param4;
    reg inst3Param1En, inst3Param2En, inst3Param3En, inst3Param4En;
    reg inst3Param1IsReg, inst3Param2IsReg, inst3Param3IsReg, inst3Param4IsReg;
    reg [0:1] inst3Param1RW, inst3Param2RW, inst3Param3RW, inst3Param4RW;
    //instruction 4
    reg [0:regSize-1] inst4Param1, inst4Param2, inst4Param3, inst4Param4;
    reg inst4Param1En, inst4Param2En, inst4Param3En, inst4Param4En;
    reg inst4Param1IsReg, inst4Param2IsReg, inst4Param3IsReg, inst4Param4IsReg;
    reg [0:1] inst4Param1RW, inst4Param2RW, inst4Param3RW, inst4Param4RW;

    //File handle to the debug output
    `ifdef DEBUG_PRINT
    integer debugFID;
    `endif

    integer i = 0;
    always @(posedge clock_i)
    begin

        `ifdef DEBUG $display("--------------------------------"); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID ,"--------------------------------"); `endif
        if(reset_i)
        begin
            `ifdef DEBUG_PRINT
            case(FXRATFileInstance)//If we have multiple fetch queues, they each get different files.
            0: begin debugFID = $fopen("FxRATFile0.log", "w"); end
            1: begin debugFID = $fopen("FxRATFile1.log", "w"); end
            2: begin debugFID = $fopen("FxRATFile2.log", "w"); end
            3: begin debugFID = $fopen("FxRATFile3.log", "w"); end
            4: begin debugFID = $fopen("FxRATFile4.log", "w"); end
            5: begin debugFID = $fopen("FxRATFile5.log", "w"); end
            6: begin debugFID = $fopen("FxRATFile6.log", "w"); end
            7: begin debugFID = $fopen("FxRATFile7.log", "w"); end
            endcase
            `endif
            `ifdef DEBUG $display("Fx RATfile: %d: Resetting", FXRATFileInstance); `endif  
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fx RATfile: %d: Resetting", FXRATFileInstance); `endif  

            for(i = 0; i < numRegs; i = i + 1)
                isEntryFree[i] <= 0;

        end
        else//not in reset
        begin
            ///Stage 1
            if(enable_i)
            begin
                //standard bypass
                numInst <= numInst_i; enabled <= enable_i;
                //instruction 1 - always inst1 if enabled
                //bypass buffers
                inst1Addr <= inst1Addr_i; inst1MajId <= inst1MajId_i; inst1MinId <= inst1MinId_i;
                inst1Pid <= inst1Pid_i; inst1Tid <= inst1Tid_i; inst1OpCode <= inst1OpCode_i;
                //RAT access buffers
                inst1Param1 <= inst1Param1_i; inst1Param2 <= inst1Param2_i; inst1Param3 <= inst1Param3_i; inst1Param4 <= inst1Param4_i;
                inst1Param1En <= inst1Param1En_i; inst1Param2En <= inst1Param2En_i; inst1Param3En <= inst1Param3En_i; inst1Param4En <= inst1Param4En_i;
                inst1Param1IsReg <= inst1Param1IsReg_i; inst1Param2IsReg <= inst1Param2IsReg_i; inst1Param3IsReg <= inst1Param3IsReg_i; inst1Param4IsReg <= inst1Param4IsReg_i;
                inst1Param1RW <= inst1Param1RW_i; inst1Param2RW <= inst1Param2RW_i; inst1Param3RW <= inst1Param3RW_i; inst1Param4RW <= inst1Param4RW_i;
    
                //instruction 2
                if(numInst_i > 1)
                begin
                    //bypass buffers
                    inst2Addr <= inst2Addr_i; inst2MajId <= inst2MajId_i; inst2MinId <= inst2MinId_i;
                    inst2Pid <= inst2Pid_i; inst2Tid <= inst2Tid_i; inst2OpCode <= inst2OpCode_i;
                    //RAT access buffers
                    inst2Param1 <= inst2Param1_i; inst2Param2 <= inst2Param2_i; inst2Param3 <= inst2Param3_i; inst2Param4 <= inst2Param4_i;
                    inst2Param1En <= inst2Param1En_i; inst2Param2En <= inst2Param2En_i; inst2Param3En <= inst2Param3En_i; inst2Param4En <= inst2Param4En_i;
                    inst2Param1IsReg <= inst2Param1IsReg_i; inst2Param2IsReg <= inst2Param2IsReg_i; inst2Param3IsReg <= inst2Param3IsReg_i; inst2Param4IsReg <= inst2Param4IsReg_i;
                    inst2Param1RW <= inst2Param1RW_i; inst2Param2RW <= inst2Param2RW_i; inst2Param3RW <= inst2Param3RW_i; inst2Param4RW <= inst2Param4RW_i;
                end
                if(numInst_i > 2) begin
                    //bypass buffers
                    inst3Addr <= inst3Addr_i; inst3MajId <= inst3MajId_i; inst3MinId <= inst3MinId_i;
                    inst3Pid <= inst3Pid_i; inst3Tid <= inst3Tid_i; inst3OpCode <= inst3OpCode_i;
                    //RAT access buffers
                    inst3Param1 <= inst3Param1_i; inst3Param2 <= inst3Param2_i; inst3Param3 <= inst3Param3_i; inst3Param4 <= inst3Param4_i;
                    inst3Param1En <= inst3Param1En_i; inst3Param2En <= inst3Param2En_i; inst3Param3En <= inst3Param3En_i; inst3Param4En <= inst3Param4En_i;
                    inst3Param1IsReg <= inst3Param1IsReg_i; inst3Param2IsReg <= inst3Param2IsReg_i; inst3Param3IsReg <= inst3Param3IsReg_i; inst3Param4IsReg <= inst3Param4IsReg_i;
                    inst3Param1RW <= inst3Param1RW_i; inst3Param2RW <= inst3Param2RW_i; inst3Param3RW <= inst3Param3RW_i; inst3Param4RW <= inst3Param4RW_i;
                end
                if(numInst_i == 3) begin
                    //bypass buffers
                    inst4Addr <= inst4Addr_i; inst4MajId <= inst4MajId_i; inst4MinId <= inst4MinId_i;
                    inst4Pid <= inst4Pid_i; inst4Tid <= inst4Tid_i; inst4OpCode <= inst4OpCode_i;
                    //RAT access buffers
                    inst4Param1 <= inst4Param1_i; inst4Param2 <= inst4Param2_i; inst4Param3 <= inst4Param3_i; inst4Param4 <= inst4Param4_i;
                    inst4Param1En <= inst4Param1En_i; inst4Param2En <= inst4Param2En_i; inst4Param3En <= inst4Param3En_i; inst4Param4En <= inst4Param4En_i;
                    inst4Param1IsReg <= inst4Param1IsReg_i; inst4Param2IsReg <= inst4Param2IsReg_i; inst4Param3IsReg <= inst4Param3IsReg_i; inst4Param4IsReg <= inst4Param4IsReg_i;
                    inst4Param1RW <= inst4Param1RW_i; inst4Param2RW <= inst4Param2RW_i; inst4Param3RW <= inst4Param3RW_i; inst4Param4RW <= inst4Param4RW_i;
                end                  
            end

            ///Stage 2
            if(enabled)
            begin
                numInst_o <= numInst;
                //instruction 1 - always inst1 if enabled
                //bypass buffers
                inst1Addr_o <= inst1Addr; inst1MajId_o <= inst1MajId; inst1MinId_o <= inst1MinId;
                inst1Pid_o <= inst1Pid; inst1Tid_o <= inst1Tid; inst1OpCode_o <= inst1OpCode;

                ///RAT access buffers
                ///Inst1
                //param1
                inst1Param1En_o <= inst1Param1En;
                if(inst1Param1En) begin
                    inst1Param1IsReg_o <= inst1Param1IsReg;
                    if(inst1Param1IsReg) begin
                        if(inst1Param1RW == 2'b10)//Write
                        begin
                            //rename the reg
                            inst1Param1_o <= FXRAT[inst1Param1];//output the current name
                            FXRAT[inst1Param1] <= inst1Param1;//rename reg name
                        end
                        if(inst1Param1RW == 2'b01)//Read
                        begin
                            //get the name of the reg
                            inst1Param1_o <= FXRAT[inst1Param1];
                        end
                        else//Read & Write
                        begin
                            inst1Param1_o <= FXRAT[inst1Param1];//output the current name
                            FXRAT[inst1Param1] <= inst1Param1;//rename reg name
                        end
                    end
                    else
                    begin
                        inst1Param1_o <= inst1Param1;
                    end
                end

                //param2
                inst1Param2En_o <= inst1Param2En;
                if(inst1Param2En) begin
                    inst1Param2IsReg_o <= inst1Param2IsReg;
                    if(inst1Param2IsReg) begin
                        if(inst1Param2RW == 2'b10)//Write
                        begin
                            //rename the reg
                            inst1Param2_o <= FXRAT[inst1Param2];//output the current name
                            FXRAT[inst1Param2] <= inst1Param2;//rename reg name
                        end
                        if(inst1Param2RW == 2'b01)//Read
                        begin
                            //get the name of the reg
                            inst1Param2_o <= FXRAT[inst1Param2];
                        end
                        else//Read & Write
                        begin
                            inst1Param2_o <= FXRAT[inst1Param2];//output the current name
                            FXRAT[inst1Param2] <= inst1Param2;//rename reg name
                        end
                    end
                    else
                    begin
                        inst1Param2_o <= inst1Param2;
                    end
                end
                
                //param3
                inst1Param3En_o <= inst1Param3En;
                if(inst1Param3En) begin
                    inst1Param3IsReg_o <= inst1Param3IsReg;
                    if(inst1Param3IsReg) begin
                        if(inst1Param3RW == 2'b10)//Write
                        begin
                            //rename the reg
                            inst1Param3_o <= FXRAT[inst1Param3];//output the current name
                            FXRAT[inst1Param3] <= inst1Param3;//rename reg name
                        end
                        if(inst1Param3RW == 2'b01)//Read
                        begin
                            //get the name of the reg
                            inst1Param3_o <= FXRAT[inst1Param3];
                        end
                        else//Read & Write
                        begin
                            inst1Param3_o <= FXRAT[inst1Param3];//output the current name
                            FXRAT[inst1Param3] <= inst1Param3;//rename reg name
                        end
                    end
                    else
                    begin
                        inst1Param3_o <= inst1Param3;
                    end
                end

                //param4
                inst1Param4En_o <= inst1Param4En;
                if(inst1Param4En) begin
                    inst1Param4IsReg_o <= inst1Param4IsReg;
                    if(inst1Param4IsReg) begin
                        if(inst1Param4RW == 2'b10)//Write
                        begin
                            //rename the reg
                            inst1Param4_o <= FXRAT[inst1Param4];//output the current name
                            FXRAT[inst1Param4] <= inst1Param4;//rename reg name
                        end
                        if(inst1Param4RW == 2'b01)//Read
                        begin
                            //get the name of the reg
                            inst1Param4_o <= FXRAT[inst1Param4];
                        end
                        else//Read & Write
                        begin
                            inst1Param4_o <= FXRAT[inst1Param4];//output the current name
                            FXRAT[inst1Param4] <= inst1Param4;//rename reg name
                        end
                    end
                    else
                    begin
                        inst1Param4_o <= inst1Param4;
                    end
                end


                ///////////Inst2
                //param1
                inst2Param1En_o <= inst2Param1En;
                if(inst2Param1En) begin
                    inst2Param1IsReg_o <= inst2Param1IsReg;
                    if(inst2Param1IsReg) begin
                        if(inst2Param1RW == 2'b10)//Write
                        begin
                            //rename the reg
                            inst2Param1_o <= FXRAT[inst2Param1];//output the current name
                            FXRAT[inst2Param1] <= inst2Param1;//rename reg name
                        end
                        if(inst2Param1RW == 2'b01)//Read
                        begin
                            //get the name of the reg
                            inst2Param1_o <= FXRAT[inst2Param1];
                        end
                        else//Read & Write
                        begin
                            inst2Param1_o <= FXRAT[inst2Param1];//output the current name
                            FXRAT[inst2Param1] <= inst2Param1;//rename reg name
                        end
                    end
                    else
                    begin
                        inst2Param1_o <= inst2Param1;
                    end
                end

                //param2
                inst2Param2En_o <= inst2Param2En;
                if(inst2Param2En) begin
                    inst2Param2IsReg_o <= inst2Param2IsReg;
                    if(inst2Param2IsReg) begin
                        if(inst2Param2RW == 2'b10)//Write
                        begin
                            //rename the reg
                            inst2Param2_o <= FXRAT[inst2Param2];//output the current name
                            FXRAT[inst2Param2] <= inst2Param2;//rename reg name
                        end
                        if(inst2Param2RW == 2'b01)//Read
                        begin
                            //get the name of the reg
                            inst2Param2_o <= FXRAT[inst2Param2];
                        end
                        else//Read & Write
                        begin
                            inst2Param2_o <= FXRAT[inst2Param2];//output the current name
                            FXRAT[inst2Param2] <= inst2Param2;//rename reg name
                        end
                    end
                    else
                    begin
                        inst2Param2_o <= inst2Param2;
                    end
                end
                
                //param3
                inst2Param3En_o <= inst2Param3En;
                if(inst2Param3En) begin
                    inst2Param3IsReg_o <= inst2Param3IsReg;
                    if(inst2Param3IsReg) begin
                        if(inst2Param3RW == 2'b10)//Write
                        begin
                            //rename the reg
                            inst2Param3_o <= FXRAT[inst2Param3];//output the current name
                            FXRAT[inst2Param3] <= inst2Param3;//rename reg name
                        end
                        if(inst2Param3RW == 2'b01)//Read
                        begin
                            //get the name of the reg
                            inst2Param3_o <= FXRAT[inst2Param3];
                        end
                        else//Read & Write
                        begin
                            inst2Param3_o <= FXRAT[inst2Param3];//output the current name
                            FXRAT[inst2Param3] <= inst2Param3;//rename reg name
                        end
                    end
                    else
                    begin
                        inst2Param3_o <= inst2Param3;
                    end
                end

                //param4
                inst2Param4En_o <= inst2Param4En;
                if(inst2Param4En) begin
                    inst2Param4IsReg_o <= inst2Param4IsReg;
                    if(inst2Param4IsReg) begin
                        if(inst2Param4RW == 2'b10)//Write
                        begin
                            //rename the reg
                            inst2Param4_o <= FXRAT[inst2Param4];//output the current name
                            FXRAT[inst2Param4] <= inst2Param4;//rename reg name
                        end
                        if(inst2Param4RW == 2'b01)//Read
                        begin
                            //get the name of the reg
                            inst2Param4_o <= FXRAT[inst2Param4];
                        end
                        else//Read & Write
                        begin
                            inst2Param4_o <= FXRAT[inst2Param4];//output the current name
                            FXRAT[inst2Param4] <= inst2Param4;//rename reg name
                        end
                    end
                    else
                    begin
                        inst2Param4_o <= inst2Param4;
                    end
                end


                ///////////Inst3
                //param1
                inst3Param1En_o <= inst3Param1En;
                if(inst3Param1En) begin
                    inst3Param1IsReg_o <= inst3Param1IsReg;
                    if(inst3Param1IsReg) begin
                        if(inst3Param1RW == 2'b10)//Write
                        begin
                            //rename the reg
                            inst3Param1_o <= FXRAT[inst3Param1];//output the current name
                            FXRAT[inst3Param1] <= inst3Param1;//rename reg name
                        end
                        if(inst3Param1RW == 2'b01)//Read
                        begin
                            //get the name of the reg
                            inst3Param1_o <= FXRAT[inst3Param1];
                        end
                        else//Read & Write
                        begin
                            inst3Param1_o <= FXRAT[inst3Param1];//output the current name
                            FXRAT[inst3Param1] <= inst3Param1;//rename reg name
                        end
                    end
                    else
                    begin
                        inst3Param1_o <= inst3Param1;
                    end
                end

                //param2
                inst3Param2En_o <= inst3Param2En;
                if(inst3Param2En) begin
                    inst3Param2IsReg_o <= inst3Param2IsReg;
                    if(inst3Param2IsReg) begin
                        if(inst3Param2RW == 2'b10)//Write
                        begin
                            //rename the reg
                            inst3Param2_o <= FXRAT[inst3Param2];//output the current name
                            FXRAT[inst3Param2] <= inst3Param2;//rename reg name
                        end
                        if(inst3Param2RW == 2'b01)//Read
                        begin
                            //get the name of the reg
                            inst3Param2_o <= FXRAT[inst3Param2];
                        end
                        else//Read & Write
                        begin
                            inst3Param2_o <= FXRAT[inst3Param2];//output the current name
                            FXRAT[inst3Param2] <= inst3Param2;//rename reg name
                        end
                    end
                    else
                    begin
                        inst3Param2_o <= inst3Param2;
                    end
                end

                //param3
                inst3Param3En_o <= inst3Param3En;
                if(inst3Param3En) begin
                    inst3Param3IsReg_o <= inst3Param3IsReg;
                    if(inst3Param3IsReg) begin
                        if(inst3Param3RW == 2'b10)//Write
                        begin
                            //rename the reg
                            inst3Param3_o <= FXRAT[inst3Param3];//output the current name
                            FXRAT[inst3Param3] <= inst3Param3;//rename reg name
                        end
                        if(inst3Param3RW == 2'b01)//Read
                        begin
                            //get the name of the reg
                            inst3Param3_o <= FXRAT[inst3Param3];
                        end
                        else//Read & Write
                        begin
                            inst3Param3_o <= FXRAT[inst3Param3];//output the current name
                            FXRAT[inst3Param3] <= inst3Param3;//rename reg name
                        end
                    end
                    else
                    begin
                        inst3Param3_o <= inst3Param3;
                    end
                end

                //param4
                inst3Param4En_o <= inst3Param4En;
                if(inst3Param4En) begin
                    inst3Param4IsReg_o <= inst3Param4IsReg;
                    if(inst3Param4IsReg) begin
                        if(inst3Param4RW == 2'b10)//Write
                        begin
                            //rename the reg
                            inst3Param4_o <= FXRAT[inst3Param4];//output the current name
                            FXRAT[inst3Param4] <= inst3Param4;//rename reg name
                        end
                        if(inst3Param4RW == 2'b01)//Read
                        begin
                            //get the name of the reg
                            inst3Param4_o <= FXRAT[inst3Param4];
                        end
                        else//Read & Write
                        begin
                            inst3Param4_o <= FXRAT[inst3Param4];//output the current name
                            FXRAT[inst3Param4] <= inst3Param4;//rename reg name
                        end
                    end
                    else
                    begin
                        inst3Param4_o <= inst3Param4;
                    end
                end
                

                ///////////Inst4
                //param1
                inst4Param1En_o <= inst4Param1En;
                if(inst4Param1En) begin
                    inst4Param1IsReg_o <= inst4Param1IsReg;
                    if(inst4Param1IsReg) begin
                        if(inst4Param1RW == 2'b10)//Write
                        begin
                            //rename the reg
                            inst4Param1_o <= FXRAT[inst4Param1];//output the current name
                            FXRAT[inst4Param1] <= inst4Param1;//rename reg name
                        end
                        if(inst4Param1RW == 2'b01)//Read
                        begin
                            //get the name of the reg
                            inst4Param1_o <= FXRAT[inst4Param1];
                        end
                        else//Read & Write
                        begin
                            inst4Param1_o <= FXRAT[inst4Param1];//output the current name
                            FXRAT[inst4Param1] <= inst4Param1;//rename reg name
                        end
                    end
                    else
                    begin
                        inst4Param1_o <= inst4Param1;
                    end
                end

                //param2
                inst4Param2En_o <= inst4Param2En;
                if(inst4Param2En) begin
                    inst4Param2IsReg_o <= inst4Param2IsReg;
                    if(inst4Param2IsReg) begin
                        if(inst4Param2RW == 2'b10)//Write
                        begin
                            //rename the reg
                            inst4Param2_o <= FXRAT[inst4Param2];//output the current name
                            FXRAT[inst4Param2] <= inst4Param2;//rename reg name
                        end
                        if(inst4Param2RW == 2'b01)//Read
                        begin
                            //get the name of the reg
                            inst4Param2_o <= FXRAT[inst4Param2];
                        end
                        else//Read & Write
                        begin
                            inst4Param2_o <= FXRAT[inst4Param2];//output the current name
                            FXRAT[inst4Param2] <= inst4Param2;//rename reg name
                        end
                    end
                    else
                    begin
                        inst4Param2_o <= inst4Param2;
                    end
                end
                
                //param3
                inst4Param3En_o <= inst4Param3En;
                if(inst4Param3En) begin
                    inst4Param3IsReg_o <= inst4Param3IsReg;
                    if(inst4Param3IsReg) begin
                        if(inst4Param3RW == 2'b10)//Write
                        begin
                            //rename the reg
                            inst4Param3_o <= FXRAT[inst4Param3];//output the current name
                            FXRAT[inst4Param3] <= inst4Param3;//rename reg name
                        end
                        if(inst4Param3RW == 2'b01)//Read
                        begin
                            //get the name of the reg
                            inst4Param3_o <= FXRAT[inst4Param3];
                        end
                        else//Read & Write
                        begin
                            inst4Param3_o <= FXRAT[inst4Param3];//output the current name
                            FXRAT[inst4Param3] <= inst4Param3;//rename reg name
                        end
                    end
                    else
                    begin
                        inst4Param3_o <= inst4Param3;
                    end
                end

                //param4
                inst4Param4En_o <= inst4Param4En;
                if(inst4Param4En) begin
                    inst4Param4IsReg_o <= inst4Param4IsReg;
                    if(inst4Param4IsReg) begin
                        if(inst4Param4RW == 2'b10)//Write
                        begin
                            //rename the reg
                            inst4Param4_o <= FXRAT[inst4Param4];//output the current name
                            FXRAT[inst4Param4] <= inst4Param4;//rename reg name
                        end
                        if(inst4Param4RW == 2'b01)//Read
                        begin
                            //get the name of the reg
                            inst4Param4_o <= FXRAT[inst4Param4];
                        end
                        else//Read & Write
                        begin
                            inst4Param4_o <= FXRAT[inst4Param4];//output the current name
                            FXRAT[inst4Param4] <= inst4Param4;//rename reg name
                        end
                    end
                    else
                    begin
                        inst4Param4_o <= inst4Param4;
                    end
                end
            end
        end

    end


endmodule