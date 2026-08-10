# v1.3 gameplay smoke pass - 2026-08-09

## User acceptance

- Wave 03 garments: "All those items look good"
- Tattoo controls: "Tattoo passes on RC2, including Match Vanilla and Hide."

## Garments passed

- `HUM_F_ARM_Scalemail_Armor`
- `HUM_F_ARM_Scalemail_Armor_Alt`
- `HUM_F_ARM_Soul_Vest`
- `HUM_F_ARM_Soul_Vest_Alt`
- `HUM_F_ARM_Soul_Vest_Type_C`
- `HUM_F_ARM_Soul_Vest_Type_D`

## Script Extender evidence

- Log: `Extender Runtime 2026-08-10 02-37-33.log`
- Final size: 292,512 bytes
- Runtime server bootstrap: line 1490
- Runtime MCM/server listener: line 1494
- Runtime v4.21 command registration: line 1495
- BCB bootstrap/registration: lines 1496 and 1641
- SCO bootstrap/registration: lines 1497 and 1645
- Match/Hide transitions: lines 1734, 1751, 1753, 1795, 1836, 2811, 2814, 2900, and 2941
- Policy-triggered body refreshes: lines 1735-1736 and 2812-2816
- ClothMorph-specific error/failure lines: 0
- ClothMorph-specific duplicate/conflict lines: 0

The user-visible result is authoritative for appearance. The log independently proves that Runtime, BCB, and SCO loaded, body switching occurred, and both tattoo policies were exercised.
