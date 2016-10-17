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

module mark_counter #(
   parameter [`PositionNumberBitMax:0] LEVEL=1
)(
   input wire       clock,
   input wire       reset,
   output reg       ready,
   input wire       requestForMarkToTakeControl,
//   input wire [`PositionValueBitMax:0] resetvalue,
   input wire [`PositionValueBitMax:0] startvalue,
   input wire [`PositionValueBitMax:0] limit, // in, minlength-optiruler found, val stays below
   input wire [`PositionNumberBitMax:0] enabled,
   output reg [`PositionValueBitMax:0] val, // current position, fed to m[] of _assembly
   output reg [`PositionNumberBitMax:0] nextEnabled, // out
   output reg [`PositionValueBitMax:0] nextStartValue, // out
   input wire [1:`MAXVALUE] distances,
   output wire [1:`MAXVALUE] pdHash,  // out
   input wire [((`NUMPOSITIONS+1)*(`PositionValueBitMax+1)):1] marks_in
);

wire good;
reg [`PositionNumberBitMax:0] i=0;
reg [`PositionValueBitMax:0] d=0;

reg resetPerformedInMarkCounter=0;

reg [`PositionValueBitMax:0] prevEnabled=-1;


reg distance_check_start_compute = 0;
wire distance_check_results_ready;
reg distance_check_cleanup = 0;

distance_check #(.LEVEL(LEVEL)) dc (
	.clock(clock),
        .reset(reset),
        .cleanup(distance_check_cleanup),
        .distances(distances),
        .pdHash(pdHash),
        .marks_in(marks_in),
        .limit(limit),
        .val(val),
        .startCompute(distance_check_start_compute),
        .resultsReady(distance_check_results_ready),
        .good(good)
);


//assign nextStartValue=val+1;

localparam state_idle = 0;
localparam state_updatePositions = 1;
localparam state_earlyValueCheck = 2;
localparam state_waitForDistanceCheck = 3;
localparam state_backtrack = 4;
localparam state_done = 6;
reg [2:0] state = state_idle;

reg carry;
reg carry1;

always @(posedge clock) begin

   if (reset) begin

      $display("I(%0d): Reset of mark counter from val=%0d to resetvalue=%0d, startvalue would be %0d",
								LEVEL,val,`ResetPosition,startvalue);
      //nextStartValue = resetvalue; 
      if (LEVEL<`FirstVariablePosition) begin
         val <= startvalue;
         {carry,nextStartValue} <= startvalue+1;
         distance_check_start_compute <= 1;
      end else begin
         val <= `ResetPosition;
         {carry,nextStartValue} <= `ResetPosition+1;
         distance_check_start_compute <= 0;
      end
      nextEnabled <= enabled; // calling routine knows what is right
      
      //distances=MAXVALUE'b0;
      ready <= 1;
      resetPerformedInMarkCounter <= 1; // confirmed, can be removed

      state <= state_idle;

   end else if (LEVEL != enabled) begin
      if (state_idle != state) begin
         $display("I(%0d): was caught to be deactivated while not in idle: state=%0d",LEVEL,state);
      end
      distance_check_start_compute <= 0;
      state <= state_idle;
      ready <= 1;
      if (LEVEL<enabled) begin
          nextEnabled <= LEVEL + 1'b1; // FIXME: should not be required
          nextStartValue <= val + 1'b1; // FIXME: should not be required
      end
   end else if (LEVEL == enabled) begin

      case (state)

         state_idle: begin

            if (requestForMarkToTakeControl) begin
               $display("I(%0d): Enabled mark counter, val=%0d, startvalue=%0d",LEVEL,val,startvalue);
               ready <= 1'b0;
               state <= state_updatePositions;
            end else begin
               $display("I(%0d): Enabled mark counter, nothing do, waiting for control, val=%0d, startvalue=%0d",LEVEL,val,startvalue);
               ready <= 1'b1;
            end
         
         end

         state_updatePositions: begin

            $display("I(%0d): distances:  %b",LEVEL,distances);
            // setting value
            if (`ResetPosition == val) begin
               val <= startvalue;
               nextStartValue <= startvalue + 3'd1;
               $display("I(%0d): val was at ResetPosition, now occupying startvalue==%0d",LEVEL,startvalue);
            end else begin
               {carry1,nextStartValue} <= val + 3'd2; 
               {carry,val} <= val+3'd1;
               $display("I(%0d): regular interim val, now increased val by one to %0d",LEVEL,val);
            end
            $display("I(%0d): nextStartValue set to %0d",LEVEL,nextStartValue);
         
            $display("I(%0d): Updated mark counter, val=%0d, startvalue=%0d, nextStartValue=%0d",
                   LEVEL,val,startvalue,nextStartValue);

            state <= state_earlyValueCheck;

         end

         state_earlyValueCheck: begin
            if (val < limit) begin // not <= since not leaf
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
	       if (good) begin
                  // we can continue with the level below
                  {carry,nextEnabled} <= LEVEL + 1'b1;
                  distance_check_cleanup <= 0; // not required, just for clarity, we still need this pdHash value
                  $display("I(%0d): good! interim, val==%0d, nextEnabled=%0d", LEVEL, val, nextEnabled);
               end else begin
                  // we skip this value and try the next because of distance clash
                  {nextEnabled} <= LEVEL;
                  $display("I(%0d): distance clash, val==%0d, nextEnabled=%0d", LEVEL, val, nextEnabled);
                  distance_check_cleanup <= 1;
                  // FIXME we should check that pdHash is indeed 0
               end
               state <= state_done;
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
            nextStartValue <= `ResetPosition;
            distance_check_cleanup <= 1;
            distance_check_start_compute <= 1;
            //$display(pdHash); // FIXME a test that pdHash is 0 here may be good
            state <= state_done;
         end

         state_done: begin
            ready <= 1;
            distance_check_cleanup <= 0;
            distance_check_start_compute <= 0;
            if (distance_check_results_ready) begin
                state <= state_idle;
            end else begin
                $display("I(%0d): waiting for distance check to be completed in state_done");
            end
         end
			
      endcase

   end
	
end // always

endmodule
