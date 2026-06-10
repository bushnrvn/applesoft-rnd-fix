# Language Card Patch (Runtime)

This approach patches Applesoft in language card RAM at runtime. No hardware
modification required. The patch must be reapplied after every cold boot.

## Requirements

- Apple II+ or IIe with a 16K language card in slot 0
- DOS 3.3 or ProDOS
- The built binaries: `patch_lc.bin` and `lc_loader.bin`

## Setup

Copy the following files to a DOS 3.3 disk image:

- `build/patch_lc.bin` as `PATCH_LC.BIN`
- `build/lc_loader.bin` as `LCLDR.BIN`
- `tools/PATCHRND.BAS` as `PATCHRND`
- `tools/RNDTEST.BAS` as `RNDTEST` (optional, for testing)

## Applying the patch

Boot to DOS 3.3 with the disk containing the above files. At the Applesoft prompt:

```
RUN PATCHRND
```

The loader will:
1. Load `PATCH_LC.BIN` to $0800
2. Load `LCLDR.BIN` to $0900
3. Copy $E000-$FFFF from Applesoft ROM to language card RAM
4. Write `JMP $0800` at $EFAE in the LC copy
5. Switch the language card to read mode

After completion, RND() seeds from $4E/$4F on the first positive call.
RND(-n) and RND(0) behavior are unchanged.

## Verifying the patch

Run the test program:

```
RUN RNDTEST
```

Without the patch: `PRINT RND(1)` returns `0.973136996` on every cold boot.
With the patch: a different value appears each session.

Cold boot the machine and re-run RNDTEST to confirm the value changes.

## Notes

The patch persists until the next cold boot. On warm reset (Ctrl-Reset) the
language card copy remains active and the patch continues to work.

Load address $0800 must be free. $0900 must be free during patching.
Both are safe in a standard DOS 3.3 environment before any programs are loaded.

**DOS 3.3 and Integer BASIC**

DOS 3.3 automatically loads Integer BASIC into language card bank 1 during boot,
producing the "(LOADING INTEGER INTO LANGUAGE CARD)" message. This does not
conflict with the patch. DOS uses LC bank 1, accessed via $C089/$C08B. The patch
loader uses LC bank 2, accessed via $C081/$C080. The two banks occupy separate
physical RAM in the $D000-$DFFF range and do not interfere with each other.

Typing INT after patching will switch to Integer BASIC (LC bank 1) and the
Applesoft patch will be inactive until you type FP to return to Applesoft.
