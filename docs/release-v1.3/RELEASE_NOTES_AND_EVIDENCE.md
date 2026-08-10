# Body and Clothing Morph v1.3 release notes and verification evidence

## Readiness

v1.3 is the first public release after v1.2.1. It includes the previously staged consolidation/garment work, the tattoo correction, and the six proven Wave 03 SCO corrections.

Gameplay evidence:

- Alan reported: "All those items look good" after checking all six Wave 03 garments.
- Alan reported: "Tattoo passes on RC2, including Match Vanilla and Hide."
- The final Runtime PAK is byte-identical to the earlier TEST-2 Runtime that received a positive gameplay result.
- The final SCO PAK differs from the gameplay-tested RC2 SCO only in `Mods/ClothMorphSCO/meta.lsx`; all other 162 extracted paths are identical.

## Final PAK identities

| Component | Bytes | SHA-256 | Verification boundary |
|---|---:|---|---|
| `ClothMorphRuntime.pak` | 320,998,012 | `B030385F5D5F93EDEFE29C38CC7051E0DC9300EA15DC944C339B355DF41C3D24` | Exact TEST-2 gameplay binary; v1.3.0.0 metadata |
| `ClothMorphSCO.pak` | 196,323,117 | `B42E5D21EF3C05094CEB24C80CF2D0D95B76ED9C3206E710C057BF566794E1E6` | RC2 functional payload; only release metadata changed to v1.3.0.0 |
| `ClothMorphBCB.pak` | 140,642,680 | `9E315B49F54F29B278313E974198674ACC951E55A7BC0C81BB05B800B1E91062` | Byte-identical to verified prior binary |

Runtime and SCO use Version64 `36451009484029952` (`1.3.0.0`).

## File-level verification

- Runtime: 737/737 extracted paths; compared with RC2, only `Mods/ClothMorphRuntime/meta.lsx` differs. The final extracted Runtime matches the verified v1.3 build source tree at all 737 paths.
- SCO: 163/163 extracted paths; compared with RC2, only `Mods/ClothMorphSCO/meta.lsx` differs.
- BCB: whole-file SHA-256 identity.
- Complete tattoo suite: 85 tests run, 84 passed, 1 skipped, 0 failures, 0 errors.

## Gameplay smoke log

Completed Script Extender log: `Extender Runtime 2026-08-10 02-37-33.log`, 292,512 bytes, last written 2026-08-09 10:59:09 PM local time.

- Runtime server bootstrap: line 1490; Runtime v4.21 loaded at line 1495.
- BCB bootstrap: line 1496; registered at line 1641.
- SCO bootstrap: line 1497; registered at line 1645.
- Tattoo policy transitions and body refreshes: lines 1734-1837, 2811-2816, and 2900-2942.
- The client scripts were loaded in two client contexts during the session; the server and add-ons loaded once.
- ClothMorph-specific error/failure lines: 0.
- ClothMorph-specific duplicate/conflict lines: 0.

The full game log contains warnings/errors from unrelated installed mods; they are not attributed to ClothMorph and are outside this release claim.

## Tested boundary

The tattoo visual pass was performed with KAVT NVP/non-VT. No-KAVT and KAVT VT have static coverage but were not separately gameplay-confirmed. The Wave 03 gameplay pass covers Scalemail Armor, Scalemail Armor Alt, Soul Vest, Soul Vest Alt, Soul Vest Type C, and Soul Vest Type D.
