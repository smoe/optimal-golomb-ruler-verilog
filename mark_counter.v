`default_nettype none

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

module mark_counter #(
   parameter /*[8:0]*/ LEVEL=1,
   parameter /*[8:0]*/ MAXVALUE=500, // effective operationally is 'minlength'
   parameter /*[8:0]*/ NUMPOSITIONS=5
)(
   input wire       clock,
   input wire       reset,
   output reg       ready,
   input wire [8:0] resetvalue,
   input wire [8:0] startvalue,
   input wire [8:0] limit, // in, minlength-optiruler found, val stays below
   input wire [6:0] enabled,
   output reg [8:0] val, // current position, fed to m[] of _assembly
   output reg [6:0] nextEnabled, // out
   output reg [8:0] nextStartValue, // out
   input wire [0:MAXVALUE] distances,
   output reg [0:MAXVALUE] pdHash,  // out
   input wire [((NUMPOSITIONS+1)*9):1] marks_in
);

reg good;
reg [6:0] i;
reg [8:0] d;

reg [8:0] m[0:NUMPOSITIONS]; // m[0]==0

reg carry;

always @(posedge clock) begin

   if (reset) begin

      $display("I(%0d): Reset of mark counter, val=%0d, startvalue=%0d",LEVEL,val,startvalue);
      val = resetvalue;
      {nextEnabled} = enabled; // calling routine knows what is right
      {carry,nextStartValue} = startvalue+1'b1;

      ready<=0;

      if (1'bx !== m[LEVEL]) begin

         good=1;
         pdHash=0; // ISE error: is connected to following multiple drivers
         if (val>0) begin
            {m[0],m[1],m[2],m[3],m[4],m[5]}=marks_in; // extend to include m[NUMPOSITIONS]
            $display("I(%0d): Initialising distances, m: %0d-%0d-%0d-%0d-%0d-%0d",LEVEL,m[0],m[1],m[2],m[3],m[4],m[5]);
            for(i=0; good && i<LEVEL; i=i+1'b1) begin
               d = val - m[i];
               if (0 != distances[d]) begin
                  $display("I(%0d): distance clash at %0d with earlier distances (i=%0d,val=%0d,m[i]=%0d)",LEVEL,d,i,val,m[i]);
                  good=1'b0;
               end else if (0 != pdHash[d]) begin
                  $display("W(%0d): distance clash at %0d with current distances - how can this be (i=%0d,val=%0d,m[i]=%0d)",LEVEL,d,i,val,m[i]);
                  good=1'b0;
               end else begin
                  $display("I(%0d): distance set (d=%0d,i=%0d,val=%0d,m[i]=%0d)",LEVEL,d,i,val,m[i]);
                  pdHash[d] = 1'b1;
               end // if
            end // for
         end // if val
      end

      ready<=1;

   end else begin

      ready<=0;

      if (enabled==LEVEL) begin	

         if (0 == LEVEL) begin
           $display("I: LEVEL 0 was enabled. This better be the end.");
           $finish();
         end

         {m[0],m[1],m[2],m[3],m[4],m[5]}=marks_in; // extend to include m[NUMPOSITIONS]

         //$display("I(%0d): Enabled mark counter, val=%0d, startvalue=%0d",LEVEL,val, startvalue);
         // setting value
         if (0==val) begin
            {val} = startvalue;
         end else begin
            {carry,val} = val+1'b1;
         end
         m[LEVEL]=val;
		
         // checking if value is within constraint
         if (val <= limit) begin // not <= since not leaf
			
            pdHash=0;
            good=1;
            /**/
            for(i=0; good && i<LEVEL; i=i+1'b1) begin
               d = val - m[i];
               if (0 != distances[d]) begin
                  //$display("I(%0d): distance clash at %0d with earlier distances (i=%0d,val=%0d,m[i]=%0d)",LEVEL,d,i,val,m[i]);
                  good=1'b0;
               end else if (0 != pdHash[d]) begin
                  //$display("W(%0d): distance clash at %0d with current distances - how can this be (i=%0d,val=%0d,m[i]=%0d)",LEVEL,d,i,val,m[i]);
                  good=1'b0;
	       end else begin
                  //$display("I(%0d): distance set (d=%0d,i=%0d,val=%0d,m[i]=%0d)",LEVEL,d,i,val,m[i]);
                  pdHash[d] = 1'b1;
               end
            end
            /**/

            {carry,nextStartValue} = val + 1'b1; // val was already increased
            if (good) begin
               // we can continue with the level below
               {carry,nextEnabled}    = LEVEL + 1'b1;
               //$display("I(%0d): interim, val==%0d, nextEnabled=%0d",LEVEL, val, nextEnabled);
            end else begin
               // we skip this value and try the next because of distance clash
               {nextEnabled}    = LEVEL;
               //$display("I(%0d): distance clash, val==%0d, nextEnabled=%0d",LEVEL, val, nextEnabled);
               pdHash=0; // when trying level again, this needs a new good chance
            end

         end else begin
            // the module "above" needs to address this
            //$display("I(%0d): level-up, val==%0d -> 0",LEVEL, val);
            if (0 == nextEnabled) begin
              $display("I: LEVEL 0 is next enabled. This better be the end.");
              $finish();
            end
            {val}=0;
            {carry,nextEnabled} = enabled-1'b1;
            pdHash=0; // when trying upper level, this should not be affected by past distances of later marks
            //$display(pdHash);
         end

         //$display("I(%0d): val=%0d, nextEnabled == %0d",LEVEL,val,nextEnabled);

         m[LEVEL]=val;
      end else begin
         //$display("I(%0d): clock=%0d, enabled=%0d",LEVEL,clock,enabled);
      end

      ready <= 1;
	
   end
	
end

endmodule
