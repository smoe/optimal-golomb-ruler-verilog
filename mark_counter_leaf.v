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
   input wire       globalready,
   input wire [`PositionValueBitMax:0] resetvalue,

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

reg good;
reg [`PositionNumberBitMax:0] i; // iterator checking distances
reg [`PositionValueBitMax:0] d; // temporary variable holding distance

// interim distances in leaf, not sent back as output
reg [1:`MAXVALUE] pdHash=0;

wire [`PositionValueBitMax:0] m[0:`NUMPOSITIONS];
assign {m[0],m[1],m[2],m[3],m[4],m[5]}=marks_in; // extend to include m[NUMPOSITIONS]

reg carry;


always @(posedge clock or posedge reset) begin

   if (reset) begin

      $display("I(%0d): Reset of mark counter (leaf), val=%0d, resetvalue=%0d, startvalue=%0d",
		      LEVEL,val,resetvalue,startvalue);
      val<=resetvalue;
      good = 0;
      success <= 0;
      nextEnabled=enabled; // calling routine knows what is right
      ready <= 1;
		pdHash <= 0;
		
   end else begin

      if (ready && globalready && enabled==LEVEL) begin

         ready <= 0;
   	   success <= 0; // new value to be assigned to m, yet untested
			
         $display("I(%0d): Enabled mark counter (leaf), val=%0d, startvalue=%0d",LEVEL,val,startvalue);
         // setting value
         if (0==val) begin
            val <= startvalue;
         end else begin
            {carry,val} <= val+1'b1;
         end
			
			
         // checking if value is within constraint
         if (val<=limit) begin
				
            pdHash <= 0;
            good = 1;

            for(i=1; good && i<LEVEL; i=i+1'b1) begin
               d = val - m[i];
               if (0 != distances[d]) begin
	          //$display("I(%0d): distance clash with earlier distances at %0d (i=%0d,val=%0d,m[i]=%0d)",LEVEL,d,i,val,m[i]);
                  good = 1'b0;
               end else	if (0 != pdHash[d]) begin
                  //$display("W(%0d): distance clash at %0d with current distances - how can this be (i=%0d,val=%0d,m[i]=%0d)",LEVEL,d,i,val,m[i]);
                  good = 1'b0;
               end else begin
                  //$display("I(%0d): distance set (d=%0d,i=%0d,val=%0d,m[i]=%0d)",LEVEL,d,i,val,m[i]);
                  pdHash[d] <= 1'b1; // not required for leaf
               end
            end
            /**/

            /*
	    // Optional display of internal state
            if (good) begin
               // we can continue
               $display("I(%0d): ** action, val==%0d (leaf)",LEVEL, val);
            end else begin
               // no action since conflicts with distances
               $display("I(%0d): NO action, val==%0d (leaf)",LEVEL, val);
            end
	    */
            success <= good; // here see a single change of 'return value'
				
            nextEnabled = LEVEL; // we stay at this module if tests fail or not

         end else begin
            // we have reached beyond the limit and thus have to find better
            // values at th earlier marks
            nextEnabled = LEVEL-1'b1;
            //$display("I(%0d): action, val==%0d (leaf), level up to %d",LEVEL, val, nextEnabled);
            val<=0;
         end

         //$display("I(%0d): val=%0d, nextEnabled == %0d (leaf)",LEVEL,val,nextEnabled);
			
         ready <= 1;

      end
		
   end
	
end

endmodule
