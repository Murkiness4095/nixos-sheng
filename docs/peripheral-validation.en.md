# Hardware validation

English · [简体中文](./peripheral-validation.md)

This English overview links to the [full Chinese reference](./peripheral-validation.md) for commands and evidence.

The source records hands-on results from the B-slot, `linux`-partition baseline. It distinguishes device enumeration, physical interaction, and desktop-specific behavior. Pen and fingerprint results apply to the interactions tested. Fingerprint enrollment requires the owner and any test fingerprints must be removed and deletion verified.

On November 25, 2026, switching from Guix to NixOS produced repeated Xiaomi Focus Pen notifications while BlueZ failed to initialize the pen's HID services. The two systems used the same Bluetooth controller address and held different pairing keys. Copying the working pen record from Guix restored the NixOS connection and HID device enumeration. The [Chinese reference](./peripheral-validation.md) records the incident and recurrence conditions.

[Power validation](power-validation.en.md)
