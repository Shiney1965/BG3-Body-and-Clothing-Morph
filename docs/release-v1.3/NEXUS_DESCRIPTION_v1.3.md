# Body and Clothing Morph for SBBF and BCB - v1.3

## New tattoo bleedthrough fix - set this first

v1.3 fixes the SBBF/BCB body-tattoo bleedthrough and incorrect-atlas behavior confirmed in the tested KAVT NVP/non-VT setup.

After installation, open MCM and find **SBBF/BCB body tattoos**:

- **Match Vanilla** - default. Preserves the character's saved tattoo selection and applies compatible tattoo material behavior to naked SBBF and BCB bodies.
- **Hide on SBBF/BCB** - hides the body tattoo on naked SBBF and BCB bodies while leaving Vanilla and the saved tattoo selection untouched.

Both modes, including switching between them, passed the v1.3 release gameplay smoke test.

## What the mod does

Choose Vanilla, SBBF, or BCB per character and have supported clothing and armor refit with the selected body. Choices persist in the save and can be changed through MCM, hotkeys, or Script Extender console commands.

## Also new in v1.3

- Corrects BCB faceting on six SCO meshes: Scalemail Armor, Scalemail Armor Alt, Soul Vest, Soul Vest Alt, Soul Vest Type C, and Soul Vest Type D. All six passed Alan's gameplay check.
- Consolidates the old five-PAK layout into three PAKs. The required Runtime now includes the body switcher, base-game garments, Githyanki support, and tattoo fix.
- Adds proper SBBF meshes for 32 camp-clothing variants backed by 18 meshes.
- Extends the SCO tightening pass to BCB as well as SBBF: 2,187 recorded problem vertices fell to 122 across 33 comparable garments, a 94.4% reduction.

## Upgrading from v1.2.x

Deactivate and remove the retired `ClothMorphContent.pak` and `ClothMorphGithyanki.pak` before installing v1.3. Their content is now inside `ClothMorphRuntime.pak`. Full instructions are included in `UPGRADING_TO_v1.3.md`.

## Requirements and installation

- MCM 1.19+
- BG3 Script Extender
- SCO add-on only: Scantily Clad Camp Outfits by Crosscrusade
- BCB add-on only: BCBPak by Sindae

Install Main plus only the add-ons you need, or install AIO when you use both source mods. Load ClothMorph above BCB. Do not leave duplicate older ClothMorph PAKs in the Mods folder.

## Downloads

- **Main** - required Runtime PAK and complete documentation.
- **SCO add-on** - install only when Scantily Clad Camp Outfits is installed.
- **BCB add-on** - install only when BCBPak is installed.
- **AIO** - all three PAKs and complete documentation.

## Known boundaries

- The successful visual tattoo test used KAVT NVP/non-VT. No-KAVT and KAVT VT have static coverage but were not separately gameplay-confirmed for this release.
- Some unconvertible SCO garments still use their original mesh and may clip on SBBF/BCB.
- Oathbreaker routes supplied by BCBScantily remain unresolved and are not part of Wave 03.
- Tiefling females are not supported. Scope is the human-body female family and Githyanki females.
- See the included known-issues and garment-list documents for the complete boundary.

## Credits and KAVT permission condition

SBBF by FredKarrera. BCB and BCBPak by Sindae. Scantily Clad Camp Outfits by Crosscrusade. MCM by Volitio and contributors. BG3 Script Extender and Divine/LSLib by Norbyte.

KAVT interoperability is credited to Kazstralities/Astralities/Kaz. No KAVT textures are bundled. The KAVT author permits asset use with credit and prohibits Donation Points when those assets are used; Donation Points must remain disabled for this release.
