CA65    = ca65
LD65    = ld65
SRCDIR  = src
OUTDIR  = build

# Language card version -- loads at $0800 in RAM
PATCH_LC_BIN  = $(OUTDIR)/patch_lc.bin
PATCH_LC_OBJ  = $(OUTDIR)/patch_lc.o

# LC loader -- copies ROM to LC and applies JMP hook
LOADER_BIN    = $(OUTDIR)/lc_loader.bin
LOADER_OBJ    = $(OUTDIR)/lc_loader.o

# ROM version -- assembled to free ROM space (address TBD)
PATCH_ROM_BIN = $(OUTDIR)/patch_rom.bin
PATCH_ROM_OBJ = $(OUTDIR)/patch_rom.o

.PHONY: all clean lc rom

all: $(OUTDIR) lc

lc: $(OUTDIR) $(PATCH_LC_BIN) $(LOADER_BIN)

rom: $(OUTDIR) $(PATCH_ROM_BIN)

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(PATCH_LC_OBJ): $(SRCDIR)/patch_lc.s $(SRCDIR)/applesoft.inc
	$(CA65) -t none -o $@ $<

$(PATCH_LC_BIN): $(PATCH_LC_OBJ) $(SRCDIR)/patch_lc.cfg
	$(LD65) -C $(SRCDIR)/patch_lc.cfg -o $@ $<

$(LOADER_OBJ): $(SRCDIR)/lc_loader.s $(SRCDIR)/applesoft.inc
	$(CA65) -t none -o $@ $<

$(LOADER_BIN): $(LOADER_OBJ) $(SRCDIR)/lc_loader.cfg
	$(LD65) -C $(SRCDIR)/lc_loader.cfg -o $@ $<

$(PATCH_ROM_OBJ): $(SRCDIR)/patch_rom.s $(SRCDIR)/applesoft.inc
	$(CA65) -t none -o $@ $<

$(PATCH_ROM_BIN): $(PATCH_ROM_OBJ) $(SRCDIR)/patch_rom.cfg
	$(LD65) -C $(SRCDIR)/patch_rom.cfg -o $@ $<

clean:
	rm -rf $(OUTDIR)
