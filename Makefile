
SOURCES=mark_clock_gen.v mark_counter_tb.v mark_counter_assembly.v mark_counter.v mark_counter_leaf.v mark_counter_head.v
GENSOURCES=MarkXilinx/ipcore_dir/clk0.v
mark: $(SOURCES)
	iverilog -Wtimescale -o mark -s mark_counter_tb $(SOURCES)

test: mark
	time ./mark

mark.tgz tar tgz: $(SOURCES) MarkXilinx
	tar czf mark.tgz Makefile $(SOURCES) MarkXilinx

mark.zip zip: $(SOURCES) MakrXilinx
	#GZIP=-9n tar czvf mark.tar.gz Makefile mark_counter_assembly.v mark_counter_tb.v mark_counter.v
	zip mark.zip Makefile $(SOURCES) MarkXilinx

clean:
	rm -f mark

.PHONY: tar zip tgz
