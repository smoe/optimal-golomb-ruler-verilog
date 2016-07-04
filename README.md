optimal-golomb-ruler-verilog
============================

The Optimal Golomb Rulers (OGR) as a challenge were motivated by
the cognate http://distributed.net project.  The OGR problem appeals
for its simplicity and its awareness from the distributed computing
community.

Besides finding more optimal rulers, this project sets out to prepare
low-budget FPGA for application acceleration in distributed computing.
As such it aims at using a single source tree for the generation
of readily synthesisable FPGA code for a range of FPGA boards.

The difficulty is to get the technology into many households. And
into many developers' hearts - this is until upcoming Intel chips
feature the technology and ship with free compilers. If we can get
some early adopters buying into these accelerators, then developers
also of others projects are likely to follow.

This project is the author's first hardware description language
(HDL) project. And the code likely looks a bit more like how artificial
agents would address the problem. I have now seen other, completely
array-based implementations. But, for now, it synthesises. And at least
for the LX75 it uses no more than 15% of its resources.

A very first implementation was insensibly loaded with nested
for loops and many thanks go to my then colleagues next door at the
University of Luebeck, i.e. especially to Thilo Piontec for a brain reset,
to Eric Maehle, Volker Hampel and Steffen Prehn for the access to their
Xilinx suite. The early bioinformatics products of TimeLogic is thanked
for the general awareness of hardware acceleration. And yes, of course,
I hope for the emergence of a series of Open Source solutions for
sequence analysis and, even more so, structural computing.
Stefan Ziegenbalg of ztex.de also helped a lot to get me going with
one of his USB-FPGA modules.

This project yet is a mere technical and social exercise.
It shall not compete with the distributed.net effort but speed it up.
There is already the BOINC project Yoyo@Home which wraps the original
distributed.net client. And similarly one
could have an FPGA-aware BOINC (Berkeley Open Infrastructure for 
Network Computing) flavour that knows about how to transform,
or from where to download, a bitstream to fit the attached accelerator.

So this project aims at:
 * gathering feedback on an the OGR implementation per se
 * find ways to implement the OGR seach on the very low budget FPGA
   available that can also be programmed with Open Source tools
 * collect adaptor code for many different FPGA platforms
 * render BOINC FPGA-aware
 * preparing for an on-the-fly bitstream creation for BOINC

This project is successful once a diversity of implementations for
various FPGA boards is available to jointly accelerate the computation.

Some tantalising developments support the very small
Xilinx chips via the
  fpgatools https://github.com/Wolfgang-Spraul/fpgatools
and others for the one shipped by Lattice Semiconductors
  fpga-icestorm   http://www.clifford.at/icestorm/
These are all available as Debian/Ubuntu/Mint Linux packages.

This first upload from my Dropbox to github does not feature any
bitstreams. It is meant to allow my immediate peers to inspect
it all and make friendly comments. For a quick impression
install iverilog and run "make test" which performs a quick
exhaustive search for OGR with 5 marks.

<pre>
   time ./mark
   I(0): Reset of mark counter, val=0
   I(5): Reset of mark counter (leaf), val=x, startvalue=x
   I(5): Reset of mark counter (leaf), val=0, startvalue=x
   Zeit:                   0 Takt:0 reset:1 m: 0-x-x-x-x-0
   I(4): Reset of mark counter, val=x, startvalue=x
   I(3): Reset of mark counter, val=x, startvalue=x
   I(2): Reset of mark counter, val=x, startvalue=x
   I(1): Reset of mark counter, val=x, startvalue=1
   I(1): Initialising distances, m: 0-1-0-0-0-0
   I(1): distance set (d=1,i=0,val=1,m[i]=0)
   I(5): Reset of mark counter (leaf), val=0, startvalue=x
   Zeit:                 150 Takt:1 reset:1 m: 0-1-0-0-0-0
   I(5): Reset of mark counter (leaf), val=0, startvalue=x
   Zeit:                 300 Takt:0 reset:1 m: 0-1-0-0-0-0
   I(1): Reset of mark counter, val=1, startvalue=1
   I(1): Initialising distances, m: 0-1-0-0-0-0
   I(1): distance set (d=1,i=0,val=1,m[i]=0)
   I(2): Reset of mark counter, val=0, startvalue=2
   I(3): Reset of mark counter, val=0, startvalue=3
   I(4): Reset of mark counter, val=0, startvalue=4
   I(5): Reset of mark counter (leaf), val=0, startvalue=5
   Zeit:                 450 Takt:1 reset:1 m: 0-1-0-0-0-0
   I: Reset now set to 0
   Zeit:                 500 Takt:1 reset:0 m: 0-1-0-0-0-0
   Zeit:                 600 Takt:0 reset:0 m: 0-1-0-0-0-0
   I: Moving enabled from 2 to 2
   Zeit:                 750 Takt:1 reset:0 m: 0-1-2-0-0-0
   Zeit:                 900 Takt:0 reset:0 m: 0-1-2-0-0-0
   I: Moving enabled from 2 to 2
   Zeit:                1050 Takt:1 reset:0 m: 0-1-3-0-0-0
   Zeit:                1200 Takt:0 reset:0 m: 0-1-3-0-0-0
   I: Moving enabled from 2 to 3
</pre>

...

<pre>
   : Moving enabled from 5 to 5
   Zeit:                5550 Takt:1 reset:0 m: 0-1-3-7-12-18
   Zeit:                5700 Takt:0 reset:0 m: 0-1-3-7-12-18
   I: Moving enabled from 5 to 5
   Zeit:                5850 Takt:1 reset:0 m: 0-1-3-7-12-19
   Zeit:                6000 Takt:0 reset:0 m: 0-1-3-7-12-19
   I: Moving enabled from 5 to 5
   Zeit:                6150 Takt:1 reset:0 m: 0-1-3-7-12-20
   Zeit:                6300 Takt:0 reset:0 m: 0-1-3-7-12-20
   I: Moving enabled from 5 to 5
   ************ GOOD FOR 0-1-3-7-12-20 ****************
   Zeit:                6450 Takt:1 reset:0 m: 0-1-3-7-12-0
   Zeit:                6600 Takt:0 reset:0 m: 0-1-3-7-12-0
   I: Moving enabled from 5 to 4
   Zeit:                6750 Takt:1 reset:0 m: 0-1-3-7-13-0
   Zeit:                6900 Takt:0 reset:0 m: 0-1-3-7-13-0
   I: Moving enabled from 4 to 4
</pre>

...

<pre>
   Zeit:              185250 Takt:1 reset:0 m: 0-1-11-14-0-0
   Zeit:              185400 Takt:0 reset:0 m: 0-1-11-14-0-0
   I: Moving enabled from 3 to 4
   Zeit:              185550 Takt:1 reset:0 m: 0-1-11-14-15-0
   Zeit:              185700 Takt:0 reset:0 m: 0-1-11-14-15-0
   I: Moving enabled from 4 to 4
   Zeit:              185850 Takt:1 reset:0 m: 0-1-11-14-16-0
   Zeit:              186000 Takt:0 reset:0 m: 0-1-11-14-16-0
   I: Moving enabled from 4 to 5
   Zeit:              186150 Takt:1 reset:0 m: 0-1-11-14-16-17
   Zeit:              186300 Takt:0 reset:0 m: 0-1-11-14-16-17
   I: Moving enabled from 5 to 5
   Zeit:              186450 Takt:1 reset:0 m: 0-1-11-14-16-0
   Zeit:              186600 Takt:0 reset:0 m: 0-1-11-14-16-0
   I: Moving enabled from 5 to 4
   Zeit:              186750 Takt:1 reset:0 m: 0-1-11-14-0-0
   Zeit:              186900 Takt:0 reset:0 m: 0-1-11-14-0-0
   I: Moving enabled from 4 to 3
   Zeit:              187050 Takt:1 reset:0 m: 0-1-11-0-0-0
   Zeit:              187200 Takt:0 reset:0 m: 0-1-11-0-0-0
   I: Moving enabled from 3 to 2
   Zeit:              187350 Takt:1 reset:0 m: 0-1-0-0-0-0
   Zeit:              187500 Takt:0 reset:0 m: 0-1-0-0-0-0
   I: Moving enabled from 2 to 1
   I: assembly: m[0..4]: 0-1-0-0-0
   I:   1 == enabled<firstvariableposition ==  2, completed.
   I: Found 4 results.
   I: Result 1:   1-4-10-12-17  x
   I: Result 2:   1-4-10-15-17  x
   I: Result 3:   1-8-11-13-17  x
   I: Result 4:   1-8-12-14-17  x
   Zeit:              187650 Takt:1 reset:0 m: 0-2-0-0-0-0
   0.02user 0.00system 0:00.05elapsed 54%CPU (0avgtext+0avgdata 7068maxresident)k
   0inputs+0outputs (0major+741minor)pagefaults 0swaps
</pre>

The results are identical with what Wikipedia says for rulers of length 6.

The implementation I found to be about the same as described in
http://people.ee.duke.edu/~wrankin/golomb/golomb_paper.pdf
as the 2.4 Tree Algorithm with a few of the optimisations also implemented.

The invidividual source files offer a description of how they are working:

<table>
<tr><th>File</th>                  <th>Description</th></tr>
<tr><td>mark_counter_tb.v</td>      <td>Testbed</td></tr>
<tr><td>mark_clock_gen.v</td>       <td>Module providing a clock</td></tr>
<tr><td>mark_counter_assembly.v</td><td>Module forming the ruler, i.e. a collection of individual marks</td></tr>
<tr><td>mark_counter.v</td>         <td>Module representing a regular mark on the ruler</td></tr>
<tr><td>mark_counter_leaf.v</td>    <td>Module representing the final mark on the ruler</td></tr>
<tr><td>mark_counter_head.v</td>    <td>Module representing the very first mark on the ruler, i.e. position 0</td></tr>
</table>
-- 
 Steffen Möller, 8/2012 to 7/2016
 
 Niendorf/Ostsee, Germany
