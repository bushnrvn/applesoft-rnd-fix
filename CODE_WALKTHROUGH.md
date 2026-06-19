# How the Patch Works

This is a walkthrough of the two assembly files that make up the patch. If you
want to understand what the code is doing and why, read this first.

---

## Background

Applesoft's RND() function lives at $EFAE in ROM. You cannot modify ROM directly,
so the language card patch works by copying the entire Applesoft ROM into language
card RAM, writing a redirect at $EFAE in that copy, and writing the replacement
code into free space in the LC at $F5CB. After the loader runs, Applesoft executes
from the LC copy and every call to RND() hits the redirect at $EFAE, which jumps
to the replacement code at $F5CB.

The replacement handles the sign check, negative path, and zero path, then mixes
the monitor's timing counter at $4E and $4F into the seed before jumping back into
the original LCG in the LC copy. The original RND function handles everything from
the LCG forward.

---

## A note on $4E and $4F

The KEYIN routine in the monitor ROM increments $4E on every iteration of its
keyboard polling loop, not on every keypress. The counter advances thousands of
times per second while the machine is sitting at a prompt. A keypress just exits
the loop. By the time you have typed a command and called RND(), the counter
reflects how long the machine spent in that polling loop, which varies from session
to session. That variation is the entropy.

---

## patch_rom.s and patch_lc.s: The replacement RND() stub

Both files contain the same 44 bytes of logic. patch_rom.s assembles to $F5CB
for the EEPROM approach. patch_lc.s assembles to $F5CB as well, but its bytes
are embedded directly in lc_loader.s as a data table rather than loaded as a
separate binary.

The stub handles three cases.

### Negative argument

```asm
JSR SIGN
TAX
BPL NOT_NEG
JMP $EFCC
```

SIGN is Applesoft's own routine at $EB82. It reads the argument from FAC and
returns -1, 0, or +1 in A. We save that in X. If the argument was negative,
BPL falls through to the JMP which goes to $EFCC in the LC copy. That is the
original byte swap entry point. The argument in FAC gets byte-swapped,
normalized, and stored as the new seed. No change to this behavior.

BMI cannot reach $EFCC from $F5CB (too far for a relative branch), so we use
BPL to skip over a JMP instead.

### Zero argument

```asm
LDA #<RNDSEED
LDY #>RNDSEED
JSR LOAD_FAC_YA
TXA
BNE NOT_ZERO
JMP $EFA5
```

Load RNDSEED ($C9) into FAC. If the argument was zero, jump to $EFA5 in the
LC copy, which is an RTS. That returns the current seed value unchanged.

### Positive argument: mixing in $4E and $4F

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

JMP $EFBE
```

Read RNDL ($4E) and RNDH ($4F) and XOR each byte into the corresponding
mantissa byte of RNDSEED. XOR modifies the seed value without invalidating
the floating point format. Reload the modified seed into FAC, then jump to
$EFBE in the LC copy. That is the start of the original LCG, which runs the
multiply, add, byte swap, normalize, store, and return, all from the
unmodified LC copy of Applesoft.

This happens on every positive call. The counter reflects current timing at
the moment of each call. In interactive use with keyboard activity between
calls, the values will vary. In a tight loop with no keyboard activity, the
counter may not change much between calls since KEYIN only runs while waiting
for input.

---

## lc_loader.s: The language card loader

Loads at $0900. Run once with CALL 2304. After it returns, the patch is active
for the session. The loader code at $0900 can be overwritten after that. It is not
needed again. The patch code lives in the LC at $F5CB and survives for the session.

### Enabling LC write

```asm
LDA $C081
LDA $C081
```

Reading $C081 twice sets the write latch. After this, writes to $D000-$FFFF
go to language card RAM while reads still come from ROM.

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

Copies 48 pages (12,288 bytes) from $D000 through $FFFF into LC bank 2.
Self-modifying code: INC SRC_LDA+2 increments the high byte of the LDA
instruction's operand, advancing the source address from $D0xx through $FFxx
one page at a time. The STA does the same for the destination. This covers
all of Applesoft and the monitor ROM without needing a zero page pointer.

We copy all of $D000-$FFFF because switching the LC to read mode affects the
entire range. Copying only part of it would leave uninitialized RAM where
Applesoft code needs to run.

### Writing the patch code into the LC

```asm
LDY #$00
WRITE_PATCH:
    LDA PATCH_DATA,Y
    STA $F5CB,Y
    INY
    CPY #PATCH_DATA_SIZE
    BNE WRITE_PATCH
```

Writes 44 bytes from the PATCH_DATA table into the LC at $F5CB. LC write is
still active, so the STAs go to LC RAM. PATCH_DATA is in regular RAM at
$09xx, so the LDAs read from there. $F5CB-$F5FF is documented unused space
in the Applesoft ROM (Apple Assembly Line, March 1983).

### Writing the hook

```asm
LDA #$4C
STA $EFAE
LDA #$CB
STA $EFAF
LDA #$F5
STA $EFB0
```

Writes JMP $F5CB at $EFAE in the LC copy. LC write is still active.
The original ROM is untouched.

### Switching to LC read mode

```asm
LDA $C080
RTS
```

A single read of $C080 clears the write latch and switches $D000-$FFFF to
read from LC instead of ROM. RND() at $EFAE in the LC now contains JMP $F5CB.

---

## What was not changed

The negative argument path goes through the original byte swap in the LC copy
unchanged. The zero argument path returns the current seed unchanged. The LCG
algorithm, the broken constants, the byte swap, the normalization, the store --
all of it runs from the original LC copy of Applesoft. The only thing the patch
changes is what the seed contains before the LCG runs.

---

## Verified in AppleWin 1.32.00

Cold boot without patch: PRINT RND(1) returns .973136996 on every boot.
Cold boot with patch applied: value differs across sessions.
RND(-1) behavior identical with and without patch.
PEEK(78) and PEEK(79) values at time of each RND(1) call influence the result.
