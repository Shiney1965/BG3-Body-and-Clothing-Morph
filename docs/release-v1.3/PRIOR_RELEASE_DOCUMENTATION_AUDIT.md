# v1.3 documentation baseline audit

## Result

**PASS.** All **11** documentation files tracked in the prior v1.2.1 release tag were enumerated and completely reviewed. The seven public/release documents were used as the wording and structure baseline; the four internal technical records were reviewed for factual context and were not copied into customer-facing documentation.

The restored v1.3 README and Nexus Markdown are byte-identical to each other. The Nexus BBCode retains the prior release's full section order and all checked tag families are balanced.

## Prior-release source manifest

Source tag: v1.2.1 (7818dbc11cfc3658a1f9c8ffb6af3465e143f2c9)

| Prior-release path | Use | Lines | Git blob bytes | Git blob ID |
|---|---|---:|---:|---|
| `README.md` | Public/release baseline | 106 | 11043 | `c56662169cc88a9f8d81ce821db498ddecfabd8e` |
| `docs/CHANGELOG.md` | Public/release baseline | 39 | 3533 | `1fc53317487fcd59f792bfef18f0e6fb635e731c` |
| `docs/Cloth Explosion Root Cause Review 2026-07-10.md` | Supporting technical record | 61 | 10762 | `49fbea9ac951bca411f6315b11bc9a8c789e9a80` |
| `docs/Clothing Morph Mod - Approach and Open Questions 2026-06-20.md` | Supporting technical record | 250 | 40675 | `3851adc77fbf3e4824fa862ad7605d37abd21bc9` |
| `docs/Clothing Morph Mod - Build Plan 2026-06-23.md` | Supporting technical record | 60 | 7937 | `963af7b926f5239c1f1e37e65bf471f0342edc05` |
| `docs/DESCRIPTION_v1.2.md` | Public/release baseline | 106 | 11043 | `c56662169cc88a9f8d81ce821db498ddecfabd8e` |
| `docs/GARMENT_LISTS_v1.2.md` | Public/release baseline | 725 | 25465 | `4d24832b79302df15490a46d492202aa302ec6ad` |
| `docs/Modder_Permission_Flag_v1.md` | Public/release baseline | 51 | 2729 | `293643f4572b3ed27dd8a9b04b341b147ba9399a` |
| `docs/Project TODO snapshot 2026-07-11.md` | Supporting technical record | 34 | 9009 | `6145e838bd8905e374f1f63450700510eb7aecc3` |
| `docs/README.md` | Public/release baseline | 63 | 3576 | `ea03a24846cf28835f011347d13a7dd2c07ace7a` |
| `docs/nexus_description.bbcode` | Public/release baseline | 145 | 11925 | `599d6cd49321174fee3a0897def87c10357d61bf` |

## Allowed v1.3 documentation changes

- Version and release date.
- Tattoo bleedthrough fix placed first, with MCM instructions for **Match Vanilla** and **Hide on SBBF/BCB**, plus the exact gameplay-test boundary.
- Three-PAK consolidation: Main Runtime now contains the body switcher, base-game garments, Githyanki support, and tattoo fix; retired Content/Githyanki PAK upgrade instructions.
- Proper SBBF meshes for 32 camp-clothing variants backed by 18 meshes.
- SCO tightening figures (2,187 to 122 across 33 comparable garments, 94.4%) and the six gameplay-approved Scalemail Armor/Soul Vest corrections.
- Githyanki true-Vanilla extension and BCB add-on unchanged status.
- KAVT credit and the resulting requirement that Donation Points remain disabled.
- v1.3-specific packaging, test evidence, and known-boundary documents.

All unrelated prior sections remain: overview, compatibility/incompatibilities, hard and soft requirements, body controls, detailed limitations, mod-author permission flag, full credits, and the prior AI disclosure.

## BBCode balance

| Tag | Opens | Closes | Result |
|---|---:|---:|---|
| `center` | 1 | 1 | PASS |
| `size` | 14 | 14 | PASS |
| `b` | 102 | 102 | PASS |
| `i` | 9 | 9 | PASS |
| `list` | 9 | 9 | PASS |
| `font` | 7 | 7 | PASS |

## Stale-reference checks

- No v1.4 references.
- No references to GARMENT_LISTS_v1.2.md or the superseded internal GARMENT_LISTS_v1.3_BASELINE_REFERENCE.md filename.
- No obsolete “All 5 paks” download language.
