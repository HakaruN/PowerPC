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


module FxReg
    #(
        parameter regSize = 64,
        parameter numGPRAddressBits = 6,
        parameter fxRegFileInstance = 0

    )
    (
        //command
        input wire clock_i, reset_i,
        ///reg read requests
        //GPR
        input wire gprRead1En_i, gprRead2En_i, gprRead3En_i, gprRead4En_i,
        input wire [0:numGPRAddressBits-1] gprReadAddr1_i, gprReadAddr2_i, gprReadAddr3_i, gprReadAddr4_i, 
        
        ///reg write requests
        //GPR
        input wire gprWrite1En_i, gprWrite2En_i, gprWrite3En_i, gprWrite4En_i,
        input wire [0:numGPRAddressBits-1] gprWriteAddr1_i, gprWriteAddr2_i, gprWriteAddr3_i, gprWriteAddr4_i, 
        input wire [0:regSize-1] gprWrite1Val_i, gprWrite2Val_i, gprWrite3Val_i, gprWrite4Val_i,
        //XER
        input wire XERWriteEn_i,
        input wire [0:regSize-1] XERVal_i,

        ///Reg outputs
        //GPR
        output reg [0:regSize-1] gprRead1_o, gprRead2_o, gprRead3_o, gprRead4_o, 
        //XER
        output reg [0:regSize-1] XER_o        
    );

    //General registers
    reg [0:63] GPR [0:31];
    reg [0:63] XER;
    //Special registers
    reg [32:63] PVR;//Processor version register
    reg [32:63] CIR;//Chip Information Register
    reg [32:63] PIR;//Chip Information Register

    ///IO buffers
    //GPR read input buffers
    reg [0:numGPRAddressBits-1] gprReadAddr1, gprReadAddr2, gprReadAddr3, gprReadAddr4;//address input buffer
    reg gprRead1, gprRead2, gprRead3, gprRead4;//flag to perform the read from the Reg to the buffers
    ///GPR write input buffers
    reg gprWrite1En, gprWrite2En, gprWrite3En, gprWrite4En;
    reg [0:numGPRAddressBits-1] gprWriteAddr1, gprWriteAddr2, gprWriteAddr3, gprWriteAddr4;
    reg [0:regSize-1] gprWrite1Val, gprWrite2Val, gprWrite3Val, gprWrite4Val;

    //XER write buffer
    reg XERWriteEn;
    reg [0:regSize-1] XERVal;

    //File handle to the debug output
    `ifdef DEBUG_PRINT
    integer debugFID;
    `endif

    always @(posedge clock_i)
    begin
        `ifdef DEBUG $display("--------------------------------"); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID ,"--------------------------------"); `endif
        if(reset_i)
        begin
            `ifdef DEBUG_PRINT
            case(fxRegFileInstance)//If we have multiple fetch queues, they each get different files.
            0: begin debugFID = $fopen("FxRegFile0.log", "w"); end
            1: begin debugFID = $fopen("FxRegFile1.log", "w"); end
            2: begin debugFID = $fopen("FxRegFile2.log", "w"); end
            3: begin debugFID = $fopen("FxRegFile3.log", "w"); end
            4: begin debugFID = $fopen("FxRegFile4.log", "w"); end
            5: begin debugFID = $fopen("FxRegFile5.log", "w"); end
            6: begin debugFID = $fopen("FxRegFile6.log", "w"); end
            7: begin debugFID = $fopen("FxRegFile7.log", "w"); end
            endcase
            `endif
            `ifdef DEBUG $display("Fx Regfile: %d: Resetting", fxRegFileInstance); `endif  
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fx Regfile: %d: Resetting", fxRegFileInstance); `endif  

            gprRead1_o <= 0; gprRead2_o <= 0; gprRead3_o <= 0; gprRead4_o <= 0;//outputs
            gprRead1 <= 0; gprRead2 <= 0; gprRead3 <= 0; gprRead4 <= 0;//buffers
            XER_o <= 0; XERWriteEn <= 0;
            gprWrite1En <= 0; gprWrite2En <= 0; gprWrite3En <= 0; gprWrite4En <= 0;

        end
        else//not in reset
        begin
            
            ///read request
            gprRead1 <= gprRead1En_i; gprRead2 <= gprRead2En_i; gprRead3 <= gprRead3En_i; gprRead4 <= gprRead4En_i;            
            //buffer inputs
            if(gprRead1En_i)
            begin
                gprReadAddr1 <= gprReadAddr1_i;
                `ifdef DEBUG $display("Fx Regfile: %d: Port 1: Read Cycle 1: Address %d", fxRegFileInstance, gprReadAddr1_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fx Regfile: %d: Port 1: Read Cycle 1: Address %d", fxRegFileInstance, gprReadAddr1_i); `endif
            end

            if(gprRead2En_i)
            begin
                gprReadAddr2 <= gprReadAddr2_i;
                `ifdef DEBUG $display("Fx Regfile: %d: Port 2: Read Cycle 1: Address %d", fxRegFileInstance, gprReadAddr2_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fx Regfile: %d: Port 2: Read Cycle 1: Address %d", fxRegFileInstance, gprReadAddr2_i); `endif
            end

            if(gprRead3En_i)
            begin   
                gprReadAddr3 <= gprReadAddr3_i;
                `ifdef DEBUG $display("Fx Regfile: %d: Port 3: Read Cycle 1: Address %d", fxRegFileInstance, gprReadAddr3_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fx Regfile: %d: Port 3: Read Cycle 1: Address %d", fxRegFileInstance, gprReadAddr3_i); `endif
            end

            if(gprRead4En_i)
            begin
                gprReadAddr4 <= gprReadAddr4_i;
                `ifdef DEBUG $display("Fx Regfile: %d: Port 4: Read Cycle 1: Address %d", fxRegFileInstance, gprReadAddr4_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fx Regfile: %d: Port 4: Read Cycle 1: Address %d", fxRegFileInstance, gprReadAddr4_i); `endif
            end

            ///outputs
            if(gprRead1) begin
                gprRead1_o <= GPR[gprReadAddr1];
                `ifdef DEBUG $display("Fx Regfile: %d: Port 1: Read Cycle 2: Address %d: Value %d", fxRegFileInstance, gprReadAddr1, GPR[gprReadAddr1]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fx Regfile: %d: Port 1: Read Cycle 2: Address %d: Value %d", fxRegFileInstance, gprReadAddr1, GPR[gprReadAddr1]); `endif
            end
            
            if(gprRead2) begin
                gprRead2_o <= GPR[gprReadAddr2];
                `ifdef DEBUG $display("Fx Regfile: %d: Port 2: Read Cycle 2: Address %d: Value %d", fxRegFileInstance, gprReadAddr2, GPR[gprReadAddr2]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fx Regfile: %d: Port 2: Read Cycle 2: Address %d: Value %d", fxRegFileInstance, gprReadAddr2, GPR[gprReadAddr2]); `endif
            end

            if(gprRead3) begin
                gprRead3_o <= GPR[gprReadAddr3];
                `ifdef DEBUG $display("Fx Regfile: %d: Port 3: Read Cycle 2: Address %d: Value %d", fxRegFileInstance, gprReadAddr3, GPR[gprReadAddr3]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fx Regfile: %d: Port 3: Read Cycle 2: Address %d: Value %d", fxRegFileInstance, gprReadAddr3, GPR[gprReadAddr3]); `endif
            end

            if(gprRead4) begin
                gprRead4_o <= GPR[gprReadAddr4];
                `ifdef DEBUG $display("Fx Regfile: %d: Port 4: Read Cycle 2: Address %d: Value %d", fxRegFileInstance, gprReadAddr4, GPR[gprReadAddr4]); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fx Regfile: %d: Port 4: Read Cycle 2: Address %d: Value %d", fxRegFileInstance, gprReadAddr4, GPR[gprReadAddr4]); `endif
            end

            ////Write requests
            ///cycle 1
            //GPR
            gprWrite1En <= gprWrite1En_i; gprWrite2En <= gprWrite2En_i; gprWrite3En <= gprWrite3En_i; gprWrite4En <= gprWrite4En_i;
            if(gprWrite1En_i)
            begin
                gprWriteAddr1 <= gprWriteAddr1_i; gprWrite1Val <= gprWrite1Val_i;
                `ifdef DEBUG $display("Fx Regfile: %d: Port 1: Write Cycle 1: Address %d, Value %d", fxRegFileInstance, gprWriteAddr1_i, gprWrite1Val_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fx Regfile: %d: Port 1: Write Cycle 1: Address %d, Value %d", fxRegFileInstance, gprWriteAddr1_i, gprWrite1Val_i); `endif
            end
            
            if(gprWrite2En_i)
            begin
                gprWriteAddr2 <= gprWriteAddr2_i; gprWrite2Val <= gprWrite2Val_i;
                `ifdef DEBUG $display("Fx Regfile: %d: Port 2: Write Cycle 1: Address %d, Value %d", fxRegFileInstance, gprWriteAddr2_i, gprWrite2Val_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fx Regfile: %d: Port 2: Write Cycle 1: Address %d, Value %d", fxRegFileInstance, gprWriteAddr2_i, gprWrite2Val_i); `endif
            end

            if(gprWrite3En_i)
            begin
                gprWriteAddr3 <= gprWriteAddr3_i; gprWrite3Val <= gprWrite3Val_i;
                `ifdef DEBUG $display("Fx Regfile: %d: Port 3: Write Cycle 1: Address %d, Value %d", fxRegFileInstance, gprWriteAddr3_i, gprWrite3Val_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fx Regfile: %d: Port 3: Write Cycle 1: Address %d, Value %d", fxRegFileInstance, gprWriteAddr3_i, gprWrite3Val_i); `endif
            end

            if(gprWrite4En_i)
            begin
                gprWriteAddr4 <= gprWriteAddr4_i; gprWrite4Val <= gprWrite4Val_i;
                `ifdef DEBUG $display("Fx Regfile: %d: Port 4: Write Cycle 1: Address %d, Value %d", fxRegFileInstance, gprWriteAddr4_i, gprWrite4Val_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fx Regfile: %d: Port 4: Write Cycle 1: Address %d, Value %d", fxRegFileInstance, gprWriteAddr4_i, gprWrite4Val_i); `endif
            end

            //XER
            XERWriteEn <= XERWriteEn_i;
            if(XERWriteEn_i)
            begin
                XERVal <= XERVal_i;
                `ifdef DEBUG $display("Fx Regfile: %d: XER Reg. Write Cycle 1: Writing value %b", fxRegFileInstance, XERVal_i); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fx Regfile: %d: XER Reg. Write Cycle 1: Writing value %b", fxRegFileInstance, XERVal_i); `endif
            end


            ///cycle 2
            //GPR
            if(gprWrite1En)
            begin
                GPR[gprWriteAddr1] <= gprWrite1Val;
                `ifdef DEBUG $display("Fx Regfile: %d: Port 1: Write Cycle 2: writing reg %d, Value %d", fxRegFileInstance, gprWriteAddr1, gprWrite1Val); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fx Regfile: %d: Port 1: Write Cycle 2: writing reg %d, Value %d", fxRegFileInstance, gprWriteAddr1, gprWrite1Val); `endif
            end

            if(gprWrite2En)
            begin
                GPR[gprWriteAddr2] <= gprWrite2Val;
                `ifdef DEBUG $display("Fx Regfile: %d: Port 2: Write Cycle 2: writing reg %d, Value %d", fxRegFileInstance, gprWriteAddr2, gprWrite2Val); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fx Regfile: %d: Port 2: Write Cycle 2: writing reg %d, Value %d", fxRegFileInstance, gprWriteAddr2, gprWrite2Val); `endif
            end

            if(gprWrite3En)
            begin
                GPR[gprWriteAddr3] <= gprWrite3Val;
                `ifdef DEBUG $display("Fx Regfile: %d: Port 3: Write Cycle 2: writing reg %d, Value %d", fxRegFileInstance, gprWriteAddr3, gprWrite3Val); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fx Regfile: %d: Port 3: Write Cycle 2: writing reg %d, Value %d", fxRegFileInstance, gprWriteAddr3, gprWrite3Val); `endif
            end

            if(gprWrite4En)
            begin
                GPR[gprWriteAddr4] <= gprWrite4Val;
                `ifdef DEBUG $display("Fx Regfile: %d: Port 4: Write Cycle 2: writing reg %d, Value %d", fxRegFileInstance, gprWriteAddr4, gprWrite4Val); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fx Regfile: %d: Port 4: Write Cycle 2: writing reg %d, Value %d", fxRegFileInstance, gprWriteAddr4, gprWrite4Val); `endif
            end

            //XER
            if(XERWriteEn)
            begin
                XER_o <= XERVal;
                `ifdef DEBUG $display("Fx Regfile: %d: XER Reg. Write Cycle 2: Writing value %b", fxRegFileInstance, XERVal); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fx Regfile: %d: XER Reg. Write Cycle 2: Writing value %b", fxRegFileInstance, XERVal); `endif
            end

            
        end
    end


endmodule
