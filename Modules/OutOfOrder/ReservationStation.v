`define DEBUG
`define DEBUG_PRINT

/*/////////Reservation Station/////////////
Writen by Josh "Hakaru" Cantwell - 16.01.2022

This file implements the reservation station module for the power core.
*//////////////////////////////////////////


module ReservationStation
#(
    parameter queueWidth = 302, parameter RStationInstance = 0, parameter RSIdxBits = 6
)
(
    ///Input
    //command
    input wire clock_i,
    input wire reset_i,
    input wire enable_i, stall_i,
    //Data
    input wire [0:queueWidth-1] instruction_i,

    ///Output
    output reg enable_o,
);

`ifdef DEBUG_PRINT
integer debugFID;
`endif

//Reservation station data structure
reg [0:RSIdxBits-1] ReservationStation [0:queueWidth-1];


always @(posedge clock_i)
begin
    if(reset_i)
    begin//resetting
    `ifdef DEBUG_PRINT
    case(RStationInstance)//If we have multiple decoders, they each get different files. The second number indicates the decoder# log file.
        0: begin 
            debugFID = $fopen("ResStation0.log", "w");
        end
        1: begin 
            debugFID = $fopen("ResStation1.log", "w");
        end
        2: begin 
            debugFID = $fopen("ResStation2.log", "w");
        end
        3: begin 
            debugFID = $fopen("ResStation3.log", "w");
        end
        4: begin 
            debugFID = $fopen("ResStation4.log", "w");
        end
        5: begin 
            debugFID = $fopen("ResStation5.log", "w");
        end
        6: begin 
            debugFID = $fopen("ResStation6.log", "w");
        end
        7: begin 
            debugFID = $fopen("ResStation7.log", "w");
        end
        endcase
        `ifdef DEBUG_PRINT $fdisplay(debugFID, "Reservation station %d resetting", RStationInstance); `endif
    `endif
    `ifdef DEBUG $display("Reservation station %d resetting", RStationInstance); `endif
        enable_o <= 0;
    end
    else if(enable_i)
    begin//Enabled and not resetting
    //Try to find an empty entry in the RS, if there is then use it. If there isn't then stall
    
    end
    else
    begin//Neither enabled or resetting
        //disable the output
        enable_o <= 0;
    end
end
endmodule