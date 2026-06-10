; lc_loader.s
; Language Card patch loader for applesoft-rnd-fix
;
; Copies $D000-$FFFF from Applesoft ROM to language card RAM,
; writes JMP $0800 at $EFAE in the LC copy, then switches
; the language card to read mode.
;
; After execution, calls to RND() hit the patched LC copy which
; jumps to the replacement at $0800 (patch_lc.bin, loaded separately).
;
; Load at $0900. Invoke with CALL 2304 from Applesoft BASIC,
; or BRUN LCLDR.BIN from DOS 3.3.
;
; References:
;   Applesoft RND at $EFAE: txbobsc.com/scsc/scdocumentor/EE8D.html
;   LC soft switches: Understanding the Apple IIe, Jim Sather, 1983

.setcpu "6502"

; Language card soft switches
LC_WRITE    = $C081     ; Enable LC write + ROM read (access twice to enable)
LC_READ     = $C080     ; Enable LC read, disable write

; Patch locations
RND_ENTRY   = $EFAE     ; Applesoft RND() entry point
PATCH_ADDR  = $0800     ; Address of replacement RND() code (patch_lc.bin)

; Init flag -- cleared so first RND(1) call seeds from $4E/$4F
INIT_FLAG   = $CE

.org $0900

LOADER:

    ; --------------------------------------------------------
    ; Step 1: Enable LC write while keeping ROM readable
    ; Reading $C081 twice enables write to LC, read from ROM
    ; --------------------------------------------------------
    LDA LC_WRITE
    LDA LC_WRITE

    ; --------------------------------------------------------
    ; Step 2: Copy $D000-$FFFF from ROM to LC RAM
    ; Self-modifying loop advances SRC/DST address high bytes
    ; 48 pages x 256 bytes = 12288 bytes ($3000)
    ; --------------------------------------------------------
    LDY #$30            ; 48 pages to copy
    LDX #$00            ; byte offset within page

COPY_PAGE:
COPY_BYTE:
SRC_LDA:    LDA $D000,X ; source: ROM (modified: high byte advances per page)
DST_STA:    STA $D000,X ; dest:   LC  (modified: high byte advances per page)
    INX
    BNE COPY_BYTE       ; inner loop: 256 bytes per page

    INC SRC_LDA+2       ; advance source to next page ($E0 -> $E1 -> ... -> $FF)
    INC DST_STA+2       ; advance dest to next page (same)
    DEY
    BNE COPY_PAGE       ; outer loop: 48 pages

    ; --------------------------------------------------------
    ; Step 3: Write JMP $0800 at $EFAE in the LC copy
    ; This redirects Applesoft RND() to our replacement
    ; LC write is still enabled here
    ; --------------------------------------------------------
    LDA #$4C            ; JMP opcode
    STA RND_ENTRY
    LDA #<PATCH_ADDR    ; $00 (low byte of $0800)
    STA RND_ENTRY+1
    LDA #>PATCH_ADDR    ; $08 (high byte of $0800)
    STA RND_ENTRY+2

    ; --------------------------------------------------------
    ; Step 4: Clear INIT_FLAG so first RND(1) call seeds
    ; from $4E/$4F (RNDL/RNDH) as intended
    ; --------------------------------------------------------
    LDA #$00
    STA INIT_FLAG

    ; --------------------------------------------------------
    ; Step 5: Switch LC to read mode
    ; Reads from $D000-$FFFF now come from LC (patched copy)
    ; RND() at $EFAE now jumps to $0800 (our replacement)
    ; --------------------------------------------------------
    LDA LC_READ

    RTS
