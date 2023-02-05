`timescale 1ns / 1ps
`define DEBUG
`define DEBUG_PRINT

/*///////////////Fetch queue////////////////////



*///////////////////////////////////////////////

module FetchQueue
#(
    parameter instructionWidth = 4 * 8, // POWER instructions are 4 byte fixed sized
    parameter bundleSize = 4 * instructionWidth, //A bundle is the collection of instructions fetched per cycle.
    parameter queueIndexBits = 7,
    parameter queueLenth = 2**queueIndexBits,
    parameter fetchQueueInstance = 0
)
(
    input wire clock_i, reset_i,
    //Fetch in
    input wire bundleWrite_i,
    input wire [0:bundleSize-1] bundle_i,//bundle coming from fetch unit

    input wire decode1Busy_i, decode2Busy_i, decode3Busy_i, decode4Busy_i, //Tells the queue if the decoders are busy or not. If busy dont sent an instruction to them

    //output to decoders
    output reg decoder1En_o, decoder2En_o, decoder3En_o, decoder4En_o, 
    output reg [0:instructionWidth-1] decdoer1Ins_o, decdoer2Ins_o, decdoer3Ins_o, decdoer4Ins_o, 
    //queue state output
    output reg [0:queueIndexBits-1] head_o, tail_o,
    output reg isFull_o, isEmpty_o
);

//File handle to the debug output
`ifdef DEBUG_PRINT
integer debugFID;
`endif

    reg [0:instructionWidth-1] instructionQueue [0:queueLenth-1];

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
            head_o <= 0; tail_o <= 0;
            isFull_o <= 0; isEmpty_o <= 1;
            decoder1En_o <= 0; decoder2En_o <= 0;
            decoder3En_o <= 0; decoder4En_o <= 0;
        end
        else
        begin
            decoder1En_o <= ~decode1Busy_i; decoder2En_o <= ~decode2Busy_i;
            decoder3En_o <= ~decode3Busy_i; decoder4En_o <= ~decode4Busy_i;

            //Add a bundle to the queue and check for fullness
            if(isFull_o)
            begin                    
                `ifdef DEBUG $display("Fetch Queue: %d. Full, not enquing bundle", fetchQueueInstance); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID ,"Fetch Queue: %d. Full, not enquing bundle", fetchQueueInstance); `endif
            end
            else begin//we have enough space for a whole bundle

                if (bundleWrite_i)begin
                    instructionQueue[tail_o + 0] <= bundle_i[0 * instructionWidth+: instructionWidth];
                    instructionQueue[tail_o + 1] <= bundle_i[1 * instructionWidth+: instructionWidth];
                    instructionQueue[tail_o + 2] <= bundle_i[2 * instructionWidth+: instructionWidth];
                    instructionQueue[tail_o + 3] <= bundle_i[3 * instructionWidth+: instructionWidth];
                    tail_o <= (tail_o + 4) % (2**queueIndexBits);//Move the head up by 4 instructions
                    `ifdef DEBUG $display("Fetch Queue: %d. Enqueing bundle.", fetchQueueInstance); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID ,"Fetch Queue: %d. Enqueing bundle.", fetchQueueInstance); `endif
                    isEmpty_o <= 0;

                    if(((tail_o + 8) % (2**queueIndexBits) > head_o))//were not full
                    begin
                        isFull_o <= 0;
                        `ifdef DEBUG $display("Fetch Queue: %d. Not full.", fetchQueueInstance); `endif
                        `ifdef DEBUG_PRINT $fdisplay(debugFID ,"Fetch Queue: %d. Not full.", fetchQueueInstance); `endif
                    end
                    else
                    begin
                        isFull_o <= 1;
                        `ifdef DEBUG $display("Fetch Queue: %d. Full.", fetchQueueInstance); `endif
                        `ifdef DEBUG_PRINT $fdisplay(debugFID ,"Fetch Queue: %d. Full.", fetchQueueInstance); `endif
                    end
                end
                else
                begin
                    `ifdef DEBUG $display("Fetch Queue: %d. Not full but write enable is low. Not enqueing.", fetchQueueInstance); `endif
                    `ifdef DEBUG_PRINT $fdisplay(debugFID ,"Fetch Queue: %d. Not full but write enable is low. Not enqueing.", fetchQueueInstance); `endif
                end
            end

            //Dispatch instructions to decode (read from queue)
            if(isEmpty_o)
            begin
                decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                `ifdef DEBUG $display("Fetch Queue: %d. Queue Empty, not issuing instruction to decoders.", fetchQueueInstance); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fetch Queue: %d. Queue Empty, not issuing instruction to decoders.", fetchQueueInstance); `endif
            end
            else begin
                `ifdef DEBUG $display("Fetch Queue: %d. Decoder state %b. Num Instructions in Queue: %d.", fetchQueueInstance, {~decode1Busy_i, ~decode2Busy_i, ~decode3Busy_i, ~decode4Busy_i}, tail_o - head_o); `endif
                `ifdef DEBUG_PRINT $fdisplay(debugFID, "Fetch Queue: %d. Decoder state %b. Num Instructions in Queue: %d.", fetchQueueInstance, {~decode1Busy_i, ~decode2Busy_i, ~decode3Busy_i, ~decode4Busy_i}, tail_o - head_o); `endif
                case({~decode1Busy_i, ~decode2Busy_i, ~decode3Busy_i, ~decode4Busy_i})
                4'b0000: begin
                    //Do nothing, all decoders are busy
                end
                4'b0001: begin
                    head_o <= (head_o + 1) % (2**queueIndexBits);//increment the head
                    isFull_o <= 0;                    
                    if((head_o + 1) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                        isEmpty_o <= 1;
                    decdoer4Ins_o <= instructionQueue[head_o];
                    decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 1;
                end
                4'b0010: begin
                    head_o <= (head_o + 1) % (2**queueIndexBits); isFull_o <= 0;                    
                    if((head_o + 1) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                        isEmpty_o <= 1;
                    decdoer4Ins_o <= instructionQueue[head_o];
                    decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 1;
                end
                4'b0011: begin
                    if(tail_o - head_o >= 2)//enough instructions to fullfill demand
                    begin
                        head_o <= (head_o + 2) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 2) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer3Ins_o <= instructionQueue[head_o]; decdoer4Ins_o <= instructionQueue[head_o + 1];
                        decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 1; decoder4En_o <= 1;
                    end
                    else if(tail_o - head_o == 1)//enough instructions for 1 decoder
                    begin
                        head_o <= (head_o + 1) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 1) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer3Ins_o <= instructionQueue[head_o];
                        decoder1En_o <= 0; decoder2En_o <= 0; decoder3En_o <= 1; decoder4En_o <= 0;
                    end
                end
                4'b0100: begin
                    head_o <= (head_o + 1) % (2**queueIndexBits); isFull_o <= 0;                    
                    if((head_o + 1) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                        isEmpty_o <= 1;
                    decdoer2Ins_o <= instructionQueue[head_o];
                    decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                end
                4'b0101: begin
                    if(tail_o - head_o >= 2)//enough instructions to fullfill demand
                    begin
                        head_o <= (head_o + 2) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 2) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer2Ins_o <= instructionQueue[head_o]; decdoer4Ins_o <= instructionQueue[head_o + 1];
                        decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 1;
                    end
                    else if(tail_o - head_o == 1)//enough instructions for 1 decoder
                    begin
                        head_o <= (head_o + 1) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 1) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer2Ins_o <= instructionQueue[head_o];
                        decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                    end
                end
                4'b0110: begin
                    if(tail_o - head_o >= 2)//enough instructions to fullfill demand
                    begin
                        head_o <= (head_o + 2) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 2) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer2Ins_o <= instructionQueue[head_o]; decdoer3Ins_o <= instructionQueue[head_o + 1];
                        decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 0;
                    end
                    else if(tail_o - head_o == 1)//enough instructions for 1 decoder
                    begin
                        head_o <= (head_o + 1) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 1) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer2Ins_o <= instructionQueue[head_o];
                        decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                    end
                end
                4'b0111: begin
                    if(tail_o - head_o >= 3)//enough instructions to fullfill demand
                    begin
                        head_o <= (head_o + 3) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 3) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer2Ins_o <= instructionQueue[head_o]; decdoer3Ins_o <= instructionQueue[head_o + 1]; decdoer4Ins_o <= instructionQueue[head_o + 2];
                        decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 1;
                    end
                    else if(tail_o - head_o >= 2)//enough instructions for 2 decoders
                    begin
                        head_o <= (head_o + 2) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 2) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer2Ins_o <= instructionQueue[head_o]; decdoer3Ins_o <= instructionQueue[head_o + 1];
                        decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 0;
                    end
                    else if(tail_o - head_o == 1)//enough instructions for 1 decoder
                    begin
                        head_o <= (head_o + 1) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 1) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer2Ins_o <= instructionQueue[head_o];
                        decoder1En_o <= 0; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                    end
                end
                4'b1000: begin
                    head_o <= (head_o + 1) % (2**queueIndexBits);//increment the head
                    isFull_o <= 0;                    
                    if((head_o + 1) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                        isEmpty_o <= 1;
                    decdoer1Ins_o <= instructionQueue[head_o];
                    decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                end
                4'b1001: begin
                    if(tail_o - head_o >= 2)//enough instructions to fullfill demand
                    begin
                        head_o <= (head_o + 2) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 2) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer1Ins_o <= instructionQueue[head_o]; decdoer4Ins_o <= instructionQueue[head_o + 1];
                        decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 1;
                    end
                    else if(tail_o - head_o == 1)//enough instructions for 1 decoder
                    begin
                        head_o <= (head_o + 1) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 1) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer1Ins_o <= instructionQueue[head_o];
                        decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                    end
                end
                4'b1010: begin
                    if(tail_o - head_o >= 2)//enough instructions to fullfill demand
                    begin
                        head_o <= (head_o + 2) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 2) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer1Ins_o <= instructionQueue[head_o]; decdoer3Ins_o <= instructionQueue[head_o + 1];
                        decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 1; decoder4En_o <= 0;
                    end
                    else if(tail_o - head_o == 1)//enough instructions for 1 decoder
                    begin
                        head_o <= (head_o + 1) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 1) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer1Ins_o <= instructionQueue[head_o];
                        decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                    end
                end
                4'b1011: begin
                    if(tail_o - head_o >= 3)//enough instructions to fullfill demand
                    begin
                        head_o <= (head_o + 3) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 3) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer1Ins_o <= instructionQueue[head_o]; decdoer3Ins_o <= instructionQueue[head_o + 1]; decdoer4Ins_o <= instructionQueue[head_o + 2];
                        decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 1; decoder4En_o <= 1;
                    end
                    else if(tail_o - head_o >= 2)//enough instructions for 2 decoders
                    begin
                        head_o <= (head_o + 2) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 2) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer1Ins_o <= instructionQueue[head_o]; decdoer3Ins_o <= instructionQueue[head_o + 1];
                        decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 1; decoder4En_o <= 0;
                    end
                    else if(tail_o - head_o == 1)//enough instructions for 1 decoder
                    begin
                        head_o <= (head_o + 1) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 1) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer1Ins_o <= instructionQueue[head_o];
                        decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                    end
                end
                4'b1100: begin
                    if(tail_o - head_o >= 2)//enough instructions to fullfill demand
                    begin
                        head_o <= (head_o + 2) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 2) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer1Ins_o <= instructionQueue[head_o]; decdoer2Ins_o <= instructionQueue[head_o + 1];
                        decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                    end
                    else if(tail_o - head_o == 1)//enough instructions for 1 decoder
                    begin
                        head_o <= (head_o + 1) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 1) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer1Ins_o <= instructionQueue[head_o];
                        decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                    end
                end
                4'b1101: begin
                    if(tail_o - head_o >= 3)//enough instructions to fullfill demand
                    begin
                        head_o <= (head_o + 3) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 3) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer1Ins_o <= instructionQueue[head_o]; decdoer2Ins_o <= instructionQueue[head_o + 1]; decdoer4Ins_o <= instructionQueue[head_o + 2];
                        decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 1;
                        //$display("asdfa");
                    end
                    else if(tail_o - head_o >= 2)//enough instructions for 2 decoders
                    begin
                        head_o <= (head_o + 2) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 2) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer1Ins_o <= instructionQueue[head_o]; decdoer2Ins_o <= instructionQueue[head_o + 1];
                        decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                        $display("asdfa");
                    end
                    else if(tail_o - head_o == 1)//enough instructions for 1 decoder
                    begin
                        head_o <= (head_o + 1) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 1) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer1Ins_o <= instructionQueue[head_o];
                        decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                        //$display("asdfa");
                    end
                end
                4'b1110: begin
                    if(tail_o - head_o >= 3)//enough instructions to fullfill demand
                    begin
                        head_o <= (head_o + 3) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 3) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer1Ins_o <= instructionQueue[head_o]; decdoer2Ins_o <= instructionQueue[head_o + 1]; decdoer3Ins_o <= instructionQueue[head_o + 2];
                        decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 0;
                    end
                    else if(tail_o - head_o >= 2)//enough instructions for 2 decoders
                    begin
                        head_o <= (head_o + 2) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 2) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer1Ins_o <= instructionQueue[head_o]; decdoer2Ins_o <= instructionQueue[head_o + 1];
                        decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                    end
                    else if(tail_o - head_o == 1)//enough instructions for 1 decoder
                    begin
                        head_o <= (head_o + 1) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 1) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer1Ins_o <= instructionQueue[head_o];
                        decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                    end
                end
                4'b1111: begin
                    if(tail_o - head_o >= 4)//enough instructions to fullfill demand
                    begin
                        head_o <= (head_o + 4) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 4) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer1Ins_o <= instructionQueue[head_o]; decdoer2Ins_o <= instructionQueue[head_o + 1]; decdoer3Ins_o <= instructionQueue[head_o + 2]; decdoer4Ins_o <= instructionQueue[head_o + 3];
                        decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 1;
                    end
                    else if(tail_o - head_o >= 3)//enough instructions for 3 decoders
                    begin
                        head_o <= (head_o + 3) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 3) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer1Ins_o <= instructionQueue[head_o]; decdoer2Ins_o <= instructionQueue[head_o + 1]; decdoer3Ins_o <= instructionQueue[head_o + 2];
                        decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 1; decoder4En_o <= 0;
                    end
                    else if(tail_o - head_o == 2)//enough instructions for 2 decoders
                    begin
                        head_o <= (head_o + 2) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 2) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer1Ins_o <= instructionQueue[head_o]; decdoer2Ins_o <= instructionQueue[head_o + 1];
                        decoder1En_o <= 1; decoder2En_o <= 1; decoder3En_o <= 0; decoder4En_o <= 0;
                    end
                    else if(tail_o - head_o == 1)//enough instructions for 1 decoder
                    begin
                        head_o <= (head_o + 1) % (2**queueIndexBits); isFull_o <= 0; 
                        if((head_o + 1) % (2**queueIndexBits) >= tail_o)//check if we're now empty
                            isEmpty_o <= 1;
                        decdoer1Ins_o <= instructionQueue[head_o];
                        decoder1En_o <= 1; decoder2En_o <= 0; decoder3En_o <= 0; decoder4En_o <= 0;
                    end
                end
                endcase

            end
        end

    end

endmodule