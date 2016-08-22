`timescale 1ns / 1ps

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

`include "definitions.v"

module mark_counter_tb;

parameter [`PositionNumberBitMax:0] FIRSTVARIABLEPOSITION=1; // what mark is first to take non-fixed value, 1 means 'unconstrained'
                                               // but then one also gets symmetric results with a difference of 1 for
                                               // the last two positions
`ifdef WithResultsArray
parameter [5:0] NUMRESULTS=5;           // number of solutions to keep with shortest length found
`endif

wire clock;
reg  reset;
wire done;

wire[`PositionValueBitMax:0] m[0:`NUMPOSITIONS];               // double arrays cannot be passed, only vectors
wire[((`NUMPOSITIONS+1)*(`PositionValueBitMax+1)):1] marks;    // m[0] ... m[NUMPOSITIONS] is equal to marks
assign {m[0],m[1],m[2],m[3],m[4],m[5]}=marks;    // to help interpreting the values

reg[`PositionValueBitMax:0] fv[0:`NUMPOSITIONS];                     // specification how to start
wire[((`NUMPOSITIONS+1)*(`PositionValueBitMax+1)):1] firstvalues;
assign firstvalues={fv[0],fv[1],fv[2],fv[3],fv[4],fv[5]};


wire [5:0] numResults; // Number of OGR observed

`ifdef WithResultsArray
wire [((`NUMPOSITIONS+1)*(`PositionValueBitMax+1)*NUMRESULTS):1] results;
wire [((`NUMPOSITIONS+1)*(`PositionValueBitMax+1)):1] r[1:NUMRESULTS];
assign {r[1],r[2],r[3],r[4],r[5]
			//,r[6],r[7],r[8],r[9],r[10] // should end at NUMRESULTS
        }=results;
reg [`PositionValueBitMax:0] tmpM[0:`NUMPOSITIONS];
reg [`PositionValueBitMax:0] i; // for result presentation
`endif

initial begin
   //m[0]<=9'd0; m[1]<=9'd1; m[2]<=9'd2; m[3]<=9'd3; m[4]<=9'd4;
   fv[0]<=3'd0; fv[1]<=3'd1; fv[2]<=3'd2; fv[3]<=3'd3; fv[4]<=3'd4; fv[5]<=3'd5;
   
   $monitor("Zeit:%t Takt:%b reset:%b m: %0d-%0d-%0d-%0d-%0d-%0d",
            $time, clock, reset,
            m[0],m[1],m[2],m[3],m[4],m[5]);
   
   reset=1;
   #300 reset=0;
   $display("I: Reset now set to 0");
   #20000000 $finish;
end

mark_counter_assembly #(FIRSTVARIABLEPOSITION
`ifdef WithResultsArray
							  ,NUMRESULTS
`endif
							  )
  ruler(clock,reset,firstvalues,marks
   ,numResults
`ifdef WithResultsArray  
	,results
`endif
	,done
  );

mark_clock_gen #(1500,2000000) cg (clock,reset);

always @(posedge clock) begin
   if (done) begin
		if (numResults>0) begin
			$display("I: Found %0d result%s.",numResults,1==numResults?"":"s");
`ifdef WithResultsArray
			/**/
			for(i=1; i<=numResults; i=i+1) begin
			  {tmpM[0],tmpM[1],tmpM[2],tmpM[3],tmpM[4]}=r[i];
				 $display("I: Result %0d:   %0d-%0d-%0d-%0d-%0d",i,tmpM[0],tmpM[1],tmpM[2],tmpM[3],tmpM[4],tmpM[5]);
			end
			/**/
`endif
		end
		$finish;
   end
end

endmodule
