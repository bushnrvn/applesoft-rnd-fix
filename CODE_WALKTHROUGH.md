# How the Patch Works

This is a walkthrough of the two assembly files that make up the patch. If you
want to understand what the code is doing and why, read this first.

---

## Background

Applesoft's RND() function lives at $EFAE in ROM. You cannot modify ROM directly,
so the patch works in two stages. First, a small replacement function is loaded
into regular RAM at $0800. Second, a loader copies the entire Applesoft ROM into
language card RAM, writes a three-byte redirect at $EFAE in that copy, and switches
the machine to read from the language card instead of ROM. After that, every call
to RND() hits the redirect and jumps to the replacement.

On every positive
RND(1) call, the patch reads the monitor's timing counter at $4E and $4F and mixes those
values into the seed before running the generator. RND(-n) and RND(0) run the original Applesoft code without modification.

---

## A note on $4E and $4F

The KEYIN routine in the monitor ROM increments $4E on every iteration of its
keyboard polling loop, not on every keypress. The counter advances thousands of
times per second while the machine is sitting at a prompt. A keypress just exits
the loop. By the time you have typed a few commands and called RND(), the counter
reflects how long the machine spent in that polling loop, which varies from session
to session based on your timing. That variation is the entropy.

---

## patch_lc.s: The replacement RND() function

Loads at $0800. This runs every time your program calls RND().

### Checking the argument

```asm
JSR SIGN
TAX
BMI DO_SWAP
```

SIGN is Applesoft's own routine at $EB82. It reads whatever value is in the
floating point accumulator (FAC), the argument you passed to RND(), and
returns -1, 0, or +1 in the A register. Next save that in X.

If the argument was negative, BMI branches immediately to DO_SWAP. This is the
RND(-n) seeding path. The argument in FAC gets byte-swapped, normalized, and
stored as the new seed. No changes to this behavior.

### Loading the current seed

```asm
LDA #<RNDSEED
LDY #>RNDSEED
JSR LOAD_FAC_YA
TXA
BEQ DO_RETURN
```

RNDSEED is the 5-byte floating point seed at $C9 through $CD. First load it into
FAC. If the argument was zero, branch to
DO_RETURN and give back whatever is in FAC. That is the last generated value.

### Mixing in $4E and $4F

```asm
LDA RNDL
EOR RNDSEED_M3
STA RNDSEED_M3
LDA RNDH
EOR RNDSEED_M4
STA RNDSEED_M4

LDA #<RNDSEED
LDY #>RNDSEED
JSR LOAD_FAC_YA
```

If RND() is positive, read RNDL ($4E) and RNDH ($4F) and XOR each byte
into the corresponding mantissa byte of RNDSEED. XOR modifies the seed value
without invalidating the floating point format. Then reload the modified
seed into FAC before running the LCG.

The counter reflects current timing at
the moment of each call. In interactive use with keyboard activity between
calls, the values will vary. In a tight loop with no keyboard activity, the
counter may not change much between calls since KEYIN only runs while waiting
for input.

### The LCG

```asm
JSR FMULT   ; FAC = FAC * CON_RND_1
JSR FADD    ; FAC = FAC + CON_RND_2
```

The original Applesoft linear congruential generator. Changing the original constants would break programs that
depend on RND(-n) producing a specific sequence from a known seed.

### The byte swap and return

```asm
LDX FAC_M4
LDA FAC_M1
STA FAC_M4
STX FAC_M1
LDA #0
STA FAC_SIGN
LDA FAC
STA FAC_EXT
LDA #$80
STA FAC
JSR NORMALIZE_FAC
LDX #<RNDSEED
LDY #>RNDSEED
JMP STORE_FAC_YX
```

Verbatim from the original Applesoft .1 label at $EFCC. Swap the middle two
bytes of FAC, force the result positive, set the exponent to $80 to produce
a value less than 1.0, normalize, and store back to RNDSEED. STORE_FAC_YX
handles the return to the caller.

---

## lc_loader.s: The language card loader

Loads at $0900. Run once to apply the patch. Reapply after every cold boot.

### Enabling LC write

```asm
LDA $C081
LDA $C081
```

Reading $C081 twice sets the write latch. After this, writes to $D000-$FFFF
go to language card RAM while reads still come from ROM. The double-read
requirement is intentional hardware design to prevent accidental activation.

### Copying ROM to the language card

```asm
LDY #$30
LDX #$00
COPY_PAGE:
SRC_LDA: LDA $D000,X
DST_STA: STA $D000,X
    INX
    BNE COPY_PAGE
    INC SRC_LDA+2
    INC DST_STA+2
    DEY
    BNE COPY_PAGE
```

This copies 48 pages (12,288 bytes) from $D000 through $FFFF, covering all of Applesoft and the monitor ROM.

INC SRC_LDA+2 increments the high byte of
the LDA instruction's operand. The first time through the outer loop, LDA reads
from $D0xx. After the increment it reads from $D1xx, then $D2xx, through $FFxx.
The STA works the same way. This walks through all 48 pages without needing a
zero page pointer.

The patch copies all of $D000-$FFFF rather than just the area around $EFAE because
switching the language card to read mode affects the entire range. If only
part of it were copied, Applesoft would try to execute from uninitialized RAM
the moment it returned from the loader.

### Writing the hook

```asm
LDA #$4C
STA $EFAE
LDA #$00
STA $EFAF
LDA #$08
STA $EFB0
```

LC write is still active here, so these STA go to language card RAM. $4C
$00 $08 is JMP $0800 in 6502 machine code. This replaces the first three bytes
of the RND function in the LC copy with a jump to
the replacement. 

### Switching to language card read mode

```asm
LDA $C080
RTS
```

A single read of $C080 clears the write latch and switches reads from
$D000-$FFFF to come from language card RAM. From this point, Applesoft runs
from the patched copy. RND() at $EFAE now contains JMP $0800.

---

## What was not changed

RND(-n) takes the BMI DO_SWAP branch before any of the new code runs. The
negative argument path goes through the original byte swap unchanged. Programs
that rely on RND(-n) for reproducible sequences work the same way they always have.

RND(0) takes the BEQ DO_RETURN branch before the $4E/$4F mixing code runs.

The LCG algorithm itself is unchanged.

---

## Verified in AppleWin 1.32.00

Cold boot without patch: PRINT RND(1) returns .973136996 on every boot.
Cold boot with patch applied: value differs across sessions.
RND(-1) behavior identical with and without patch.
PEEK(78) and PEEK(79) values at time of each RND(1) call influence the result.
