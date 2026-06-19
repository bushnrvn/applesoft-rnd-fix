# Building from Source

## Requirements

- [cc65](https://cc65.github.io/) — the ca65 assembler and ld65 linker
- An Applesoft ROM image for EEPROM patching (not required for language card approach)

On macOS:
```
brew install cc65
```

On Debian/Ubuntu:
```
apt install cc65
```

## Building

```
make
```

This produces two binaries in `build/`:

- `patch_lc.bin` — the patch stub, assembled to $F5CB (embedded in lc_loader.bin, not loaded separately)
- `lc_loader.bin` — the language card loader, assembled to load at $0900

## What the binaries do

`patch_lc.bin` is the core fix. It is a 6502 replacement for Applesoft's RND() entry
point at $EFAE. On every positive RND(1) call, it reads the
monitor's $4E/$4F entropy counter and XORs those values into the RNDSEED mantissa
bytes at $C9-$CD before running the existing LCG. RND(-n) and RND(0) behavior are
unchanged.

`lc_loader.bin` is the runtime loader. It copies $E000-$FFFF from Applesoft ROM to
language card RAM, writes the patch code into the LC at $F5CB, writes JMP $F5CB at $EFAE in the LC copy, and switches the
language card to read mode. After execution, Applesoft's RND() runs from the patched
LC copy rather than ROM.

## Status

The source assembles cleanly and the patch has been tested and verified in
AppleWin 1.32.00 emulating an Apple II+ with 48K RAM and a 16K language card.

Verification:
- Cold boot without patch: `PRINT RND(1)` returns `0.973136996` on every boot
- After patch applied: `PEEK(78)` and `PEEK(79)` values change between RND(1) calls, confirming $4E/$4F is being read
- Across cold boots with patch: different value every session

Testing on real hardware is in progress prior to VCFMW 21 (September 2026).
If you test this before we do, please open an issue with your results.

## Applying the patch

See [LANGUAGECARD.md](LANGUAGECARD.md) for the language card (runtime) approach.
See [EEPROM.md](EEPROM.md) for the EEPROM (permanent) approach.
