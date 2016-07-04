`default_nettype none

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

    The output in particular has the success flag.

 */

module mark_counter_leaf #(
   parameter /*[8:0]*/ LEVEL=1,
   parameter /*[8:0]*/ MAXVALUE=500,
   parameter /*[8:0]*/ NUMPOSITIONS=5
) (
   input wire       clock,
   input wire       reset,
   output reg       ready,
   input wire [8:0] resetvalue,

   input wire [8:0] startvalue,
   input wire [8:0] limit, // val needs to stay below this, may shrink over time
   input wire [6:0] enabled,
   output reg [8:0] val, // position of mark
   output reg [6:0] nextEnabled, // out
                         // no nextStartValue to return
   input wire [0:MAXVALUE] distances,

   input wire [((NUMPOSITIONS+1)*9):1] marks_in,
   output reg success // out
);

// parameter /*[8:0]*/ LEVEL=1;
// parameter /*[8:0]*/ MAXVALUE=500;
// parameter /*[8:0]*/ NUMPOSITIONS=5;

reg good;
reg [6:0] i;
reg [8:0] d;

// interim distances in leaf, not sent back as output
reg [0:MAXVALUE] pdHash;

//output
//reg [(NUMPOSITIONS*9):1] marks_out;
reg [8:0] m[0:NUMPOSITIONS];

reg carry;


always @(*) begin

   if (reset) begin

      $display("I(%0d): Reset of mark counter (leaf), val=%0d, startvalue=%0d",LEVEL,val, startvalue);
      val=resetvalue;
      good=0;
      success=0;
      nextEnabled=enabled; // calling routine knows what is right
      ready <= 1;
		
   end else if (1==clock) begin

      ready <= 0;

      if (enabled==LEVEL) begin

         success=0; // new value to be assigned to m, yet untested

         {m[0],m[1],m[2],m[3],m[4],m[5]}=marks_in; // extend to include m[NUMPOSITIONS]
			
         //$display("I(%0d): Enabled mark counter (leaf), val=%0d, startvalue=%0d",LEVEL,val,startvalue);
         // setting value
         if (0==val) begin
            val = startvalue;
         end else begin
            {carry,val} = val+1'b1;
         end
			
			
         // checking if value is within constraint
         if (val<=limit) begin
				
            pdHash=0;
            good=1;
            /**/
            for(i=1; good && i<LEVEL; i=i+1'b1) begin
               d = val - m[i];
               if (0 != distances[d]) begin
	          //$display("I(%0d): distance clash with earlier distances at %0d (i=%0d,val=%0d,m[i]=%0d)",LEVEL,d,i,val,m[i]);
                  good=1'b0;
               end else	if (0 != pdHash[d]) begin
                  //$display("W(%0d): distance clash at %0d with current distances - how can this be (i=%0d,val=%0d,m[i]=%0d)",LEVEL,d,i,val,m[i]);
                  good=1'b0;
               end else begin
                  //$display("I(%0d): distance set (d=%0d,i=%0d,val=%0d,m[i]=%0d)",LEVEL,d,i,val,m[i]);
                  pdHash[d] = 1'b1; // not required for leaf
               end
            end
            /**/

            if (good) begin
               // we can continue
               //$display("I(%0d): ** action, val==%0d (leaf)",LEVEL, val);
            end else begin
               // no action since conflicts with distances
               //$display("I(%0d): NO action, val==%0d (leaf)",LEVEL, val);
            end
            success=good; // here see a single change of 'return value'
				
            nextEnabled = LEVEL; // we stay at this module if tests fail or not

         end else begin
            nextEnabled = LEVEL-1'b1;
            //$display("I(%0d): action, val==%0d (leaf), level up to %d",LEVEL, val, nextEnabled);
            val=0;
         end

         //$display("I(%0d): val=%0d, nextEnabled == %0d (leaf)",LEVEL,val,nextEnabled);
			
         m[LEVEL]=val;
		
      end
		
		ready <= 1;
		
   end
	
end

endmodule
