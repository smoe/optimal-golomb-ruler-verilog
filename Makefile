TESTBEDS=mark_counter_tb.v 
SOURCES=mark_clock_gen.v mark_counter_assembly.v mark_counter.v mark_counter_leaf.v mark_counter_head.v

INCLUDE=
MODULES=-y /Users/moeller/install/lib/ivl/ -y .

all:
	@echo "The following targets are supported:"
	@echo ""
	@echo "mark      - iverilog-generated executable"
	@echo "synthesis - initiation of synthesis with iverilog"
	@echo ""
	@echo "mark.tgz  - generation of source tarball"
	@echo "mark.zip  - generation of source zip" -M.
	@echo "clean     - removal of generated files "

mark: $(SOURCES)
	#iverilog -Wtimescale -o mark -s mark_counter_tb $(SOURCES)
	iverilog -Wall $(MODULES) $(INCLUDE) -o mark -s mark_counter_tb $(SOURCES) $(TESTBEDS)

test: mark
	time ./mark

README.html: README.md
	markdown_py README.md > README.html

mark_yosys blif:  $(SOURCES)
	yosys -q -p "synth_ice40 -blif mark_yosys" $(SOURCES)
	
%.blif: %.v
	yosys -q -p "synth_ice40 -blif $@" $<

mark.tgz tar tgz: $(SOURCES) MarkXilinx
	tar czf mark.tgz Makefile $(SOURCES) $(TESTBEDS) MarkXilinx

mark.zip zip: $(SOURCES) MakrXilinx
	#GZIP=-9n tar czvf mark.tar.gz Makefile mark_counter_assembly.v mark_counter_tb.v mark_counter.v
	zip mark.zip Makefile $(SOURCES) $(TESTBEDS) MarkXilinx

clean:
	rm -f mark

.PHONY: tar zip tgz blif pcf
