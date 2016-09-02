`default_nettype none
`timescale 1ns / 1ps

/**

 This is a special version of the mark_counter module that is the
 very first mark of the rule, which always resides at position 0.

 The role of the 'nextStartValue' becomes obvious. This is what the
 first mark downstream shall try first. One may argue that it is
 just fine to start with position 2 since a distance '1' may also
 be checked on the far end and we reduce the search space. In later
 practice, though, the first positions will be preset externally
 to help with distributing the computation. Hence, the decision to
 start with 1 or at some later position is made elsewhere. One may
 also decide to keep it for a bit of redundancy checks.

 */

`include "definitions.v"

module mark_counter_head(
   input  wire       clock,
   input  wire       reset,
   output wire       ready, // computation done when this flag is set
   output wire [`PositionValueBitMax:0] val, // value currently owned
   output wire [`PositionValueBitMax:0] nextStartValue // set value for next mark
);

assign val = 0;
assign nextStartValue = 1;
assign ready = 1;

endmodule
