# applesoft-rnd-fix

A ROM patch for Applesoft BASIC that seeds `RND()` from the monitor's built-in
entropy counter at `$4E` and `$4F`.

The Apple II monitor ROM continuously increments a counter at `$4E` (RNDL)
and `$4F` (RNDH) while waiting for keyboard input. These locations were named and
designed as a random seed source. Integer BASIC used them in this way. When Applesoft replaced Integer BASIC, it stopped doing so.

`PRINT RND(1)` returns `0.973136996` every cold boot on a stanard Apple II+. It is
the first value the generator produces from that fixed starting state, and it always
will be until the seed changes. The problem was documented in peer-reviewed research
as early as 1984 and contaminated experimental data in at least one published
psychology study. A one-line software workaround has been published since 1987, but it
requires every programmer to know about it and apply it correctly. This patch makes
it unnecessary.

## Usage

### EEPROM Replacement

Apply the binary patch to your Applesoft ROM image.
See [EEPROM.md](EEPROM.md)

### Language Card (Runtime Patch)

Load the provided binary from DOS 3.3 at startup to apply the patch in
RAM. See [LANGUAGECARD.md](LANGUAGECARD.md) for
instructions.

## Building from Source

Requires [ca65](https://cc65.github.io/doc/ca65.html) and an Applesoft ROM image.

```
make
```

See [BUILD.md](BUILD.md) for details.

## Background

Full research notes, primary source disassembly evidence, and historical context
are in [RESEARCH.md](https://codeberg.org/bushnrvn/loaded-dice-vcfmw2026/src/branch/main/RESEARCH.md).

## References

The following sources support the claims in this document. 

- Apple Assembly Line, Vol. 4, No. 8, May 1984. [txbobsc.com](https://www.txbobsc.com/aal/1984/aal8405.html)
- Aldridge, J.W. "Cautions regarding random number generation on the Apple II." Behavior Research Methods, Instruments, and Computers, 1987, 19(4), 397-399.
- Applesoft disassembly at $EFAE. [txbobsc.com](https://www.txbobsc.com/scsc/scdocumentor/EE8D.html)
- Integer BASIC disassembly at $EF4E. [6502disassembly.com](https://6502disassembly.com/a2-rom/IntegerBASIC.html)

## Licenses

Code: MIT
RESEARCH.md: CC BY-NC 4.0
