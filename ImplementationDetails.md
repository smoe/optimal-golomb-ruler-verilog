Ideas behind this implementation
================================

Algorithm
---------

A Golomb ruler describes marks on distinct integer values, the positions,
with the property that the distances between these positions are
non-redundant.  The art is to find a Golomb ruler that requires only
minimal space, i.e. a minimal length or the lowest possible value for
the last position of the ruler. This ruler is then said to be optimal
for a given number of marks.

For any Golomb ruler, any subset of its marks also have the
Golomb property.  And this leads directly to the design for this
implementation. It is a backtracking over incrementally added positions.
The position at index 0 is always at 0. A long register array collects
all the distances observed from any position b to all positions a 
with a smaller than b. If positions for all markers could be found,
i.e. the distance check for a leaf in the backtracking was successful,
then a new Golomb ruler was found and the maximal allowed length is
reduced.

Architecture
------------

The FPGA shall compute a part of the search space, not work on the
complete set. There will hence be predefined fixed positions and the
remaining variable positions. The current implementation in
  mark_counter_tb.v
ships a testbed that passes

 * an array 'firstvariable' with those initial and permanent posisitons
 * the clock
 * reset

to another instance, the assembly module, which performs the computation
and returns a range of values that can be interpreted as status information
from the testbed or at some later stage also by controlling software on the host.

The only modules active in the computation are 

 * assembly, which is placed once and represents the ruler as
   a whole, and
 * mark_counter, which represents a single mark on the ruler.

The position of a ruler is a reg value of the mark_counter. It is wired up with
a particular element of an array of positions of the assembly module.
When the value changes in the mark_counter, so it will in the array.

Of the many mark_counters, only a single one is allowed to change its
position at any given time. Also, it checks if that position is still
allowed to feature (distances to other markers shall not be seen before,
position far enough from the allowed total length) are performed by
the mark_counter module. Depending on the outcome of that check and
the marker position reached, the mark_counter module suggests the next
marker to change its position. In analogy to the positions, the suggested
"next_enabled" position is proposed back to the assembly
module.

The first and the last mark_counter are special. The first
(mark_counter_head) permanently remains at position 0. The last
(mark_counter_leaf) has no successor and does not contribute to the
global storage of distances-between-markers-observed.


Control flow
------------

The control should alternate between the mark_counter module and the
assembly modules. The mark_counter modules thus require
the "enabled" wire passed down from the assembly to match the 
mark_counter's LEVEL parameter.

While the mark_counter is active, the assembly shall be idleing.
The number (LEVEL) of the last active mark_counter is still assigned
to the register "enabled" when the control is handled back. The
architecture then looks up in "next_enabled[enabled]" the number
of the module that should be in control, next. Nothing needs to
be done by the architecture, except for the check if the enabled
module was a leaf position and as such a new Golomb ruler was found.

The information on the number of valid rulers found is returned to the
testbed. Optionally, also the marker positions are saved and returned.
This is however not required to accelerate the Optimal Golomb Rulers
distributed.net project.

Mixed
-----

*** Use of $display throughout the code ***

The $display should only be used in the testbed to ensure that
all information needed is indeed sent back. The only ultimate final
result that this code has is the information on the presence or 
absence of any Golomb ruler that fulfils the maximal length
criterion. This is indeed wired up to the test bed.

A bit competing with the information from the graphical display
of the time course of the register variables. In this setup,
with the control changing between modules so often, This is tedious.
Instead, the $display statements together with a $monitor declaration
help with the insights on the simulation. As a convention the different
kind of messages are indicated with the letters I (standing for "informatory")
W (warning) or E(error). If a message is not raised by a module_counter,
then the letter is followed by the level (marker number and position in
the array) in parentheses.

*** Lacking compatibility with Yosys ***

There are several language features that while naively
hacking along with the ISE tools and following various instructions
on the internet the following issues arose:

 * wand and wor wire types - those are wires with a memory. Assigning
   values to it perform bitwise and or or operation. This came handy for
   the observed distances (wor) or the declaration that all modules are
   ready to compute (wand).

 * for loops with a conditional - when testing the distances between 
   a current marker positions and the ones already placed one can stop
   as soon as a distance was already observed. This is currently
   implemented by a "good && i<LEVEL" kind of check. yosys does not like
   this.

*** `define ***

In analogy to regular computer programming, an include file 
"definitions.v" provides parameter specifications that are not
module-specific. Among the exceptional parameters are:

 * YosysCompliance: If defined, the yosys-incompatible features
   are circumvented
 * MAXVALUE: maximal total length of the ruler, i.e. the last marker position
 * NUMPOSITIONS: number of markers on the ruler
 * FirstVariablePosition: first marker position that is not preset


Discussion
----------

*** Advantage of this design ***

 * intuitive to those coming from object oriented programming
 * the wand and wor assignments that optionally eliminate loops
 * easily extendable for arbitrary ruler sizes
 * local computation of observable differences, which renders everything
   quick and prior computes saved, i.e. there are no redundancies while
   backtracking

*** Problems of this design ***

 * easy initiation of race conditions between the mark_counter and
   assembly modules.
 * Blocking vs non-blocking assignments needs to be reviewed

*** Considerations ***

 * Introduce another module to implement a finite-state-machine

