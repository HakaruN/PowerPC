`timescale 1ns / 1ps
`define DEBUG
`define DEBUG_PRINT
`include "../../../Modules/Fetch/FetchQueue.v"

module FetchQueueTest
#(
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter bundleSize = 4 * instructionWidth, //A bundle is the collection of instructions fetched per cycle.
    parameter instructionsPerBundle = 4,
    parameter queueIndexBits = 7,
    parameter queueLenth = 2**queueIndexBits,
    parameter fetchQueueInstance = 0
)
(

);

    reg clockIn, resetIn;
    //input from fetch unit
    reg bundleWriteIn;
    reg [0:bundleSize-1] bundleIn;
    //input from decoders
    reg decode1BusyIn, decode2BusyIn, decode3BusyIn, decode4BusyIn;
    //output to decoders
    wire decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut;
    wire [0:instructionWidth-1] decdoer1InsOut, decdoer2InsOut, decdoer3InsOut, decdoer4InsOut;
    //queue state output
    wire [0:queueIndexBits-1] headOut, tailOut;
    wire isFullOut, isEmptyOut;//(is full can be used as to tell the fetch unit to stop fetching)

    FetchQueue #(
        .instructionWidth(4 * 8),
        .bundleSize(4 * instructionWidth),
        .queueIndexBits(7),
        .fetchQueueInstance(0)
    )
    fetchQueue (
    .clock_i(clockIn), .reset_i(resetIn),
    .bundleWrite_i(bundleWriteIn),
    .bundle_i(bundleIn),//bundle coming from fetch unit
    .decode1Busy_i(decode1BusyIn), .decode2Busy_i(decode2BusyIn), .decode3Busy_i(decode3BusyIn), .decode4Busy_i(decode4BusyIn),//Tells the queue if the decoders are busy or not. If busy dont sent an instruction to them
    .decoder1En_o(decoder1EnOut), .decoder2En_o(decoder2EnOut), .decoder3En_o(decoder3EnOut), .decoder4En_o(decoder4EnOut),
    .decdoer1Ins_o(decdoer1InsOut), .decdoer2Ins_o(decdoer2InsOut), .decdoer3Ins_o(decdoer3InsOut), .decdoer4Ins_o(decdoer4InsOut),
    .head_o(headOut), .tail_o(tailOut),
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
    bundleIn = 0;
    decode1BusyIn = 0; decode2BusyIn = 0; decode3BusyIn = 0; decode4BusyIn = 0;

    //Reset queue
    resetIn = 1; clockIn = 1;
    #1;
    resetIn = 0; clockIn = 0;
    #1;
    if(isEmptyOut == 1 && isFullOut == 0 && headOut == 0 && tailOut == 0
    && {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b0000)
        $display("Pass: Reset");
    else
        $display("Fail: Reset");

    ///Write a bundle
    bundleWriteIn = 1;
    bundleIn = {32'hAAAAAAAA, 32'hBBBBBBBB, 32'hCCCCCCCC, 32'hDDDDDDDD};
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    if(isEmptyOut == 0 && isFullOut == 0 && headOut == 0 && tailOut == 4)
    begin
        if({decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b0000) begin
            $display("Pass: Initial enqueue"); passCount = passCount + 1; end
        else begin
            $display("Fail: Initial enqueue"); failCount = failCount + 1; end
    end

    ///Read back the bundle
    bundleWriteIn = 0;
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    //We should be empty
    if(isEmptyOut == 1 && isFullOut == 0 && headOut == 4 && tailOut == 4 &&
    {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b1111) begin
        $display("Pass: Initial dequeue"); passCount = passCount + 1; end
    else begin
        $display("Fail: Initial dequeue"); failCount = failCount + 1; end

    //Try to issue instruction from an empty queue
    decode1BusyIn = 0; decode2BusyIn = 0; decode3BusyIn = 0; decode4BusyIn = 0;
    clockIn = 1;
    #1;
    clockIn = 0;
    #1; 
    if(isEmptyOut == 1 && isFullOut == 0 && headOut == 4 && tailOut == 4 &&
    {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b0000) begin
        $display("Pass: Empty dequeue attempt"); passCount = passCount + 1; end
    else begin
        $display("Fail: Empty dequeue attempt"); failCount = failCount + 1; end


    //Write another 2 bundles
    decode1BusyIn = 1; decode2BusyIn = 1; decode3BusyIn = 1; decode4BusyIn = 1;
    bundleWriteIn = 1;
    bundleIn = {32'hEEEEEEEE, 32'hFFFFFFFF, 32'hAAAAAAAA, 32'hBBBBBBBB};
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    if(isEmptyOut == 0 && isFullOut == 0 && headOut == 4 && tailOut == 8 &&
    {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b0000) begin
        $display("Pass: Second enqueue - 1"); passCount = passCount + 1; end
    else begin
        $display("Fail: Second enqueue - 1"); failCount = failCount + 1; end

    bundleIn = {32'hCCCCCCCC, 32'hDDDDDDDD, 32'hEEEEEEEE, 32'hFFFFFFFF};
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    if(isEmptyOut == 0 && isFullOut == 0 && headOut == 4 && tailOut == 12 &&
    {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b0000) begin
        $display("Pass: Second enqueue - 2"); passCount = passCount + 1; end
    else begin
        $display("Fail: Second enqueue - 2"); failCount = failCount + 1; end

    //Dequeue 1 instruction from the last decoder
    bundleWriteIn = 0;
    decode4BusyIn = 0;
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    if(isEmptyOut == 0 && isFullOut == 0 && headOut == 5 && tailOut == 12 &&
    {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b0001) begin
        $display("Pass: Second dequeue"); passCount = passCount + 1; end
    else begin
        $display("Fail: Second dequeue"); failCount = failCount + 1; end 

    //Dequeue 2 instruction from the second and last decoder
    bundleWriteIn = 0;
    decode2BusyIn = 0; decode4BusyIn = 0;
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    if(isEmptyOut == 0 && isFullOut == 0 && headOut == 7 && tailOut == 12 &&
    {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b0101) begin
        $display("Pass: Third dequeue"); passCount = passCount + 1; end
    else begin
        $display("Fail: Third dequeue"); failCount = failCount + 1; end

    //Dequeue 3 instruction from the first, second and last decoder
    bundleWriteIn = 0;
    decode1BusyIn = 0; decode2BusyIn = 0; decode4BusyIn = 0;
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    if(isEmptyOut == 0 && isFullOut == 0 && headOut == 10 && tailOut == 12 &&
    {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b1101) begin
        $display("Pass: Forth dequeue"); passCount = passCount + 1; end
    else begin
        $display("Fail: Forth dequeue"); failCount = failCount + 1; end

    //Try to dequeue 3 instructions, we only have 2 in the queue, make sure only 2 attempts to dequeue are made
    bundleWriteIn = 0;
    decode1BusyIn = 0; decode2BusyIn = 0; decode4BusyIn = 0;
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    if(isEmptyOut == 1 && isFullOut == 0 && headOut == 12 && tailOut == 12 &&
    {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b1100) begin
        $display("Pass: Fith dequeue"); passCount = passCount + 1; end
    else begin
        $display("Fail: Fith dequeue"); failCount = failCount + 1; end

    //Continue to try to dequeue
    bundleWriteIn = 0;
    decode1BusyIn = 0; decode2BusyIn = 0; decode3BusyIn = 0; decode4BusyIn = 0;
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;
    if(isEmptyOut == 1 && isFullOut == 0 && headOut == 12 && tailOut == 12 &&
    {decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b0000) begin
        $display("Pass: Sixth dequeue"); passCount = passCount + 1; end
    else begin
        $display("Fail: Sixth dequeue"); failCount = failCount + 1; end

/*
    //Fill the queue to the top - test for now withought the queue issuing to decoders
    bundleWriteIn = 1;
    bundleIn = {32'hCCCCCCCC, 32'hDDDDDDDD, 32'hEEEEEEEE, 32'hFFFFFFFF};
    decode1BusyIn = 1; decode2BusyIn = 1; decode3BusyIn = 1; decode4BusyIn = 1;
    for(i = 0; i < (queueLenth / instructionsPerBundle); i = i + 1)
    begin
        $display(i);
        clockIn = 1;
        #1;
        clockIn = 0;
        #1;
    end

*/

    $display("%d tests passed", passCount);
    $display("%d tests failed", failCount);
end

endmodule