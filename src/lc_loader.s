; lc_loader.s
; Language Card patch loader for applesoft-rnd-fix
;
; Does everything in one pass:
;   1. Copies $D000-$FFFF from Applesoft ROM to LC bank 2
;   2. Writes the patch code into LC at $F5CB (documented free space)
;   3. Writes JMP $F5CB at $EFAE in the LC copy
;   4. Switches LC to read mode
;
; After execution, RND() in the LC copy jumps to $F5CB where the
; patch code lives. No separate patch binary needs to be loaded.
;
; Load at $0900. Apply with CALL 2304 from DOS 3.3.
; The loader at $0900 can be overwritten after it runs -- it is
; no longer needed. The patch at $F5CB in LC survives for the session.
;
; Free space at $F5CB confirmed: Apple Assembly Line Vol.3 No.6, March 1983
; LC soft switches: Understanding the Apple IIe, Jim Sather, 1983

.setcpu "6502"
.include "applesoft.inc"

; Language card soft switches
LC_WRITE    = $C081     ; Enable LC write + ROM read (access twice)
LC_READ     = $C080     ; Enable LC read, disable write

PATCH_SITE  = $F5CB     ; Free space confirmed AAL March 1983

; in LC (documented free space $F5CB-$F5FF)

; RND() entry point to redirect

.org $0900

LOADER:

    ; --------------------------------------------------------
    ; Step 1: Enable LC write, ROM readable
    ; --------------------------------------------------------
    LDA LC_WRITE
    LDA LC_WRITE

    ; --------------------------------------------------------
    ; Step 2: Copy $D000-$FFFF from ROM to LC
    ; Self-modifying loop, 48 pages = 12KB
    ; --------------------------------------------------------
    LDY #$30
    LDX #$00

COPY_PAGE:
SRC_LDA:    LDA $D000,X
DST_STA:    STA $D000,X
    INX
    BNE COPY_PAGE
    INC SRC_LDA+2
    INC DST_STA+2
    DEY
    BNE COPY_PAGE

    ; --------------------------------------------------------
    ; Step 3: Write patch code into LC at $F5CB
    ; Reads from PATCH_DATA in regular RAM ($09xx),
    ; writes to LC (LC write still active)
    ; --------------------------------------------------------
    LDY #$00
WRITE_PATCH:
    LDA PATCH_DATA,Y
    STA PATCH_SITE,Y
    INY
    CPY #PATCH_DATA_SIZE
    BNE WRITE_PATCH

    ; --------------------------------------------------------
    ; Step 4: Write JMP $F5CB at $EFAE in LC copy
    ; Redirects RND() entry point to our patch
    ; --------------------------------------------------------
    LDA #$4C
    STA RND_ENTRY
    LDA #<PATCH_SITE
    STA RND_ENTRY+1
    LDA #>PATCH_SITE
    STA RND_ENTRY+2

    ; --------------------------------------------------------
    ; Step 5: Switch LC to read mode
    ; --------------------------------------------------------
    LDA LC_READ

    RTS

; --------------------------------------------------------
; Patch code to write into LC at $F5CB
; These are the assembled bytes of the RND replacement.
; Assembled for $F5CB -- see patch_rom.s for the source.
;
; Jump targets used within this code (in the LC copy):
;   $EFCC = byte swap entry (.1 label, negative arg path)
;   $EFA5 = RTS for zero argument
;   $EFBE = start of LCG multiply (positive arg path)
; --------------------------------------------------------
PATCH_DATA:
    .byte $20,$82,$EB   ; JSR $EB82  (SIGN)
    .byte $AA           ; TAX
    .byte $10,$03       ; BPL +3     (NOT_NEG)
    .byte $4C,$CC,$EF   ; JMP $EFCC  (negative: byte swap)
                        ; NOT_NEG:
    .byte $A9,$C9       ; LDA #$C9   (RNDSEED low)
    .byte $A0,$00       ; LDY #$00   (RNDSEED high)
    .byte $20,$F9,$EA   ; JSR $EAF9  (LOAD_FAC_YA)
    .byte $8A           ; TXA
    .byte $D0,$03       ; BNE +3     (NOT_ZERO)
    .byte $4C,$A5,$EF   ; JMP $EFA5  (zero: return)
                        ; NOT_ZERO:
    .byte $A5,$4E       ; LDA $4E    (RNDL)
    .byte $45,$CC       ; EOR $CC    (RNDSEED_M3)
    .byte $85,$CC       ; STA $CC
    .byte $A5,$4F       ; LDA $4F    (RNDH)
    .byte $45,$CD       ; EOR $CD    (RNDSEED_M4)
    .byte $85,$CD       ; STA $CD
    .byte $A9,$C9       ; LDA #$C9   (RNDSEED low)
    .byte $A0,$00       ; LDY #$00   (RNDSEED high)
    .byte $20,$F9,$EA   ; JSR $EAF9  (LOAD_FAC_YA)
    .byte $4C,$BE,$EF   ; JMP $EFBE  (positive: run LCG)

PATCH_DATA_SIZE = * - PATCH_DATA
