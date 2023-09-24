`timescale 1ns / 1ps
//`define DEBUG
//`define DEBUG_PRINT

/*///////////////Fetch queue////////////////////
Written by Josh "Hakaru" Cantwell - 3.02.2023
This pipeline stage acts as a queue sitting between the output of fetch and the input of decode. It allows instructions to be issued to any available decode unit(s)
It will issue up to 4 instructions per cycle to each of the decoders as long as there are 4 decoders available. If there are less than 4 decoders available then it will
issue as many instructions as there are available decoders.

The back points to the next entry to be written to (say next cycle)
The fron points to the next entry to br read from (say next cycle)

*///////////////////////////////////////////////

module FetchQueue
#(
    parameter addressWidth = 64,
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter maxBundleSize = 4 * instructionWidth, //A bundle is the collection of instructions fetched per cycle.
    parameter PidSize = 32, parameter TidSize = 64,
    parameter instructionCounterWidth = 64,
    parameter instructionsPerBundle = 4,
    parameter queueIndexBits = 7,
    parameter queueLenth = 2**queueIndexBits,
    parameter fetchQueueInstance = 0
)
(
    input wire clock_i, reset_i,
    //Fetch in
    input wire bundleWrite_i,
    input wire [0:addressWidth-1] bundleAddress_i,
    input wire [0:1] bundleLen_i,
    input wire [0:PidSize-1] bundlePid_i,
    input wire [0:TidSize-1] bundleTid_i,
    input wire [0:instructionCounterWidth-1] bundleStartMajId_i,
    input wire [0:maxBundleSize-1] bundle_i,//bundle coming from fetch unit

    input wire decode1Available_i, decode2Available_i, decode3Available_i, decode4Available_i, //Tells the queue if the decoders are busy or not. If busy dont sent an instruction to them

    //output to decoders
    output reg decoder1En_o, decoder2En_o, decoder3En_o, decoder4En_o, 
    output reg [0:instructionWidth-1] decoder1Ins_o, decoder2Ins_o, decoder3Ins_o, decoder4Ins_o, 
    //queue state output
    output reg [0:queueIndexBits-1] front_o, back_o,
    output reg isFull_o, isEmpty_o
);

//File handle to the debug output
`ifdef DEBUG_PRINT
integer debugFID;
`endif

    reg [0:instructionWidth-1] instructionQueue [0:queueLenth-1];
    reg frontInReset;

    always @(posedge clock_i)
    begin
        `ifdef DEBUG $display("--------------------------------"); `endif
        `ifdef DEBUG_PRINT $fdisplay(debugFID ,"--------------------------------"); `endif
        if(reset_i)
        begin
            `ifdef DEBUG_PRINT
            case(fetchQueueInstance)//If we have multiple fetch queues, they each get different files.
            0: begin debugFID = $fopen("FetchQueue0.log", "w"); end
            1: begin debugFID = $fopen("FetchQueue1.log", "w"); end
            2: begin debugFID = $fopen("FetchQueue2.log", "w"); end
            3: begin debugFID = $fopen("FetchQueue3.log", "w"); end
            4: begin debugFID = $fopen("FetchQueue4.log", "w"); end
            5: begin debugFID = $fopen("FetchQueue5.log", "w"); end
            6: begin debugFID = $fopen("FetchQueue6.log", "w"); end
            7: begin debugFID = $fopen("FetchQueue7.log", "w"); end
            endcase
            `endif
            `ifdef DEBUG $display("ICache: %d: Resetting", fetchQueueInstance); `endif  
            `ifdef DEBUG_PRINT $fdisplay(debugFID, "ICache: %d: Resetting", fetchQueueInstance); `endif  
            front_o <= 0; back_o <= 0;
            isFull_o <= 0; isEmpty_o <= 1;
            decoder1En_o <= 0; decoder2En_o <= 0;
            decoder3En_o <= 0; decoder4En_o <= 0;
            frontInReset <= 1;
        end
        else//not in reset
        begin
            ///perform queue accesses
            //enqueue
            if(bundleWrite_i && ~isFull_o)
            begin
                case(bundleLen_i)
                    2'b00: begin//1 inst in bundle
                    instructionQueue[back_o + 0] <= bundle_i[0 * instructionWidth+: instructionWidth];
                    if(isEmpty_o)
                        isEmpty_o <= 0;
                end
                2'b01: begin//2 insts in bundle
                    instructionQueue[back_o + 0] <= bundle_i[0 * instructionWidth+: instructionWidth];
                    instructionQueue[back_o + 1] <= bundle_i[1 * instructionWidth+: instructionWidth];
                    if(isEmpty_o)
                        isEmpty_o <= 0;
                end
                2'b10: begin//3 insts in bundle
                    instructionQueue[back_o + 0] <= bundle_i[0 * instructionWidth+: instructionWidth];
                    instructionQueue[back_o + 1] <= bundle_i[1 * instructionWidth+: instructionWidth];
                    instructionQueue[back_o + 2] <= bundle_i[2 * instructionWidth+: instructionWidth];
                    if(isEmpty_o)
                        isEmpty_o <= 0;
                end
                2'b11: begin//4 insts in bundle
                    instructionQueue[back_o + 0] <= bundle_i[0 * instructionWidth+: instructionWidth];
                    instructionQueue[back_o + 1] <= bundle_i[1 * instructionWidth+: instructionWidth];
                    instructionQueue[back_o + 2] <= bundle_i[2 * instructionWidth+: instructionWidth];
                    instructionQueue[back_o + 3] <= bundle_i[3 * instructionWidth+: instructionWidth];
                    if(isEmpty_o)
                        isEmpty_o <= 0;
                end
                endcase
                `ifdef DEBUG $display("Fetch Queue: %d. Enqueing %d instruction(s).", fetchQueueInstance, bundleLen_i+1); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID ,"Fetch Queue: %d. Enqueing %d instruction(s).", fetchQueueInstance, bundleLen_i+1); `endif
            end
            //dequeue
            if(isEmpty_o)
            begin
                decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                `ifdef DEBUG $display("Fetch Queue: %d. Queue Empty, not issuing instruction to decoders.", fetchQueueInstance); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fetch Queue: %d. Queue Empty, not issuing instruction to decoders.", fetchQueueInstance); `endif
            end
            else
            begin
                `ifdef DEBUG $display("Fetch Queue: %d. Decoder state %b.", fetchQueueInstance, {decode1Available_i, decode2Available_i, decode3Available_i, decode4Available_i}); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fetch Queue: %d. Decoder state %b.", fetchQueueInstance, {decode1Available_i, decode2Available_i, decode3Available_i, decode4Available_i}); `endif
                case({decode1Available_i, decode2Available_i, decode3Available_i, decode4Available_i})
                4'b0000: begin
                    //Do nothing, all decoders are busy
                end
                4'b0001: begin
                    decoder4Ins_o <= instructionQueue[front_o];
                    decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 1;
                    front_o <= front_o + 1; frontInReset <= 0;
                end
                4'b0010: begin
                    decoder3Ins_o <= instructionQueue[front_o];
                    decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 1; decoder4En_o <= 0;
                    front_o <= front_o + 1; frontInReset <= 0;
                end

                4'b0011: begin
                    if((back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)) > front_o )
                    begin //used entries = back - front
                        case(back_o - front_o)
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder3Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 1; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        default: begin//2 or more available
                            decoder3Ins_o <= instructionQueue[front_o]; decoder4Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 1; decoder4En_o <= 1;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        endcase
                    end
                    else if(front_o > (back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)))
                    begin //used entries = size - (front - back)
                        case(queueLenth - (front_o - back_o))
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder3Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 1; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        default: begin//2 or more available
                            decoder3Ins_o <= instructionQueue[front_o]; decoder4Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 1; decoder4En_o <= 1;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        endcase
                    end
                    else
                    begin
                        //not empty so must be full
                        decoder3Ins_o <= instructionQueue[front_o]; decoder4Ins_o <= instructionQueue[front_o + 1];
                        decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 1; decoder4En_o <= 1;
                        front_o <= front_o + 3; frontInReset <= 0;
                    end
                end

                4'b0100: begin
                    decoder2Ins_o <= instructionQueue[front_o];
                    decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                    front_o <= front_o + 1; frontInReset <= 0;
                end
                4'b0101: begin
                    if((back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)) > front_o )
                    begin //used entries = back - front
                        case(back_o - front_o)
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder2Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        default: begin//2 or more available
                            decoder2Ins_o <= instructionQueue[front_o]; decoder4Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 1;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        endcase
                    end
                    else if(front_o > (back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)))
                    begin //used entries = size - (front - back)
                        case(queueLenth - (front_o - back_o))
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder2Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        default: begin//2 or more available
                            decoder2Ins_o <= instructionQueue[front_o]; decoder4Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 1;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        endcase
                    end
                    else
                    begin
                        //not empty so must be full
                        decoder2Ins_o <= instructionQueue[front_o]; decoder4Ins_o <= instructionQueue[front_o + 1];
                        decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 1;
                        front_o <= front_o + 2; frontInReset <= 0;
                    end
                end

                4'b0110: begin
                    if((back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)) > front_o )
                    begin //used entries = back - front
                        case(back_o - front_o)
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder2Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        default: begin//2 or more available
                            decoder2Ins_o <= instructionQueue[front_o]; decoder3Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 0;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        endcase
                    end
                    else if(front_o > (back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)))
                    begin //used entries = size - (front - back)
                        case(queueLenth - (front_o - back_o))
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder2Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        default: begin//2 or more available
                            decoder2Ins_o <= instructionQueue[front_o]; decoder3Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 0;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        endcase
                    end
                    else
                    begin
                        //not empty so must be full
                        decoder2Ins_o <= instructionQueue[front_o]; decoder3Ins_o <= instructionQueue[front_o + 1];
                        decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 0;
                        front_o <= front_o + 2; frontInReset <= 0;
                    end
                end
                4'b0111: begin
                    if((back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)) > front_o)
                    begin //used entries = back - front
                        case(back_o - front_o)
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder2Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        2:  begin//2 or more available
                            decoder2Ins_o <= instructionQueue[front_o]; decoder3Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 0;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        default: begin//3 or more available
                            decoder2Ins_o <= instructionQueue[front_o]; decoder3Ins_o <= instructionQueue[front_o + 1]; decoder4Ins_o <= instructionQueue[front_o + 2];
                            decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 1;
                            front_o <= front_o + 3; frontInReset <= 0;
                        end
                        endcase
                    end
                    else if(front_o > (back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)))
                    begin //used entries = size - (front - back)
                        case(queueLenth - (front_o - back_o))
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder2Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        2:  begin//2 or more available
                            decoder2Ins_o <= instructionQueue[front_o]; decoder3Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 0;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        default: begin//3 or more available
                            decoder2Ins_o <= instructionQueue[front_o]; decoder3Ins_o <= instructionQueue[front_o + 1]; decoder4Ins_o <= instructionQueue[front_o + 2];
                            decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 1;
                            front_o <= front_o + 3; frontInReset <= 0;
                        end
                        endcase
                    end
                    else
                    begin
                        //not empty so must be full
                        decoder2Ins_o <= instructionQueue[front_o]; decoder3Ins_o <= instructionQueue[front_o + 1]; decoder4Ins_o <= instructionQueue[front_o + 2];
                        decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 1;
                        front_o <= front_o + 3; frontInReset <= 0;
                    end
                end
                4'b1000: begin
                    decoder1Ins_o <= instructionQueue[front_o];
                    decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                end
                4'b1001: begin
                    if((back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)) > front_o)
                    begin //used entries = back - front
                        case(back_o - front_o)
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder1Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        default:  begin//2 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder4Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 1;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        endcase
                    end
                    else if(front_o > (back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)))
                    begin //used entries = size - (front - back)
                        case(queueLenth - (front_o - back_o))
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder1Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        default:  begin//2 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder4Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 1;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        endcase
                    end
                    else
                    begin
                        //not empty so must be full
                        decoder1Ins_o <= instructionQueue[front_o]; decoder4Ins_o <= instructionQueue[front_o + 1];
                        decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 1;
                        front_o <= front_o + 2; frontInReset <= 0;
                    end
                end
                4'b1010: begin
                    if((back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)) > front_o)
                    begin //used entries = back - front
                        case(back_o - front_o)
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder1Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        default:  begin//2 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder3Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 1; decoder4En_o <= 0;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        endcase
                    end
                    else if(front_o > (back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)))
                    begin //used entries = size - (front - back)
                        case(queueLenth - (front_o - back_o))
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder1Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        default:  begin//2 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder3Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 1; decoder4En_o <= 0;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        endcase
                    end
                    else
                    begin
                        //not empty so must be full
                        decoder1Ins_o <= instructionQueue[front_o]; decoder3Ins_o <= instructionQueue[front_o + 1];
                        decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 1; decoder4En_o <= 0;
                        front_o <= front_o + 2; frontInReset <= 0;
                    end
                end
                4'b1011: begin
                    if((back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)) > front_o)
                    begin //used entries = back - front
                        case(queueLenth - (front_o - back_o))
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder1Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        2:  begin//2 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder3Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 1; decoder4En_o <= 0;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        default: begin//3 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder3Ins_o <= instructionQueue[front_o + 1]; decoder4Ins_o <= instructionQueue[front_o + 2];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 1; decoder4En_o <= 1;
                            front_o <= front_o + 3; frontInReset <= 0;
                        end
                        endcase
                    end
                    else if(front_o > (back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)))
                    begin //used entries = size - (front - back)
                        case(queueLenth - (front_o - back_o))
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder1Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        2:  begin//2 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder3Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 1; decoder4En_o <= 0;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        default: begin//3 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder3Ins_o <= instructionQueue[front_o + 1]; decoder4Ins_o <= instructionQueue[front_o + 2];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 1; decoder4En_o <= 1;
                            front_o <= front_o + 3; frontInReset <= 0;
                        end
                        endcase
                    end
                    else
                    begin
                        //not empty so must be full
                        decoder1Ins_o <= instructionQueue[front_o]; decoder3Ins_o <= instructionQueue[front_o + 1]; decoder4Ins_o <= instructionQueue[front_o + 2];
                        decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 1; decoder4En_o <= 1;
                        front_o <= front_o + 3; frontInReset <= 0;
                    end
                end
                4'b1100: begin
                    if((back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)) > front_o)
                    begin //used entries = back - front
                        case(back_o - front_o)
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder1Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        default:  begin//2 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder2Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        endcase
                    end
                    else if(front_o > (back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)))
                    begin //used entries = size - (front - back)
                        case(queueLenth - (front_o - back_o))
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder1Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        default:  begin//2 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder2Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        endcase
                    end
                    else
                    begin
                        //not empty so must be full
                        decoder1Ins_o <= instructionQueue[front_o]; decoder2Ins_o <= instructionQueue[front_o + 1];
                        decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                        front_o <= front_o + 2; frontInReset <= 0;
                    end
                end
                4'b1101: begin
                    if((back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)) > front_o)
                    begin //used entries = back - front
                        case(back_o - front_o)
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder1Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        2:  begin//2 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder2Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        default: begin//3 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder2Ins_o <= instructionQueue[front_o + 1]; decoder4Ins_o <= instructionQueue[front_o + 2];
                            decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 1;
                            front_o <= front_o + 3; frontInReset <= 0;
                        end
                        endcase
                    end
                    else if(front_o > (back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)))
                    begin //used entries = size - (front - back)
                        case(queueLenth - (front_o - back_o))
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder1Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        2:  begin//2 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder2Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        default: begin//3 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder2Ins_o <= instructionQueue[front_o + 1]; decoder4Ins_o <= instructionQueue[front_o + 2];
                            decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 1;
                            front_o <= front_o + 3; frontInReset <= 0;
                        end
                        endcase
                    end
                    else
                    begin
                        //not empty so must be full
                        decoder1Ins_o <= instructionQueue[front_o]; decoder2Ins_o <= instructionQueue[front_o + 1]; decoder4Ins_o <= instructionQueue[front_o + 2];
                        decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 1;
                        front_o <= front_o + 3; frontInReset <= 0;
                    end
                end
                4'b1110: begin
                    if((back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)) > front_o)
                    begin //used entries = back - front
                        case(back_o - front_o)
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder1Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        2:  begin//2 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder2Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        default: begin//3 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder2Ins_o <= instructionQueue[front_o + 1]; decoder3Ins_o <= instructionQueue[front_o + 2];
                            decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 0;
                            front_o <= front_o + 3; frontInReset <= 0;
                        end
                        endcase
                    end
                    else if(front_o > (back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)))
                    begin //used entries = size - (front - back)
                        case(queueLenth - (front_o - back_o))
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder1Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        2:  begin//2 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder2Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        default: begin//3 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder2Ins_o <= instructionQueue[front_o + 1]; decoder3Ins_o <= instructionQueue[front_o + 2];
                            decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 0;
                            front_o <= front_o + 3; frontInReset <= 0;
                        end
                        endcase
                    end
                    else
                    begin
                        //not empty so must be full
                        decoder1Ins_o <= instructionQueue[front_o]; decoder2Ins_o <= instructionQueue[front_o + 1]; decoder3Ins_o <= instructionQueue[front_o + 2];
                        decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 0;
                        front_o <= front_o + 3; frontInReset <= 0;
                    end
                    
                end
                4'b1111: begin
                    if((back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)) > front_o)
                    begin //used entries = back - front
                        case(back_o - front_o)
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder1Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        2:  begin//2 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder2Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        3: begin//3 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder2Ins_o <= instructionQueue[front_o + 1]; decoder3Ins_o <= instructionQueue[front_o + 2];
                            decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 0;
                            front_o <= front_o + 3; frontInReset <= 0;
                        end
                        default: begin//4 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder2Ins_o <= instructionQueue[front_o + 1]; decoder3Ins_o <= instructionQueue[front_o + 2]; decoder4Ins_o <= instructionQueue[front_o + 3];
                            decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 1;
                            front_o <= front_o + 4; frontInReset <= 0;
                        end
                        endcase
                    end
                    else if(front_o > (back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)))
                    begin //used entries = size - (front - back)
                        case(queueLenth - (front_o - back_o))
                        0: begin decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0; end//0 available
                        1: begin 
                            decoder1Ins_o <= instructionQueue[front_o];
                            decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 1; frontInReset <= 0;
                        end
                        2:  begin//2 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder2Ins_o <= instructionQueue[front_o + 1];
                            decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                            front_o <= front_o + 2; frontInReset <= 0;
                        end
                        3: begin//3 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder2Ins_o <= instructionQueue[front_o + 1]; decoder3Ins_o <= instructionQueue[front_o + 2];
                            decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 0;
                            front_o <= front_o + 3; frontInReset <= 0;
                        end
                        default: begin//4 or more available
                            decoder1Ins_o <= instructionQueue[front_o]; decoder2Ins_o <= instructionQueue[front_o + 1]; decoder3Ins_o <= instructionQueue[front_o + 2]; decoder4Ins_o <= instructionQueue[front_o + 3];
                            decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 1;
                            front_o <= front_o + 4; frontInReset <= 0;
                        end
                        endcase
                    end
                    else
                    begin
                        //not empty so must be full
                        decoder1Ins_o <= instructionQueue[front_o]; decoder2Ins_o <= instructionQueue[front_o + 1]; decoder3Ins_o <= instructionQueue[front_o + 2]; decoder4Ins_o <= instructionQueue[front_o + 3];
                        decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 1;
                        front_o <= front_o + 4; frontInReset <= 0;
                    end
                end
                endcase
            end

            ///perform front and back ptr adjustments
            //Enqueue - increments the back
            if(bundleWrite_i)
            begin
                back_o <= back_o + bundleLen_i + 1;
            end
            /*
            //Dequeue - increments the front
            case({decode1Available_i, decode2Available_i, decode3Available_i, decode4Available_i})
                4'b0001: begin front_o <= front_o + 1;  frontInReset <= 0; $display("DQ: 1"); end
                4'b0010: begin front_o <= front_o + 1;  frontInReset <= 0; $display("DQ: 1"); end
                4'b0011: begin front_o <= front_o + 2;  frontInReset <= 0; $display("DQ: 2"); end
                4'b0100: begin front_o <= front_o + 1;  frontInReset <= 0; $display("DQ: 1"); end
                4'b0101: begin front_o <= front_o + 2;  frontInReset <= 0; $display("DQ: 2"); end
                4'b0110: begin front_o <= front_o + 2;  frontInReset <= 0; $display("DQ: 2"); end
                4'b0111: begin front_o <= front_o + 3;  frontInReset <= 0; $display("DQ: 3"); end
                4'b1000: begin front_o <= front_o + 1;  frontInReset <= 0; $display("DQ: 1"); end
                4'b1001: begin front_o <= front_o + 2;  frontInReset <= 0; $display("DQ: 2"); end
                4'b1010: begin front_o <= front_o + 2;  frontInReset <= 0; $display("DQ: 2"); end
                4'b1011: begin front_o <= front_o + 3;  frontInReset <= 0; $display("DQ: 3"); end
                4'b1100: begin front_o <= front_o + 2;  frontInReset <= 0; $display("DQ: 2"); end
                4'b1101: begin front_o <= front_o + 3;  frontInReset <= 0; $display("DQ: 3"); end
                4'b1110: begin front_o <= front_o + 3;  frontInReset <= 0; $display("DQ: 3"); end
                4'b1111: begin front_o <= front_o + 4;  frontInReset <= 0; $display("DQ: 4"); end
            endcase
            */

            ///Calculate fullness and emptyness
            //fullness
            if(back_o > front_o)
            begin
                //available = queueLenth - ((back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)) - (front_o + (decode1Available_i + decode2Available_i + decode3Available_i + decode4Available_i)));
                if(queueLenth - ((back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)) - (front_o + (decode1Available_i + decode2Available_i + decode3Available_i + decode4Available_i))) < 4)
                begin
                    isFull_o <= 1;
                end
                else
                begin
                    isFull_o <= 0;
                end
            end
            else if(front_o > back_o)
            begin
                if((front_o + (decode1Available_i + decode2Available_i + decode3Available_i + decode4Available_i)) - (back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)) < 4)
                begin
                    isFull_o <= 1;
                end
                else
                begin
                    isFull_o <= 0;
                end
            end
            else
            begin
                if(frontInReset == 1)
                begin
                    isFull_o <= 0;
                end
                else
                begin
                    isFull_o <= 0;
                end
            end

            //emptieness
            if(back_o  > front_o )
            begin
                $display("A");
                //used = (back_o + bundleLen_i) - (front_o + (decode1Available_i + decode2Available_i + decode3Available_i + decode4Available_i));
                if(back_o - front_o < (decode1Available_i + decode2Available_i + decode3Available_i + decode4Available_i))//if there are less than the number of decoders available. 
                begin
                    if((back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)) - (front_o + (back_o - front_o)) > 0)
                    begin
                        isEmpty_o <= 0;
                        $display("1");
                    end
                    else
                    begin
                        isEmpty_o <= 1;
                        $display("2");
                    end
                end
                else
                    begin
                    if((back_o + (bundleWrite_i ? (bundleLen_i+1) : 0)) - (front_o + (decode1Available_i + decode2Available_i + decode3Available_i + decode4Available_i)) > 0)
                    begin
                        isEmpty_o <= 0;
                        $display("3");
                    end
                    else
                    begin
                        isEmpty_o <= 1;
                        $display("4");
                    end
                end
            end
            else if(front_o  > back_o)
            begin
                $display("B");
                if(queueLenth - (front_o - back_o) < (decode1Available_i + decode2Available_i + decode3Available_i + decode4Available_i))//if there are less than the number of decoders available. 
                begin
                    if(queueLenth - ((front_o + (queueLenth - (front_o - back_o))) - (back_o + (bundleWrite_i ? (bundleLen_i+1) : 0))) > 0)
                    begin
                        isEmpty_o <= 0;
                        $display("1");
                    end
                    else
                    begin
                        isEmpty_o <= 1;
                        $display("2");
                    end
                end
                else
                begin
                    if(queueLenth - ((front_o + (decode1Available_i + decode2Available_i + decode3Available_i + decode4Available_i)) - (back_o + (bundleWrite_i ? (bundleLen_i+1) : 0))) > 0)
                    begin
                        isEmpty_o <= 0;
                        $display("3");
                    end
                    else
                    begin
                        isEmpty_o <= 1;
                        $display("4");
                    end
                end
            end

        end
    end
            
endmodule