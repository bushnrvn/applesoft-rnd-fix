; patch.s
; Applesoft BASIC RND() entropy patch
;
; Seeds RND() from the monitor's RNDL/RNDH counter ($4E/$4F)
; on the first positive call after cold boot.
;
; Background:
;   Applesoft's RND() starts from a fixed seed at $C9-$CD on every
;   cold boot, producing the same sequence every session. The Apple II
;   monitor maintains an entropy counter at $4E (RNDL) and $4F (RNDH)
;   that is incremented continuously by the KEYIN routine. Integer BASIC
;   read this counter correctly. Applesoft ignores it. This patch
;   restores the connection.
;
; Strategy:
;   Replace the JSR SIGN entry instruction at $EFAE with a JMP to this
;   patch routine. On the first positive RND() call, XOR the RNDL/RNDH
;   values into the RNDSEED mantissa bytes before running the LCG.
;   All subsequent calls and all negative/zero argument behavior are
;   preserved unchanged.
;
; References:
;   Apple Assembly Line Vol.4 No.8, May 1984 (txbobsc.com/aal/1984/aal8405.html)
;   Aldridge, J.W., Behavior Research Methods, 1987, 19(4), 397-399
;   S-C DocuMentor (txbobsc.com/scsc/scdocumentor/EE8D.html)
;   Integer BASIC disassembly (6502disassembly.com/a2-rom/IntegerBASIC.html)
;
; License: MIT
; Author: Jeff Robison, 2026

.setcpu "6502"
.include "applesoft.inc"

; Patch loads to page 8 ($0800) -- typically free in Apple II memory
; For language card use: apply ROM_PATCH bytes to LC RAM at $EFAE
; For EEPROM use: burn ROM_PATCH bytes at offset $EFAE in ROM image
PATCH_ADDR = $0800     ; Language card version loads here

.org PATCH_ADDR

; ============================================================
; PATCH_RND -- replacement for Applesoft RND() at $EFAE
; ============================================================

PATCH_RND:

    ; Check sign of argument (same as original)
    JSR SIGN            ; A = -1 (neg), 0 (zero), or 1 (pos)
    TAX                 ; preserve sign

    ; Negative argument: use as seed, skip to byte swap
    ; FAC still holds the argument value here
    BMI DO_SWAP

    ; Load current RNDSEED into FAC (same as original)
    LDA #<RNDSEED
    LDY #>RNDSEED
    JSR LOAD_FAC_YA

    ; Zero argument: return current seed unchanged
    TXA
    BEQ DO_RETURN

    ; Positive argument: check if we have seeded from RNDL/RNDH yet
    LDA INIT_FLAG
    BNE DO_LCG

    ; First positive call -- seed RNDSEED from RNDL/RNDH
    ; XOR into mantissa bytes preserves float validity
    ; and mixes in the KEYIN timing entropy
    LDA RNDL
    EOR RNDSEED_M3      ; mix low byte into mantissa byte 3
    STA RNDSEED_M3
    LDA RNDH
    EOR RNDSEED_M4      ; mix high byte into mantissa byte 4
    STA RNDSEED_M4

    ; Mark initialized
    LDA #$FF
    STA INIT_FLAG

    ; Reload modified seed into FAC
    LDA #<RNDSEED
    LDY #>RNDSEED
    JSR LOAD_FAC_YA

DO_LCG:
    ; Run LCG (same constants as original -- intentionally preserved)
    ; The constants are documented as truncated and poorly chosen
    ; but are kept here for compatibility with programs that depend
    ; on specific sequence properties when using RND(-n) seeding
    LDA #<CON_RND_1
    LDY #>CON_RND_1
    JSR FMULT
    LDA #<CON_RND_2
    LDY #>CON_RND_2
    JSR FADD

DO_SWAP:
    ; Byte swap FAC+1 and FAC+4 (original .1 label at $EFCC)
    ; Sander-Cederlof notes this "supposedly makes it more random"
    LDX FAC_M4
    LDA FAC_M1
    STA FAC_M4
    STX FAC_M1

    ; Force positive result
    LDA #0
    STA FAC_SIGN

    ; Store current FAC exponent as extension byte
    LDA FAC
    STA FAC_EXT

    ; Set exponent to produce value in range [0, 1)
    LDA #$80
    STA FAC

    ; Normalize, store result back to RNDSEED, and return
    JSR NORMALIZE_FAC
    LDX #<RNDSEED
    LDY #>RNDSEED
    JMP STORE_FAC_YX    ; stores FAC to RNDSEED and returns to caller

DO_RETURN:
    RTS

; ============================================================
; PATCH_SIZE sanity check
PATCH_SIZE = * - PATCH_RND
.if PATCH_SIZE > $100
    .error "Patch exceeds page boundary -- relocate or optimize"
.endif

; ============================================================
; ROM_PATCH -- 3 bytes to write at $EFAE in ROM or LC RAM
; Replaces: 20 82 EB (JSR SIGN)
; With:     4C lo hi (JMP PATCH_RND)
; ============================================================
ROM_PATCH:
    JMP PATCH_RND
