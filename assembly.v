`default_nettype none
`timescale 1ns / 1ps

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

`include "definitions.v"

module assembly (
   input  wire                          FXCLK, // clock from board
   input  wire                          RESET_IN, // reset from board
   input  wire [((`NUMPOSITIONS+1)*`PositionValueBitMaxPlus1):1] firstvalues,
   output wire [((`NUMPOSITIONS+1)*`PositionValueBitMaxPlus1):1] marks,
`ifdef WithResultsArray
   output wire [((`NUMPOSITIONS+1)*`PositionValueBitMaxPlus1*`NumResultsStored):1] results,
`endif
   output reg  [5:0]                    numResultsObserved,
   output reg                           done
);

wire RESET;
assign RESET = RESET_IN;

reg [`PositionValueBitMax:0] minlength;
reg [`PositionValueBitMax:0] newminlength;

wire [`PositionValueBitMax:0] fv[0:`NUMPOSITIONS];
assign {fv[0],fv[1],fv[2],fv[3],fv[4],fv[5]}=firstvalues; // extend to include fv[NUMPOSITIONS]

wire[`PositionNumberBitMax:0] next_enabled[1:`NUMPOSITIONS]; // next_enabled[0] is not needed
wire[`PositionValueBitMax:0] next_value[0:`NUMPOSITIONS];

wire [`PositionValueBitMax:0] m [0:`NUMPOSITIONS];
assign marks={m[0],m[1],m[2],m[3],m[4],m[5]}; // extend to include m[NUMPOSITIONS]
wire [`PositionValueBitMax:0] vals [1:`NUMPOSITIONS];

reg[`PositionNumberBitMax:0] enabled = `FirstVariablePosition;

wire [1:`MAXVALUE] pairdistsHash[1:(`NUMPOSITIONS-1)]; // [0] is always 0, [NUMPOSITIONS] only needed internally to _leaf module, optimised away


`ifdef AvoidWOR
// compatible with yosys
wire [1:`MAXVALUE] distances;
assign distances = pairdistsHash[1] | pairdistsHash[2] | pairdistsHash[3] | pairdistsHash[4]; // extend to include pairdistHash[NUMPOSITIONS-1]
`else
wor [1:`MAXVALUE] distances;
genvar y;
generate
 // iverilog tolerates the following, generating a working binary
 // ise compilers tolerate it, isim though says "Possible zero delay oscillation detected where simulation can not advance in time because signals can not resolve to a stable value"
   for(y=1; y<=`NUMPOSITIONS-1; y=y+1) begin: distanceLoop // label due to compiler warning, may be non-intended
      assign distances = pairdistsHash[y];  // distances is wor
   end
endgenerate
`endif

reg  iamready=1'b1;
wire individualReadiness[0:`NUMPOSITIONS];

`ifdef AvoidWAND
// compatible with yosys
wire ready;
assign ready = individualReadiness[1] & individualReadiness[2] & individualReadiness[3] & individualReadiness[4] & individualReadiness[5]; // extend to include individualReadiness[NUMPOSITIONS]
`else
genvar x;
generate
   wand ready;
   for(x=0; x<=`NUMPOSITIONS; x=x+1) begin: readyLoop // label due to compiler warning, may be unintended
      assign ready = individualReadiness[x];
   end
endgenerate
`endif

wire clock;
assign clock = FXCLK;

/* */
`ifdef WithResultsArray
reg [((`NUMPOSITIONS+1)*9):1] r[1:`NumResultsStored];
assign results={r[1],r[2],r[3],r[4],r[5]
	//,r[6],r[7],r[8],r[9],r[10]
}; // this should stop at index `NumResultsStored
`endif
/* */

wire good; // indicates success or failure at leaf node

reg carry;

initial begin
   $monitor("Zeit:%t Takt:%b reset:%b enabled:%0d m:(%0d,%0d,%0d,%0d,%0d)",
            $time, clock, RESET, enabled, m[0],m[1],m[2],m[3],m[4],m[5]);
   $monitor("Distances: %b",distances);
end


/*                                           */
/* Adding individual ruler positions - marks */
/*                                           */

mark_counter_head mc0 (
   .clock(clock),
   .reset(RESET),
   .ready(individualReadiness[0]), // node z says if it is ready to compute - node 0 is always ready
   .val(m[0]),            // assignment of 0 to m[0]
   .nextStartValue(next_value[0])
);


genvar z;
generate
   for(z=1; z<`NUMPOSITIONS; z=z+1) begin : mc_loop
	   mark_counter #(z) mc (
              .clock(clock),
              .reset(RESET),
              .ready(individualReadiness[z]), // node z says if it is ready to compute
	      .globalready(ready&iamready),
              //.resetvalue(z>=`FirstVariablePosition?1'd0:fv[z]),
              .startvalue( (z>=`FirstVariablePosition)? (next_value[z-1]):fv[z]),   // value that this node should start working on, which is what the prev node would try next
              .limit(minlength-optiRuler[`NUMPOSITIONS-z+1]),
              .enabled(enabled),              // the marker currently enabled
              .val(m[z]),                     // the position of marker z
              .nextEnabled(next_enabled[z]),  // the node that a particular node z thinks should be next node that is active - typically the downstream or upstream node
              .nextStartValue(next_value[z]), // the value that this next node z thinks it should compute on next time it is enabled
              .distances(distances),          // all observed distances between all valid markers combined 
              .pdHash(pairdistsHash[z]),      // all observed distances between all markers and their respective predecessors
              .marks_in(marks)                // all marker positions
          );
   end // for
endgenerate

// The single leaf marker is at the end of the tree
mark_counter_leaf #(
      `NUMPOSITIONS
   ) mcFinal (
      .clock(clock),
      .reset(RESET),
      .ready(individualReadiness[`NUMPOSITIONS]),
      .globalready(ready&iamready),
      //.resetvalue(`NUMPOSITIONS>=`FirstVariablePosition?1'd0:fv[`NUMPOSITIONS]),
      .startvalue(next_value[`NUMPOSITIONS -1]),
      .limit(minlength-optiRuler[`NUMPOSITIONS-`NUMPOSITIONS+1]),
      .enabled(enabled),
      .val(m[`NUMPOSITIONS]),
      .nextEnabled(next_enabled[`NUMPOSITIONS]),
      .distances(distances),
      .marks_in(marks),
      .success(good)
);

/*          */
/* triggers */
/*          */

reg [`PositionValueBitMax:0] optiRuler[0:30];

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

/* 
   //     0    1    2    3    4    5    6    7    8    9   10      
	  0,   1,   3,   6,  11,  17,  25,  34,  44,  55,  72,
   //         11   12   13   14   15   16   17   18   19   20      
              85, 106, 127, 151, 177, 199, 216, 246, 283, 333,
   //         21   22   23   24   25   26   27   28   29   30      
             356, 372, 425, 480, 492,   0,   0,   0,   0
*/

end

/*
*/

reg wasPerformingReset=0;
reg wasInTheMeantimeWaitingForClientToBeReady=0;
reg [`PositionNumberBitMax:0] prevEnabled = -1;

always @(posedge clock) begin
   if ( ~iamready) begin
      wasInTheMeantimeWaitingForClientToBeReady=0;
   end else if ( ~ready ) begin
      wasInTheMeantimeWaitingForClientToBeReady=1;
   end
end

reg [`PositionValueBitMax:0] tmpM[0:`NUMPOSITIONS];

always @(posedge clock or posedge RESET) begin

   $display("I: distances: %b",distances);

   if (RESET) begin

      enabled <= `FirstVariablePosition;
      done = 0;
      if (minlength !== `MAXVALUE) begin
         minlength = `MAXVALUE;
      end
      numResultsObserved <= 0;
      wasPerformingReset <= 1;
      iamready <= 1'b1;

   end else if ( done ) begin

      $display("Hey, I know I am done. Kill me.");

   end else if ( ~ready ) begin

      $display("I: one of the counters is not ready, enabled=%0d",enabled);

   end else if ( enabled<`FirstVariablePosition ) begin

      $display("I: %d == enabled<`FirstVariablePosition ==%d, completed.",enabled,`FirstVariablePosition);
      $display("I: assembly: m[0..4]: %0d-%0d-%0d-%0d-%0d",m[0],m[1],m[2],m[3],m[4]);
      done = 1;

   end else if ( ~ iamready ) begin

      $display("I: I am not ready, clients ready: %0d, wasInTheMeantimeWaitingForClientToBeReady: %0d",ready, wasInTheMeantimeWaitingForClientToBeReady);

   end else if ( ready && ~wasInTheMeantimeWaitingForClientToBeReady) begin

      $display("I: clients should have been waited for, once at least",prevEnabled);

   end else if (ready && iamready) begin

      iamready <= 1'b0;

      $display("I: ready && iamready && %0d == prevEnabled != next_enabled[enabled] == %0d - enabled == %0d",prevEnabled, next_enabled[enabled],enabled);

      $display("I: checking if good and last enabled was leaf: good=%0d, enabled=%0d",good,enabled);
      if (good && enabled==`NUMPOSITIONS && 0!=m[`NUMPOSITIONS]) begin
           newminlength=m[`NUMPOSITIONS];
           $display("newminlength=%d, minlength=%d", newminlength, minlength);
           if (newminlength<minlength) begin
              $display("************ GOOD FOR %0d-%0d-%0d-%0d-%0d-%0d *** BETTER *****",m[0],m[1],m[2],m[3],m[4],m[5]); // extend to include m[NUMPOSITIONS]
              minlength <= newminlength;
              numResultsObserved = 5'd1;
//#50;
           end else begin
              $display("************ GOOD FOR %0d-%0d-%0d-%0d-%0d-%0d *** AS GOOD ****",m[0],m[1],m[2],m[3],m[4],m[5]); // extend to include m[NUMPOSITIONS]
              {carry,numResultsObserved} = numResultsObserved+1'b1;
           end
`ifdef WithResultsArray
           $display("I: Adding result number %0d to results array",numResultsObserved);
           //r[numResults]=marks; // results handling
           r[numResultsObserved]={m[0],m[1],m[2],m[3],m[4],m[5]}; // results handling
           {tmpM[0],tmpM[1],tmpM[2],tmpM[3],tmpM[4],tmpM[5]}=r[numResultsObserved];
           $display("I: Result %0d: %0d-%0d-%0d-%0d-%0d-%0d",numResultsObserved,tmpM[0],tmpM[1],tmpM[2],tmpM[3],tmpM[4],tmpM[5]);
           $display("I: Result %0d: %b", numResultsObserved, r[numResultsObserved]);
           $display("I: Result %0d: 0000000001111111111222222222233333333334444444444", numResultsObserved);
           $display("I: Result %0d: 1234567890123456789012345678901234567890123456789", numResultsObserved);
           #50;
`endif
      end

      $display("I: Moving enabled from %0d to %0d",enabled,next_enabled[enabled]);
      prevEnabled <= enabled;
      enabled <= next_enabled[enabled]; // magic
      $display("I: Enabled is now %0d, previously",enabled,prevEnabled);
      #20;
      iamready <= 1'b1;

      #10;

   end else begin
      $display("I: This state was not forseen, enabled=",enabled);
   end
end

endmodule

