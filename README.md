optimal-golomb-ruler-verilog
============================

The Optimal Golomb Rulers (OGR) as a challenge were motivated by
the cognate http://distributed.net project.  The OGR problem appeals
for its simplicity and its awareness from the distributed computing
community. There are earlier efforts to accelerate OGR computing
with FPGA, also with a reference to distributed comuting (Sotiriades and
Athana, 2000), and yet, these efforts have (other than the employment of
FPGA for e.g. bitcoin mining) never become mainstream.  A general overview
on algorithms and accelerators is also provided by Mountakis in 2010.

So, besides finding more optimal rulers, this project sets out to prepare
low-budget FPGA for application acceleration in distributed computing
in general. As such it aims at using a single source tree for the generation
of readily synthesisable FPGA code for a range of FPGA boards.

The difficulty, aside crafting some decent enough Verilog code, is
to get the technology into many households. And into many developers'
hearts - this is until upcoming Intel chips feature the technology and
ship with free compilers. If we can get some early adopters buying into
these accelerators, then developers also of others projects are likely
to follow.

This project is the author's first hardware description language
(HDL) project. And the code likely looks a bit more like how artificial
agents would address the problem. I have now seen other, completely
array-based implementations.

The implementation I found to be about the same as described in the thesis of
W. Rankin (1993) as the 2.4 Tree Algorithm with a few of the optimisations also implemented.

The invidividual source files offer a description of how they are working:

<table>
<tr><th>File</th>                <th>Description</th></tr>
<tr><td>testbed.v</td>           <td>Testbed for the OGR implementation</td></tr>
<tr><td>clock_gen.v</td>         <td>Module providing a clock</td></tr>
<tr><td>assembly.v</td>          <td>Module forming the ruler, i.e. a collection of individual marks</td></tr>
<tr><td>mark_counter.v</td>      <td>Module representing a regular mark on the ruler</td></tr>
<tr><td>mark_counter_leaf.v</td> <td>Module representing the final mark on the ruler</td></tr>
<tr><td>mark_counter_head.v</td> <td>Module representing the very first mark on the ruler, i.e. position 0</td></tr>
<tr><td>distance_check</td>      <td>Module to check distances between marks</td></tr>
<tr><td>definitions.v</td>       <td>Series of invariant global parameters</td></tr>
<tr><td>ogr.v</td>               <td>FPGA-side of UART communication with host</td></tr>
<tr><td>ogr_host.C</td>          <td>Linux command line to control the FPGA</td></tr>
</table>

The command line interface hass yet to be connected with the assembly.v module.


The Makefile runs iverilog by default and "make test" also executes.
Try
```
  make test|grep GOOD
```
to observe a steadily lowered length limit:
```
************ GOOD FOR 0-1-3-7-12-20 *** BETTER *****
************ GOOD FOR 0-1-3-7-15-20 *** AS GOOD ****
************ GOOD FOR 0-1-3-8-12-18 *** BETTER *****
************ GOOD FOR 0-1-3-8-14-18 *** AS GOOD ****
************ GOOD FOR 0-1-4-10-12-17 *** BETTER *****
************ GOOD FOR 0-1-4-10-15-17 *** AS GOOD ****
************ GOOD FOR 0-1-8-11-13-17 *** AS GOOD ****
************ GOOD FOR 0-1-8-12-14-17 *** AS GOOD ****
```
The first position was held fixed. See the defintions.v file to change
the FirstVariablePosition and give appropriate start values in the
testbed file.

References
----------

 * Euripdes Sotiriades, Apostolos Dollas, Peter Athanas (2000) "Hardware-Software Codesign and Parallel Implementation of a Golomb Ruler Derivation Engine", in Proceedings of the 2000 IEEE Symposium on Field-Programmable Custom Computing Machines. https://www.computer.org/csdl/proceedings/fccm/2000/0871/00/08710227.pdf
 * Kiriakos Simon Mountakis (2000) "Parallel search for optimal Golomb rulers"
 * William  T.  Rankin,  Optimal  Golomb  Rulers:   An  exhaustive  parallel search implementation, M.S. thesis, Duke University, 1993. (formerly seen at http://people.ee.duke.edu/~wrankin/golomb/golomb_paper.pdf, now as possibly at www.mathpuzzle.com/MAA/30-Rulers%20and%20Arrays/Golomb/rankin93optimal.ps)

-- 
 Steffen Möller, 8/2012 to 10/2016
 
 Niendorf/Ostsee, Germany
