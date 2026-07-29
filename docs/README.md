# Body and Clothing Morph for SBBF and BCB — v1.2

Pick a female body shape per character — **Vanilla, SBBF, or BCB** — and your equipped armor or clothing refits to match. The choice is stored per character in your save and persists across save/load.

This README is the quick-start. The full write-up is in **DESCRIPTION_v1.2.md**; the complete per-garment coverage is in **GARMENT_LISTS_v1.2.md**.

## Downloads — pick what you need

You can install the **AIO** (everything) or just the pieces you want. Each add-on needs its own source mod; the base mod needs none.

| File | Contents | Requires |
|------|----------|----------|
| **AIO** | All 5 paks + docs | MCM 1.19+, BG3SE (BCBPak / SCO only if you use those add-ons) |
| **Base (main file)** | ClothMorphRuntime + ClothMorphContent + docs | MCM 1.19+, BG3SE |
| **BCB add-on** | ClothMorphBCB | Base + **BCBPak by Sindae (Nexus 2351)** |
| **SCO add-on** | ClothMorphSCO | Base + **Scantily Clad Camp Outfits by Crosscrusade (Nexus 2617)** |
| **Githyanki add-on** | ClothMorphGithyanki | Base |

The base mod (ClothMorphRuntime + ClothMorphContent) is required by every add-on.

## Requirements

**Hard (base mod):**
- **BG3 Mod Configuration Menu (MCM)** — Nexus 9162 — v1.19 or newer (for hotkeys).
- **BG3 Script Extender (BG3SE)** — by Norbyte.

**Per add-on (only if you install that add-on):**
- BCB add-on → **BCBPak by Sindae** (Nexus 2351).
- SCO add-on → **Scantily Clad Camp Outfits** (Nexus 2617). (The Mod.io version will probably work too.)

**Soft (optional, base mod):** SBBF (Nexus 4864) + its Vanilla Outfits Patch (5040); BCB by Sindae (2351) — for the SBBF/BCB body on NPCs or their body-specific clothing.

## Install

1. Install the hard requirements (MCM 1.19+, BG3SE).
2. Install this mod's paks with your mod manager (BG3MM or MO2). Install the Base first, then any add-ons whose source mods you have.
3. **Load order:** load the ClothMorph paks **ABOVE BCB**.

## Use

- **MCM:** open the Mod Configuration Menu → "Body shape" radio picker (Vanilla / SBBF / BCB) for the character you currently control. To set another party member, switch to control them and set it again.
- **Hotkeys:** bind the "cycle body" / direct-set keys in MCM keybindings (unbound by default; requires MCM 1.19+).
- **Console:** `!cm_setbody vanilla`, `!cm_setbody sbbf`, `!cm_setbody bcb`.

## What's in this build (counts)

- **Base-game garments (Vanilla / SBBF / BCB):** ~405 refit meshes + 74 clean-vanilla clones.
- **BCB add-on:** 154 garments morphed (27 excluded — see garment lists).
- **SCO add-on:** 76 garment meshes (58 with the improved SBBF fit; 18 keep their prior look).
- **Githyanki add-on:** body switch + refits for Githyanki females (Lae'zel).

## Notes & limitations (short version — full list in the Description)

- With BCB or SBBF installed you can still change the body of any character **while you control it** (v1.2 improvement).
- Some Sindae BCB garments may look too large in **Vanilla** mode (partial nudity) — that's Sindae's revealing BCB art.
- Tiefling females (Karlach) are not yet supported. HUM_F + Githyanki only.
- Items outside the covered sets pass through unchanged by design. Multiplayer is limited/experimental.

## Credits & permissions

FREE, and must stay free. Credits: Sindae (BCB 2351), FredKarrera (SBBF 4864 + 5040), Volitio/AtilioA (MCM 9162), Norbyte (BG3SE), Crosscrusade (SCO 2617). See DESCRIPTION_v1.2.md for full credits and the AI-assistance disclosure.

Source: https://github.com/Shiney1965/BG3-Body-and-Clothing-Morph
