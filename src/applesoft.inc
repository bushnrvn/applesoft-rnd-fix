; applesoft.inc
; Verified Applesoft BASIC address definitions
; Sources:
;   S-C DocuMentor: txbobsc.com/scsc/scdocumentor/EE8D.html
;   6502disassembly.com/a2-rom/Applesoft.html
;   6502disassembly.com/a2-rom/IntegerBASIC.html

; ============================================================
; Applesoft ROM entry points
; ============================================================
SIGN            = $EB82     ; Reduce FAC to -1, 0, or +1 in A
LOAD_FAC_YA     = $EAF9     ; Load 5-byte float from address Y:A into FAC
FMULT           = $E97F     ; FAC = FAC * mem[Y:A]
FADD            = $E7BE     ; FAC = FAC + mem[Y:A]
NORMALIZE_FAC   = $E82E     ; Normalize FAC
STORE_FAC_YX    = $EB2B     ; Store FAC to address Y:X (rounded)

; RND function
RND_ENTRY       = $EFAE     ; RND() entry point (verified: EFB4 = A9 C9)
CON_RND_1       = $EFA6     ; LCG multiplier (4 bytes, truncated per AAL 1984)
CON_RND_2       = $EFAA     ; LCG addend (4 bytes, truncated per AAL 1984)

; ============================================================
; Zero page -- Applesoft floating point accumulator
; ============================================================
FAC             = $9D       ; Exponent byte
FAC_M1          = $9E       ; Mantissa byte 1 (sign in bit 7)
FAC_M2          = $9F       ; Mantissa byte 2
FAC_M3          = $A0       ; Mantissa byte 3
FAC_M4          = $A1       ; Mantissa byte 4
FAC_SIGN        = $A2       ; Sign byte (separate from mantissa)
FAC_EXT         = $AC       ; Extension byte

; ============================================================
; Zero page -- Applesoft RND seed
; 5-byte Applesoft float at $C9-$CD
; Initialized to fixed values on cold boot (4 of 5 bytes)
; $CD is uninitialized due to bug in COLD.START (AAL 1984)
; ============================================================
RNDSEED         = $C9       ; Exponent
RNDSEED_M1      = $CA       ; Mantissa byte 1
RNDSEED_M2      = $CB       ; Mantissa byte 2
RNDSEED_M3      = $CC       ; Mantissa byte 3
RNDSEED_M4      = $CD       ; Mantissa byte 4 (uninitalized by Applesoft)

; ============================================================
; Zero page -- Monitor entropy counter
; Incremented continuously by KEYIN while waiting for input
; Named RNDL/RNDH in monitor ROM (Apple II Monitor Peeled, 1978)
; Read by Integer BASIC RND at $EF4E (6502disassembly.com)
; Ignored by Applesoft RND
; ============================================================
RNDL            = $4E       ; Low byte -- incremented every KEYIN loop
RNDH            = $4F       ; High byte -- incremented on RNDL rollover

; ============================================================
; Zero page -- Patch init flag
; $CE sits in an undocumented gap between RNDSEED ($C9-$CD)
; and HGR_DX ($D0) in the Applesoft zero page map.
; Source: cmosher01/Apple-II-Source (applesoft.m4)
;
; $CE and $CF are not assigned to any named Applesoft variable,
; making $CE safe for use as an init flag in a pure Applesoft
; environment.
;
; Caveat: DOS 3.3 uses some locations in the $C0-$CF range for
; its own purposes. If the patch is loaded while DOS is resident,
; $CE may be claimed by DOS. The worst case is the seeding step
; is skipped for that session -- not a crash.
;
; For language card use without DOS: $CE is safe.
; For EEPROM use (no DOS): $CE is safe.
; For DOS environments: verify $CE is free or choose $CF.
;
; Cold boot clears this byte via RAM initialization.
; Set to $FF after first seeding from RNDL/RNDH.
; ============================================================
INIT_FLAG       = $CE
