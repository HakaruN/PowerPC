`timescale 1ns / 1ps
`define DEBUG
`define DEBUG_PRINT
`include "../../../Modules/Fetch/FetchQueue.v"

module FetchQueueTest
#(
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter bundleSize = 4 * instructionWidth, //A bundle is the collection of instructions fetched per cycle.
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


initial begin
    $dumpfile("FetchQueue.vcd");
    $dumpvars(0,fetchQueue);

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
        if({decoder1EnOut, decoder2EnOut, decoder3EnOut, decoder4EnOut} == 4'b0000)
            $display("Pass: Initial enqueue");
        else
            $display("Fail: Initial enqueue");
    end

    ///Read back the bundle
    bundleWriteIn = 0;
    clockIn = 1;
    #1;
    clockIn = 0;
    #1;

    //We should be empty



end

endmodule