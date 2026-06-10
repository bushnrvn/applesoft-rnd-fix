# How the Patch Works

This is a walkthrough of the two assembly files that make up the patch. If you
want to understand what the code is actually doing and why, read this first.

---

## Background

Applesoft's RND() function lives at $EFAE in ROM. You cannot modify ROM directly,
so the patch works in two stages. First, a small replacement function is loaded
into regular RAM at $0800. Second, a loader copies the entire Applesoft ROM into
language card RAM, writes a three-byte redirect at $EFAE in that copy, and switches
the machine to read from the language card instead of ROM. After that, every call
to RND() hits the redirect and jumps to the replacement.

The replacement does one new thing: on the first positive RND(1) call after a cold
boot, it reads the monitor's timing counter at $4E and $4F and mixes those values
into the seed before running the generator. Every other call -- RND(-n), RND(0),
and every subsequent RND(1) -- runs the original Applesoft code unchanged.

---

## patch.s -- The replacement RND() function

Loads at $0800. This is what runs every time your program calls RND().

### Checking the argument

```asm
JSR SIGN
TAX
BMI DO_SWAP
```

SIGN is Applesoft's own routine at $EB82. It reads whatever value is sitting in
the floating point accumulator (FAC) -- the argument you passed to RND() -- and
returns -1, 0, or +1 in the A register based on its sign. We save that result in
X because we need it in a moment.

If the argument was negative, BMI branches immediately to DO_SWAP. This is the
RND(-n) seeding path, completely unchanged from original Applesoft. The argument
in FAC gets byte-swapped, normalized, and stored as the new seed.

### Loading the current seed

```asm
LDA #<RNDSEED
LDY #>RNDSEED
JSR LOAD_FAC_YA
TXA
BEQ DO_RETURN
```

RNDSEED is the 5-byte floating point seed stored at $C9 through $CD. We load it
into FAC. Then we recall the sign from X. If it was zero -- meaning you called
RND(0) -- we branch to DO_RETURN and give back whatever is currently in FAC.
That is the last generated value, same behavior as original.

### The new part: first call seeding

```asm
LDA INIT_FLAG
BNE DO_LCG

LDA RNDL
EOR RNDSEED_M3
STA RNDSEED_M3
LDA RNDH
EOR RNDSEED_M4
STA RNDSEED_M4

LDA #$FF
STA INIT_FLAG

LDA #<RNDSEED
LDY #>RNDSEED
JSR LOAD_FAC_YA
```

INIT_FLAG lives at $CE, the byte immediately after RNDSEED in zero page. In
emulation, RAM is typically initialized to zero on cold boot, so $CE reliably
starts clear. On real hardware, DRAM cells drain partially between power cycles
and zero page tends to land near zero after a normal power-off, but this is not
guaranteed. In practice the patch works correctly on real hardware cold boots.
The worst case if $CE happens to be non-zero is that the seeding step is skipped
for that session and the machine falls back to the original fixed seed -- no crash,
just no seeding that boot. Once we have seeded from $4E/$4F, we set INIT_FLAG to
$FF so this only runs once per session.

If INIT_FLAG is already $FF, we skip straight to DO_LCG. If it is zero, this
is the first positive RND call after boot. We read RNDL ($4E) and RNDH ($4F)
-- the monitor's timing counter -- and XOR each byte into the corresponding
mantissa byte of RNDSEED. XOR is safe here because it changes the value of
the seed without invalidating the floating point format. We then reload the
modified seed into FAC and set INIT_FLAG to $FF.

The value in $4E and $4F reflects how long the machine has been sitting at a
prompt waiting for you to type. KEYIN increments $4E on every loop iteration,
thousands of times per second. By the time you have typed three commands and
pressed return, those counters are somewhere completely different from where
they were on any previous boot. That variation is the entropy.

### The LCG

```asm
LDA #<CON_RND_1
LDY #>CON_RND_1
JSR FMULT
LDA #<CON_RND_2
LDY #>CON_RND_2
JSR FADD
```

The original Applesoft linear congruential generator, preserved exactly. The
constants are still the broken ones from 1978. This is intentional. Changing
the algorithm would break programs that depend on RND(-n) producing a specific
sequence from a known seed. The patch changes the default starting point, not
the algorithm.

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

Verbatim from the original Applesoft .1 label at $EFCC. The middle two bytes
of FAC get swapped, the result is forced positive, the exponent is set to $80
to produce a value less than 1.0, and the whole thing is normalized and stored
back to RNDSEED. STORE_FAC_YX handles the return to the caller.

---

## lc_loader.s -- The language card loader

Loads at $0900. Run once to apply the patch. You don't need to run it again
unless you cold boot.

### Enabling LC write

```asm
LDA $C081
LDA $C081
```

The Apple II language card is controlled by soft switches at $C080 through
$C08F. Reading $C081 twice sets the write latch: after these two reads, writes
to $D000-$FFFF go to language card RAM while reads still come from ROM. The
double-read requirement is intentional hardware design to prevent accidental
activation.

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

This copies 48 pages (12,288 bytes) from $D000 through $FFFF -- all of
Applesoft plus the monitor ROM -- from ROM into language card RAM.

The trick here is self-modifying code. INC SRC_LDA+2 increments the high byte
of the LDA instruction's operand address. The first time through the outer loop,
LDA reads from $D0xx. After INC, it reads from $D1xx. Then $D2xx, and so on
through $FFxx. The same happens for the STA. This walks through the entire
address range one page at a time without needing a zero page pointer.

LDX starts at zero. The inner loop runs 256 times (INX from 0 to 255, overflow
to 0 triggers BNE to fall through). LDY starts at $30 (48 decimal). DEY counts
down the outer loop. When both wrap to zero the copy is done.

We copy all of $D000-$FFFF rather than just the Applesoft RND area because
switching the language card to read mode affects the entire $D000-$FFFF range.
If only $E000-$FFFF were copied, the $D000-$DFFF portion of Applesoft in
language card RAM would contain garbage and the machine would crash the moment
it tried to execute any code from there.

### Writing the hook

```asm
LDA #$4C
STA $EFAE
LDA #$00
STA $EFAF
LDA #$08
STA $EFB0
```

LC write is still enabled at this point, so these stores go to language card
RAM, not ROM. $4C $00 $08 is JMP $0800 in 6502 machine code. This replaces
the first three bytes of the RND function in the language card copy -- the
original JSR SIGN -- with a jump to our replacement.

The original ROM is untouched.

### Clearing the init flag

```asm
LDA #$00
STA $CE
```

INIT_FLAG is cleared so the first RND(1) call after the loader runs will
seed from $4E/$4F. Without this step, if $CE happened to contain $FF from
a previous session, the seeding would be skipped.

### Switching to language card read mode

```asm
LDA $C080
RTS
```

A single read of $C080 clears the write latch and switches reads from
$D000-$FFFF to come from language card RAM instead of ROM. From this point
forward, Applesoft runs from the patched copy. RND() at $EFAE now contains
JMP $0800 instead of JSR SIGN.

RTS returns to whatever called the loader -- typically Applesoft's CALL
handler -- and from there back to the DOS prompt. The patch is active for
the rest of the session.

---

## What was not changed

RND(-n) behavior is preserved. The BMI DO_SWAP branch fires before any of
the new code runs, so negative arguments go through the original byte swap
path unmodified. Programs that rely on RND(-n) for reproducible sequences
will work exactly as they always have.

RND(0) behavior is preserved. The BEQ DO_RETURN branch fires before the
INIT_FLAG check.

The LCG algorithm itself is preserved. The broken constants, the floating
point arithmetic, the byte swap -- all of it is there. The patch changes
where the sequence starts, not how it runs.

---

## Verified in AppleWin 1.32.00

Cold boot without patch: PRINT RND(1) returns .973136996 on every boot.
Cold boot with patch applied: PEEK(206) returns 255 after first RND(1)
call, confirming the seeding path executed. Value differs across sessions.
RND(-1) behavior identical with and without patch.
