`default_nettype none

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:       Steffen Moeller
// 
// Create Date:    14:06:05 09/22/2012 
// Design Name: 
// Module Name:    mark_counter_tb 
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

This module was only prepared to allow the simulation of the process.
The current marker positions are in 'marks', the preset ones in 'firstvalues'.
The best solutions found will be returned in 'results'.

This functionality is about what would need to be recreated for the
communication with a host system for a real FPGA.

 */
//////////////////////////////////////////////////////////////////////////////////
module mark_counter_tb;

parameter /*  [8:0]  */ MAXVALUE=30;             // highest value a node could accept
parameter /*  [6:0]  */ NUMPOSITIONS=5;          // number of marks beyond 0
parameter /**/[6:0]/**/ FIRSTVARIABLEPOSITION=2; // what mark is first to take non-fixed value, 1 means 'unconstrained'
                                                 // but then one also gets symmetric results with a difference of 1 for
                                                 // the last two positions
parameter /*  [5:0]  */ NUMRESULTS=10;           // number of solutions to keep with shortest length found

wire clock;
reg  reset;
wire done;

wire[8:0] m[0:NUMPOSITIONS];                     // double arrays cannot be passed, only vectors
wire[((NUMPOSITIONS+1)*9):1] marks;              // m[0] ... m[NUMPOSITIONS] is equal to marks
assign {m[0],m[1],m[2],m[3],m[4],m[5]}=marks;    // to help interpreting the values

reg[8:0] fv[0:NUMPOSITIONS];                     // specification how to start
wire[((NUMPOSITIONS+1)*9):1] firstvalues;
assign firstvalues={fv[0],fv[1],fv[2],fv[3],fv[4],fv[5]};


output wire [((NUMPOSITIONS+1)*9*NUMRESULTS):1] results;
wire [((NUMPOSITIONS+1)*9):1] r[1:20];
assign {r[1],r[2],r[3],r[4],r[5],r[6],r[7],r[8],r[9],r[10]}=results;
reg [8:0] tmpM[0:NUMPOSITIONS];

wire [5:0] numResults;

reg [8:0] i; // for result presentation

initial begin
   //m[0]<=9'd0; m[1]<=9'd1; m[2]<=9'd2; m[3]<=9'd3; m[4]<=9'd4;
   fv[0]<=9'd0; fv[1]<=9'd1; fv[2]<=9'd2; fv[3]<=9'd3; fv[4]<=9'd4; fv[5]<=9'd5;
   
   $monitor("Zeit:%t Takt:%b reset:%b m: %0d-%0d-%0d-%0d-%0d-%0d",
            $time, clock, reset,
            m[0],m[1],m[2],m[3],m[4],m[5]);
   
   reset=1;
   #500 reset<=0;
   $display("I: Reset now set to 0");
   #10000000 $finish;
end

mark_counter_assembly #(MAXVALUE,NUMPOSITIONS,NUMRESULTS)
  ruler(clock,reset,FIRSTVARIABLEPOSITION,firstvalues,marks,numResults
	,results // 
	,done
  );

mark_clock_gen #(150,2000000) cg (clock,1'b0);

always @(posedge done) begin
   if (numResults>0) begin
      $display("I: Found %0d result%s.",numResults,1==numResults?"":"s");

      /**/
      for(i=1; i<=numResults;i=i+1) begin
        {tmpM[0],tmpM[1],tmpM[2],tmpM[3],tmpM[4]}=r[i];
          $display("I: Result %0d:   %0d-%0d-%0d-%0d-%0d",i,tmpM[0],tmpM[1],tmpM[2],tmpM[3],tmpM[4],tmpM[5]);
      end
      /**/
   end
   $finish;
end

endmodule
