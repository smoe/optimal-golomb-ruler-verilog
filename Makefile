TESTBEDS=mark_counter_tb.v 
SOURCES=mark_clock_gen.v mark_counter_assembly.v mark_counter.v mark_counter_leaf.v mark_counter_head.v
GENSOURCES=MarkXilinx/ipcore_dir/clk0.v
mark: $(SOURCES)
	iverilog -Wtimescale -o mark -s mark_counter_tb $(SOURCES) $(TESTBEDS)

test: mark
	time ./mark

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
