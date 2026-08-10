# Changelog - Body and Clothing Morph for SBBF and BCB

## v1.3 - 2026-08-10

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

## v1.3 - 2026-08-10

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

## v1.2.1 — 2026-07-30 (hotfix)

**Fixed**
- **Vanilla mode now shows the true VANILLA body.** Previously, picking Vanilla restored whatever body your install ships by default — so if you use a body replacer (e.g. Unique Tav with a BCB-shaped body), "Vanilla" still showed the replacer's shape. Vanilla mode now forces the actual vanilla body, exactly like the SBBF and BCB modes force theirs. Applies to the 7 HUM_F-body races (Human, Elf, Half-Elf, Drow subraces); Githyanki and other races keep the previous behavior. Modded/base-game garments already switched to their vanilla shapes in Vanilla mode (the 74 clean-vanilla clones) — that half was working and is unchanged.
- `!cm_revert` still means "mod off for this character" and restores your install's original body (it is NOT the forced vanilla body).

**Note for existing saves:** if you previously used `!cm_revert` to turn the mod off for a character, run `!cm_revert` on that character once after updating — older saves cannot distinguish a revert from a Vanilla pick, so such characters will show the true-vanilla body until you re-revert them.

Updated files: `ClothMorphRuntime.pak` (v4.19) and `ClothMorphContent.pak` (v1.2.0). The BCB, SCO, and Githyanki add-on paks are unchanged.

## v1.2 — 2026-07-28

**New**
- **BCB clothing add-on (ClothMorphBCB):** 154 garments from Sindae's BCB.pak morphed to fit the Vanilla and SBBF bodies (they keep their native fit on the BCB body). 27 of the 181 scoped garments are excluded due to a mesh-conversion limitation (candidates for a future update).
- **Githyanki add-on (ClothMorphGithyanki):** the body switch and clothing refits now work on Githyanki females, including **Lae'zel**.
- **Improved compatibility with SBBF / BCB body mods:** you can now change a party member's body even with those mods installed, for any character while you control it (previously the body mod's shape stuck on companions).

**Improved**
- **SCO on SBBF:** fixed the "chest opening doesn't grow with the bust" problem, so SCO camp outfits fit the SBBF body correctly. 58 of 76 SCO garment meshes got the improved fit; the remaining 18 keep their prior look (mostly meshes that can't yet be converted).
- **Base-game coverage** confirmed across all three bodies (Vanilla, SBBF, and BCB) for ~405 garments, plus 74 clean-vanilla clones so revealing tops get a properly covered Vanilla version.
- **Moonshadow Armor (SBBF):** now shows the leather body and pants correctly (its small decorative top layer is still absent when BCBPak is installed — a proper fit is planned).

**Fixed**
- Camp Clothes Wavemother Robe (both variants) reverted to its previously-shipped SBBF mesh after the new fit clipped.

**Known limitations (unchanged)**
- Some Sindae BCB garments may look too large in Vanilla mode (partial nudity) — Sindae's revealing BCB art.
- Tiefling females (e.g. Karlach) not yet supported; HUM_F + Githyanki only.
- Draped/slinky dresses on BCB conform approximately; baked-body garments keep their original BCB look by design; Shar Leggings + Oathbreaker Heels excluded; multiplayer limited/experimental.

## v1.1

- Added Drow and Half-Drow Tav/Durge support (body switch now works on those subraces).

## v1.0

- Initial release: per-character body shape (Vanilla / SBBF / BCB) applied to the controlled character and saved per character, with automatic refitting of equipped base-game clothing and armor; MCM UI, console commands, and optional hotkeys.
