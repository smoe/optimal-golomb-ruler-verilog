/*
 * Copyright 2015 Forest Crossman
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

`include "cores/osdvu/uart.v"
`include "definitions.v"


module top(
	input  wire iCE_CLK,
	input  wire RS232_Rx_TTL,
	output wire RS232_Tx_TTL,
	output wire LED0,
	output wire LED1,
	output wire LED2,
	output wire LED3,
	output wire LED4
);

    reg reset = 0;
    reg transmit;
    reg [7:0] tx_byte;
    wire received;
    wire [7:0] rx_byte;
    wire is_receiving;
    wire is_transmitting;
    wire recv_error;

    reg ledval0, ledval1, ledval2, ledval3, ledval4;
    assign {LED3, LED2, LED1, LED0} = {ledval3,ledval2,ledval1,ledval0};

    assign LED4 = recv_error | is_transmitting;
    //assign {LED3, LED2, LED1, LED0} = rx_byte[7:4];
    //assign {LED3, LED2, LED1, LED0} = rx_byte[3:0];



    uart #(
        .baud_rate(9600),                 // The baud rate in kilobits/s
        .sys_clk_freq(12000000)           // The master clock frequency
    ) uart0 (
        .clk(iCE_CLK),                    // The master clock for this module
        .rst(reset),                      // Synchronous reset
        .rx(RS232_Rx_TTL),                // Incoming serial line
        .tx(RS232_Tx_TTL),                // Outgoing serial line
        .transmit(transmit),              // Signal to transmit
        .tx_byte(tx_byte),                // Byte to transmit
        .received(received),              // Indicated that a byte has been received
        .rx_byte(rx_byte),                // Byte received
        .is_receiving(is_receiving),      // Low when receive line is idle
        .is_transmitting(is_transmitting),// Low when transmit line is idle
        .recv_error(recv_error)           // Indicates error in receiving packet.
    );

    wire done;
    wire[((`NUMPOSITIONS+1)*`PositionValueBitMaxPlus1):1] marks;    // m[0] ... m[NUMPOSITIONS] is equal to marks
    wire[((`NUMPOSITIONS+1)*`PositionValueBitMaxPlus1):1] firstvalues;

    wire [5:0] numResultsObserved; // Number of OGR observed

`ifdef WithResultsArray
    wire [((`NUMPOSITIONS+1)*`PositionValueBitMaxPlus1*`NumResultsStored):1] results;
    wire [((`NUMPOSITIONS+1)*`PositionValueBitMaxPlus1):1] r[1:`NumResultsStored];
    assign {r[1],r[2],r[3],r[4],r[5]
			//,r[6],r[7],r[8],r[9],r[10] // should end at `NumResultsStored
            }=results;
    reg [`PositionValueBitMax:0] tmpM[0:`NUMPOSITIONS];
    reg [5:0] i; // for result presentation
`endif

    assembly ruler(
        .clock(iCE_CLK),
        .reset(reset),
        .firstvalues(firstvalues),
        .marks(marks),
`ifdef WithResultsArray  
        .results(results),
`endif
        .numResultsObserved(numResultsObserved),
        .done(done)
    );


    // input and output to be communicated
//    localparam inputlength=16+8*`FirstVariablePosition;
//    localparam outputlength=inputlength+16;
    localparam inputlength=48;
    localparam outputlength=64;

    reg [0:(inputlength-1)] vinput=0;  // input and output are reserved keywords
    reg [0:(outputlength-1)] voutput=0;


    reg [1:0] writecount=write_A;
    reg [1:0] calccount=calc_A;
    reg [1:0] readcount =read_A;

    localparam STATE_RECEIVING   = 2'd0;
    localparam STATE_CALCULATING = 2'd1;
    localparam STATE_SENDING     = 2'd2;
    //parameter STATE_SEND_COMPLETED = 2'b11;

    localparam read_A              = 2'd0;
    localparam read_A_transition_B = 2'd1;
    localparam read_B              = 2'd2;

    localparam calc_A              = 2'd0;
    localparam calc_B              = 2'd1;
    localparam calc_C              = 2'd2;

    localparam write_A             = 2'd0;
    localparam write_A_transit_B   = 2'd1;
    localparam write_B             = 2'd2;
    localparam write_done          = 2'd3;

    reg ready=1;

    reg [1:0] state=STATE_RECEIVING;

    reg [6:0] numBitsRead=0;
    reg [6:0] numBitsWritten=0;
    reg [6:0] k;

    initial begin
        numBitsWritten=0;
    end


    always @(posedge iCE_CLK) begin

        case (state) 

        STATE_RECEIVING: begin
           transmit <= 0;

           case (readcount)
            
              read_A:  begin
                  ledval0 <= 1;
                  ledval1 <= 0;
                  ledval2 <= 0;
                  ledval3 <= 0;
                  ledval4 <= 0;
                  if(received) begin
                      vinput[0+:8]<=rx_byte;
                      readcount <= read_A_transition_B;
                      numBitsRead <= numBitsRead+8;
                   end else begin
                      numBitsRead <= 0;
                  end
              end

              read_A_transition_B:  begin
                  ledval0 <= 0;
                  // ledval1 <= 1;
                  if (numBitsRead+8>inputlength) begin
                      state<=STATE_CALCULATING;
                  end else begin
                      if(~received) begin
                          readcount <= read_B;
                      end
                  end
              end

              read_B: begin
                  //ledval2 <= 1;
                  if(received) begin
                      vinput[numBitsRead+:8]<=rx_byte;
                      readcount <= read_A_transition_B;
                      numBitsRead <= numBitsRead+8;
                  end
              end

              default: begin
                  // should not be reached
                  state<=STATE_CALCULATING;
                  calccount<=calc_A;
              end
           endcase
        end

        STATE_CALCULATING: begin
           ledval1 <= 1;
           case (calccount)

           calc_A: begin
                       voutput[0+:16]  <= vinput[0+:16]; // maxdistance allowed
                       //voutput[16+:16] <= 16'd0; // minimal distance found 
                       voutput[16+:16] <= numResultsObserved; // The number of GRs with that prefix
/*
                       for(k=0; 32+k*8 < outputlength; k=k+1) begin
                          //firstvalues[((`NUMPOSITIONS+1-k)*`PositionValueBitMaxPlus1)-:`PositionValueBitMaxPlus1];
                          //output[((k*8)+32) +: 8] <= vinput[((k*8)+32-16) +: 8]; // number of fixed positions
                       end
*/
                       calccount <= calc_B;
                   end

           calc_B: begin
                       if (done) begin
                          voutput[0+:16]  <= vinput[0+:16]; // maxdistance allowed
                          state          <= STATE_SENDING;
                          writecount     <= write_A;
                          numBitsWritten <= 0;
                          calccount      <= calc_A;
                       end
                   end
           endcase
        end

        STATE_SENDING: begin

            case (writecount)

            write_A: begin
                ledval2 <= 1;
                ledval1 <= 1;
                if (~ is_transmitting) begin
                    writecount      <= write_A_transit_B;
                    tx_byte         <= voutput[0+:8];
                    transmit        <= 1;
                    numBitsWritten  <= numBitsWritten+8;
                    state           <= STATE_SENDING;
                end else begin
                    numBitsWritten  <= 0;
                end
            end

            write_A_transit_B: begin
                ledval3 <= 1;
                ledval2 <= 0;
                ledval1 <= 0;
                if (numBitsWritten+8>outputlength) begin
                    writecount      <= write_done;
                end else begin
                    if ( is_transmitting) begin
                        writecount  <= write_B;
                        transmit    <= 0;
                    end
                end
            end

            write_B: begin
                ledval3 <= 1;
                ledval2 <= 1;
                ledval1 <= 0;
                if (~ is_transmitting) begin
                    writecount      <= write_A_transit_B;
                    tx_byte         <= voutput[numBitsWritten+:8];
                    transmit        <= 1;
                    numBitsWritten  <= numBitsWritten+8;
                    state           <= STATE_SENDING;
                end
            end

            write_done: begin
                ledval3 <= 1;
                ledval2 <= 0;
                ledval1 <= 1;
                transmit <= 0;
                if (~ is_transmitting) begin
                    writecount <= write_A; 
                    state     <= STATE_RECEIVING;
                    readcount <= read_A;
                end

            end

            endcase

        end

        default: begin
            // should not be reached
            state     <= STATE_RECEIVING;
            readcount <= read_A;
        end

        endcase

    end


endmodule
