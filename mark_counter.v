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
	input wire       globalready,
   input wire [`PositionValueBitMax:0] resetvalue,
   input wire [`PositionValueBitMax:0] startvalue,
   input wire [`PositionValueBitMax:0] limit, // in, minlength-optiruler found, val stays below
   input wire [`PositionNumberBitMax:0] enabled,
   output reg [`PositionValueBitMax:0] val, // current position, fed to m[] of _assembly
   output reg [`PositionNumberBitMax:0] nextEnabled, // out
   output reg [`PositionValueBitMax:0] nextStartValue, // out
   input wire [1:`MAXVALUE] distances,
   output reg [1:`MAXVALUE] pdHash,  // out
   input wire [((`NUMPOSITIONS+1)*(`PositionValueBitMax+1)):1] marks_in
);

reg good=0;
reg [`PositionNumberBitMax:0] i=0;
reg [`PositionValueBitMax:0] d=0;

wire [`PositionValueBitMax:0] m[0:`NUMPOSITIONS]; // m[0]==0
assign {m[0],m[1],m[2],m[3],m[4],m[5]}=marks_in; // extend to include m[NUMPOSITIONS]

reg carry, carry1;
reg test;

reg resetPerformedInMarkCounter=0;

always @(posedge clock or posedge reset) begin

   if (reset) begin

      $display("I(%0d): Reset of mark counter from val=%0d to resetvalue=%0d, startvalue would be %0d",
								LEVEL,val,resetvalue,startvalue);
      val <= resetvalue;
      nextStartValue <= resetvalue + 9'd1; 
      nextEnabled = enabled; // calling routine knows what is right
      
      pdHash=0;
      pdHash[val]=1'b1; // omnipresent comparison against mark 0

      if (val>0) begin
         for(i=1; i<LEVEL; i=i+1'b1) begin
            //d <= val-m[i]; // just to check
            pdHash[val-m[i]] <= 1'b1;
         end // for
      end // if val

      //distances=MAXVALUE'b0;
      good <= 1'b1;
      ready <= 1'b1;
      pdHash <= 0;
      resetPerformedInMarkCounter <= 1; // confirmed, can be removed

   end else begin

      if (ready && globalready && enabled==LEVEL) begin	

         ready<=1'b0;

         if (0 == LEVEL) begin
           $display("I: LEVEL 0 was enabled. This is the head node and should not happen. This better be the end. Please investigate.");
           $finish();
         end

         $display("I(%0d): Enabled mark counter, val=%0d, startvalue=%0d",LEVEL,val,startvalue);
         $display("I: distances@level%d:  %b",LEVEL,distances);
         // setting value
         if (0 == val) begin
            {val} <= startvalue;
				nextStartValue <= startvalue + 9'd1;
         end else begin
            {carry,val} <= val+9'd1;
				{carry1,nextStartValue} <= val + 9'd2; 
         end
         
         $display("I(%0d): Updated mark counter, val=%0d, startvalue=%0d, nextStartValue=%0d",
                   LEVEL,val,startvalue,nextStartValue);
		
         // checking if value is within constraint
         if (val < limit) begin // not <= since not leaf
			
            pdHash <= 0;
            good <= 1;
`ifndef avoidWOR
	   #1 // critical for the computation of distances if not using wor
`endif
            /* yosys has issue with good && ...*/
            for(i=0; good && i < LEVEL; i=i+1'b1) begin
               //if (good) begin
                  d = val - m[i];
                  if (0 != distances[d]) begin
                     $display("I(%0d): distance clash at %0d with earlier distances (i=%0d,val=%0d,m[i]=%0d)",LEVEL,d,i,val,m[i]);
                     good <= 1'b0;
                  end else if (0 != pdHash[d]) begin
                     $display("W(%0d): distance clash at %0d with current distances - how can this be (i=%0d,val=%0d,m[i]=%0d)",LEVEL,d,i,val,m[i]);
                     good <= 1'b0;
	          end else begin
                     $display("I(%0d): distance set (d=%0d,i=%0d,val=%0d,m[i]=%0d)",LEVEL,d,i,val,m[i]);
                     pdHash[d] <= 1'b1;
                  end
               //end // if good
            end
            
            #1
	    if (good) begin
               // we can continue with the level below
               {carry,nextEnabled} = LEVEL + 1'b1;
               $display("I(%0d): good! interim, val==%0d, nextEnabled=%0d", LEVEL, val, nextEnabled);
            end else begin
               // we skip this value and try the next because of distance clash
               {nextEnabled} = LEVEL;
               $display("I(%0d): distance clash, val==%0d, nextEnabled=%0d", LEVEL, val, nextEnabled);
               pdHash <= 0; // when trying level again, this needs a new good chance
            end

         end else begin
            // the module "above" needs to address this
            $display("I(%0d): level-up, val==%0d -> 0",LEVEL, val);
            if (0 == nextEnabled) begin
              $display("I: LEVEL 0 is next enabled. This better be the end.");
              $finish();
            end
            val <= 1'b0;
            nextStartValue <= 1'b0;
            {carry,nextEnabled} = enabled-1'b1;
            pdHash<=0; // when trying upper level, this should not be affected by past distances of later marks
            //$display(pdHash);
         end

         $display("I(%0d): val=%0d, nextEnabled == %0d",LEVEL,val,nextEnabled);

         ready <= 1;

      end else begin
         $display("I(%0d): clock=%0d, enabled=%0d, ready=%0d, globalready=%0d",LEVEL,clock,enabled,ready,globalready);
      end

	
   end // reset
	
end // always

endmodule
