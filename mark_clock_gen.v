`timescale 1ns / 1ps

// ~~~~~~~~ ~~~~~~~~ ~~~~~~~~ ~~~~~~~~ ~~~~~~~~ ~~~~~~~~
// ~ --
// ~ Published by:   www.asic-digital-design.com
// ~ --
// ~ Description: This is clock generator model.
// ~ --
// ~~~~~~~~ ~~~~~~~~ ~~~~~~~~ ~~~~~~~~ ~~~~~~~~ ~~~~~~~~
// from http://www.asic-digital-design.eu/verilog-examples/testbench-components-models/clock-generator

module mark_clock_gen ( 
   output wire clk,
   input  wire reset
);

   parameter param_clock_half_period = 50;
   parameter param_time_end_of_sim   = 25000000;
  
   reg clk_i;

   // clock generation
   initial begin
     {clk_i} <= 1'b0;
    //#(param_time_end_of_sim) $finish;
   end
   //end initial

   always @(negedge reset) begin
      $display("Initial set clock to 1 after reset");
      clk_i <= 1'b1;
   end

   always #(param_clock_half_period) begin
      if (reset) begin
         //$display("Something noted in the clock, reset still set, clk_i<=0");
         clk_i <= 1'b0;
      end else begin
        {clk_i} <= ~clk_i;
       //$display("Something noted in the clock, clk_i now %0d, clk is %0d",clk_i,clk);
      end
   end

   // outputs --
   assign {clk}=clk_i;
   //--
endmodule
