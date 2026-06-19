# EEPROM Patch (Apple II+)

This approach burns a patched Applesoft ROM to an EEPROM and installs it in
the Apple II+. The patch is permanent and requires no software to activate
on each boot.

These instructions are specific to the Apple II+. The IIe and IIc are not confirmed working or supported at this time.

## Requirements

- Apple II+ ROM
- A hex editor
- An EEPROM programmer and a compatible EEPROM chip

## Hex editor instructions

Open Apple2_Plus.rom in a hex editor.

### Change 1: Redirect entry point

Go to file offset **0x1FAE** (8110 decimal).

You should see these three bytes:
```
20 82 EB
```
That is the original JSR $EB82 (JSR SIGN). Replace them with:
```
4C CB F5
```
That is JMP $F5CB (jump to the new routine).

### Change 2: Write new routine

Go to file offset **0x25CB** (9675 decimal).

Write the following 53 bytes:
```
20 82 EB AA 10 03 4C CC EF A9 C9 A0 00 20 F9 EA
8A D0 03 4C A5 EF A5 4E 45 CC 85 CC A5 4F 45 CD
85 CD A9 C9 A0 00 20 F9 EA 4C BE EF EA EA EA EA
EA EA EA EA EA
```

Save the file and burn to your EEPROM.


