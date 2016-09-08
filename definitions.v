//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    22:11:38 08/20/2016 
// Design Name: 
// Module Name:    definitions 
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
//////////////////////////////////////////////////////////////////////////////////

//`define WithResultsArray
`define YosysCompliance
`ifdef YosysCompliance
`define AvoidWAND
`define AvoidWOR
`endif

`define PositionValueBitMax 6
`define PositionValueBitMaxPlus1 7
`define PositionNumberBitMax 3
`define PositionNumberBitMaxPlus1 4

`define MAXVALUE `PositionValueBitMaxPlus1'd30
`define NUMPOSITIONS 5

`define ResetPosition 0

`define FirstVariablePosition `PositionNumberBitMaxPlus1'd2

`define NumResultsStored 5
