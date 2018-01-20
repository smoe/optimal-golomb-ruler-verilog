INCLUDE=

#DEVICE = 1k
DEVICE = 8k
PCF = pinmap_$(DEVICE).pcf
PATHTODEVICE = /dev/ttyUSB1

YOSYS=/home/moeller/git/yosys/yosys
TESTBEDS=clock_gen.v testbed.v 
SOURCES=assembly.v mark_counter.v mark_counter_leaf.v mark_counter_head.v definitions.v distance_check.v ogr.v
GENSOURCES=MarkXilinx/ipcore_dir/clk0.v

TOP=ogr.v
BITSTREAM = $(patsubst %.v,%.bin,$(TOP))
HOST      = $(patsubst %.v,%_host,$(TOP))

#VALGRIND=valgrind --leak-check=full 

SOURCES2=ogr.v

.SUFFIXES: .v .md .html .blif

.md.html:
	markdown_py $< > $@

ogr.blif: cores/osdvu/uart.v $(SOURCES)
	iverilog $<
	$(VALGRIND) $(YOSYS) -q -p "hierarchy -check -top top; synth_ice40 -blif $@" $(SOURCES)

%.blif: %.v
	iverilog $<
	$(VALGRIND) $(YOSYS) -q -p "synth_ice40 -blif $@" $<

%.tiles: %.blif
	arachne-pnr -d $(DEVICE) -p $(PCF) -o $@ $<

%.bin: %.tiles
	icepack $< $@

all:
	@echo "The following targets are supported:"
	@echo ""
	@echo "mark      - iverilog-generated executable"
	@echo "synthesis - initiation of synthesis with iverilog"
	@echo "bitstream - creating bitstream"
	@echo "flash     - bitstream flashed to device"
	@echo "run       - bitstream created, flashed and run"
	@echo ""
	@echo "mark.tgz  - generation of source tarball"
	@echo "mark.zip  - generation of source zip" -M.
	@echo "clean     - removal of generated files "

ifeq (uart_adder.v,$(TOP))
bitstream: $(BITSTREAM) $(HOST)
else
bitstream: $(BITSTREAM)
endif

flash: $(BITSTREAM)
	iceprog $<

run:	$(HOST)
	sudo ./ogr_host $(PATHTODEVICE) 26 1 2 3


testbed: mark ogr_host


ogr:	ogr.blif ogr_host

mark: $(SOURCES) $(TESTBEDS)
	iverilog -Wtimescale -o mark -s testbed $(SOURCES) $(TESTBEDS)

markdown: README.html ImplementationDetails.html
>>>>>>> d6cd1400f72daf3ee93dc0a8605cccd6caf39957

test: mark
	time ./mark

mark_yosys blif yosys:  $(SOURCES)
	yosys -q -p "synth_ice40 -blif mark_yosys" $(SOURCES)
	

mark.tgz tar tgz: $(SOURCES) MarkXilinx
	tar czf mark.tgz Makefile $(SOURCES) $(TESTBEDS) MarkXilinx

mark.zip zip: $(SOURCES) MakrXilinx
	#GZIP=-9n tar czvf mark.tar.gz Makefile mark_counter_assembly.v mark_counter_tb.v mark_counter.v
	zip mark.zip Makefile $(SOURCES) $(TESTBEDS) MarkXilinx

clean:
	rm -f mark

.PHONY: tar zip tgz blif pcf yosys
