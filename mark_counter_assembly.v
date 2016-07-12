`default_nettype none
//`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:06:05 09/22/2012 
// Design Name: 
// Module Name:    mark_counter_assembly
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 	
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
/**

 This module constructs the complete ruler from a series of marks, here implemented by the name mark_counter. There is a special mark for the start (mark_counter_head), the middle marks (mark_counter_center) and the tail (mark_counter_leaf). The number of marks on the rules is determined by an externally set parameter NUMPOSITIONS. The maximal length of the rules is constrained by MAXVALUE. The basic idea of the algorithm is that whenever any of the marks attempts to position itself at a position higher than that value, or (and this is already an optimisation), if it is forseeable that the remainig number of positions need more ruler-estate than there is available, then a new position of an earlier marker needs to be found. That "remaining space" information is indicated by the 'optiRuler' array, i.e. the best results yet known.

 Marks are not equal also for the number range they are allowed to investigate as some marks may be preset by some external magic. The FPGA then concentrates on finding the best solution for the remaining number of marks to be set. This allow for distributed computation of larger challenges, The leftmost positions up to position firstvariableposition-1 may already be preset, The first position to be touched by the whole process is provided externally from the calling machine, passed as "firstvariableposition".

The many numbers are no straightforward to pass between the verilog modules. They are best human-readable as an array of numbers but (verilog-flavours vary here) can only be passed between modules as a bit vector. The array "fv" is a human-interpretable way to access the values passed as the bitvector "firstvalues". It also eases the communication of the values to the individual representations of marks that each see on of those firstvalue elements as a start value.

The array 'm' holds the positions of the individual marks.

The variable 'enabled' identifies what mark number (not position but the nth mark) is allowed to change its position. That position starts at 1, which technically is not the 1st but the 2nd mark. The first mark is is always at position 0 and is also give the index 0.

The following may be the only trick in the whole FPGA golomb bits - it is easy to perform many comparisons in what appears to be a single operation. We know that distances are integers. And it is small integers. Instead of using a binary representation, the value is taken as a single 1 bit position in a bit vector that has MAXVALUE many bits. And since orders of distances does not matter for the distances check, and any optimal golomb ruler does not have any distance twice, all the distances observable by a mark added to the ruler can be placed in a single such MAXVALUE long bitstream.

To further help the comparison, the wire distances is created as the logical or of all the individual pairdistsHash entries. Any pairdistsHash position that should not be considered needs to be 0ed out. The 'distances' and the particular entry of the 'pairdistsHash' are passed to the individual mark counter modules to update the values and check for consequences.

The construction of ruler involves the instantiation of the mark counter head (the one remaining at position 0), many regular mark counters in the middle and finally as single mark counter leaf. The single active mark is indicate by the register value 'enabled'. Every mark returns the position of the mark that it thinks should be allowed to change its value next. The only opinion that counts is the one of the node that is currently enabled, as in 'enabled=next_enabled[enabled]'. Once the whole subtree was evaluated, the flag 'done' is set.
 
 */
//
//////////////////////////////////////////////////////////////////////////////////

module mark_counter_assembly #(
   parameter /*[8:0]*/ MAXVALUE=22,
   parameter /*[6:0]*/ NUMPOSITIONS=5,
   parameter /*[5:0]*/ NUMRESULTS=10
) (
   input  wire                          FXCLK, // clock from board
   input  wire                          RESET_IN, // reset from board
   input  wire [6:0]                    firstvariableposition,
   input  wire [((NUMPOSITIONS+1)*9):1] firstvalues,
   output wire [((NUMPOSITIONS+1)*9):1] marks,
   output reg  [5:0]                    numResults,
   output wire [((NUMPOSITIONS+1)*9*NUMRESULTS):1] results,
   output reg                           done
);

wire RESET;
assign RESET = RESET_IN;

reg [8:0] minlength;
reg [8:0] newminlength;

wire [8:0] fv[0:NUMPOSITIONS];
assign {fv[0],fv[1],fv[2],fv[3],fv[4],fv[5]}=firstvalues; // extend to include fv[NUMPOSITIONS]

wire[6:0] next_enabled[1:NUMPOSITIONS]; // next_enabled[0] is not needed
wire[8:0] next_value[0:NUMPOSITIONS];

wire [8:0] m [0:NUMPOSITIONS];
assign marks={m[0],m[1],m[2],m[3],m[4],m[5]}; // extend to include m[NUMPOSITIONS]
wire [8:0] vals [1:NUMPOSITIONS];

reg[6:0] enabled;

wire [0:MAXVALUE] pairdistsHash[1:(NUMPOSITIONS-1)]; // [0] is always 0, [NUMPOSITIONS] only needed internally to _leaf module, optimised away


// compatible with yosym
wire [1:MAXVALUE] distances;
assign distances = pairdistsHash[1] | pairdistsHash[2] | pairdistsHash[3] | pairdistsHash[4]; // extend to include pairdistHash[NUMPOSITIONS-1]

/* 
wor [0:MAXVALUE] distances;
genvar y;
generate
 // iverilog tolerates the following, generating a working binary
 // ise compilers tolerate it, isim though says "Possible zero delay oscillation detected where simulation can not advance in time because signals can not resolve to a stable value"
   for(y=1; y<=NUMPOSITIONS-1; y=y+1) begin: distanceLoop // label due to compiler warning, may be non-intended
      assign distances = pairdistsHash[y];  // distances is wor
   end
endgenerate
*/

wire individualReadiness[0:NUMPOSITIONS];

wire ready;
assign ready =  individualReadiness[1] & individualReadiness[2] & individualReadiness[3] & individualReadiness[4] & individualReadiness[5]; // extend to include individualReadiness[NUMPOSITIONS]

/*
genvar x;
generate
   wand ready;
   for(x=0; x<=NUMPOSITIONS; x=x+1) begin: readyLoop // label due to compiler warning, may be unintended
      assign ready = individualReadiness[x];
   end
endgenerate
*/

wire clock;
assign clock = FXCLK;

/* */
reg [((NUMPOSITIONS+1)*9):1] r[1:10];
assign results={r[1],r[2],r[3],r[4],r[5],r[6],r[7],r[8],r[9],r[10]};
/* */

wire good; // indicates success or failure at leaf node

reg [8:0] optiRuler[0:30];
reg carry;

initial begin
   $monitor("Zeit:%t Takt:%b reset:%b enabled:%0d m:(%0d,%0d,%0d,%0d,%0d)",
            $time, clock, RESET, enabled,
            m[0],m[1],m[2],m[3],m[4],m[5]);
   $monitor("Distances: %b",distances);
   done    <= 0;
   enabled <= firstvariableposition;
end


/*                                           */
/* Adding individual ruler positions - marks */
/*                                           */

mark_counter_head #(0,MAXVALUE,NUMPOSITIONS) mc0 (
   clock,RESET,individualReadiness[0],
   m[0],            // assignment of 0 to m[0]
   next_value[0]
);


genvar z;
generate
   for(z=1; z<NUMPOSITIONS; z=z+1) begin : mc_loop
	   mark_counter #(z,MAXVALUE,NUMPOSITIONS) mc (
         clock,RESET,individualReadiness[z],
	      z>=firstvariableposition?9'd0:fv[z],
			next_value[z-1],minlength-optiRuler[NUMPOSITIONS-z+1],
			enabled,m[z],next_enabled[z],next_value[z],
			distances,pairdistsHash[z],marks);
   end // for
endgenerate

// The single leaf marker is at the end of the tree
mark_counter_leaf #(
      NUMPOSITIONS,MAXVALUE,NUMPOSITIONS
   ) mcFinal (
      clock,
      RESET,
      individualReadiness[NUMPOSITIONS],
      NUMPOSITIONS>=firstvariableposition?9'd0:fv[NUMPOSITIONS],
      next_value[NUMPOSITIONS -1],
      minlength-optiRuler[NUMPOSITIONS-NUMPOSITIONS+1],
      enabled,
      m[NUMPOSITIONS],
      next_enabled[NUMPOSITIONS],
      distances,
      marks,
      good
);

/*          */
/* triggers */
/*          */

always @(posedge RESET) begin
   optiRuler[ 0]<= 0;
   optiRuler[ 1]<= 0; optiRuler[11]<= 72; optiRuler[21]<=333;
   optiRuler[ 2]<= 1; optiRuler[12]<= 85; optiRuler[22]<=356;
   optiRuler[ 3]<= 3; optiRuler[13]<=106; optiRuler[23]<=372;
   optiRuler[ 4]<= 6; optiRuler[14]<=127; optiRuler[24]<=425;
   optiRuler[ 5]<=11; optiRuler[15]<=151; optiRuler[25]<=480;
   optiRuler[ 6]<=17; optiRuler[16]<=177; optiRuler[26]<=492;
   optiRuler[ 7]<=25; optiRuler[17]<=199; optiRuler[27]<=0;
   optiRuler[ 8]<=34; optiRuler[18]<=216; optiRuler[28]<=0;
   optiRuler[ 9]<=44; optiRuler[19]<=246; optiRuler[29]<=0;
   optiRuler[10]<=55; optiRuler[20]<=283; optiRuler[30]<=0;
end

always @(posedge clock or posedge RESET) begin
   $display("I: distances: distances: %b",distances);
   if (RESET) begin
      enabled=firstvariableposition;
      if (minlength !== MAXVALUE) begin
         minlength=MAXVALUE;
         numResults=0;
      end
   end else if (clock && ready) begin
      if (enabled>=firstvariableposition) begin
        $display("I: Moving enabled from %0d to %0d",enabled,next_enabled[enabled]);
        if (good && enabled==NUMPOSITIONS && 0!=m[NUMPOSITIONS]) begin
           newminlength=m[NUMPOSITIONS];
           $display("newminlength=%d, minlength=%d", newminlength, minlength);
           if (newminlength<minlength) begin
              $display("************ GOOD FOR %0d-%0d-%0d-%0d-%0d-%0d *** BETTER *****",m[0],m[1],m[2],m[3],m[4],m[5]); // extend to include m[NUMPOSITIONS]
              minlength=newminlength;
              numResults=1;
           end else begin
              $display("************ GOOD FOR %0d-%0d-%0d-%0d-%0d-%0d *** AS GOOD ****",m[0],m[1],m[2],m[3],m[4],m[5]); // extend to include m[NUMPOSITIONS]
              {carry,numResults}=numResults+1'b1;
           end
           r[numResults]=marks; // results handling
        end
        enabled=next_enabled[enabled]; // magic
        if (enabled<firstvariableposition) begin
           $display("I: assembly: m[0..4]: %0d-%0d-%0d-%0d-%0d",m[0],m[1],m[2],m[3],m[4]);
           $display("I: %d == enabled<firstvariableposition ==%d, completed.",enabled,firstvariableposition);
           done <= 1;
        end
     end
   end else if (clock && !ready) begin
      //$display("I: not ready");
   end
end

endmodule

