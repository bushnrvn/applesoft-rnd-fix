; patch_lc.s
; Applesoft BASIC RND() entropy patch -- Language Card version
;
; Loads at $0800 in RAM. The LC loader writes JMP $0800 at $EFAE
; in the LC copy of the ROM, redirecting RND() here.
;
; Structurally identical to patch_rom.s. Handles the sign check,
; negative path, zero path, and seeding, then jumps back into the
; original RND function at $EFBE in the LC copy to run the LCG.
;
; On every positive RND(1) call, RNDL ($4E) and RNDH ($4F) are XORed
; into the RNDSEED mantissa bytes before the original LCG runs.
; RND(-n) and RND(0) behavior are unchanged.
;
; References:
;   S-C DocuMentor RND at $EFAE: txbobsc.com/scsc/scdocumentor/EE8D.html
;   Apple Assembly Line Vol.4 No.8, May 1984: txbobsc.com/aal/1984/aal8405.html
;   Aldridge, J.W., Behavior Research Methods, 1987, 19(4), 397-399
;   Integer BASIC disassembly: 6502disassembly.com/a2-rom/IntegerBASIC.html
;
; Verified working: AppleWin 1.32.00, Apple II+ 48K + 16K language card
;
; License: MIT
; Author: Jeff Robison, 2026

.setcpu "6502"
.include "applesoft.inc"

PATCH_ADDR      = $0C00

; Jump targets back into the original RND function in LC copy
RND_BYTESWAP    = $EFCC     ; .1 label -- byte swap entry (negative arg path)
RND_ZERO_RTS    = $EFA5     ; RTS.19 -- return for zero argument
RND_LCG         = $EFBE     ; start of LCG multiply (positive arg path)

.org PATCH_ADDR

PATCH_RND:
    ; Check sign of argument
    JSR SIGN            ; A = -1, 0, or +1
    TAX                 ; save sign in X

    ; Negative argument: jump to byte swap in original function
    BPL NOT_NEG
    JMP RND_BYTESWAP

NOT_NEG:
    ; Load current RNDSEED into FAC
    LDA #<RNDSEED
    LDY #>RNDSEED
    JSR LOAD_FAC_YA

    ; Zero argument: return current seed unchanged
    TXA
    BNE NOT_ZERO
    JMP RND_ZERO_RTS

NOT_ZERO:
    ; Positive argument: mix RNDL/RNDH into RNDSEED on every call
    LDA RNDL
    EOR RNDSEED_M3
    STA RNDSEED_M3
    LDA RNDH
    EOR RNDSEED_M4
    STA RNDSEED_M4

    ; Reload modified seed into FAC
    LDA #<RNDSEED
    LDY #>RNDSEED
    JSR LOAD_FAC_YA

    ; Jump into original LCG at $EFBE (LDA #CON_RND_1)
    ; FAC has the modified seed, X has the sign (1)
    JMP RND_LCG

; ============================================================
; PATCH_SIZE sanity check
PATCH_SIZE = * - PATCH_RND
.if PATCH_SIZE > $100
    .error "Patch exceeds page boundary"
.endif

; ============================================================
; ROM_PATCH -- 3 bytes to write at $EFAE in LC RAM
; Replaces: 20 82 EB (JSR SIGN)
; With:     4C 00 08 (JMP PATCH_RND)
; ============================================================
ROM_PATCH:
    JMP PATCH_RND
