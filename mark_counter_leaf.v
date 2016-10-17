`timescale 1ns / 1ps

/**
    This module represents an individual mark. It is a special one
    in that it is the last mark on the ruler. Nothing is following.
    If this mark is active and its value below the minimum then a
    new golomb ruler is found.

    The input is analogous to the regular mark_counter.

    The input 'enabled' specifies the single counter of the many that
    make up the ruler that may change its position, i.e. that is active.
    The parameter LEVEL determines that (invariant) rank this instance
    has on the ruler.

    The output 'nextEnabled' indicates the opinion of the current
    enabled mark what mark should be allowed to perform the next
    computation.

    The output in particular has the success flag to indicate when a
    valid golomb ruler was found. If it is optimal we will only know
    at the very end.

 */

`include "definitions.v"

module mark_counter_leaf #(
   parameter [`PositionNumberBitMax:0] LEVEL=`NUMPOSITIONS
) (
   input wire       clock,
   input wire       reset,
   output reg       ready,
   input wire       requestForMarkToTakeControl,
   //input wire [`PositionValueBitMax:0] resetvalue,
   input wire [`PositionValueBitMax:0] startvalue,
   input wire [`PositionValueBitMax:0] limit, // val needs to stay below this, may shrink over time
   input wire [`PositionNumberBitMax:0] enabled,
   output reg [`PositionValueBitMax:0] val, // position of mark
   output reg [`PositionNumberBitMax:0] nextEnabled, // out
                         // no nextStartValue to return
   input wire [1:`MAXVALUE] distances,

   input wire [((`NUMPOSITIONS+1)*(`PositionValueBitMax+1)):1] marks_in,
   output reg success // out
);

wire good;  // indicator if a Golomb Ruler was found
reg [`PositionNumberBitMax:0] i; // iterator checking distances
reg [`PositionValueBitMax:0] d; // temporary variable holding distance

// interim distances in leaf, not sent back as output, only the good flag is required
wire [1:`MAXVALUE] pdHash=0; // not needed

reg distance_check_start_compute = 0;
wire distance_check_results_ready;

distance_check #(.LEVEL(LEVEL)) dc (
	.clock(clock),
        .reset(reset),
        .distances(distances),
        .pdHash(pdHash),
		  .limit(limit),
        .marks_in(marks_in),
        .val(val),
        .startCompute(distance_check_start_compute),
        .resultsReady(distance_check_results_ready),
        .good(good)
);


localparam state_idle = 0;
localparam state_updatePositions = 1;
localparam state_earlyValueCheck = 2;
localparam state_waitForDistanceCheck = 3;
localparam state_backtrack = 4;
localparam state_done = 6;
reg [2:0] state = state_idle;


reg carry;


always @(posedge clock) begin

   if (reset) begin

      $display("I(%0d == LEAF): Reset of mark counter (leaf), val=%0d, resetvalue=%0d, startvalue=%0d",
		      LEVEL,val,`ResetPosition,startvalue);
      val<=`ResetPosition;
      success <= 0;
      nextEnabled <= enabled; // calling routine knows what is right
      ready <= 1;
      state <= state_idle;
		
   end else begin

      case (state)

         state_idle: begin

            if (enabled == LEVEL && requestForMarkToTakeControl) begin
               $display("I(%0d == LEAF): Enabled mark counter, val=%0d, startvalue=%0d",LEVEL,val,startvalue);
               ready <= 1'b0;
   	       success <= 0; // new value to be assigned to m, yet untested
               state <= state_updatePositions;
            end else begin
               ready <= 1'b1;
            end
         
         end

         state_updatePositions: begin

            $display("I(%0d == LEAF): distances:  %b",LEVEL,distances);
            // setting value
            if (`ResetPosition == val) begin
               val <= startvalue;
               $display("I(%0d == LEAF): val was at ResetPosition, now occupying startvalue==%0d",LEVEL,startvalue);
            end else begin
               {carry,val} <= val+3'd1;
               $display("I(%0d == LEAF): regular interim val, now increased val by one to %0d",LEVEL,val);
            end
         
            $display("I(%0d == LEAF): Updated mark counter, val=%0d, startvalue=%0d",
                   LEVEL,val,startvalue);

            state <= state_earlyValueCheck;

         end

         state_earlyValueCheck: begin
            if (val <= limit) begin // <= since leaf
               distance_check_start_compute <=  1;
               if (~distance_check_results_ready) begin
                  state <= state_waitForDistanceCheck;
               end
            end else begin
               state <= state_backtrack;
            end
         end

         state_waitForDistanceCheck: begin
            distance_check_start_compute <=  0;
            if (distance_check_results_ready) begin
               success <= good;
	       if (good) begin
                  state <= state_done;
                  //state <= state_backtrack;
               end else begin
                  // we skip this value and try the next because of distance clash
                  $display("I(%0d): distance clash, val==%0d, nextEnabled=%0d", LEVEL, val, nextEnabled);
                  // FIXME we should check that pdHash is indeed 0
                  nextEnabled <= LEVEL;
                  state <= state_done;
               end
            end  
         end

         state_backtrack: begin
            // the module "above" needs to address this
            $display("I(%0d): level-up, val==%0d -> 0",LEVEL, val);
            if (0 == nextEnabled) begin
              $display("I: LEVEL 0 is next enabled. This better be the end.");
              //$finish();
            end
            {carry,nextEnabled} <= enabled-1'b1;
            val <= `ResetPosition;
            //$display(pdHash); // FIXME a test that pdHash is 0 here may be good
            state <= state_done;
         end

         state_done: begin
            ready <= 1;
            state <= state_idle;
         end

      endcase

   end
	
end

endmodule
