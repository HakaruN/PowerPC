`timescale 1ns / 1ps
`define DEBUG
`define DEBUG_PRINT
//`define GENERAL_TEST
`define DEQUEUE_ON_RESET_TEST
`include "../../../Modules/Fetch/FetchQueue.v"

module FetchQueueTest
#(
    parameter addressWidth = 64,
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter maxBundleSize = 4 * instructionWidth, //A bundle is the collection of instructions fetched per cycle.
    parameter PidSize = 32, parameter TidSize = 64,
    parameter instructionCounterWidth = 64,
    parameter instructionsPerBundle = 4,
    parameter queueIndexBits = 4,
    parameter queueLenth = 2**queueIndexBits,
    parameter fetchQueueInstance = 0
)
(

);

    reg clockIn, resetIn;
    //input from fetch unit
    reg bundleWriteIn;
    reg [0:addressWidth-1] bundleAddressIn;
    reg [0:1] bundleLenIn;
    reg [0:PidSize-1] bundlePidIn;
    reg [0:TidSize-1] bundleTidIn;
    reg [0:instructionCounterWidth-1] bundleStartMajIdIn;
    reg [0:maxBundleSize-1] bundleIn;
    //input from decoders
    reg decode1AvailableIn, decode2AvailableIn, decode3AvailableIn, decode4AvailableIn;
    //output to decoders
    wire decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut;
    wire [0:instructionWidth-1] decoder1InsOut, decoder2InsOut, decoder3InsOut, decoder4InsOut;
    //queue state output
    wire [0:queueIndexBits-1] frontOut, backOut;
    wire isFullOut, isEmptyOut;//(is full can be used as to tell the fetch unit to stop fetching)

    reg [0:maxBundleSize-1] bundles [0:5];

    FetchQueue #(
        .addressWidth(addressWidth),
        .instructionWidth(instructionWidth),
        .maxBundleSize(maxBundleSize),
        .PidSize(PidSize), .TidSize(TidSize),
        .instructionCounterWidth(), 
        .instructionsPerBundle(instructionsPerBundle),
        .queueIndexBits(queueIndexBits),
        .fetchQueueInstance(0)
    )
    fetchQueue (
    .clock_i(clockIn), .reset_i(resetIn),
    .bundleWrite_i(bundleWriteIn),
    .bundleAddress_i(bundleAddressIn), 
    .bundleLen_i(bundleLenIn), 
    .bundlePid_i(bundlePidIn), .bundleTid_i(bundleTidIn),
    .bundleStartMajId_i(bundleStartMajIdIn), 
    .bundle_i(bundleIn),//bundle coming from fetch unit
    .decode1Available_i(decode1AvailableIn), .decode2Available_i(decode2AvailableIn), .decode3Available_i(decode3AvailableIn), .decode4Available_i(decode4AvailableIn),//Tells the queue if the decoders are busy or not. If busy dont sent an instruction to them
    .decoder1En_o(decoder1EnOut), .decoder2En_o(decoder2EnOut), .decoder3En_o(decoder3EnOut), .decoder4En_o(decoder4EnOut),
    .decoder1Ins_o(decoder1InsOut), .decoder2Ins_o(decoder2InsOut), .decoder3Ins_o(decoder3InsOut), .decoder4Ins_o(decoder4InsOut),
    .front_o(frontOut), .back_o(backOut),
    .isFull_o(isFullOut), .isEmpty_o(isEmptyOut)
    );

integer i; 
integer passCount, failCount;
initial begin
    $dumpfile("FetchQueue.vcd");
    $dumpvars(0,fetchQueue);
    passCount = 0; failCount = 0;
    clockIn = 0; resetIn = 0;
    bundleWriteIn = 0;
    bundleAddressIn = 0;
    bundleLenIn = 2'b11; 
    bundlePidIn = 0; bundleTidIn = 0;
    bundleStartMajIdIn = 0;
    bundleIn = 0;
    decode1AvailableIn = 0; decode2AvailableIn = 0; decode3AvailableIn = 0; decode4AvailableIn = 0;
    bundles[0] = {32'hAAAAAAAA, 32'hBBBBBBBB, 32'hCCCCCCCC, 32'hDDDDDDDD};
    bundles[1] = {32'hBBBBBBBB, 32'hCCCCCCCC, 32'hDDDDDDDD, 32'hEEEEEEEE};
    bundles[2] = {32'hCCCCCCCC, 32'hDDDDDDDD, 32'hEEEEEEEE, 32'hFFFFFFFF};
    bundles[3] = {32'hDDDDDDDD, 32'hEEEEEEEE, 32'hFFFFFFFF, 32'hAAAAAAAA};
    bundles[4] = {32'hEEEEEEEE, 32'hFFFFFFFF, 32'hAAAAAAAA, 32'hBBBBBBBB};
    bundles[5] = {32'hFFFFFFFF, 32'hAAAAAAAA, 32'hBBBBBBBB, 32'hCCCCCCCC};

`ifdef GENERAL_TEST
    //Reset queue
    resetIn = 1; clockIn = 1;
    #1;
    resetIn = 0; clockIn = 0;
    #1;
    if(isEmptyOut == 1 && isFullOut == 0 && frontOut == 0 && backOut == 0
    && {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b0000) begin
        $display("Pass: Reset");  passCount = passCount + 1; end
    else begin
        $display("Fail: Reset"); failCount = failCount + 1; end

    
    ///Write a bundle
    bundleWriteIn = 1;
    decode1AvailableIn = 0; decode2AvailableIn = 0; decode3AvailableIn = 0; decode4AvailableIn = 0;
    bundleIn = bundles[0];
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    if(isEmptyOut == 0 && isFullOut == 0 && frontOut == 0 && backOut == 4
    && {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b0000)
    begin
        $display("Pass: Initial enqueue"); passCount = passCount + 1; end
    else begin
        $display("Fail: Initial enqueue"); failCount = failCount + 1; end

    
    ///Read back the bundle
    bundleWriteIn = 0;
    decode1AvailableIn = 1; decode2AvailableIn = 1; decode3AvailableIn = 1; decode4AvailableIn = 1;
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    //We should be empty
    if(isEmptyOut == 1 && isFullOut == 0 && frontOut == 4 && backOut == 4 &&
    {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b1111) begin
        $display("Pass: Initial dequeue"); passCount = passCount + 1; end
    else begin
        $display("Fail: Initial dequeue"); failCount = failCount + 1; end

    
    //Try to issue instruction from an empty queue
    decode1AvailableIn = 0; decode2AvailableIn = 0; decode3AvailableIn = 0; decode4AvailableIn = 0;
    clockIn = 1;
    #1;
    clockIn = 0;
    #1; 
    if(isEmptyOut == 1 && isFullOut == 0 && frontOut == 4 && backOut == 4 &&
    {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b0000) begin
        $display("Pass: Empty dequeue attempt"); passCount = passCount + 1; end
    else begin
        $display("Fail: Empty dequeue attempt"); failCount = failCount + 1; end
    
    
    //Write another 2 bundles
    decode1AvailableIn = 0; decode2AvailableIn = 0; decode3AvailableIn = 0; decode4AvailableIn = 0;
    bundleWriteIn = 1;
    bundleIn = bundles[1];
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    if(isEmptyOut == 0 && isFullOut == 0 && frontOut == 4 && backOut == 8 &&
    {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b0000) begin
        $display("Pass: Second enqueue - 1"); passCount = passCount + 1; end
    else begin
        $display("Fail: Second enqueue - 1"); failCount = failCount + 1; end

    
    bundleIn = bundles[2];
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    if(isEmptyOut == 0 && isFullOut == 0 && frontOut == 4 && backOut == 12 &&
    {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b0000) begin
        $display("Pass: Second enqueue - 2"); passCount = passCount + 1; end
    else begin
        $display("Fail: Second enqueue - 2"); failCount = failCount + 1; end
    
    //Dequeue 1 instruction from the last decoder
    bundleWriteIn = 0;
    decode4AvailableIn = 1;
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    if(isEmptyOut == 0 && isFullOut == 0 && frontOut == 5 && backOut == 12 &&
    {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b0001) begin
        $display("Pass: Second dequeue"); passCount = passCount + 1; end
    else begin
        $display("Fail: Second dequeue"); failCount = failCount + 1; end 

    
    //Dequeue 2 instruction from the second and last decoder
    bundleWriteIn = 0;
    decode2AvailableIn = 1; decode4AvailableIn = 1;
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    if(isEmptyOut == 0 && isFullOut == 0 && frontOut == 7 && backOut == 12 &&
    {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b0101) begin
        $display("Pass: Third dequeue"); passCount = passCount + 1; end
    else begin
        $display("Fail: Third dequeue"); failCount = failCount + 1; end

    
    //Dequeue 3 instruction from the first, second and last decoder
    bundleWriteIn = 0;
    decode1AvailableIn = 1; decode2AvailableIn = 1; decode4AvailableIn = 1;
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    if(isEmptyOut == 0 && isFullOut == 0 && frontOut == 10 && backOut == 12 &&
    {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b1101) begin
        $display("Pass: Forth dequeue"); passCount = passCount + 1; end
    else begin
        $display("Fail: Forth dequeue"); failCount = failCount + 1; end

    
    //Try to dequeue 3 instructions, we only have 2 in the queue, make sure only 2 attempts to dequeue are made
    bundleWriteIn = 0;
    decode1AvailableIn = 1; decode2AvailableIn = 1; decode4AvailableIn = 1;
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    if(isEmptyOut == 1 && isFullOut == 0 && frontOut == 12 && backOut == 12 &&
    {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b1100) begin
        $display("Pass: Fith dequeue"); passCount = passCount + 1; end
    else begin
        $display("Fail: Fith dequeue"); failCount = failCount + 1; end

    
    //Continue to try to dequeue
    bundleWriteIn = 0;
    decode1AvailableIn = 1; decode2AvailableIn = 0; decode3AvailableIn = 0; decode4AvailableIn = 0;
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    if(isEmptyOut == 1 && isFullOut == 0 && frontOut == 12 && backOut == 12 &&
    {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b0000) begin
        $display("Pass: Sixth dequeue"); passCount = passCount + 1; end
    else begin
        $display("Fail: Sixth dequeue"); failCount = failCount + 1; end

`endif

`ifdef DEQUEUE_ON_RESET_TEST
    //Reset queue
    resetIn = 1; clockIn = 1;
    #1;
    resetIn = 0; clockIn = 0;
    #1;
    if(isEmptyOut == 1 && isFullOut == 0 && frontOut == 0 && backOut == 0
    && {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b0000) begin
        $display("Pass: Reset");  passCount = passCount + 1; end
    else begin
        $display("Fail: Reset"); failCount = failCount + 1; end

    ///Read a budle. We shouldn't be able to
    bundleWriteIn = 0;
    decode1AvailableIn = 1; decode2AvailableIn = 0; decode3AvailableIn = 0; decode4AvailableIn = 0;
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    //We should be empty
    if(isEmptyOut == 1 && isFullOut == 0 && frontOut == 0 && backOut == 0 &&
    {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b0000) begin
        $display("Pass: Initial dequeue"); passCount = passCount + 1; end
    else begin
        $display("Fail: Initial dequeue"); failCount = failCount + 1; end

`endif
    
    /*
    //Fill the queue to the top - test for now withought the queue issuing to decoders
    bundleWriteIn = 1;
    bundleIn = {32'hCCCCCCCC, 32'hDDDDDDDD, 32'hEEEEEEEE, 32'hFFFFFFFF};
    decode1AvailableIn = 0; decode2AvailableIn = 0; decode3AvailableIn = 0; decode4AvailableIn = 0;
    for(i = 0; i < (queueLenth / instructionsPerBundle); i = i + 1)
    begin
        //bundleWriteIn = ~isFullOut;
        clockIn = 1;
        #1;
        clockIn = 0;
        #1;
    end

    
    //Dequeue the instructions
    bundleWriteIn = 0;
    decode1AvailableIn = 1; decode2AvailableIn = 1; decode3AvailableIn = 1; decode4AvailableIn = 1;
    for(i = 0; i < (queueLenth / instructionsPerBundle); i = i + 1)
    begin
        clockIn = 1;
        #1;
        clockIn = 0;
        #1;
    end
    
    bundleWriteIn = 1;
    bundleIn = {32'hCCCCCCCC, 32'hDDDDDDDD, 32'hEEEEEEEE, 32'hFFFFFFFF};
    decode1AvailableIn = 0; decode2AvailableIn = 0; decode3AvailableIn = 0; decode4AvailableIn = 0;
    for(i = 0; i < (queueLenth / instructionsPerBundle); i = i + 1)
    begin
        //bundleWriteIn = ~isFullOut;
        clockIn = 1;
        #1;
        clockIn = 0;
        #1;
    end
    */

    /*
    //do it again but different
    //Fill the queue to the top - test for now withought the queue issuing to decoders
    bundleWriteIn = 1;
    bundleIn = {32'hCCCCCCCC, 32'hDDDDDDDD, 32'hEEEEEEEE, 32'hFFFFFFFF};
    decode1AvailableIn = 0; decode2AvailableIn = 0; decode3AvailableIn = 0; decode4AvailableIn = 0;
    for(i = 0; i < (queueLenth / instructionsPerBundle); i = i + 1)
    begin
        //bundleWriteIn = ~isFullOut;
        clockIn = 1;
        #1;
        clockIn = 0;
        #1;
    end

    //Dequeue the instructions
    bundleWriteIn = 0;
    decode1AvailableIn = 0; decode2AvailableIn = 1; decode3AvailableIn = 0; decode4AvailableIn = 0;
    for(i = 0; i < queueLenth ; i = i + 1)
    begin
        clockIn = 1;
        #1;
        clockIn = 0;
        #1;
    end
    */



    

    $display("\n########TEST RESULTS########");
    $display("%d tests passed", passCount);
    $display("%d tests failed", failCount);
end

endmodule