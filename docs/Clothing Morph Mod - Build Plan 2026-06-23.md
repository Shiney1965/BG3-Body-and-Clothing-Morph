# Clothing Morph for Specialized Bodies — Build Plan (2026-06-23)

*Bridge doc to resume in a new chat. Full detail/history is in `Clothing Morph Mod - Approach and Open Questions 2026-06-20.md` (§1–§20). Memory files also auto-load. To resume: "continue the BG3 clothing-morph project."*

## Goal (v1)
Let the player choose, **per character, in-game**, a body type (vanilla / SBBF / BCB) and have that character's **nude body** and **equipped clothing/armor** render correctly fitted to it. Scope v1 = **BT1 Feminine Regular**, all armor slots; vanilla clothing first; modded clothing only with an author opt-in marker. Identity: SerpentineShel.

## Proven mechanisms (no longer guesswork — read from working mods on this machine)
- **Nude body, per character:** `Osi.AddCustomVisualOverride(char, ccsvId)` / `Osi.RemoveCustomVisualOverride(char, ccsvId)`, where `ccsvId` is a **CharacterCreationSharedVisual (CCSV)** wrapping the body mesh — NOT a raw VisualResource. Pick the CCSV per character via a `<race>_<bodytype><shape>` map read off `entity.CharacterCreationStats` (Race/BodyType/BodyShape). Re-apply on `SavegameLoaded` to persist. (Proven by RemodelledFrameBody.)
- **Clothed armor, per character:** BG3 renders worn gear from the **equipped item's RootTemplate visual** — there is no "set the visual field" path. So swap the equipped item to a **variant whose template carries the body-fitted visual**, and graft the original's gameplay components onto it via `entity:CreateComponent(type)` + `entity:Replicate(type)` (server-side). (Proven by Transmog Enhanced.)

## Architecture (3 parts)
1. **Sidecar (offline asset pipeline)** — generates, per supported body (SBBF, BCB):
   - Body-fitted clothing meshes for vanilla outfits (MLS/IDW prototype OR Lazy Tailor — MLS/IDW validated, Blender-free; correspondence step is the quality lever).
   - **CCSV wrappers** for each body mesh (per race/variant) for the nude-body override.
   - **Transmog variant item templates** for each vanilla armor × body (template whose `Equipment.Visuals` → the body-fitted mesh), for the clothed swap.
   - Packs the result (content pak per body + the runtime mod). Requires `granny2.dll` on the path for GR2 conversion (Divine).
2. **Runtime SE mod (BG3SE Lua)** —
   - Per-character body choice stored in `PersistentVars`, re-applied on `SavegameLoaded`.
   - Nude: apply chosen body's CCSV via `AddCustomVisualOverride` (remove previous first).
   - Clothed: on equip / on body change, transmog-swap each equipped armor piece to the body-fitted variant + graft stats; revert on body change/unequip.
   - Permission marker: only process modded clothing whose author included the opt-in marker.
   - Gotchas (see memory): SE console commands need `!` prefix; the Lua sandbox has **no `os`/`io`** (use `Ext.IO.*`, `Ext.Utils.MonotonicTime()`); `Replicate` is server→client only.
3. **UI — BG3 Mod Configuration Menu (BG3MCM)** page: per-character body dropdown (vanilla / SBBF / BCB). (User has BG3MCM installed.)

## Build phases
- **Phase 0 — confirmation tests:**
  - (a) **Nude-body CCSV test** — ✅ BUILT + installed (CCSV `c0ffeeb0-d100-4b0d-9e57-5bbf00000001` wraps SBBF body Resource `672a9c38-…` in ClothMorphSpikeTest). **Awaiting in-game run:** load a HUM_F host → SE console → `server` → `!applybody` (observe nude body) / `!revertbody`. CCSV format now fully decoded (see project memory).
  - (b) **EquipmentRace probes (NEW, 2026-07-01 — run BEFORE building any transmog code)** — see §"Revised clothed-half plan" below and `ClothMorph_Build/05_equipmentrace_probe/PROBE_GUIDE.md`. If the probes pass, (c) is never built.
  - (c) **Clothed transmog test (now the FALLBACK, not the plan)** — swap one equipped armor to a body-fitted variant + graft stats, confirm it renders. *(not yet built; build only if (b) fails)*
- **Phase 1 — vertical slice:** sidecar produces the SBBF body CCSV + a handful of body-fitted clothing meshes + their variant templates; minimal runtime mod applies nude + clothed for ONE character (console-triggered); validate end-to-end on SBBF.
- **Phase 2 — breadth:** sidecar generates all vanilla armor × SBBF (then BCB); BG3MCM per-character UI; persistence + revert; load-order/compat with the user's CompatibleBodiesTooltip work.
- **Phase 3 — modded clothing + release:** define + document the author opt-in marker; sidecar converts marker-flagged modded outfits; polish, perf pass, README with credits, release.

## Status of inputs (all green)
- **Permissions:** SBBF (FredKarrera) and BCB (Sindae) both cleared — credit required, no selling, Donation Points need separate permission. (Confirm SBBF VOP mod 5040 page shows the same open terms.)
- **Toolchain:** Blender 4.2 LTS + dos2de exporter (Divine path set) verified; Divine.exe verified; LSPK/LSF tooling working; MLS/IDW deformation prototype validated on real meshes.
- **Decompiled refs (mechanism learning only, no asset reuse):** Transmog Enhanced (clothed), RemodelledFrameBody (nude body).

## Open risks / to-resolve
- ~~Transmog variant-template generation at scale (one per armor × body) — volume + correctness.~~ *(moot if EquipmentRace probes pass; transmog demoted to fallback — see §Revised clothed-half plan)*
- ~~Clothed-swap performance and save/load robustness (transmog mods hit softlocks / require save+reload for armor-type refresh).~~ *(moot for the same reason - transmog is now the fallback only)*
- P2 tail risk: a hireling sharing the host's player template would flip together with the host (origin companions proven safe 2026-07-01). Check opportunistically in-game.
- Blanket-pass cost: iterating all item root templates once per session - measure the ms figure the first run prints; chunk it if it stalls.

## Revised clothed-half plan - EquipmentRace-first (2026-07-01) - ADOPTED
*(This section was recorded in memory on 2026-07-01 but the doc write was truncated; restored 2026-07-01 when the v4 runtime was built.)*

Probes P1-P3 (see `ClothMorph_Build/05_equipmentrace_probe/PROBE_GUIDE.md`, "Interim findings") PASSED in-game on 2026-07-01, meeting the decision rule. The clothed half is now:

1. **Mint** one EquipmentRace GUID per body mod (SBBF = `c7a11e5e-0001-4b0d-9e57-5bbf00000001`, proven live).
2. **Blanket shared-mesh pass (MANDATORY, P3):** at runtime, for every item template with `Equipment.Visuals`, copy the effective Human-Female visual array (walking the DefaultParent chain) under the minted GUID. Unregistered GUIDs have NO fallback - skipping this renders gear invisible.
3. **Refit injection:** templates with real SBBF refits get the copied array with the body visual name-replaced by the refit visual (vanilla arrays hold 3 visuals - body + trim; keep the trim).
4. **Per-character flip:** write `entity.ServerCharacter.Template.EquipmentRace = <minted>` (NOT `CurrentTemplate` - stale bg3se test name), then unequip/re-equip to refresh. Original GUID recorded for restore.
5. **Persistence:** choice in PersistentVars (schema v4); template writes are session-global and NOT save-persistent, so the pass re-runs on SessionLoaded and flips re-apply on LevelGameplayStarted / SavegameLoaded.
6. **Late injection:** Equipped listener injects the minted key into any newly equipped template that lacks it (child templates do not inherit injected parent entries), then re-equips.

Eliminated by this design: variant item templates at scale, item swapping, stats grafting, transmog jank. Transmog remains the documented FALLBACK only (Phase 0c, never built unless this fails at breadth).

**Status 2026-07-01 (v4 build):** `EquipRace.lua` implemented and wired into BootstrapServer/BootstrapClient (commands `!cm_setclothed`, `!cm_erpass`, `!cm_erstatus`, `!cm_refresh`; `!cm_setbody` now drives both halves). Pak BUILT; deploy pending (BG3 was running). Next: run the test sequence in `01_runtime_se_mod/TEST_THIS_BUILD.md`.
