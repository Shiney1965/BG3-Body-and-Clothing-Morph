# ClothMorph Modder Permission Flag — Spec v1 (2026-07-10)

**Purpose:** ClothMorph's Path-B refit pipeline can mechanically generate SBBF/BCB refits for any garment mod, but we only process third-party assets with the author's permission. This spec defines a machine-readable opt-in that modders drop into their own pak, which our **offline build pipeline** (not the runtime) reads before processing.

## The flag

A JSON file inside the mod's pak at:

```
Mods/<ModFolder>/ClothMorphPermission.json
```

(next to the mod's `meta.lsx`; any `*/ClothMorphPermission.json` found in the pak listing is accepted).

```json
{
  "spec_version": 1,
  "mod_name": "Example Armour Pack",
  "mod_uuid": "00000000-0000-0000-0000-000000000000",
  "author": "ExampleAuthor",
  "permission": "granted",
  "bodies": ["sbbf", "bcb"],
  "items": "*",
  "credit_line": "Example Armour Pack by ExampleAuthor (Nexus mod #00000)",
  "url": "https://www.nexusmods.com/baldursgate3/mods/00000",
  "date": "2026-07-10",
  "notes": ""
}
```

Field rules:
- `mod_uuid` **must match** the UUID in the pak's own `meta.lsx` (pipeline cross-checks; prevents third parties granting permission for someone else's pak).
- `permission`: `"granted"` or `"denied"` (denied = explicit refusal, pipeline hard-skips and records it).
- `bodies`: subset of `["sbbf","bcb"]` or `["*"]` for any current/future body.
- `items`: `"*"` or an explicit list of GR2 basenames and/or VisualResource UUIDs.
- `credit_line`: verbatim string we must include in our credits section.

## Pipeline behavior

1. Before processing any non-vanilla pak, list it and look for the flag file. No flag → **do not process** (log as `no-permission`).
2. Flag present → validate `mod_uuid` against `meta.lsx`; validate JSON against this spec; on failure, treat as no flag and log the reason.
3. Record every accepted flag in the build's `permissions_manifest.json` (source pak, hash of the flag file, fields) — this drives the credits section of the Nexus page/README, reusing the CompatibleBodiesTooltip credits-tooling pattern.

## Manual override (permission given in writing, no flag in pak)

For authors who grant permission by DM/comment but don't ship the file: we record the same JSON object ourselves in `ClothMorph_Build/permissions_local_overrides.json`, plus a `evidence` field (where/when permission was given). The pipeline treats a local override identically to an in-pak flag. In-pak `"denied"` always wins over a local override.

## Non-goals

- Not a runtime mechanism: the shipped ClothMorph pak contains only content that was already permission-checked at build time.
- Not a license: it's an opt-in signal + credit contract; the mod's own license terms still govern.
