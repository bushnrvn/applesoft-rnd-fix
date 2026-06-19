# Language Card Loading Instructions

This approach patches Applesoft in language card RAM at runtime. No hardware
modification required. The patch must be reapplied after every cold boot.

## Requirements

- Apple II or II+ with a 16K language card installed in slot 0, or any Apple
  IIe or IIc (language card RAM is built in on these models)
- DOS 3.3
- The built binaries: `patch_lc.bin` and `lc_loader.bin`

Note: ProDOS compatibility is untested. ProDOS uses the language card for its
own code and the patch loader may conflict with it. DOS 3.3 is recommended.

## Setup

Copy the following files to a DOS 3.3 disk image using CiderPress II or
equivalent. Set the file type to BIN and the load address as shown:

| File | DOS name | Type | Load address |
|---|---|---|---|
| `build/patch_lc.bin` | `PATCH_LC.BIN` | BIN | $0800 |
| `build/lc_loader.bin` | `LC_LOADER.BIN` | BIN | $0900 |

## Applying the patch

Boot to DOS 3.3 with the disk containing the above files. At the Applesoft
prompt, type these three commands:

```
]BLOAD PATCH_LC.BIN,A$800
]BLOAD LC_LOADER.BIN,A$900
]CALL 2304
```

The patch is now active for this session.

## What the loader does

1. Enables language card write mode while keeping ROM readable
2. Copies $D000-$FFFF (all of Applesoft and the monitor ROM) from ROM to LC RAM
3. Writes `JMP $0800` at $EFAE in the LC copy
4. Clears the init flag at $CE
5. Switches the language card to read mode

After CALL 2304 returns, RND() seeds from $4E/$4F on the first positive call.
RND(-n) and RND(0) behavior are unchanged.

## Verifying the patch

```
]PRINT RND(1)
```

Without the patch: returns `0.973136996` on every cold boot.
With the patch: returns a different value each session.

To confirm the seeding path ran:

```
]PRINT PEEK(206)
```

Returns 255 after the first RND(1) call if the patch is active. Returns 0 if
the patch has not been applied or the first RND(1) call has not yet occurred.

## Notes

The patch persists until the next cold boot. On warm reset (Ctrl-Reset) the
language card copy remains active and the patch continues to work.

Load addresses $0800 and $0900 must be free when the patch is applied. Both
are safe in a standard DOS 3.3 environment before any programs are loaded. Do
not run a BASIC program before applying the patch -- BASIC program storage
begins at $0800 and would overwrite the patch code.

**DOS 3.3 and Integer BASIC**

DOS 3.3 automatically loads Integer BASIC into language card bank 1 during
boot, producing the "(LOADING INTEGER INTO LANGUAGE CARD)" message. This does
not conflict with the patch. DOS uses LC bank 1, accessed via $C089/$C08B.
The patch loader uses LC bank 2, accessed via $C081/$C080. The two banks
occupy separate physical RAM in the $D000-$DFFF range and do not interfere
with each other.

Typing INT after patching will switch to Integer BASIC (LC bank 1) and the
Applesoft patch will be inactive until you type FP to return to Applesoft.

## Compatibility

Tested in AppleWin 1.32.00 emulating an Apple II+ with 48K RAM and a 16K
language card. Testing on real hardware is in progress prior to VCFMW 21
(September 2026). If you test this before we do, please open an issue with
your results.
