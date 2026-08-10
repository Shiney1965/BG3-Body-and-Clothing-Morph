# Body and Clothing Morph - v1.3 changelog

## Tattoo correction

- Adds the MCM setting **SBBF/BCB body tattoos**.
- Adds **Match Vanilla** as the default and **Hide on SBBF/BCB** as the opt-out policy.
- Corrects unintended tattoo bleedthrough and atlas behavior on supported naked HUM_F SBBF and BCB bodies in the gameplay-tested KAVT NVP/non-VT setup.
- Preserves Vanilla behavior and the character's saved tattoo selection.
- Adds read-only `!cm_tattootest` and `!cm_tattoodump` diagnostics.

## Proven Wave 03 SCO corrections

Corrects visible BCB faceting in these six exact-family meshes:

- `HUM_F_ARM_Scalemail_Armor`
- `HUM_F_ARM_Scalemail_Armor_Alt`
- `HUM_F_ARM_Soul_Vest`
- `HUM_F_ARM_Soul_Vest_Alt`
- `HUM_F_ARM_Soul_Vest_Type_C`
- `HUM_F_ARM_Soul_Vest_Type_D`

Alan's release review result was: "All those items look good."

## Consolidation and garment improvements

- Consolidates five PAKs into three by merging Runtime, base-game garment content, and Githyanki support into `ClothMorphRuntime.pak`.
- Retires `ClothMorphContent.pak` and `ClothMorphGithyanki.pak`.
- Extends true-Vanilla body behavior to Githyanki.
- Adds proper SBBF meshes for 32 camp-clothing variants backed by 18 meshes.
- Extends the SCO skin-inward pass over both SBBF and BCB cuts. Across 33 comparable garments, the recorded problem-vertex count decreases from 2,187 to 122, a 94.4% reduction, with no measured garment worsening.
- Includes the v1.2.1 forced true-Vanilla behavior for the seven HUM_F-body races.

## BCB add-on

- No content changes. `ClothMorphBCB.pak` remains byte-identical to the verified prior binary.

## Explicit exclusions

- Wave 04 Runtime Wavemother/Viconia candidate: packaging-only, not gameplay-approved.
- Wave 07 Bard proof: packaging-only, not gameplay-approved.
- Wave 08 external optional add-on: packaging-only, not gameplay-approved.
- Wave 09 Elegant Robe: packaging-only, not gameplay-approved.
- Wave 14 descriptor deletion: routing passed, rendering failed.
- Wave 16 Authority candidate: rejected; do not load.
- Wave 19 Oathbreaker donor candidate: rejected after clipping.
- Wave 20 Oathbreaker/SBBF alignment: unfinished, not gameplay-proven, and not included.
