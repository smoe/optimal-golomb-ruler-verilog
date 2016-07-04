`default_nettype none

/**

 This is a special version of the mark_counter module that is the very first.

 */

module mark_counter_head(
   input  wire       clock,
   input  wire       reset,
   output wire       ready, // always 1
   output wire [8:0] val, // value currently owned
   output wire [8:0] nextStartValue // set value for next mark
);

parameter /*[8:0]*/ LEVEL=0;
parameter /*[8:0]*/ MAXVALUE=500; // effective operationally is 'minlength'
parameter /*[8:0]*/ NUMPOSITIONS=5;

//input wire [0:MAXVALUE] distances;
//output reg [0:MAXVALUE] pdHash;
reg [8:0] m[0:NUMPOSITIONS]; // m[0]==0

reg carry;

/*
always @(negedge reset or val or marks_in) begin
end
*/

assign val = 0;
assign nextStartValue = 1'b1;
assign ready=1; // no need to wait for this ruler at all

always @(*) begin

   if (reset) begin

      $display("I(%0d): Reset of mark counter, val=%0d",LEVEL,val);
/*
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
*/
   end else begin
      // $display("I(%0d): Situation: clock=%0d, reset=%0d",LEVEL,clock,reset);
   end
end

endmodule
