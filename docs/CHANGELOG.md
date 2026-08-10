# Changelog — Body and Clothing Morph for SBBF and BCB

## v1.3 — 2026-08-10

**New**
- **Tattoo correction:** adds the MCM setting **SBBF/BCB body tattoos** with **Match Vanilla** (default) and **Hide on SBBF/BCB**. Both policies and switching between them passed the release gameplay test in the tested KAVT NVP/non-VT setup. KAVT is optional; no KAVT tattoo textures are bundled.
- **Consolidated Main Runtime:** `ClothMorphRuntime.pak` now includes the body switcher, base-game garments, Githyanki support, and tattoo fix. The separate `ClothMorphContent.pak` and `ClothMorphGithyanki.pak` are retired.
- **Camp clothing:** adds proper SBBF meshes for 32 outfit variants backed by 18 meshes.

**Improved**
- **SCO SBBF/BCB fits:** across 33 comparable garments, the recorded problem-vertex count decreased from 2,187 to 122 (94.4%), with no measured garment worsening.
- **Six SCO corrections:** Scalemail Armor, Scalemail Armor Alt, Soul Vest, Soul Vest Alt, Soul Vest Type C, and Soul Vest Type D passed gameplay review.
- **Githyanki true Vanilla:** extends the forced true-Vanilla body behavior to Githyanki.

**Packaging / compatibility**
- Distribution is now three PAKs: required Runtime, optional SCO, and optional BCB.
- `ClothMorphBCB.pak` is unchanged from v1.2.1.
- Upgraders must deactivate and remove the retired Content and Githyanki PAKs before installing v1.3.
- Because v1.3 ships KAVT compatibility definitions under the author's published permission terms, Donation Points must remain disabled.

**Test boundary**
- The tattoo gameplay pass covered KAVT NVP/non-VT. No-KAVT and KAVT VT have static test coverage but were not independently gameplay-confirmed for this release.
- Sixteen unconvertible SCO garments still use SCO's original mesh and may clip on SBBF/BCB.
- All other previously documented limitations remain unless specifically changed above.
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
