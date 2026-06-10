; patch_lc.s
; Applesoft BASIC RND() entropy patch -- Language Card version
;
; Replacement for Applesoft RND() at $EFAE. On every positive RND(1) call,
; mixes the monitor's RNDL/RNDH counter ($4E/$4F) into RNDSEED before
; running the existing LCG. This is the entropy source the platform was
; designed for, used correctly by Integer BASIC, and ignored by Applesoft.
;
; RND(-n) and RND(0) behavior are preserved unchanged.
;
; References:
;   S-C DocuMentor (txbobsc.com/scsc/scdocumentor/EE8D.html)
;   Apple Assembly Line Vol.4 No.8, May 1984 (txbobsc.com/aal/1984/aal8405.html)
;   Aldridge, J.W., Behavior Research Methods, 1987, 19(4), 397-399
;   Integer BASIC disassembly (6502disassembly.com/a2-rom/IntegerBASIC.html)
;
; Verified working: AppleWin 1.32.00, Apple II+ 48K + 16K language card
;
; License: MIT
; Author: Jeff Robison, 2026

.setcpu "6502"
.include "applesoft.inc"

PATCH_ADDR = $0800     ; Language card version loads here

.org PATCH_ADDR

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

    ; Positive argument: mix RNDL/RNDH into RNDSEED on every call
    ; XOR preserves float validity and mixes in KEYIN timing entropy
    LDA RNDL
    EOR RNDSEED_M3      ; mix low byte into mantissa byte 3
    STA RNDSEED_M3
    LDA RNDH
    EOR RNDSEED_M4      ; mix high byte into mantissa byte 4
    STA RNDSEED_M4

    ; Reload modified seed into FAC
    LDA #<RNDSEED
    LDY #>RNDSEED
    JSR LOAD_FAC_YA

DO_LCG:
    ; Run LCG (same constants as original -- preserved for compatibility)
    LDA #<CON_RND_1
    LDY #>CON_RND_1
    JSR FMULT
    LDA #<CON_RND_2
    LDY #>CON_RND_2
    JSR FADD

DO_SWAP:
    ; Byte swap FAC+1 and FAC+4 (original .1 label at $EFCC)
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
; With:     4C 00 08 (JMP PATCH_RND)
; ============================================================
ROM_PATCH:
    JMP PATCH_RND
