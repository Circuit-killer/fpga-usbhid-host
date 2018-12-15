
PROJ_FILE := $(shell ls *.ldf | head -1)
PROJ_NAME := $(shell fgrep default_implementation ${PROJ_FILE} | cut -d'"' -f 4)
IMPL_NAME := $(shell fgrep default_implementation ${PROJ_FILE} | cut -d'"' -f 8)
IMPL_DIR := $(shell fgrep default_strategy ${PROJ_FILE} | cut -d'"' -f 4)

DIAMOND_BASE := /usr/local/diamond
DIAMOND_BIN :=  $(shell find ${DIAMOND_BASE}/ -maxdepth 2 -name bin | sort -rn | head -1)
DIAMONDC := $(shell find ${DIAMOND_BIN}/ -name diamondc)
DDTCMD := $(shell find ${DIAMOND_BIN}/ -name ddtcmd)

OPENOCD ?= openocd_ft232r
OPENOCD_BASE := ../../programmer/openocd/ulx3s

FLEAFPGA_JTAG ?= FleaFPGA-JTAG

UJPROG ?= ujprog

# name of the project as defined in project file
PROJECT = project

BOARD ?= ulx3s
BOARD_VERSION ?= v20

# FPGA_SIZE 12/25/45/85
FPGA_SIZE ?= 12

# bitstream file prefix
BITSTREAM_PREFIX ?= f32c_$(BOARD)_$(BOARD_VERSION)_$(FPGA_SIZE)k_pix8bpp640x480_100mhz

XCF_PREFIX = $(BOARD)_$(FPGA_SIZE)

JUNK = ${IMPL_DIR} .recovery ._Real_._Math_.vhd *.sty reportview.xml
JUNK += dummy_sym.sort project_tcl.html promote.xml
JUNK += generate_core.tcl generate_ngd.tcl msg_file.log
JUNK += project_tcr.dir

all: $(PROJECT)/$(PROJECT)_$(PROJECT).bit \
	$(PROJECT)/$(BITSTREAM_PREFIX).bit \
	$(PROJECT)/$(BITSTREAM_PREFIX)_sram.svf \
	$(PROJECT)/$(BITSTREAM_PREFIX)_sram.vme \
	$(PROJECT)/$(BITSTREAM_PREFIX)_flash_is25lp032d.svf \
	$(PROJECT)/$(BITSTREAM_PREFIX)_flash_is25lp032d.vme \
	$(PROJECT)/$(BITSTREAM_PREFIX)_flash_s25fl164k.svf \
	$(PROJECT)/$(BITSTREAM_PREFIX)_flash_s25fl164k.vme \
	$(PROJECT)/$(BITSTREAM_PREFIX)_flash_is25lp128f.svf \
	$(PROJECT)/$(BITSTREAM_PREFIX)_flash_is25lp128f.vme \


$(PROJECT)/$(PROJECT)_$(PROJECT).bit:
	echo prj_project open ${PROJ_FILE} \; prj_run Export -task Bitgen | ${DIAMONDC}

$(PROJECT)/$(BITSTREAM_PREFIX)_sram.vme: $(PROJECT)/$(PROJECT)_$(PROJECT).bit
	LANG=C ${DDTCMD} -oft -fullvme -if $(XCF_PREFIX)f_sram.xcf -nocompress -noheader -of $@

$(PROJECT)/$(BITSTREAM_PREFIX)_sram.svf: $(PROJECT)/$(PROJECT)_$(PROJECT).bit
	LANG=C ${DDTCMD} -oft -svfsingle -revd -maxdata 8 -if $(XCF_PREFIX)f_sram.xcf -of $@

$(PROJECT)/$(PROJECT)_$(PROJECT).mcs: $(PROJECT)/$(PROJECT)_$(PROJECT).bit
	LANG=C ${DDTCMD} -dev LFE5U-$(FPGA_SIZE)F \
	-if $< -oft -int -quad 4 -of $@

$(PROJECT)/$(BITSTREAM_PREFIX).bit: $(PROJECT)/$(PROJECT)_$(PROJECT).bit
	cd $(PROJECT); ln -s $(PROJECT)_$(PROJECT).bit $(BITSTREAM_PREFIX).bit

#$(PROJECT)/$(PROJECT)_$(PROJECT)_flash_is25lp032d.mcs: $(PROJECT)/$(PROJECT)_$(PROJECT).bit
#	LANG=C ${DDTCMD} -dev LFE5U-$(FPGA_SIZE)F -oft -advanced -format int -flashsize 32 -quad 4 -header \
#	-if $< -of $@

$(PROJECT)/$(PROJECT)_$(PROJECT)_flash_is25lp032d.mcs: $(PROJECT)/$(PROJECT)_$(PROJECT).mcs
	cd $(PROJECT); ln -sf $(PROJECT)_$(PROJECT).mcs $(PROJECT)_$(PROJECT)_flash_is25lp032d.mcs

$(PROJECT)/$(BITSTREAM_PREFIX)_flash_is25lp032d.vme: $(PROJECT)/$(PROJECT)_$(PROJECT)_flash_is25lp032d.mcs
	LANG=C ${DDTCMD} -oft -fullvme -if $(XCF_PREFIX)f_flash_is25lp032d.xcf -nocompress -noheader -of $@

$(PROJECT)/$(BITSTREAM_PREFIX)_flash_is25lp032d.svf: $(PROJECT)/$(PROJECT)_$(PROJECT)_flash_is25lp032d.mcs
	LANG=C ${DDTCMD} -oft -svfsingle -revd -maxdata 8 -if $(XCF_PREFIX)f_flash_is25lp032d.xcf -of $@
	sed --in-place -f $(OPENOCD_BASE)/fix_flash_is25lp128f.sed $@

#$(PROJECT)/$(PROJECT)_$(PROJECT)_flash_s25fl164k.mcs: $(PROJECT)/$(PROJECT)_$(PROJECT).bit
#	LANG=C ${DDTCMD} -dev LFE5U-$(FPGA_SIZE)F -oft -advanced -format int -flashsize 64 -quad 1 -header \
#	-if $< -of $@

$(PROJECT)/$(PROJECT)_$(PROJECT)_flash_s25fl164k.mcs: $(PROJECT)/$(PROJECT)_$(PROJECT).mcs
	cd $(PROJECT); ln -sf $(PROJECT)_$(PROJECT).mcs $(PROJECT)_$(PROJECT)_flash_s25fl164k.mcs

$(PROJECT)/$(BITSTREAM_PREFIX)_flash_s25fl164k.vme: $(PROJECT)/$(PROJECT)_$(PROJECT)_flash_s25fl164k.mcs
	LANG=C ${DDTCMD} -oft -fullvme -if $(XCF_PREFIX)f_flash_s25fl164k.xcf -nocompress -noheader -of $@

$(PROJECT)/$(BITSTREAM_PREFIX)_flash_s25fl164k.svf: $(PROJECT)/$(PROJECT)_$(PROJECT)_flash_s25fl164k.mcs
	LANG=C ${DDTCMD} -oft -svfsingle -revd -maxdata 8 -if $(XCF_PREFIX)f_flash_s25fl164k.xcf -of $@

#$(PROJECT)/$(PROJECT)_$(PROJECT)_flash_is25lp128f.mcs: $(PROJECT)/$(PROJECT)_$(PROJECT).bit
#	LANG=C ${DDTCMD} -dev LFE5U-$(FPGA_SIZE)F -oft -advanced -format int -flashsize 128 -quad 1 -header \
#	-if $< -of $@

$(PROJECT)/$(PROJECT)_$(PROJECT)_flash_is25lp128f.mcs: $(PROJECT)/$(PROJECT)_$(PROJECT).mcs
	cd $(PROJECT); ln -sf $(PROJECT)_$(PROJECT).mcs $(PROJECT)_$(PROJECT)_flash_is25lp128f.mcs

$(PROJECT)/$(BITSTREAM_PREFIX)_flash_is25lp128f.vme: $(PROJECT)/$(PROJECT)_$(PROJECT)_flash_is25lp128f.mcs
	LANG=C ${DDTCMD} -oft -fullvme -if $(XCF_PREFIX)f_flash_is25lp128f.xcf -nocompress -noheader -of $@

$(PROJECT)/$(BITSTREAM_PREFIX)_flash_is25lp128f.svf: $(PROJECT)/$(PROJECT)_$(PROJECT)_flash_is25lp128f.mcs
	LANG=C ${DDTCMD} -oft -svfsingle -revd -maxdata 8 -if $(XCF_PREFIX)f_flash_is25lp128f.xcf -of $@
	sed --in-place -f $(OPENOCD_BASE)/fix_flash_is25lp128f.sed $@

# default programmer is "ujprog"
program: $(PROJECT)/$(PROJECT)_$(PROJECT).bit
	$(UJPROG) $<

# needs ft2232 cable
program_diamond: $(PROJECT)/$(PROJECT)_$(PROJECT).bit
	echo pgr_project open $(XCF_PREFIX)f_sram.xcf \; pgr_program run | ${DIAMONDC}

program_ujprog: $(PROJECT)/$(PROJECT)_$(PROJECT).bit
	$(UJPROG) $<

program_wifi: $(PROJECT)/$(PROJECT)_$(PROJECT)_sram.svf
	$(OPENOCD) --file=$(OPENOCD_BASE)/remote.ocd --file=$(OPENOCD_BASE)/ecp5-$(FPGA_SIZE)f.ocd

program_web: $(PROJECT)/$(PROJECT)_$(PROJECT)_sram.svf
	svfupload.py ulx3s.lan $<

program_web_flash: $(PROJECT)/$(PROJECT)_$(PROJECT)_flash.svf
	svfupload.py ulx3s.lan $<

program_ft2232: $(PROJECT)/$(PROJECT)_$(PROJECT)_sram.svf
	ln -sf $(BITSTREAM_PREFIX)_sram.svf $(PROJECT)/$(PROJECT)_$(PROJECT)_sram.svf
	$(OPENOCD) --file=$(OPENOCD_BASE)/ft2232-fpu1.ocd --file=$(OPENOCD_BASE)/ecp5-$(FPGA_SIZE)f.ocd
	rm -f $(PROJECT)/$(PROJECT)_$(PROJECT)_sram.svf

program_ft231x: $(PROJECT)/$(BITSTREAM_PREFIX)_sram.svf
	ln -sf $(BITSTREAM_PREFIX)_sram.svf $(PROJECT)/$(PROJECT)_$(PROJECT)_sram.svf
	$(OPENOCD) --file=$(OPENOCD_BASE)/ft231x.ocd --file=$(OPENOCD_BASE)/ecp5-$(FPGA_SIZE)f.ocd
	rm -f $(PROJECT)/$(PROJECT)_$(PROJECT)_sram.svf

program_flea: $(PROJECT)/$(BITSTREAM_PREFIX)_sram.vme
	$(FLEAFPGA_JTAG) $<

program_flea_flash: $(PROJECT)/$(BITSTREAM_PREFIX)_flash_is25lp128f.vme
	$(FLEAFPGA_JTAG) $<

clean:
	rm -rf $(JUNK) *~
