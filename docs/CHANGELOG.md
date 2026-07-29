# Changelog — Body and Clothing Morph for SBBF and BCB

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
