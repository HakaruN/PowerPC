`timescale 1ns / 1ps
`include "../../../Modules/OutOfOrder/FXReg.v"

////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
`define DEBUG


module FXReg_Test
   #(
        parameter regSize = 64,
        parameter numGPRAddressBits = 6,
        parameter fxRegFileInstance = 0

    )
    (  
    );

       
    //control
    reg clock, reset;
    ///reg read requests
    //GPR
    reg gprRead1En, gprRead2En, gprRead3En, gprRead4En;
    reg [0:numGPRAddressBits-1] gprReadAddr1, gprReadAddr2, gprReadAddr3, gprReadAddr4;
    ///reg write requests
    //GPR
    reg gprWrite1En, gprWrite2En, gprWrite3En, gprWrite4En;
    reg [0:numGPRAddressBits-1] gprWriteAddr1, gprWriteAddr2, gprWriteAddr3, gprWriteAddr4;
    reg [0:regSize-1] gprWrite1Val, gprWrite2Val, gprWrite3Val, gprWrite4Val;
    //XER
    reg XERWriteEn;
    reg [0:regSize-1] XERVal;

    ///outputs
    //GPR
    wire [0:regSize-1] gprRead1, gprRead2, gprRead3, gprRead4;
    //XER
    wire [0:regSize-1] XER;


    FxReg #(
        .regSize(regSize),
        .numGPRAddressBits(numGPRAddressBits),
        .fxRegFileInstance(fxRegFileInstance)
    )
    fxReg
    (
        //command
        .clock_i(clock), .reset_i(reset),
        ///reg read requests
        //GPR
        .gprRead1En_i(gprRead1En), .gprRead2En_i(gprRead2En), .gprRead3En_i(gprRead3En), .gprRead4En_i(gprRead4En),
        .gprReadAddr1_i(gprReadAddr1), .gprReadAddr2_i(gprReadAddr2), .gprReadAddr3_i(gprReadAddr3), .gprReadAddr4_i(gprReadAddr4),        
        ///reg write requests
        //GPR
        .gprWrite1En_i(gprWrite1En), .gprWrite2En_i(gprWrite2En), .gprWrite3En_i(gprWrite3En), .gprWrite4En_i(gprWrite4En),
        .gprWriteAddr1_i(gprWriteAddr1), .gprWriteAddr2_i(gprWriteAddr2), .gprWriteAddr3_i(gprWriteAddr3), .gprWriteAddr4_i(gprWriteAddr4),
        .gprWrite1Val_i(gprWrite1Val), .gprWrite2Val_i(gprWrite2Val), .gprWrite3Val_i(gprWrite3Val), .gprWrite4Val_i(gprWrite4Val),
        //XER
        .XERWriteEn_i(XERWriteEn),
        .XERVal_i(XERVal),
        ///Reg outputs
        //GPR
        .gprRead1_o(gprRead1), .gprRead2_o(gprRead2), .gprRead3_o(gprRead3), .gprRead4_o(gprRead4),
        //XER
        .XER_o(XER)
    );


    reg [0:63] testReadVal1 = 0;
    reg [0:63] testReadVal2 = 0;
    reg [0:63] testReadVal3 = 0;
    reg [0:63] testReadVal4 = 0;
    reg [0:63] testXERVal4 = 0;

    initial begin
    $dumpfile("FxRegFileTest.vcd");
    $dumpvars(0,FXReg_Test);
    // Initialize Inputs
    clock = 0; reset = 0;
    gprRead1En = 0; gprRead2En = 0; gprRead3En = 0; gprRead4En = 0;
    gprReadAddr1 = 0; gprReadAddr2 = 0; gprReadAddr3 = 0; gprReadAddr4 = 0;
    gprWrite1En = 0; gprWrite2En = 0; gprWrite3En = 0; gprWrite4En = 0;
    gprWriteAddr1 = 0; gprWriteAddr2 = 0; gprWriteAddr3 = 0; gprWriteAddr4 = 0;
    gprWrite1Val = 0; gprWrite2Val = 0; gprWrite3Val = 0; gprWrite3Val = 0;
    XERWriteEn = 0;
    XERVal = 0;

    #5;
    clock = 1;
    reset = 1;
    #1;
    clock = 0;
    reset = 0;
    #1;


    ///Test reset behavour
    gprRead1En = 1; gprReadAddr1 = 0;
    gprRead2En = 1; gprReadAddr2 = 1;
    gprRead3En = 1; gprReadAddr3 = 2;
    gprRead4En = 1; gprReadAddr4 = 3;

    clock = 1;
    #1;
    clock = 0;
    #1;

    gprRead1En = 0;
    gprRead2En = 0;
    gprRead3En = 0;
    gprRead4En = 0;

    clock = 1;
    #1;
    clock = 0;
    #1;


    //write to regs - cycle 1
    testReadVal1 = 10;
    testReadVal2 = 11;
    testReadVal3 = 12;
    testReadVal4 = 13;
    gprWrite1En = 1; gprWriteAddr1 = 0; gprWrite1Val = testReadVal1;
    gprWrite2En = 1; gprWriteAddr2 = 1; gprWrite2Val = testReadVal2;
    gprWrite3En = 1; gprWriteAddr3 = 2; gprWrite3Val = testReadVal3;
    gprWrite4En = 1; gprWriteAddr4 = 3; gprWrite4Val = testReadVal4;
    clock = 1;
    #1;
    clock = 0;
    #1;

    //write to regs - cycl 1
    gprWrite1En = 0;
    gprWrite2En = 0;
    gprWrite3En = 0;
    gprWrite4En = 0;
    clock = 1;
    #1;
    clock = 0;
    #1;

    //read values back
    gprRead1En = 1; gprReadAddr1 = 0;
    gprRead2En = 1; gprReadAddr2 = 1;
    gprRead3En = 1; gprReadAddr3 = 2;
    gprRead4En = 1; gprReadAddr4 = 3;

    clock = 1;
    #1;
    clock = 0;
    #1;

    gprRead1En = 0;
    gprRead2En = 0;
    gprRead3En = 0;
    gprRead4En = 0;

    clock = 1;
    #1;
    clock = 0;
    #1;

    if(
        gprRead1 == testReadVal1 && 
        gprRead2 == testReadVal2 && 
        gprRead3 == testReadVal3 && 
        gprRead4 == testReadVal4
    )begin
        $display("Write to Read: PASS");
    end
    else
        $display("Write to Read: FAIL");



    ///Write and read XER Test
    testXERVal4 = 64'b10100101_11111111_00000000_11000011_11000011_00000000_11111111_10100101;
    //write
    XERWriteEn = 1; XERVal = testXERVal4;
    clock = 1;
    #1;
    clock = 0;
    #1;

    XERWriteEn = 0;
    clock = 1;
    #1;
    clock = 0;
    #1;

    //read
    if(XER == testXERVal4)
        $display("Write and read XER Test: PASS");
    else
        $display("Write and read XER Test: FAIL");

    

    ///Multi write and read test
    //Write 
    testReadVal1 = 20;
    testReadVal2 = 21;
    testReadVal3 = 22;
    testReadVal4 = 23;
    gprWrite1En = 1; gprWriteAddr1 = 0; gprWrite1Val = testReadVal1;
    gprWrite2En = 1; gprWriteAddr2 = 1; gprWrite2Val = testReadVal2;
    gprWrite3En = 1; gprWriteAddr3 = 2; gprWrite3Val = testReadVal3;
    gprWrite4En = 1; gprWriteAddr4 = 3; gprWrite4Val = testReadVal4;
    //read
    gprRead1En = 1; gprReadAddr1 = 0;
    gprRead2En = 1; gprReadAddr2 = 1;
    gprRead3En = 1; gprReadAddr3 = 2;
    gprRead4En = 1; gprReadAddr4 = 3;
    clock = 1;
    #1;
    clock = 0;
    #1;
    testReadVal1 = 30;
    testReadVal2 = 31;
    testReadVal3 = 32;
    testReadVal4 = 33;
    gprWrite1En = 1; gprWriteAddr1 = 0; gprWrite1Val = testReadVal1;
    gprWrite2En = 1; gprWriteAddr2 = 1; gprWrite2Val = testReadVal2;
    gprWrite3En = 1; gprWriteAddr3 = 2; gprWrite3Val = testReadVal3;
    gprWrite4En = 1; gprWriteAddr4 = 3; gprWrite4Val = testReadVal4;
    //read
    gprRead1En = 1; gprReadAddr1 = 0;
    gprRead2En = 1; gprReadAddr2 = 1;
    gprRead3En = 1; gprReadAddr3 = 2;
    gprRead4En = 1; gprReadAddr4 = 3;
    clock = 1;
    #1;
    clock = 0;
    #1;
    //Now first write complete

    clock = 1;
    #1;
    clock = 0;
    #1;
    //now second write completes

    clock = 1;
    #1;
    clock = 0;
    #1;



    end

endmodule