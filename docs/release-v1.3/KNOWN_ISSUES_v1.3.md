# Known issues and test boundaries - v1.3

## Tattoo correction test boundary

- The successful gameplay test used KAVT NVP/non-VT and passed Match Vanilla, Hide on SBBF/BCB, and switching between them.
- No-KAVT and KAVT VT configurations have static coverage but were not independently gameplay-confirmed for this release.
- The release does not bundle KAVT textures. Its compatibility definitions reference installed resources where applicable.

## Open garment issues

- Oathbreaker routes supplied by BCBScantily still do not switch correctly among Vanilla, SBBF, and BCB. Wave 20 work is unfinished and not included.
- Approximately 16 SCO garments that could not be converted still ship SCO's original mesh in every body mode and may clip on SBBF/BCB. Common examples include Surgeon's Attire, Orin's outfit, and the Butler outfit.
- Some revealing BCBPak garments may appear too large in Vanilla mode because the original BCB artwork shows through at smaller proportions.
- 27 BCBPak garments remain excluded from the conversion set; see `EXCLUDED_27.md`.
- Shar Leggings and Oathbreaker Heels remain excluded.
- Moonshadow Armor on SBBF can lose its small decorative top layer when BCBPak is installed.

## Scope and source-item limitations

- Items outside the covered sets pass through unchanged by design. Mercenary Armor is a common example.
- Nightsong's Armor has no proper player-body visual in the source item and can render nude; this is not corrected here.
- SCO Monk Robe remains an untestable source-item exclusion.
- Tiefling females, including Karlach, are not supported. Supported scope is the human-body female family and Githyanki females.
- Draped or slinky dresses on BCB remain approximate.
- Multiplayer support remains limited and experimental.
