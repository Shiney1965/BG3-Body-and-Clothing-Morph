# Body and Clothing Morph for SBBF and BCB — v1.3

Pick a female body shape per character — **Vanilla, SBBF, or BCB** — and your equipped armor or clothing refits to match. The choice is stored per character in your save and persists across save/load.

This README is the quick-start. The full write-up is in **NEXUS_DESCRIPTION_v1.3.md**; the complete per-garment coverage is in **GARMENT_LISTS_v1.3.md**.

## Downloads — pick what you need

You can install the **AIO** (everything) or just the pieces you want. Each add-on needs its own source mod; the base mod needs none.

| File | Contents | Requires |
|------|----------|----------|
| **AIO** | All 3 paks + docs | MCM 1.19+, BG3SE (BCBPak / SCO only if you use those add-ons) |
| **Main file** | ClothMorphRuntime + docs | MCM 1.19+, BG3SE |
| **BCB add-on** | ClothMorphBCB | Main + **BCBPak by Sindae (Nexus 2351)** |
| **SCO add-on** | ClothMorphSCO | Main + **Scantily Clad Camp Outfits by Crosscrusade (Nexus 2617)** |

The Main mod (`ClothMorphRuntime.pak`) is required by every add-on. It now includes the body switcher, base-game garments, Githyanki support, and tattoo fix.

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
2. If upgrading from v1.2.x, deactivate and remove the retired `ClothMorphContent.pak` and `ClothMorphGithyanki.pak` first; see **UPGRADING_TO_v1.3.md**.
3. Install the Main Runtime, then any add-ons whose source mods you have.
4. **Load order:** load the ClothMorph paks **ABOVE BCB**. Do not leave duplicate older ClothMorph PAKs in the Mods folder.

## Use

- **MCM:** open the Mod Configuration Menu → "Body shape" radio picker (Vanilla / SBBF / BCB) for the character you currently control. To set another party member, switch to control them and set it again. The **SBBF/BCB body tattoos** setting selects **Match Vanilla** (default) or **Hide on SBBF/BCB**.
- **Hotkeys:** bind the "cycle body" / direct-set keys in MCM keybindings (unbound by default; requires MCM 1.19+).
- **Console:** `!cm_setbody vanilla`, `!cm_setbody sbbf`, `!cm_setbody bcb`.

## What's in this build (counts)

- **Main Runtime:** 343 distinct base-game garment meshes / 1,321 active refits, plus Githyanki support and the tattoo fix.
- **BCB add-on:** 154 garments morphed (27 excluded — see garment lists).
- **SCO add-on:** 79 meshes per body folder; v1.3 extends tightening to BCB and corrects six gameplay-approved Scalemail Armor/Soul Vest meshes. Sixteen unconvertible garments still use SCO's original mesh.
- **Githyanki:** body switch + refits for Githyanki females (Lae'zel), included in Main.

## Notes & limitations (short version — full list in the Description)

- **Tattoo fix:** use MCM to choose **Match Vanilla** or **Hide on SBBF/BCB**; both passed the v1.3 gameplay smoke test in the tested KAVT NVP/non-VT setup.
- With BCB or SBBF installed you can still change the body of any character **while you control it** (v1.2 improvement).
- Some Sindae BCB garments may look too large in **Vanilla** mode (partial nudity) — that's Sindae's revealing BCB art.
- Tiefling females (Karlach) are not yet supported. HUM_F + Githyanki only.
- Items outside the covered sets pass through unchanged by design. Multiplayer is limited/experimental.

## Tattoo Function Tested with the Following Tattoo Mod List:

Relevant KAVT and tattoo entries in their exact top-to-bottom order in the tested load order (unrelated intervening mods omitted):

1. **UT/KAVT Universal Automatic Patcher**
2. **KAVT NVP - KAZSTRA Virtual Tav x Tattoo, Makeup & Scar Extender**
3. **Rogue Tattoo**
4. **KAZSTRA CC Body Tattoo Selector**
5. **KAZSTRA Virtual Tav x Tattoo, Makeup & Scar Extender - Customization Patch**
6. **KAZSTRA Virtual Tav x Tattoo, Makeup & Scar Extender - EotB Patch**
7. **BhaalistTats**
8. **More Makeup and Tattoos**
9. **More Makeup and Tattoos - Unique Tav Patch**
10. **More Makeup and Tattoos Icons**

This is the gameplay-tested configuration, not a requirement to install every listed mod. KAVT is optional; no-KAVT and KAVT VT were not independently gameplay-confirmed for v1.3.

## Credits & permissions

FREE, and must stay free. Donation Points must remain disabled for v1.3 because it ships KAVT compatibility definitions under the author's published terms. Credits: Sindae (BCB 2351), FredKarrera (SBBF 4864 + 5040), Volitio/AtilioA (MCM 9162), Norbyte (BG3SE), Crosscrusade (SCO 2617), and Kazstralities/Astralities/Kaz (KAVT 16325). See NEXUS_DESCRIPTION_v1.3.md for full credits and the unchanged prior AI-assistance disclosure.

Source: https://github.com/Shiney1965/BG3-Body-and-Clothing-Morph
