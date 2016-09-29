`timescale 1ns / 1ps

/**
    This module represents an individual mark. That mark needs to decide
    if it should decide to the right (increase its position value)
    or better still evaluate the positions of marks downstream to it.

    The input 'enabled' specifies the single counter of the many that
    make up the ruler that may change its position, i.e. that is active.
    The parameter LEVEL determines that (invariant) rank this instance
    has on the ruler. It is set at generation time in the mark_assembly
    module.

    Communicated back are the mark that shall be 'nextEnabled' and the
    value that it should first test goes to 'nextStartValue'. The mutual
    distances observed so far are in 'distances' and the newly added
    distances are communicated back in 'pdHash'.

    The disassembly of the marks_in array is accredited to different
    flavours of verilog. Not all allow an array of bitarrays to be passed.
 */

`include "definitions.v"


module distance_check #(
   parameter [`PositionNumberBitMax:0] LEVEL=1
)(
    input clock,
    input reset,
    input wire [1:`MAXVALUE] distances,
    input wire [`PositionValueBitMax:0] limit, // in, minlength-optiruler found, val stays below
    input wire [((`NUMPOSITIONS+1)*(`PositionValueBitMax+1)):1] marks_in,
    input wire [`PositionValueBitMax:0] val,
    input wire startCompute,
   output reg [1:`MAXVALUE] pdHash,  // out
   output reg resultsReady,
   output reg good);

wire [`PositionValueBitMax:0] m[0:`NUMPOSITIONS]; // m[0]==0
assign {m[0],m[1],m[2],m[3],m[4],m[5]}=marks_in; // extend to include m[NUMPOSITIONS]


localparam state_idle        =3'd0;
localparam state_startCompute=3'd1;
localparam state_done        =3'd2;

reg [2:0] state=0;

reg ret=1;
reg [`PositionValueBitMax:0] i=0;
reg [`PositionValueBitMax:0] d;
reg carry;

always @(posedge clock) begin

   if (reset) begin

      pdHash <= 0;
      resultsReady <= 1;
      good <= 1;

   end else begin


      case (state) 

      state_idle:   begin
                 ret<=1;
                 if (startCompute) begin
                    i<=0;
                    state<=state_startCompute;
                    resultsReady<=0;
                 end else begin
                    resultsReady<=1;
                 end
              end

      state_startCompute: begin
                if (i>=LEVEL) begin
                   state<=state_done;
                end else if (!ret) begin
                   // should not happen
                   state<=state_done;
                end else begin
                   d = val - m[i]; // val itself is tested for 0==i
                   if (0 != distances[d]) begin
                      $display("I(%0d): distance clash at %0d with earlier distances (i=%0d,val=%0d,m[i]=%0d)",LEVEL,d,i,val,m[i]);
                      ret <= 1'b0;
                   end else if (0 != pdHash[d]) begin
                      $display("W(%0d): distance clash at %0d with current distances - how can this be (i=%0d,val=%0d,m[i]=%0d)",LEVEL,d,i,val,m[i]);
                      ret <= 1'b0;
                   end else begin
                      $display("I(%0d): distance set (d=%0d,i=%0d,val=%0d,m[i]=%0d)",LEVEL,d,i,val,m[i]);
                      pdHash[d] <= 1'b1; // needs to be blocked
                   end
                   {carry,i} <= i+1;
                end
             end

       state_done: begin

                if (ret) begin
                end else begin
                   pdHash <= 0;
                end
                good <= ret;
                resultsReady<=1;

                state <= state_idle;
             end

       endcase
   end
	
end

endmodule

