# EEPROM Patch (Permanent)

This approach burns a patched Applesoft ROM to an EEPROM and installs it in the
Apple II. The patch is permanent and requires no software to activate. RND() seeds
from $4E/$4F on every cold boot without any user action.

## Status

EEPROM patching instructions are in progress. The patch binary and ROM offset are
confirmed. Chip compatibility and programming instructions are being verified prior
to VCFMW 21 (September 2026).

## What is confirmed

The patch bytes to write are `4C 00 08` (JMP $0800) at ROM offset $EFAE. This
redirects RND() to the replacement code.

The replacement code (patch.bin) must also be present at $0800 in RAM or burned
into unused ROM space. The language card approach (LANGUAGECARD.md) demonstrates
the runtime equivalent.


