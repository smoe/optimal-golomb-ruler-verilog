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
//`include "definitions.v"


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

	wire reset = 0;
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

    // input and output to be communicated
//    localparam inputlength=16+8*`FirstVariablePosition;
//    localparam outputlength=inputlength+16;
    localparam inputlength=48;
    localparam outputlength=64;

    reg [0:(inputlength-1)] vinput=0;  // input and output are reserved keywords
    reg [0:(outputlength-1)] voutput=0;


    reg [2:0] writecount=write_A;
    reg [2:0] readcount =read_A;

    parameter STATE_RECEIVING   = 2'd0;
    parameter STATE_CALCULATING = 2'd1;
    parameter STATE_SENDING     = 2'd2;
    //parameter STATE_SEND_COMPLETED = 2'b11;

    parameter read_A              = 3'd0;
    parameter read_A_transition_B = 3'd1;
    parameter read_B              = 3'd2;

    parameter write_A             = 3'd0;
    parameter write_A_transit_B   = 3'd1;
    parameter write_B             = 3'd2;
    parameter write_done          = 3'd5;

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
              end
           endcase
        end

        STATE_CALCULATING: begin
           ledval1 <= 1;
           voutput[0+:16]  <= vinput[0+:16]; // maxdistance allowed
           voutput[16+:16] <= 16'd0; // minimal distance found 
           for(k=32; k<outputlength; k=k+8) begin
              voutput[k+:8]  <= vinput[(k-16)+:8]; // number of fixed positions
           end
/*
           voutput[0+:8]  <= 8'd1; // number of fixed positions
           voutput[8+:8]  <= 8'd2; // number of fixed positions
           voutput[16+:8] <= 8'd3; // number of fixed positions
           voutput[24+:8] <= 8'd4; // number of fixed positions
           voutput[32+:8] <= 8'd5; // number of fixed positions
           voutput[40+:8] <= 8'd6; // number of fixed positions
*/
           state          <= STATE_SENDING;
           writecount     <= write_A;
           numBitsWritten <= 0;
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
