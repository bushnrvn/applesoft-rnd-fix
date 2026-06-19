# EEPROM Patch (Apple II+)

This approach burns a patched Applesoft ROM to an EEPROM and installs it in
the Apple II+. The patch is permanent and requires no software to activate
on each boot.

These instructions are specific to the Apple II+. The IIe and IIc are not confirmed working or supported at this time.

## Requirements

- Apple II+ ROM
- A hex editor
- An EEPROM programmer and a compatible EEPROM chip (see chip notes below)

## How it works

Two regions of the ROM image are modified:

**At $EFAE (file offset 0x1FAE)** The original entry point of RND() is
redirected with a JMP to new code in unused ROM space.

**At $F5CB (file offset 0x25CB):** The routine mixes the monitor's $4E/$4F counter into RNDSEED on
every positive RND(1) call, then jumps back into the original LCG at $EFBE.

The original RND function from $EFAE onward is preserved intact. The entry
point is the only thing changed. Programs that want a deterministic sequence
can still call the original directly at $EFB1 via CALL 61361.

## Hex editor instructions

Open Apple2_Plus.rom in a hex editor.

### Change 1: Redirect entry point

Go to file offset **0x1FAE** (8110 decimal).

You should see these three bytes:
```
20 82 EB
```
That is the original JSR $EB82 (JSR SIGN). Replace them with:
```
4C CB F5
```
That is JMP $F5CB (jump to the new routine).

### Change 2: Write new routine

Go to file offset **0x25CB** (9675 decimal).

Write the following 53 bytes:
```
20 82 EB AA 10 03 4C CC EF A9 C9 A0 00 20 F9 EA
8A D0 03 4C A5 EF A5 4E 45 CC 85 CC A5 4F 45 CD
85 CD A9 C9 A0 00 20 F9 EA 4C BE EF EA EA EA EA
EA EA EA EA EA
```

The final nine EA bytes are NOP padding to fill the unused space through $F5FF.
The EA bytes within the code (at positions 16 and 41 in the sequence above)
are the high byte of the JSR $EAF9 (LOAD_FAC_YA) instruction, not NOPs.

### Verification

After making both changes, verify:

- Offset 0x1FAE: `4C CB F5`
- Offset 0x25CB: `20 82 EB AA 10 03 4C CC EF`

Save the file and burn to your EEPROM.

## Burning the patch

How you get those bytes into
ROM depends on what hardware you have available EPROM programmer, EEPROM
burner, or a ROM emulator. The Apple II community has documented various
approaches to ROM replacement on the II+, including chip-specific pinout
considerations. Search Applefritter or the comp.sys.apple2 archives for
current guidance on your specific setup.


## Status

The ROM patch source assembles cleanly and the byte offsets have been verified.
Testing on real hardware is in progress prior to VCFMW 21 (September 2026).
If you test this before we do, please open an issue with your results.