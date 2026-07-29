-- ===========================================================================
-- ClothMorphRuntime / EquipRace.lua                          (SERVER ONLY)
-- ---------------------------------------------------------------------------
-- The EquipmentRace clothed-half runtime (adopted 2026-07-01 after probes
-- P1/P2/P3 PASSED in-game; transmog swap/graft is dead as the primary plan).
--
-- MECHANISM (all proven live 2026-07-01, see 05_equipmentrace_probe/PROBE_GUIDE.md):
--   * Vanilla armor renders per-EquipmentRace via
--       ItemTemplate.Equipment.Visuals : HashMap<EquipmentRaceGuid, Array<VisualId>>
--     Lua table assignment into that HashMap WORKS at runtime.
--   * Flipping a character's clothed body = write
--       entity.ServerCharacter.Template.EquipmentRace = <minted GUID>
--     (NOT entity.CurrentTemplate / ServerCharacter.CurrentTemplate - those
--     paths are invalid; confirmed in-game.)
--   * P3 GOTCHA: an unregistered EquipmentRace GUID has NO fallback - any item
--     without a Visuals entry under our GUID renders INVISIBLE. Therefore the
--     BLANKET PASS below (copy each item's effective vanilla array under our
--     GUID) is MANDATORY before any character is flipped.
--   * Child templates that redeclare Equipment do NOT inherit injected parent
--     entries -> we also inject on the template ACTUALLY equipped (Equipped
--     listener + pre-flip sweep of the char's equipped items).
--   * Template writes are session-global and NOT save-persistent -> re-run the
--     pass on SessionLoaded and re-apply flips after level/savegame load.
--
-- Gotchas obeyed: no os.*/io.* (Ext.* only); every risky step pcall'd; ASCII.
-- ===========================================================================

local M = {}

local function Log(msg)  Ext.Utils.Print("[ClothMorphRuntime:EquipRace] " .. tostring(msg)) end
local function Warn(msg) Ext.Utils.PrintWarning("[ClothMorphRuntime:EquipRace] " .. tostring(msg)) end

-- ---------------------------------------------------------------------------
-- Minted EquipmentRace GUIDs (ours; unregistered anywhere else).
-- v1 ships ONE: SBBF for the Human-Female family (BT1 Feminine Regular).
-- The SBBF GUID is the exact GUID proven live in probe P1.
-- ---------------------------------------------------------------------------
M.MINTED = {
    sbbf = "c7a11e5e-0001-4b0d-9e57-5bbf00000001",
    bcb = "c7a11e5e-0002-4b0d-9e57-5bbf00000002",  -- BCB (Beautiful Curvy Body); refit set added 2026-07-05
    vanilla = "c7a11e5e-0003-4b0d-9e57-5bbf00000003", -- clean-vanilla override (defeats BCB's in-place VR override); added 2026-07-15
}

-- Human Female is the source race whose visual arrays the blanket pass copies.
M.SOURCE_RACE = "71180b76-5752-4a97-b71f-911a69197f58"  -- Human Female (BT1)

-- ---------------------------------------------------------------------------
-- KNOWN_ORIG - recovery table of original EquipmentRace GUIDs, keyed by bare
-- lowercase character GUID. Used ONLY when a character's OrigEquipRace was
-- never captured (nil) AND its live EquipmentRace is already our minted GUID -
-- the "corrupted save" state (found 2026-07-04: origin/unique AND player
-- templates PERSIST our EquipmentRace write across save/reload, so on a later
-- session `cur` is already minted and the true original is lost). Entries here
-- let revert still work. See M.ForceSetEquipRace / !cm_seterace for a manual
-- recovery path that does not depend on this table.
-- CONFIDENCE:
--   * Shadowheart 3ed74f06 -> 76217761: original ER observed live at probe P2
--     (2026-07-01) before any corruption. Origin companion GUIDs are stable
--     across playthroughs; treat as high-but-verify.
--   * Tav c2a5ae28 -> ad21d837: Alan's Tav = Elf/Drow Female; ad21d837 is the
--     standard Elf/Drow-F EquipmentRace (in PARENT map). The Tav *character*
--     GUID is SAVE-SPECIFIC (generated per playthrough) -> this row only helps
--     Alan's current save and MUST be removed / generalized before any release.
-- ---------------------------------------------------------------------------
M.KNOWN_ORIG = {
    ["3ed74f06-3c60-42dc-83f6-f034cb47c679"] = "76217761-eeac-47bb-b273-fab583ee3b57", -- Shadowheart (P2 observed; origin GUID stable across playthroughs)
    -- NOTE (release hygiene, 2026-07-21): a save-specific dev Tav row was removed
    -- here for public release (per-playthrough character GUIDs never generalize;
    -- use !cm_seterace / M.ForceSetEquipRace for per-save manual recovery instead).
}

-- EquipmentRace DefaultParent chain (SharedDev EquipmentRaces.lsx, Patch 8,
-- 24 entries; only the parented ones matter for chain walks). Lowercase keys.
local PARENT = {
    ["7dd0aa66-5177-4f65-b7d7-187c02531b0b"] = "7d73f501-f65e-46af-a13b-2cacf3985d05", -- Elf/Drow M -> Human M
    ["ad21d837-2db5-4e46-8393-7d875dd71287"] = "71180b76-5752-4a97-b71f-911a69197f58", -- Elf/Drow F -> Human F
    ["a0737289-ca84-4fde-bd52-25bae4fe8dea"] = "7d73f501-f65e-46af-a13b-2cacf3985d05", -- Half-Elf M -> Human M
    ["541473b3-0bf3-4e68-b1ab-d85894d96d3e"] = "71180b76-5752-4a97-b71f-911a69197f58", -- Half-Elf F -> Human F
    ["6503c830-9200-409a-bd26-895738587a4a"] = "7d73f501-f65e-46af-a13b-2cacf3985d05", -- Tiefling M -> Human M
    ["cf421f4e-107b-4ae6-86aa-090419c624a5"] = "71180b76-5752-4a97-b71f-911a69197f58", -- Tiefling F -> Human F
    ["f07faafa-0c6f-4f79-a049-70e96b23d51b"] = "7d73f501-f65e-46af-a13b-2cacf3985d05", -- Githyanki M -> Human M
    ["06aaae02-bb9e-4fa3-ac00-b08e13a5b0fa"] = "71180b76-5752-4a97-b71f-911a69197f58", -- Githyanki F -> Human F
    ["9a8bbeba-850c-402f-bac5-ff15696e6497"] = "e39505f7-f576-4e70-a99e-8e29cd381a11", -- Dragonborn M -> Human Strong M
    ["6d38f246-15cb-48b5-9b85-378016a7a78e"] = "47c0315c-7dc6-4862-b39b-8bf3a10f8b54", -- Dragonborn F -> Human Strong F
    ["eb81b1de-985e-4e3a-8573-5717dc1fa15c"] = "47c0315c-7dc6-4862-b39b-8bf3a10f8b54", -- Half-Orc F -> Human Strong F
    ["6dd3db4f-e2db-4097-b82e-12f379f94c2e"] = "e39505f7-f576-4e70-a99e-8e29cd381a11", -- Half-Orc M -> Human Strong M
    ["a5789cd3-ecd6-411b-a53a-368b659bc04a"] = "47c0315c-7dc6-4862-b39b-8bf3a10f8b54", -- Tiefling F Strong -> Human Strong F
    ["6326d417-315c-4605-964e-d0fad73d719b"] = "a5789cd3-ecd6-411b-a53a-368b659bc04a", -- Karlach -> Tiefling F Strong
    ["f625476d-29ec-4a6d-9086-42209af0cf6f"] = "e39505f7-f576-4e70-a99e-8e29cd381a11", -- Tiefling M Strong -> Human Strong M
}

-- ---------------------------------------------------------------------------
-- REFIT_BY_VR - generalized refit map (2026-07-05, generalization phase).
-- Key   : vanilla VisualResource GUID (lowercase) that has an SBBF-refit mesh.
-- Value : minted refit VisualResource GUID (in ClothMorphContent's combined
--         VisualBank [PAK]_ClothMorph_Refits/_merged.lsf).
-- The injector copies each item's Human-Female Visuals array and, for every
-- entry whose VR id is a key here, swaps in the refit VR id. Keyed PER VR (not
-- per item, not per GR2 basename) because a single GR2 is shared by multiple
-- VRs with DIFFERENT materials (51/342 in-zone GR2 confirmed 2026-07-05) - the
-- refit VR carries that VR's own vanilla materials, so per-VR keying is the
-- only materially-correct mapping. Replaces the old per-item/SourceFile-basename
-- REFIT_MAP (which was ambiguous for shared GR2). Refit IDs are uuid5-minted
-- from the vanilla VR id (see gen_visualbanks.py; namespace c7a11e5e-0000-...).
-- v1 SMALL VALIDATION BATCH (5 items): leather(control) + plate + wizard robe +
-- skirt + chainshirt(DAE-fallback path).
-- ---------------------------------------------------------------------------
M.REFIT_BY_VR = {
    vanilla = {  -- clean-vanilla clones (new GUIDs; SourceFile=vanilla GR2) -> override BCB in-place VR redefinition. gen 2026-07-15, 405 items.
        ["089ee9e1-e764-38dd-c742-fd905f976f13"] = "c58443a9-a6b4-5f88-bc95-06914046c9e2",  -- HUM_F_ARM_BarbarianMagical_A_Chest (synthesized node; VR lives in [PAK]_Male_Armor)
        ["d7196f12-bfcb-84d7-b96d-088284ef2a7f"] = "6040b4e6-45e0-5457-86e9-7d527447da62",  -- HUM_F_ARM_Scalemail_Paladin_OathOfCrown_Body (synthesized node)
        ["02964f77-c398-423b-a5e9-f7810243811c"] = "472210b6-5947-5c56-830d-994f9ff5adb2",  -- HUM_F_ARM_Adventurer_Body_A
        ["ed8e5366-bfa5-91c4-9eae-9ef39f402214"] = "86c5fdca-be6c-5103-8a22-58775d8a4497",  -- HUM_F_ARM_Astarion_Body
        ["7187c0c1-3752-5d43-9858-7b72fdb0fa3c"] = "11cdd5f3-39d4-5711-ac74-d920e8815b31",  -- HUM_F_ARM_Astarion_Pants
        ["51ae8337-9dd3-8552-f4c2-85e755a44503"] = "83489103-b03e-5ded-ac50-f32a5a31ac7e",  -- HUM_F_ARM_BG_Watch_A_Pants
        ["3a2f737e-8f3d-a59b-d457-36e89775d423"] = "ee42bb84-934c-5020-8c90-4f60cd26e78c",  -- HUM_F_ARM_BG_Watch_B_Pants
        ["f395018f-ffb4-03e8-add9-ed9698fb1e51"] = "509028d8-4c0d-5c79-ae2d-cfba926a7d75",  -- HUM_F_ARM_BG_Watch_C_Pants
        ["a2edea05-8d9d-4d60-c128-6484fec0727c"] = "df79058a-eff5-5714-a2a0-b604ed0e15fb",  -- HUM_F_ARM_BG_Watch_Leather_A_Body
        ["6bcaace7-2b7f-f347-bbbf-b7f6de1b406c"] = "1115d7c0-aad9-575d-8280-8adb26a9a965",  -- HUM_F_ARM_BG_Watch_Leather_B_Body
        ["7eecdfb8-78f4-791c-dcdb-dce69bcf89a4"] = "b30a0ae5-e608-5bad-8eba-06763efa9f87",  -- HUM_F_ARM_BG_Watch_Metal_A_Body
        ["73eaa7e2-e2c4-bb99-8cdd-c02bce1979f7"] = "eb9ecb15-9054-517c-a3fd-0907f810d927",  -- HUM_F_ARM_Bandit_A_Body
        ["c18aac16-80cf-b3a1-7a68-2321e4e7f26d"] = "1016a100-8f5b-57e2-94cf-cc1ae0296747",  -- HUM_F_ARM_Bandit_A_Long_Body
        ["4bf4a998-d2ae-a670-b31b-6efff35a28a4"] = "dc058110-8785-50bf-ad3e-be993dd270bb",  -- HUM_F_ARM_Bandit_A_Pants
        ["2ec28d08-14cd-cf28-a750-ce566d791ef8"] = "5ac76741-ea05-53d7-a6d6-16311bfe330f",  -- HUM_F_ARM_Bandit_B_Body
        ["fe22e643-1266-a94a-0b42-eba64f922d8b"] = "d877bf7a-6ebd-5597-89b5-a216cf79b707",  -- HUM_F_ARM_Bandit_C_Body
        ["904fbbc1-fca5-af69-66b0-f883728baf77"] = "3943ee8e-9282-5ff3-92fb-390690f71fe8",  -- HUM_F_ARM_Bandit_C_Body_Accessories
        ["5b042a61-3dcc-4a82-a2bf-b710f04abb81"] = "23bff0a3-4dde-5367-b166-fa45ea8b2d2d",  -- HUM_F_ARM_Bandit_D_Body
        ["aa476663-1b31-19af-8e56-d071a91b74e8"] = "291a3326-1805-526e-a9d2-ad5aa6ae6ea0",  -- HUM_F_ARM_Bandit_D_Body_Belt_A
        ["67cf64e2-d4df-d5c8-c988-bbe24c9ab0ef"] = "39b7bf39-c4e9-52bf-b704-0a6658ffaed6",  -- HUM_F_ARM_Bandit_D_Body_Belt_B
        ["d2f744a0-4d40-1da3-bc2d-188cab1cf9cc"] = "18e7f795-df28-5fb9-8a03-9200886a3ec4",  -- HUM_F_ARM_Bane_Light_Body_A
        ["c6f30055-6e56-88ec-afff-8b16e0861797"] = "a86b7957-6426-512e-9658-6270e386c8e4",  -- HUM_F_ARM_Bane_Light_Body_B
        ["c390c1b4-9592-e7bd-45c7-25de362c39d0"] = "80e0ebdc-f0c7-5114-b5de-c6dbc91f03d4",  -- HUM_F_ARM_Bane_Light_Pants_A
        ["070fb86b-3b1c-07b6-bda6-ae3f54e6202c"] = "a6f6f544-7a01-5d90-8f90-bb59699cd1b9",  -- HUM_F_ARM_Bane_Plate_Body_B
        ["4e6a8fd0-0f1b-97d5-2938-156505003b0c"] = "8b7a6f2b-1606-5c37-81ed-13f854245f15",  -- HUM_F_ARM_Bane_Plate_Body_A
        ["dde52dc3-cb63-0d90-393e-f3d9c3b8967b"] = "fb09406e-cd79-5176-adf5-0533e2ca33e9",  -- HUM_F_ARM_Bane_Robe_Body_A
        ["3fb7ea07-c5dc-954b-c58a-a8ec276ace28"] = "037aefab-11fc-564f-ad00-df1587d9a9fd",  -- HUM_F_ARM_Bane_Robe_Body_A_Sleeve
        ["6671bb2f-ab3c-ce01-30c5-05ab81e64ec4"] = "eea2d96c-1d75-5e3b-b3d8-19ce828ae071",  -- HUM_F_ARM_Bane_Robe_Body_A_Sleeves
        ["577e0453-07bb-c66e-33b1-7bee394c1a7f"] = "61ead6ca-2dfe-5f87-ae6c-6dc2b26f41b7",  -- HUM_F_ARM_BarbarianMagical_A_Body
        ["7723fc3b-12a2-9f4f-d753-adaf00b281ec"] = "2a7f1e3b-fb34-5b58-88cf-1574c42ac91c",  -- HUM_F_ARM_BarbarianMagical_A_Pants
        ["bcdf262d-b528-2448-76cb-3444588738a4"] = "47baf8f7-3f6f-5492-ad61-12bef4a20990",  -- HUM_F_ARM_BarbarianMagical_B_Body
        ["0aed3d1c-709d-3f1e-71f1-1134ba9e060e"] = "05324107-57e2-579b-b247-e6988f3e0e76",  -- HUM_F_ARM_BarbarianMagical_B_Chest
        ["40c284ef-a371-eec7-a27a-dd277dee03cb"] = "2b71a807-238a-5b51-85ae-e3e07f5b712c",  -- HUM_F_ARM_BarbarianMagical_B_Pants
        ["991c652e-3aa8-f8b1-609a-f8bd87b28636"] = "f6d35c00-66de-5d17-840c-376cb158b86a",  -- HUM_F_ARM_Barbarian_A_Body
        ["1b60efd1-c080-f02e-4b7c-988699485ae0"] = "e2aa8a29-7ad2-54a9-beb7-3a3e533d960f",  -- HUM_F_ARM_Barbarian_A_Pants
        ["11a29e17-99fd-0db5-ec2e-d90a40ec5b1f"] = "3ff3a99f-b854-5d76-912c-ffb544896507",  -- HUM_F_ARM_Barbarian_Karlach_A_Body
        ["7cc5cafc-2bb8-3627-97e0-125d2c4fd084"] = "27da9caa-033a-550d-8935-29d386bec8a0",  -- HUM_F_ARM_Barbarian_Karlach_A_Pants
        ["34fbe3a5-7d74-c705-a42c-4e9922fa12fc"] = "ca3d61f5-e2cd-566e-8aff-ff253585ffec",  -- HUM_F_ARM_Bard_BodyBot
        ["69bf1065-75ae-2930-33b8-ac4a5bdde0ad"] = "0e45763b-1d97-587c-ba5c-d4ab8772ad78",  -- HUM_F_ARM_Bard_BodyTop
        ["29153218-c410-bd1e-b23d-d615ead06201"] = "a6634417-4b93-5a0c-9e82-b7666e65f692",  -- HUM_F_ARM_Bard_Pants
        ["a8b54d83-bbba-1c0c-a3a0-f8143409b018"] = "b9b2298d-7e82-5c12-b8f6-f407c0f87a01",  -- HUM_F_ARM_Bhaal_A_Body
        ["aa09792f-4f55-dd17-c2f5-7ca30642a95c"] = "c3a65cfb-42bc-597f-a40f-8356604c6d7a",  -- HUM_F_ARM_Bhaal_A_Pants
        ["f8c9f76d-d57e-d818-f028-6be46ef6ac5a"] = "39d8f533-121d-57ce-842a-00de75d403ac",  -- HUM_F_ARM_Bhaal_Rags_Body
        ["5e07542e-8dd0-ef58-ef8e-f9c92a9a5670"] = "c45fd58a-ea1d-5c97-b10e-fef759263820",  -- HUM_F_ARM_Bhaal_Rags_Pants
        ["9a255759-35b9-2aca-77d4-b8b331091887"] = "f8c5b00c-4b87-55ec-8b43-0db824f0b2f2",  -- HUM_F_ARM_BreastPlate_A_0_Body
        ["40d6023f-73cc-cf97-7b7c-e0efa5ef2252"] = "a949694b-85df-551b-a358-86fbd551b825",  -- HUM_F_ARM_BreastPlate_A_1_Body
        ["41f442ce-a9dd-57b1-8703-c0612de681ba"] = "273be19d-6531-5b1c-8dc8-649e0653c02b",  -- HUM_F_ARM_BreastPlate_A_2_Body
        ["2d76e68d-122c-ca1b-eae6-2754d6f2a427"] = "690fb051-8e19-50aa-80ae-4a1954acdfc0",  -- HUM_F_ARM_Breastplate_A_1_Pants
        ["52a0a341-e040-3d36-14cf-9ddbb1964d86"] = "3b7bcbb2-8724-5d51-b99d-42fba306aaa8",  -- HUM_F_ARM_Breastplate_A_0_Pants
        ["7842adad-0d32-2845-321a-ae53e02759c7"] = "98f1b4ad-b884-5931-9210-f34d24030a55",  -- HUM_F_ARM_Breastplate_A_2_Pants
        ["4b220494-227c-2286-06e7-81f5aa621fbc"] = "23fdbbb3-4116-5dce-806c-f9367a9a3395",  -- HUM_F_ARM_ChainMail_A_0_Body
        ["746d3091-9b4e-05d2-d6e3-990e88b4e697"] = "808d653d-cd0e-5260-8257-429f859a06a1",  -- HUM_F_ARM_ChainMail_A_1_Body
        ["ea647791-dae1-f65a-4045-d971868d70a7"] = "5e55f124-ae42-5eb4-9358-de843a76ea35",  -- HUM_F_ARM_FlamingFist_ChainMail_A_1_Body
        ["7a0a8086-cf8a-8526-7196-3f96c1a31764"] = "df6f235e-c059-5ab7-9070-5e11b1d50117",  -- HUM_F_ARM_ChainMail_A_2_Body
        ["57aa9036-497a-bc54-7889-763bcf0f5ecd"] = "67694d50-a0ab-5d56-ac98-2a39723b13cc",  -- HUM_F_ARM_ChainMail_A_Pants
        ["c977d6cf-90ba-08f5-0d6a-96bfcbc2ff37"] = "915c80d7-04dc-5990-95c9-2d05ccc74aee",  -- HUM_F_ARM_ChainShirt_A_0_Body
        ["e5b5a50e-2200-ee2a-2cac-1868323d3c2b"] = "6441f822-914a-5822-90d8-e4260cdc3254",  -- HUM_F_ARM_ChainShirt_A_1_Body
        ["adc9638c-946d-f253-fab5-a2185780e38e"] = "dbf9a3e7-d775-573d-9be8-3c42190f7536",  -- HUM_F_ARM_ChainShirt_A_2_Body
        ["c18914df-2ecd-7418-df18-e27521d89e07"] = "27918870-626d-5901-8591-16d93f832c46",  -- HUM_F_ARM_ChainShirt_B_0_Body
        ["f6000495-b090-d2fc-1d8c-8b3269ac469d"] = "19cc0610-89b7-54fd-a425-6d0b228de8d1",  -- HUM_F_ARM_ChainShirt_B_0_Broken_Body
        ["f8be761d-9160-c57d-fd57-436735b91403"] = "65e261bf-e586-5f04-b04b-201445f5fdca",  -- HUM_F_ARM_ChainShirt_B_1_Body
        ["9a04bfd8-2a6f-a2b6-6c18-3921a81df32e"] = "4bdafb8e-3c74-5697-a940-98ef206f504c",  -- HUM_F_ARM_ChainShirt_B_2_Body
        ["7f17b0c8-69dc-799f-457f-aa9b0edf87cf"] = "b2f628f6-6256-54e4-b529-dd09771e8270",  -- HUM_F_ARM_ChainShirt_B_2_Pants
        ["86beb015-ba3b-e2f5-8fc1-a13eaae763ed"] = "4718df68-1d5c-5b4c-8e9d-6d95780f37c6",  -- HUM_F_ARM_ChainShirt_B_Broken_Pants
        ["2a24cc0a-bf6a-042b-3d02-237596da3a02"] = "c3d8595f-19f2-592c-b45f-d4bcb105fd45",  -- HUM_F_ARM_ChainShirt_B_Pants
        ["46d2d271-a292-6511-ab69-b5b3fb8d4732"] = "7ea0a1a1-635b-52be-8bd9-e905c1721d01",  -- HUM_F_ARM_ChainShirt_Shadowheart_A_Body
        ["355acc60-c8ae-129a-f9b8-fd46d66a9cd9"] = "04392424-7085-571a-9e4a-558d33951e00",  -- HUM_F_ARM_Cloth_Magic_A_Chest
        ["7626ae1c-1f46-fc33-f267-fa42d6f00a5f"] = "09df102a-e819-5cec-93f5-00615aee43b0",  -- HUM_F_ARM_Cloth_Magic_A_Pants
        ["75fe0fe7-8b43-7c04-d6ff-559601640e7b"] = "6e357589-b15b-5d44-b2b8-ce82e1c8e3e4",  -- HUM_F_ARM_Cloth_Magic_B_Chest
        ["fcfff744-87aa-18d1-71b6-dd3dde8ffd2f"] = "60fc3338-61a9-5e49-baa3-dd0a27fe4a0c",  -- HUM_F_ARM_Cloth_Magic_C_Chest
        ["d1228194-ed35-a085-f73b-469f46be1a63"] = "dfa38157-be33-5c62-8842-0819640c699c",  -- HUM_F_ARM_Cloth_Magic_B_Pants
        ["d1c28da5-1518-5565-e948-546ff74f14b9"] = "eb5accdc-5f69-5795-8e20-a2128536bc6a",  -- HUM_F_ARM_Cult_Absolute_Body_A
        ["40c6743d-7f7b-9a36-ea69-ee5be3fd42ef"] = "c439a849-528f-5761-8b06-bd883472ba0c",  -- HUM_F_ARM_Cult_Absolute_Body_B
        ["e936b4b2-5c11-ff4a-a9b4-7a744844e508"] = "bbc10a33-2894-54ef-8954-8b80a7e18ce3",  -- HUM_F_ARM_Cult_Absolute_Body_C
        ["4fad5d72-61e3-a66d-5789-5adb266d5262"] = "a47112e4-a15f-5746-993a-b69a7c3c23d6",  -- HUM_F_ARM_Cult_Absolute_Pants_A
        ["f593ca9c-fb69-ce98-58b2-d240acb832ee"] = "e9fd6dd0-6e45-5821-b353-8f940fedf732",  -- HUM_F_ARM_Cult_Absolute_Pants_B
        ["92904542-5941-883f-5ef9-64ed849223c3"] = "0e0fc207-f234-5bd2-94ae-04840c04aa24",  -- HUM_F_ARM_Cult_Absolute_Robe_Body_A
        ["223c2250-b8d2-02f8-7d81-3a5dd8aba412"] = "10e03c56-36fb-539a-8af5-557354b41044",  -- HUM_F_ARM_Cult_Absolute_Robe_Body_A_Belt_A
        ["9423615d-6287-ba55-b5ac-9120d68abbf9"] = "49a695c6-4d70-516d-a5a4-5a5291033a43",  -- HUM_F_ARM_Cult_Absolute_Robe_Body_B
        ["ab01e06f-c22c-4389-6d09-170408da0397"] = "d02e7a1d-0521-5200-a5f0-30f422d96091",  -- HUM_F_ARM_Cult_Absolute_Robe_Body_C
        ["7ac2ee68-c81a-5acb-bc20-0dd74798d4ca"] = "12a8380c-a9af-5c1a-b363-5df400fa6be9",  -- HUM_F_ARM_Cult_Absolute_Skirt_A
        ["8f018691-9ad2-8fda-e332-4625fdc9be38"] = "d364d7ed-8d80-504f-8b5f-0d6939905593",  -- HUM_F_ARM_Cult_Absolute_Skirt_B
        ["6d3ff410-6a56-1570-945b-c9400294efd3"] = "e2ba218e-a90a-5b21-b69a-ed34a08b6c9c",  -- HUM_F_ARM_Daisy_Body
        ["8629e0f0-bf23-f8d7-aa26-059bdee2f274"] = "583f22eb-5ac2-5619-800b-6c7090e87b01",  -- HUM_F_ARM_Daisy_Pants
        ["47550623-1e6d-c1ee-8d8b-c104e3212add"] = "6bf119c4-8ac1-5ec1-ab20-03ce6e92ade4",  -- HUM_F_ARM_Shadowheart_Dark_Justiciar_Body_A
        ["64f991ff-b533-4095-7fe7-68484ec99438"] = "0a018a15-c61c-55e6-acf0-6e2b1fda77b5",  -- HUM_F_ARM_Dark_Justiciar_A_0_Body
        ["5878c12d-03ae-58e1-3010-76819284ebd1"] = "094f84fa-2613-5c22-b209-f594927e8b51",  -- HUM_F_ARM_Dark_Justiciar_A_1_Body
        ["ae75ef0b-1265-48c8-b295-62d0d140fe44"] = "fe741c30-668a-5007-bdb8-b818f9f09e5e",  -- HUM_F_ARM_Shadowheart_Dark_Justiciar_Pants_A
        ["b639f736-82cf-9765-bf2c-4b55725e1fdf"] = "084c51d8-44dd-53b6-aa31-ce9638eacded",  -- HUM_F_ARM_Dark_Justiciar_A_Pants
        ["da47419f-1174-c82e-a26e-e813f658d0c9"] = "4c96503f-3d16-5477-a3b2-d0839e09f5b7",  -- HUM_F_ARM_Dark_Justiciar_Damaged_A_0_Body
        ["a79c23c2-d7fd-f97d-f7c2-72b699efb3ed"] = "6e30687d-fef8-5a29-bc05-7b11ba286f2e",  -- HUM_F_ARM_Demon_A_Body
        ["abd56050-e481-c65c-e113-a097267fc46b"] = "1b9e7823-21cd-5920-b3b8-d1fd88d96856",  -- HUM_F_ARM_Demon_A_Pants
        ["20b5ba6a-3d8c-1190-8f3e-693a16c0bd2d"] = "2820c446-d574-5acd-8eb5-29d05b7e32c8",  -- HUM_F_ARM_Desire_Dress
        ["af423ae5-de48-9fed-6ea7-982d4c822dc4"] = "b90f9686-866d-5cbf-b6a8-740e5cdd8755",  -- HUM_F_ARM_Desire_Pants
        ["7a3000df-92f1-be0d-b367-0a6916bd2a7d"] = "eefc15d3-2b33-5692-9028-d47600564b5c",  -- HUM_F_ARM_Devils_Blacksmith_Body
        ["ae3551af-f085-6a5e-cd1f-2d73903c3c73"] = "9128a39d-3e9e-585b-9752-286bd2f45815",  -- HUM_F_ARM_Devils_Blacksmith_Pants
        ["9691c75a-8cee-b6df-b212-f4ce74886bd1"] = "1b8dd1ca-acca-5f44-a681-d1f8d2d1d045",  -- HUM_F_ARM_Devils_Blacksmith_Pants_B
        ["8523fbab-d973-bbfb-7aa2-2449a7587996"] = "dd86c5d8-fd75-5a92-9e3f-86d77de10a20",  -- HUM_F_ARM_DrowLeather_A_Body
        ["aba6f4a5-c062-6481-afd8-7be4c19e3877"] = "b055bca4-8046-5158-99cd-d93b823ca05e",  -- HUM_F_ARM_DrowLeather_A_Pants
        ["5e46bd3c-6ecf-dda1-e5ec-defa96bd9eff"] = "06f7c34b-4249-5965-a9ab-76dddf9a9823",  -- HUM_F_ARM_DrowLeather_B_Body
        ["f2efe983-d13d-0da6-34a8-d6a6dbd5f328"] = "72c7afd9-ceb9-5314-ae24-602588db4dd7",  -- HUM_F_ARM_DrowLeather_B_Pants
        ["eee49ed4-6498-d170-da59-46b1cedcefbc"] = "9768bcdb-3065-5a57-b939-5765f1497167",  -- HUM_F_ARM_DrowLeather_C_Body
        ["8a1afa94-327f-2d6c-ac2c-dd8de339c225"] = "56ab4449-23b7-5a4a-a02b-60287f91da9f",  -- HUM_F_ARM_Druid_A_Body
        ["f358cebf-6795-3bc5-adb9-463015af6888"] = "b38b35bc-def5-5a00-87f2-9c11fd8bb163",  -- HUM_F_ARM_Druid_A_Body_Leaves
        ["86c56da4-ddad-22d9-4375-bb8800380fc4"] = "36bc04f7-82ec-585f-a9f7-2600d0fbce8a",  -- HUM_F_ARM_Druid_B_1_Pants
        ["10f69796-9490-29fd-074b-a8d14b2a94f2"] = "bb1aee57-e0ed-5df8-8ca9-6b4089e2cbca",  -- HUM_F_ARM_Druid_B_2_Pants
        ["3f27e356-0f04-0b9c-3363-19d59d648f09"] = "48a13f5c-9694-5ba6-98c2-67116d5629bd",  -- HUM_F_ARM_Druid_B_Body
        ["70385c52-b782-a539-aae9-a5bde03aef61"] = "b1e2680d-9cb3-5d91-90ff-8364bab8cb25",  -- HUM_F_ARM_Druid_C_2_Body
        ["b6b27f8b-060c-1f74-4557-1ca70aa83783"] = "ebe50f03-54f7-5dbc-97f0-81fdd7253124",  -- HUM_F_ARM_Druid_C_Body
        ["30751bdc-98e5-4e70-2d73-5d17ad6a766a"] = "2f505034-3a81-5d3e-8a52-9fedca159546",  -- HUM_F_ARM_DwarvenPlate_A_Body
        ["72c1578a-153a-5e91-b98e-b895ef850102"] = "60b5d969-f9b3-5339-add3-1bcb478d1fb8",  -- HUM_F_ARM_DwarvenPlate_A_Pants
        ["ab0f614d-c855-6eaa-c6e7-5802bdcdd944"] = "999d3578-1ab9-5ac3-b12d-b7f11dfae5fc",  -- HUM_F_ARM_EPI_Robe_Shar_Body_A
        ["f94c451b-bfa1-9fa5-eee3-6acf1d1a073c"] = "966e5695-cfab-5a70-863b-fbe2310e6b1c",  -- HUM_F_ARM_Elven_ChainShirt_Body
        ["ab162662-4ed3-3c46-6fc9-2269b9e96c45"] = "39f49f1d-8747-52b6-93c0-08142ef28462",  -- HUM_F_ARM_Elven_Umberlee_Chainshirt_Body
        ["4efcdd6b-63a1-f238-b40d-9eeba145e4b5"] = "e2ae2f10-1d5a-5e2b-aea9-91eaa669636a",  -- HUM_F_ARM_FlamingFist_Halfplate_A_0_Body_Pin
        ["5ad493a4-3b43-ac38-120f-3a306218d9c8"] = "5c96027a-7ee0-5c2e-9e8d-0032bf69c5d3",  -- HUM_F_ARM_FlamingFist_HalfPlate_A_1_Body
        ["6444108d-0e23-fbe5-a27d-e86f31330b34"] = "725ae3e0-cd37-5d9f-8bf6-8f6a83c00535",  -- HUM_F_ARM_FlamingFist_Halfplate_A_0_Body
        ["782867e4-a17b-89a2-5556-ad3d70d66489"] = "65bedf0b-d982-532d-8160-9319f0e76b41",  -- HUM_F_ARM_FlamingFist_Halfplate_Marcus_Body
        ["d2cd78eb-2199-a0b2-1fd3-cc95cc4785ff"] = "fae23150-2f3a-52fa-b61f-e4b0e1941836",  -- HUM_F_ARM_FlamingFist_Leather_Body
        ["06590900-7c2f-8087-4121-18d84631b106"] = "1b4c9d7a-d620-5504-9226-a4d08bbed839",  -- HUM_F_ARM_FlamingFist_Robe_Body
        ["ddfe0903-7361-3e46-50e9-ef1a77dfd057"] = "d7ab4870-6ae0-58b9-96f0-a1de2a113572",  -- HUM_F_ARM_FlamingFist_Scalemail_Body
        ["75e5b7e7-3c17-6a19-c3db-6c94084dff4f"] = "0c528635-67e0-5c11-a739-67bcd009dab1",  -- HUM_F_ARM_Githyanki_HalfPlate_A_Body
        ["dde1397d-d127-00a9-6c0f-39f924f4d777"] = "34bbb092-e4c7-561d-b7ef-eb1d8a215820",  -- HUM_F_ARM_Githyanki_HalfPlate_Leather_A_Body
        ["fdbfa9ae-c140-9270-0b8c-d8e475e9d767"] = "7f3e8934-ef39-52bf-ace4-b75a8bd1b40f",  -- HUM_F_ARM_Githyanki_HalfPlate_A_Pants
        ["640e0bc8-f648-f14a-cbb1-6e762e498ae9"] = "4c4b3d9b-d750-58f7-9947-7f464a9c3994",  -- HUM_F_ARM_Githyanki_HalfPlate_B_Body
        ["87ed8561-ee52-8cc2-fae7-b375940d23fe"] = "b6f82273-8e08-56d8-8a3c-aa3552d7e365",  -- HUM_F_ARM_Githyanki_HalfPlate_Leather_B_Body
        ["281249cf-2236-1738-2646-2ec5082b51e2"] = "84cf61ba-3961-5055-a927-44d51db0dbe0",  -- HUM_F_ARM_Githyanki_HalfPlate_B_Pants
        ["7ed2928d-4e3c-bb5d-bc13-10b3abf14823"] = "d2b96277-a6f4-551f-a711-b9cf70b20b19",  -- HUM_F_ARM_Gortash_Body_Jacket
        ["165491b8-6344-efc1-ad62-b8a6547c1052"] = "68ec85d9-0a6e-56e3-8d79-9430b20760fa",  -- HUM_F_ARM_Gortash_Body_Skirt
        ["8234a9bb-3b79-4691-459f-024ec60ab109"] = "0a537b7e-4049-543d-b6f5-2ae4978c4298",  -- HUM_F_ARM_HalfPlate_A_1_Body
        ["f0fa736a-804a-5bee-3aa8-dcc130c01f38"] = "11524143-ba2e-5616-9f00-457c812722cf",  -- HUM_F_ARM_HalfPlate_A_0_Body
        ["d8e274b7-5bd8-70a0-0d1d-bfe17aae40d2"] = "663b69e8-4d94-5774-bd93-7c8f974c54d1",  -- HUM_F_ARM_HalfPlate_A_2_Body
        ["05a76972-4b7c-7b02-a5bd-5ad8f664b7e7"] = "af8a3c2a-a020-5ec8-b8eb-b977d88e6cf3",  -- HUM_F_ARM_HalfPlate_A_1_Body_Shoulderpads
        ["0d1e9563-5fef-e704-5c71-273dd0a5bb5d"] = "1ae0695a-aa35-5929-8f4a-2adc39d82659",  -- HUM_F_ARM_HalfPlate_A_0_Body_Shoulderpads
        ["dcfaaada-b1b2-21bd-bffb-e4f0059bac19"] = "e4cbd909-4199-5fdf-9a27-e4b2b5dd72ab",  -- HUM_F_ARM_HalfPlate_A_2_Body_Shoulderpads
        ["89d15a0f-20e0-8309-922f-f9e6fd3a408a"] = "7c240d57-9649-50ec-9696-0718a0fda677",  -- HUM_F_ARM_HalfPlate_A_1_Pants
        ["addcf306-1dc0-041e-8035-f17ce2a511cf"] = "1b5be07e-5cc2-53d0-a4fb-4b793b1b2df0",  -- HUM_F_ARM_HalfPlate_A_2_Pants
        ["f689fa3d-8047-77e7-cf71-4cddcd476748"] = "f5bb4d3a-70d3-5ba1-b97b-d106aa1cd32f",  -- HUM_F_ARM_HalfPlate_A_0_Pants
        ["8163e3db-992f-5232-0d93-3e115d1c5325"] = "4d9837ce-23fa-5a26-afcc-5723577e6430",  -- HUM_F_ARM_HalfPlate_B_0_Body
        ["d5d8886f-255e-c24d-1b53-627b86a57f85"] = "4581678b-92bb-5cc4-b506-befeb5d73d8d",  -- HUM_F_ARM_HalfPlate_B_0_Skirt
        ["0d9ccc2a-2877-0aa4-34e7-515ca1a25c68"] = "c6af1c3d-2c0c-55d8-85c7-272bd1f0a82f",  -- HUM_F_ARM_HalfPlate_B_1_Body
        ["018611dd-f4a5-09bb-2239-9ee9b04996ea"] = "75eff336-8081-53a5-bf4c-f6b4f6e60f32",  -- HUM_F_ARM_HalfPlate_B_2_Pants
        ["364e4254-fd0d-a55f-8822-9ff105c6b55b"] = "e1280119-bf42-5fd3-b58f-0f18b2c8d177",  -- HUM_F_ARM_HalfPlate_B_1_Pants
        ["e08a82f1-c191-09be-3223-989d4d2c69fe"] = "7524c026-8418-51ef-a8a0-c820144902bf",  -- HUM_F_ARM_HalfPlate_B_0_Pants
        ["6b7c0656-2be7-75c9-a99c-132aef475bfb"] = "2c572270-d609-59cd-9269-33605ffed8ad",  -- HUM_F_ARM_HalfPlate_B_1_Skirt
        ["9e0dda43-4f5d-db94-98fd-d4188eb558a4"] = "72ad9ada-74f5-5eb2-ba18-e0c9fefa6911",  -- HUM_F_ARM_HalfPlate_B_2_Body
        ["f0057ae6-6efb-9b6a-9849-feb67cdfc48a"] = "baa98235-891c-505d-ae56-42ac906b6156",  -- HUM_F_ARM_HalfPlate_B_2_Skirt
        ["28b9efee-0da6-f29d-1f00-6977155b8fb5"] = "15c4d117-7d40-5aa8-8658-0b1b5de67875",  -- HUM_F_ARM_HalfPlate_EndGame_Body
        ["01e98505-64e9-81bb-4419-9b27c451aff9"] = "bf2621e7-18a0-533f-b91a-fba69c0a4fc4",  -- HUM_F_ARM_HalfPlate_EndGame_Pants
        ["33c3502d-8ef5-b4ab-059f-7a4f8cbfefc7"] = "95ded393-2ea7-5cb4-a426-75681c57b99c",  -- HUM_F_ARM_Hide_A_0_Body
        ["f6399f9e-19ae-cbad-d113-f72ac1574b19"] = "db61b9f3-e7f3-5ba6-924f-1e91742ea180",  -- HUM_F_ARM_Hide_A_1_Body
        ["3e6b87e1-4b57-50f3-a06b-7c3ced1bb4ef"] = "6471b131-bca7-56cb-95d3-f902851c94ff",  -- HUM_F_ARM_Hide_A_2_Body
        ["cb592497-afb7-f684-0daa-4af5b81c186c"] = "6b1c8514-e481-51db-8377-d11cc79de9dc",  -- HUM_F_ARM_Hide_Druid_1
        ["e62bf9cd-7779-92c1-df3e-99c3de5df172"] = "018f2caa-ec18-53bf-98ba-4b203adf9369",  -- HUM_F_ARM_Hide_A_Pants_A
        ["5efbe777-69e7-97e0-e59b-beece8550742"] = "a52ba6c4-8150-5ddf-8ac0-09316c3d84a6",  -- HUM_F_ARM_Hide_A_Pants_B
        ["d21c0b33-ae6a-7e31-c749-6e2ee855700c"] = "017dad66-723e-5889-bdd7-02d359b843c7",  -- HUM_F_ARM_Infernal_Robe_Pants
        ["fdea9130-9c3a-aa7a-66a1-8e5dec87a1c6"] = "2b63d52d-93b5-5b69-b27e-2ac354e37b5c",  -- HUM_F_ARM_Isobel_A_Pants
        ["32f77742-2d5e-39a8-3b6b-6541fa09e05d"] = "040b01a9-1d0e-50cd-ac62-62aeabde6e3d",  -- HUM_F_ARM_Isobel_A_Body
        ["00b5bc65-3298-0d52-1200-6377414e1fc7"] = "ab34e795-6e0b-52d6-963f-5787fc5eee65",  -- HUM_F_ARM_Infernal_Robe_Body
        ["c911aacc-69b4-a52f-77ac-ae2ea41c72d7"] = "6075f5cb-4151-5a96-90c0-8df64e2d8d04",  -- HUM_F_ARM_Isobel_A_Robe_Body
        ["21041aa7-c364-e341-60a2-c7ae861bca79"] = "5195db84-3e6d-5edc-9e6a-650ffb639128",  -- HUM_F_ARM_Isobel_A_Robe_Skirt
        ["2dccb52f-cb96-13c4-0241-7ac9c8a69d81"] = "7b3cd848-33c9-5474-88ca-b0aea902e8de",  -- HUM_F_ARM_Jaheira_Pants
        ["d0336146-7ecc-0b01-520b-98985a34c0ba"] = "c714916d-ace5-5b87-91c2-2ae0f589bc9d",  -- HUM_F_ARM_Jaheira_Skirt
        ["1ae5d864-e9b7-be32-5f04-88da2699fb97"] = "4b31beba-f07d-5ba5-969d-731506918436",  -- HUM_F_ARM_Karlach_Epilogue_Player_Body
        ["fb084ed8-92e2-e11e-db79-2d22069c7a67"] = "4ca88123-0bb7-5feb-b21b-9d869b079cd5",  -- HUM_F_ARM_Ketheric_Body_A
        ["03a18f12-cda7-40be-fbf2-707cd5fdd806"] = "44a86c36-4273-547e-81fe-df77b45f0524",  -- HUM_F_ARM_Ketheric_Pants_A
        ["79ce64fd-01f6-f04e-4386-83018e3321a6"] = "73a8d125-4704-5ed8-aad4-d04f064f165d",  -- HUM_F_ARM_Laezel_Githyanki_HalfPlate_A_Body
        ["b601d974-bdcc-4653-ba7c-58ef45a0c5e4"] = "0d87da1b-18b3-5034-900c-4b122134ff9c",  -- HUM_F_ARM_Laezel_Githyanki_HalfPlate_Broken_A_Body
        ["956e11cc-41da-9e43-036b-c59a70c1b945"] = "6cc531d9-a288-50ba-a891-c1917e7d818a",  -- HUM_F_ARM_Leather_A_1_Body
        ["d6f8ef96-3674-39c6-3e7a-73f94bdd5595"] = "bdf670d0-7a78-53ce-a71d-edd4b61ba798",  -- HUM_F_ARM_FlamingFist_Leather_Pants
        ["f29af014-91cb-f1a8-3b6f-d59de4ae8e91"] = "7dfb06bf-e196-575d-b96c-0b39a92a57e8",  -- HUM_F_ARM_Leather_A_1_Pants
        ["b36b4826-00a5-0a1a-f1e7-1e13fb7192db"] = "508f3ec2-86f9-571e-87d3-beb0b66b19f2",  -- HUM_F_ARM_Leather_A_2_Body
        ["a8b2d37c-aee8-7458-c570-638c830d31d1"] = "cacc02a2-cbb6-5aba-be8e-4b82908a918f",  -- HUM_F_ARM_Leather_A_2_Pants
        ["e4bd0d2b-0160-f802-3429-7bb4b305a613"] = "3e8cfeec-20f6-5258-9e7c-01cef39cfabc",  -- HUM_F_ARM_Leather_A_2_Guild_Pants
        ["66bcfba0-cea0-504f-2790-053dc8cb0bbf"] = "15dceed4-f1fe-52be-a7ad-aad62eaddc1e",  -- HUM_F_ARM_Leather_A_Body
        ["27e35669-4d7c-b39a-6476-abbff870074c"] = "4402b26a-0110-5894-afd9-1a639f740b6d",  -- HUM_F_ARM_Leather_A_Pants
        ["a506a44a-d295-01b5-37f2-c19e33aa62c9"] = "7cf96297-eb16-5ae3-a15f-9908e2ce0aa1",  -- HUM_F_CLT_Drow_Pants_A
        ["1e87abcb-c98a-538a-c9a1-00df18b91355"] = "99627c97-3e53-5d94-a77e-caf3c3f79ae6",  -- HUM_F_ARM_Leather_Old_A_Body
        ["aeedba01-02a7-25ec-bca5-b314ba4c4fee"] = "264eab83-6b06-5225-b49a-53a601eaad7e",  -- HUM_F_ARM_Leather_Old_A_Pants
        ["3693fa90-0f57-6cb7-d8e9-b46d64a14e70"] = "a4793308-4d73-5646-bab4-a93012bb7f94",  -- HUM_F_ARM_Leather_Old_A_Pants_B
        ["6d5c83a6-cce9-4dff-6735-a7e015bdc82c"] = "04b99e2c-c6ba-5539-84ea-b88cffb51245",  -- HUM_F_ARM_Leather_Old_A_Pants_B_Kneepads
        ["0ff48dde-2f79-77e4-a76b-4e119f8ed081"] = "eb9e80b0-546b-5ebd-ba33-297bac6431b7",  -- HUM_F_ARM_Magic_Monk_B_Body
        ["ca714562-2c20-67e8-8db8-34ee8e354534"] = "e9e89e02-a80d-53bd-aa67-f8d2b0f2c372",  -- HUM_F_ARM_Magic_Monk_Body
        ["c3070973-5315-4061-70a3-c81b7af8992e"] = "c97c17b4-ef5f-51b2-8d72-7239dd4f0d3e",  -- HUM_F_ARM_Magic_Monk_Pants
        ["52372a10-326b-b2af-4b35-f5cc5919cb2e"] = "ee8dd0a0-4d80-5629-85ff-8bfb8118f26a",  -- HUM_F_ARM_Magic_Monk_Pants_Scarf
        ["49926d18-9968-fe7d-cd69-8d69b3888a58"] = "86fcb623-330f-5136-928e-4d00e3f436f8",  -- HUM_F_ARM_Mindflayer_Body_A
        ["beae81d8-4251-f077-4463-0cf6e541f71f"] = "97ebb9b6-033e-5aa2-a3c4-8b2cecb47584",  -- HUM_F_ARM_Mindflayer_Pants_A
        ["49551064-df2d-4baa-bf8d-48893db8af50"] = "124175a6-1d32-5c1a-a4ed-ea22411ae13c",  -- HUM_F_ARM_Mindflayer_Skirt_A
        ["ff401e93-8d2f-4bb2-66f6-a1d879f38ad2"] = "7ba8938a-af9c-528e-9e89-b3f5c0bd8f31",  -- HUM_F_ARM_Monk_A_Body
        ["48a70a5d-f440-ab7d-f0a7-308d3a6d830f"] = "1bb13990-9e15-5a3a-a414-631651014a96",  -- HUM_F_ARM_Monk_A_Pants
        ["7d323252-e866-db48-dff8-ba787efef763"] = "67a87487-7176-5383-aedb-5d4cfe4752a7",  -- HUM_F_ARM_Myrkul_A_Body
        ["a570519e-f495-8f55-108d-8f8a076b562a"] = "53741e4c-2dc1-557c-ad35-9fc3f77af77a",  -- HUM_F_ARM_Myrkul_A_Pants
        ["adf969ed-6b7d-f4a9-c743-4856e552b246"] = "71abec15-5035-5163-a80c-7e592b66290f",  -- HUM_F_ARM_Myrkul_B_Body
        ["507bb7aa-294b-0e8c-ca3a-ca5bf52e5caf"] = "6a229dcc-b568-5c14-add7-0d3503b51ba3",  -- HUM_F_ARM_Myrkul_Plate_Body_A
        ["a5ad64ac-5d73-a959-60e5-22a13c19445c"] = "59239333-cb7a-55fe-96b0-22b4df4f169a",  -- HUM_F_ARM_Myrkul_Plate_Body_C
        ["c7d97828-bd40-e39f-8f6b-ee87bb5de187"] = "5c523feb-0456-56e2-8e28-15f4fdf94dd3",  -- HUM_F_ARM_Myrkul_Plate_Body_D
        ["5eddf203-8eb5-9db0-5eba-60c77f765c02"] = "7b6c9fee-232b-5dba-964a-e7f384b709b7",  -- HUM_F_ARM_Myrkul_Plate_Pants_A
        ["d2cbe9dd-1de9-541f-aa9e-03d32f1bd3d2"] = "2609f8b1-4b2b-5951-b313-79bd675c98e7",  -- HUM_F_ARM_NightsongPrison_Body
        ["93399195-5282-44b9-9d98-bb288faedc52"] = "ee831093-a4e4-5b51-8ff1-58daa684a654",  -- HUM_F_ARM_NightsongPrison_Pants
        ["4db1eff0-08f1-c83b-eb61-2e40c837f1e7"] = "c0a54a5e-99bb-5855-b04d-c59626eed989",  -- HUM_F_ARM_Nightsong_Body
        ["8f81b249-93b0-cd99-c27c-3b6987232f19"] = "6959cd5d-252a-5c98-b92c-6b81df5bce5f",  -- HUM_F_ARM_Orin_Body
        ["a22984e8-b28c-46e9-5862-930af7b7b136"] = "0f892ee8-28f6-5d28-a9a9-754662c2d047",  -- HUM_F_ARM_Orin_Body_Player
        ["092db3bc-9cbc-87aa-c21c-d0016f80bbc7"] = "77849787-7d4d-5c1c-9d7d-ef6f34ca380e",  -- HUM_F_ARM_Orin_Pants
        ["f6d6d155-6390-a211-e86b-73a977b9738a"] = "8095cbc7-6903-5130-8066-ea236fcbe9fa",  -- HUM_F_ARM_Orin_Pants_Player
        ["113bae24-e267-5982-59ed-1454a41cce60"] = "fec28c24-a33c-560e-b69b-3e943a421425",  -- HUM_F_ARM_Padded_A_0_Body
        ["9ea94d2f-f341-1cb4-a780-d9724474758d"] = "327b3118-640e-542f-9499-2557ad1acb40",  -- HUM_F_ARM_Padded_A_0_Body_Broken
        ["e4865cdc-10de-62ec-aedb-ac32b7973dee"] = "e7cf8428-be34-5b52-a6f9-0e1913e5357d",  -- HUM_F_ARM_Padded_A_0_Pants_Broken
        ["057b7784-3ae7-1c5a-e404-d502b6602bae"] = "a5e88f8d-cea9-5944-bdf1-c0070b030106",  -- HUM_F_ARM_Padded_A_1_Body
        ["f9a9aa02-5ceb-1ff8-beac-5ff9a3243f41"] = "c81cbf38-2b0c-542e-8a0a-19ce727057ff",  -- HUM_F_ARM_Padded_A_1_Body_B
        ["6b3bf5e0-d886-8646-0623-2fcff33a3695"] = "80873062-5118-56e3-8439-bcc6714964f6",  -- HUM_F_ARM_Padded_A_1_Body_Spring
        ["74bb8dd6-2010-f90d-caa1-a172ad5c4a95"] = "f9460b40-d057-5b2c-aa3a-5d9c7dece991",  -- HUM_F_ARM_Padded_A_2_Body
        ["29b64740-a9cf-d0f4-c536-0bd7b631e710"] = "c183f0d1-0286-5d07-80a7-a89811f9a679",  -- HUM_F_ARM_Padded_A_2_Body_B
        ["c80e582d-0f68-62a3-bc89-5738d2000319"] = "b20cec72-7b5a-5a05-89b6-30ce9f3e0731",  -- HUM_F_ARM_Padded_A_Pants
        ["e704163f-d9ea-6dbe-c897-b44b042f1769"] = "6eabee68-1810-5078-93c1-ad6046ab6d44",  -- HUM_F_ARM_PlateMail_A_0_Body
        ["9b33ece1-b01d-74f8-7ef1-4183cd80220c"] = "0d32a20c-fafa-5a0d-b62c-c09ddb805119",  -- HUM_F_ARM_PlateMail_A_0_Skirt
        ["a7cf3830-d44f-a31a-9e90-ffb00e718078"] = "e55cdad6-0e25-5545-8b44-abd93310a20d",  -- HUM_F_ARM_Paladin_Oathbreaker_Platemail_Body
        ["b457d115-a6f7-7f10-f674-7eea94896eb9"] = "0c7a4d50-75e8-51a2-9825-a11d3ce67c0a",  -- HUM_F_ARM_PlateMail_A_1_Body
        ["5f58f18f-ec6b-10c3-8462-0603dca6e573"] = "a4cb3433-f527-5f3e-8aac-066ebc2d3808",  -- HUM_F_ARM_PlateMail_A_1_Skirt
        ["f8c8854d-1f75-7595-932f-5bcc78051351"] = "707d3dcd-e37d-50ae-9b90-c27b7aec28cf",  -- HUM_F_ARM_Paladin_Oathbreaker_Platemail_Skirt
        ["04a5084e-efe5-f61d-5a28-577b059cbaaf"] = "6262dc15-51b3-5a64-8a1a-2a1ec46a91dc",  -- HUM_F_ARM_PlateMail_A_2_Body
        ["153fafa5-944d-9f49-c1ac-bc96ebc81383"] = "dd6d84dd-fb82-5bb0-b1d8-1cc266e2c81a",  -- HUM_F_ARM_PlateMail_A_2_Skirt
        ["4961b222-0434-2ce6-8cbd-67c36c2f9896"] = "df8d1afb-303d-5521-b854-b47906b97a2e",  -- HUM_F_ARM_Paladin_Oathbreaker_Platemail_Pants
        ["94a4cbf4-39d7-5e7d-5429-bf6530cbb7b4"] = "20653a4d-4881-51ca-94b5-c6a3be3e861a",  -- HUM_F_ARM_PlateMail_A_Pants
        ["92c2ecdc-30be-dde9-ed3f-0bf056394331"] = "fcbf9c34-baf8-5c7c-bed7-f411e39ec365",  -- HUM_F_ARM_Platemail_B_Body
        ["11c721c2-e56f-ddd0-24f1-684ccceeee0a"] = "b3abd0f5-8501-5f90-9160-856256944754",  -- HUM_F_ARM_Ravengard_A_Body
        ["006159ea-8880-6589-52ef-313fc228ee26"] = "f9b8ab0c-0bb1-5cde-bdf9-670ad52b990a",  -- HUM_F_ARM_RingMail_A_0_Body
        ["f8f01df9-1fd5-f92d-a62d-432da17ba1a6"] = "ddadcb13-db2b-54e6-a0ba-b22abef8b96a",  -- HUM_F_ARM_RingMail_A_0_Skirt
        ["d3482469-a43e-8de3-88f2-e5a8907c95d6"] = "f0b73209-3903-57fb-975f-af62287a43d1",  -- HUM_F_ARM_RingMail_A_1_Body
        ["e86250ad-54b5-29a0-1383-321dfd77115c"] = "a623f0b0-c4c1-5bcc-80fa-3daf1a91487e",  -- HUM_F_ARM_RingMail_A_1_Skirt
        ["9f06b0f7-1d68-85f0-3b4c-276fab55a1f9"] = "81072c13-fd67-5081-acb0-e8f991f641a1",  -- HUM_F_ARM_RingMail_A_2_Body
        ["571adfc4-0033-449a-9be6-9602bdd35d04"] = "c417db88-8d41-5802-8802-b4d1db9cc05e",  -- HUM_F_ARM_RingMail_A_2_Skirt
        ["9f847c1c-25bc-5417-942e-c78986e5071c"] = "2349081d-f4ee-5014-80bc-d6a57031308c",  -- HUM_F_ARM_RingMail_A_Pants
        ["5b4c8f52-5336-6b43-96bf-7ae2cde81e1c"] = "2726716e-9b88-591d-b349-f4f159cdf765",  -- HUM_F_ARM_RingMail_B_Body
        ["ad28b80d-799e-60f3-ecd8-8c8d64fdb28e"] = "fbdded19-35fb-5b05-ada6-377c3fe36ac0",  -- HUM_F_ARM_RingMail_B_Pants
        ["a0e71abf-5235-6bbd-a52b-f1e898b7dfab"] = "e1e0a50a-3c4a-5bd7-bd07-3a0ab511e01f",  -- HUM_F_ARM_RingMail_B_Skirt
        ["d27d9b6e-fa2f-34f1-c17a-94eb2b63a087"] = "8a0cdab7-02ef-5d96-9731-ab7923f427f5",  -- HUM_F_ARM_RingMail_C_Skirt
        ["095be887-6b9d-c7c4-ea62-4ab6d0b513d6"] = "31e4fa28-0abd-55f1-b8e8-77eb8ca9358f",  -- HUM_F_ARM_Robe_Fire_A_Body
        ["2c5d9266-8a99-7143-754c-fc2b57422c01"] = "92c9c75b-3fb7-5d41-b575-43be541c7076",  -- HUM_F_ARM_Robe_A_1_Body
        ["78b1b1b1-1bba-0a46-8577-72c74903575d"] = "1e4ff416-0960-571e-8ccb-2e2e79427ab4",  -- HUM_F_ARM_Robe_Frost_A_Body
        ["eecab0b0-f7bf-77c4-761f-c07325ea0c43"] = "7ac3618a-ad8c-5e9d-b692-3c0eca857c33",  -- HUM_F_ARM_Robe_A_Body_Satin
        ["69649acf-f219-d2b9-8cba-d044263f00bb"] = "dca36d04-dd52-524f-8480-660d030330d8",  -- HUM_F_ARM_Robe_A_CloseQuarter
        ["4084d9c1-de9e-bb68-f0bc-0395ad80357b"] = "0606bd9e-371f-5eed-9b1b-21751f450439",  -- HUM_F_ARM_Robe_A_Body
        ["c4347cae-8638-4f27-d847-d848a587869f"] = "48e5f9cd-9092-5c60-bec1-067e07c7f5d0",  -- HUM_F_ARM_Robe_B_2_Body
        ["fb2968d6-a8a5-571a-f803-8b91a2cd5346"] = "d6036f2b-1bb3-579e-8e88-6ef6f3bc7d34",  -- HUM_F_ARM_Robe_B_Body
        ["11749113-6fe4-1593-6981-be73277484a8"] = "940b01a0-c1f0-5a6d-a17c-e5b3dd15192e",  -- HUM_F_ARM_Robe_B_Wizard_Body
        ["324ccffb-b76c-ddf9-c133-058cbab4a5de"] = "27458460-a9e4-5dec-ac88-bccc26565486",  -- HUM_F_ARM_Robe_B_Undead_Body
        ["2482f256-6050-4e01-2620-05c9525297aa"] = "b342c260-46d2-5f29-a3cb-ef363570a07d",  -- HUM_F_ARM_Robe_C_0_Body
        ["26ff5e8a-4077-c579-c3ef-e1304554b3e1"] = "ee5297e3-053d-5403-aa69-7fbd52f89f59",  -- HUM_F_ARM_Robe_C_1_Body
        ["55b92629-3026-3563-b3b5-df3d033efcb3"] = "1535cd21-29f0-5e0c-8b37-3593ddd42a88",  -- HUM_F_ARM_Robe_C_2_Body
        ["04741d75-66f6-e766-18a8-2c07f326ca13"] = "1f0bdbbf-687c-55a2-a95d-17e05732a9cd",  -- HUM_F_ARM_Robe_C_3_Body
        ["25a13ce8-126b-e0b8-44b4-133b2cfeeaf1"] = "416e43d6-a0c5-55ae-b976-ee6663cc05f3",  -- HUM_F_ARM_Robe_SpellResistance_Body
        ["0aabb3a8-eed7-b19b-24da-5e9d82b266fd"] = "9ad64e5f-e015-5de1-bd42-9d2c21f26746",  -- HUM_F_ARM_Robe_D_Body
        ["66dab175-f470-b1d7-60a8-1fe553f12ea7"] = "e14d68d8-639d-5f9c-a3e6-593349efef21",  -- HUM_F_ARM_Robe_E_Body
        ["c9ed14a2-99f2-57c9-9542-c2867dec37ef"] = "3e64c40c-3625-5bf3-817b-25c3245fc244",  -- HUM_F_ARM_Robe_E_SpiderQueen_Body
        ["7831d6c6-8324-1d9f-6909-96165a057ec4"] = "53df5e00-2768-5019-8fc3-96613f7fd060",  -- HUM_F_ARM_Robe_EndGame_A_Body
        ["ff43d550-a7af-63a1-dd6e-731e525376e0"] = "b8755b0e-e5ab-5760-a178-6bc07bb1fc42",  -- HUM_F_ARM_Robe_Lorroakan_A_Body
        ["96dab08a-eb0c-2ffe-6c36-7566ab78e346"] = "7c358563-2982-5ac7-8461-20368f316138",  -- HUM_F_ARM_Robe_Lorroakan_Body
        ["1ae5d16d-de79-6e1d-331f-c11d75dbbaf5"] = "a65f215b-c041-58a9-8922-0c5be4bd1649",  -- HUM_F_ARM_Robe_Shar_Body_A
        ["338fcd6b-71c1-a991-26a2-db02dee1a5af"] = "9d86d97d-bb74-50f1-a055-d7f735c1c9ea",  -- HUM_F_ARM_Robe_Shar_Body_Viconia
        ["cd5de58b-6dd3-55c6-748e-ad71cad54c39"] = "c1b9763a-8fbf-50e5-8dec-bd8069fc7657",  -- HUM_F_ARM_Robe_Shar_Body_B
        ["b6811b31-25f6-c4bc-5e93-ec0ab37a1677"] = "324dee40-acd6-5b47-984d-657741d83058",  -- HUM_F_ARM_Robe_Shar_Pants_A
        ["209f6f56-54f8-d4e9-35af-70867c839c67"] = "df297608-dcd3-55d8-b8dd-55bf8a098b0a",  -- HUM_F_CLT_Camp_Shar_Pant
        ["958458e2-45af-5996-a365-25d258c17a2b"] = "424566e0-3ce7-54c6-9fd3-851cba1bd6bf",  -- HUM_F_ARM_Camp_Citizen_Pants_B
        ["f0c533e2-e10f-5fea-a143-065df33e6fa1"] = "29023a08-3d0a-573c-94bd-066812b4721c",  -- HUM_F_ARM_Robe_Shar_Pants_B
        ["f62dfa70-6b63-feb1-3bae-059a77ded1ff"] = "864409c0-66f4-5600-aa86-492df38a6153",  -- HUM_F_ARM_Robe_Shar_Skirt
        ["0fe2e1a1-da35-e2e8-5c87-d2ad15e24208"] = "5295a751-7f04-53bc-9cd3-ef1b40f9a6a5",  -- HUM_F_ARM_Robe_Umberlee_A_Body
        ["b74bc9d1-2c02-7bc1-97e2-ba6b66d91db6"] = "ad296140-e728-5e35-82de-4d29b092f039",  -- HUM_F_ARM_Robe_Umberlee_A_Body_B
        ["e3a982a7-113d-e13f-deef-97625f44d46a"] = "facc6991-3b86-5f96-b46f-dad7d5d0c32f",  -- HUM_F_ARM_Robe_Umberlee_A_Pants
        ["2321fb4f-010e-495d-18c0-c2facb6f6241"] = "84aeacca-47de-5983-9255-ca8384867eaf",  -- HUM_F_ARM_Robe_Umberlee_B_Body
        ["0fdaf2c1-cf92-f263-0048-56e93238a5cc"] = "20da1916-f8ab-5369-8a9b-cddccf1574bf",  -- HUM_F_ARM_Scalemail_A_0_Body
        ["a6e89a85-dca1-816e-265d-eed5c5a54b96"] = "06eedb41-8324-567f-8ea1-7422635beabf",  -- HUM_F_ARM_Scalemail_A_1_Body
        ["9d613fa9-9188-e036-5470-d590d3aca811"] = "982b1784-e09b-52d9-a86e-d3b12e548e05",  -- HUM_F_ARM_Scalemail_A_2_Body
        ["4bdb8690-5acb-95da-abae-6b41a9fd4aa4"] = "23b7bf8f-8bfc-5b46-bc2d-3fd1560a3be1",  -- HUM_F_ARM_Scalemail_A_Pants_A
        ["3fb3ab1c-786d-c5e0-f31f-8104cc8e377b"] = "7e55ba23-5593-595d-8d3e-60e2192d2693",  -- HUM_F_ARM_Scalemail_A_Pants_B
        ["fe430473-6b87-a1e5-2f39-085b1942542f"] = "a15ada69-d371-5c91-9ee2-9fd77ac67957",  -- HUM_F_ARM_Scalemail_Adamantine_A_Body
        ["623d949f-6b7d-05ba-d20f-c7633495eb24"] = "4cbe1682-3b86-51f2-9c5b-6225836486ef",  -- HUM_F_ARM_Scalemail_Adamantine_A_Pants
        ["370b0a8d-ee6d-93aa-aca6-9ea018bbb4a7"] = "44909bc1-9307-58c3-8033-f49105f49840",  -- HUM_F_ARM_Scalemail_B_0_Body
        ["17a8d09a-f6df-0187-aac6-be01f0089f65"] = "3eefde53-2b49-5525-ae83-631cd8ac06ae",  -- HUM_F_ARM_Scalemail_Paladin_OathOfDevotion_Body
        ["fb901e95-3101-ff63-a628-e6d95c0a62e4"] = "86e374c1-5380-51c2-849e-612a42a87364",  -- HUM_F_ARM_Scalemail_Paladin_OathOfAncients_Body
        ["97d65c4c-d6fa-bd7d-1a15-ca63a4bb1831"] = "39542d8d-81e1-5fb2-b1a7-89aed90e30d9",  -- HUM_F_ARM_Scalemail_Paladin_OathOfVengeance_Body
        ["433b08ba-302c-2edf-1064-d0aae20eaf35"] = "aa750124-7fb1-5b28-af17-757cb8fd6942",  -- HUM_F_ARM_Society_Of_Brilliance_A_Body
        ["12ae1e17-9cc8-6c8c-cf35-ff4a3bb0ecc0"] = "679e1252-13cf-5d66-8887-0f62bbea5886",  -- HUM_F_ARM_Splint_A_0_Body
        ["e5eb5555-364d-16af-caea-8dd79c0d8945"] = "fa8883e7-bc50-5088-9052-e8e2d503503b",  -- HUM_F_ARM_Splint_A_1_Body
        ["789678af-6c03-8bf5-f3df-afef3cb52dd4"] = "b5393358-d385-5a3f-a00b-7f3c3f7bda85",  -- HUM_F_ARM_Splint_A_1_Pants
        ["53ab8b43-8c16-cfcf-a198-48c3dd856b48"] = "6b0b625d-e57c-514a-935d-2ea5407119ca",  -- HUM_F_ARM_Splint_A_2_Body
        ["e8185a07-77c6-6cbc-1ec6-ab4ee246fbe6"] = "305743cb-5d9f-581f-9ce7-4dde809898d1",  -- HUM_F_ARM_Splint_A_2_Pants
        ["ad128db4-9ce5-0a9b-d5a5-86692c87bcf2"] = "61b1aeea-3c1d-5ac2-8d2f-12e086c4005c",  -- HUM_F_ARM_Splint_Adamantine_Body
        ["2141e5d9-dc21-ad0d-40dc-71e333819a26"] = "d4b73774-99e0-551e-b8ff-bca02b268b79",  -- HUM_F_ARM_Splint_Adamantine_Pants
        ["bac9739c-6ed7-621c-fe61-009a44a7cf75"] = "2ed61d1e-a578-5e75-91a5-5f6ed87fe815",  -- HUM_F_ARM_StuddedLeather_A_0_Body
        ["b3b87fc5-acda-80b8-2c26-9e797b99a7de"] = "96dbee5e-5bbc-5c2c-a1f5-2fd981c5f8d9",  -- HUM_F_ARM_StuddedLeather_A_0_Pants
        ["9d67986d-21ae-401b-9837-ee4e003e1a5e"] = "7aac6a94-e5a3-5ce2-aa3b-301426c1c391",  -- HUM_F_ARM_StuddedLeather_A_1_Body
        ["da8139a1-a58f-e2a1-62a4-bcf3bf409080"] = "6b3bcad8-4a93-5276-8b02-8f6c6be2597a",  -- HUM_F_ARM_StuddedLeather_A_1_Pants
        ["eafe8199-bd10-0dca-ba1f-66b34fd1e363"] = "5917535a-1ba3-5427-8fc4-7c7b52c19871",  -- HUM_F_ARM_StuddedLeather_A_2_Pants
        ["e8b7426f-669d-a781-9f3d-d006ffb031ac"] = "9555a589-7c6a-55e7-b138-50db56d262fc",  -- HUM_F_ARM_StuddedLeather_A_2_Body
        ["d3151f1b-56af-bb04-6bba-c4c9b48104f8"] = "698ad833-3109-51f8-8b89-b8024c3776d1",  -- HUM_F_ARM_StuddedLeather_B_Body
        ["d6d2f87a-e8dc-0102-7cd3-61d0922efff2"] = "e91a0786-2bd4-5e46-8da8-0cf25c1b2330",  -- HUM_F_ARM_StuddedLeather_C_Body
        ["c403d4ba-9b22-ce02-7f87-71ea1628fb65"] = "b0b2ef56-8947-55e8-8939-607d93f8ea76",  -- HUM_F_ARM_StuddedLeather_Minsc_Body_A
        ["1f0df787-f318-50ee-1ba3-db54078b310e"] = "5234f906-e35e-5564-8014-02e6c753d8a8",  -- HUM_F_CLT_Alfira_Skirt
        ["a8f45b55-911e-a40a-e501-02022bb63a41"] = "8877178c-5d5a-555e-b85b-23a117d35b73",  -- HUM_F_CLT_Bard_Body_A_1
        ["d6bafee0-4aee-5322-8a49-84179673cd96"] = "5052b5f4-de69-58d0-a763-e892271abfa8",  -- HUM_F_CLT_Bard_Body_A
        ["7f3ec09b-8ade-1772-8fc5-822a43e4e991"] = "246b88c6-73b2-51ea-a545-964443ed0bf5",  -- HUM_F_CLT_Bard_Pants_A
        ["befe91a5-3a8a-e604-ae8d-d4413759b38c"] = "576a46ad-75dc-5e96-8d22-834b0e388501",  -- HUM_F_CLT_Bard_Pants_A_1
        ["ee42f623-c004-c1aa-dab1-7d86e8178895"] = "5e98ac91-4743-535a-ad3e-f5b52073e15c",  -- HUM_F_CLT_Bard_Skirt_A
        ["0f4c63b4-df59-c729-156f-08cc9a3c8a00"] = "cc700c3d-d243-574d-8510-dcae67053702",  -- HUM_F_CLT_Blacksmith_Body
        ["27d62490-3434-1ccc-35c8-59a8c73ad2ad"] = "fcee7b37-ccdb-5925-80a0-8875c97fc278",  -- HUM_F_CLT_Blacksmith_Pants
        ["dc75dded-74b2-1b63-5ed4-8cfaacbaf80a"] = "1064bc04-5ea8-5ea6-8c91-6cd8a38646a3",  -- HUM_F_CLT_Camp_Deva_A_Body_A
        ["435d32fc-9994-9f17-aa79-f76cb3ae300a"] = "4d3e5657-613a-51bc-aa1c-12c0d517f8af",  -- HUM_F_CLT_Camp_Halsin_Body
        ["888a24d5-650d-d4a4-be6e-7b48828e69c4"] = "e060b9f2-82e9-507c-bac2-940fb336a410",  -- HUM_F_CLT_Camp_Jaheira_Body_A
        ["dd7e1cf2-fab0-ca8f-980b-4e439ae31c9f"] = "fabcb5c3-6eb8-51b3-b88f-da39dc370adc",  -- HUM_F_CLT_Camp_Jaheira_Pants_A
        ["dcd947da-9f4b-ab17-7112-c0c95a4dacfb"] = "c45b5cc7-81d6-5589-b60a-94c84c4b1714",  -- HUM_F_CLT_Camp_Karlach_A_Pants
        ["611146cb-b98b-9ed1-78ee-1c24feee45d1"] = "c835c5bf-b2e9-5161-a151-262aa08245ee",  -- HUM_F_CLT_Camp_Minsc_Body
        ["0fc38c91-a4a2-d9b6-da09-c1d55ab9a6b3"] = "e4569ee9-55be-5d2b-80a4-fff3c430577a",  -- HUM_F_CLT_Camp_Minsc_Body_Ragged
        ["2c25ec83-c34c-2e15-d4ff-5cf35b0bb655"] = "82a489e9-5820-5cc3-8d5e-037fd2e4ea85",  -- HUM_F_CLT_Camp_Minsc_Pants_A
        ["a85bb322-f3ee-fec9-06d7-cd3d8aacd25d"] = "153bc537-1dc9-5920-8271-4e1f68faac66",  -- HUM_F_CLT_Camp_Minsc_Pants_B
        ["26ff17f0-8620-8c71-02b5-70c7977065d8"] = "1fa62727-7de9-5666-b822-48dcfc1e9d52",  -- HUM_F_CLT_Camp_Outfit_Astarion_Body
        ["372f4870-d222-39b7-a801-4d226551175c"] = "76dec601-764a-55d4-84c6-9ec84e4d8a59",  -- HUM_F_CLT_Camp_Outfit_Laezel_Pants
        ["99e0150f-659c-a90c-253a-b8529fdf2717"] = "0a042ae0-2b79-5ad0-8ce6-2c5b3fb024a3",  -- HUM_F_CLT_Camp_Shar_Body
        ["2156b7db-04a6-ce24-559e-67bec253f4b5"] = "d05b80bb-891d-5638-afa4-5fda8cf17659",  -- HUM_F_CLT_Circus_Pants_C
        ["0ccd9020-100d-5c2e-5dec-e1d279d906bb"] = "69f287b5-70dc-50d5-9f1e-cc92cbdc8a05",  -- HUM_F_CLT_Circus_Pants_D
        ["d1774c69-1642-40df-f5f6-f027dec0f5f2"] = "b0592597-254d-5b80-9447-9b1502c9fdeb",  -- HUM_F_CLT_Circus_Pants_E
        ["db5197fa-3e0c-90cb-b023-6a3f969eba2b"] = "c589281d-d8a4-5ec9-aaa3-b3f5e56728ef",  -- HUM_F_CLT_Corset_A
        ["4093b106-0202-8695-3930-c8ef8abc2256"] = "aa9ef5dd-d5c9-5a08-8400-12f49d5fb5d8",  -- HUM_F_CLT_Corset_C
        ["406bdd29-ef4e-c58a-bc1d-10863f1f5acc"] = "160245bc-073c-5818-968d-271954f9642d",  -- HUM_F_CLT_Corset_Courtesan_A
        ["015d97e7-0cb8-6744-039f-e4f4f4fc828d"] = "cb7990e4-ef6e-52a2-af3c-8435781a6152",  -- HUM_F_CLT_Daisy_Dress_Gale_God
        ["61782326-731c-e242-105b-bb81f9ba719e"] = "fa811211-6245-579f-a6b8-181aa7fc2bff",  -- HUM_F_CLT_Daisy_Dress_A
        ["b7240d70-2bad-4d2f-3796-26686410a339"] = "dfe6a57c-70e4-5bea-aa79-1f1a9d0a0f6a",  -- HUM_F_CLT_Daisy_Dress_White_A
        ["ff62821d-7630-0787-6d2f-0434ff48f27b"] = "d78b3999-a1f4-5c8e-a61f-0b0fa9a6b306",  -- HUM_F_CLT_Daisy_Dress_A_Accessories
        ["27748f4d-ad84-964d-34b4-e46ff3257a4d"] = "b516d49f-3b60-50a6-aaaf-269aadcc2840",  -- HUM_F_CLT_Daisy_Dress_Accessories_Gale_God
        ["941d5ebe-0409-fef6-28e1-d90ef3a31b52"] = "ce0e5640-6417-5258-b698-359e6a511543",  -- HUM_F_CLT_Daisy_Dress_Cape_Gale_God
        ["b7c9aec9-bbe2-340a-82ad-a0fdc0394c82"] = "17372bee-7b10-58e6-9aff-4bf58b8de69d",  -- HUM_F_CLT_Daisy_Dress_Cape
        ["870ca9d0-b98a-e0fe-6c45-6286c7b8cbea"] = "fcfb2494-7542-5d11-ad13-1dfc610437ae",  -- HUM_F_CLT_Doublet_Rich_C_Body
        ["bdbb424a-131c-1a30-ce25-4584c7fd153e"] = "3165f644-9ca5-57f1-ad6f-0022cd3a0a3a",  -- HUM_F_CLT_Doublet_Rich_C_Body_1
        ["30627639-4730-ab00-6160-3ec475cd35a9"] = "90c5bf4b-7c5f-5921-8e79-34d4baf58f27",  -- HUM_F_CLT_Doublet_Rich_C_Skirt_A
        ["458f51b4-07b3-0678-8879-75ed4f79fc78"] = "833946ab-5201-52bd-b1c9-657fafa3e1f4",  -- HUM_F_CLT_Doublet_Rich_C_Skirt_A_1
        ["d0e176ae-0389-66ac-5eda-3120e92752f8"] = "3cc2705f-38c8-51ee-a852-40bad2207644",  -- HUM_F_CLT_Doublet_Rich_C_Skirt_B_1
        ["e241a911-80fd-a32b-58e9-be4194873eaf"] = "61d4f9cb-0cd8-5711-a7e2-94f9590cdfa1",  -- HUM_F_CLT_Doublet_Rich_C_Skirt_B
        ["0461fcfa-910d-18a9-a1b3-b5b32eb4243c"] = "82c705a5-f887-50b0-aa67-1c1508ae1d59",  -- HUM_F_CLT_Drow_Body_A
        ["feea0381-4abd-9c88-139a-fbdff203761c"] = "01f9fcfa-79dd-599e-98a8-f42debfc1d51",  -- HUM_F_CLT_Drow_Body_B
        ["1ecc06a0-cc2f-a841-8ed3-ac5b7b90350a"] = "1cd2e312-507c-5b7a-a5b8-f8fb33c30b57",  -- HUM_F_CLT_Humans_Pants_A
        ["7b247806-5fe3-8fa7-2733-d0d2486e55e0"] = "1fd0d2e3-f7c1-5e43-b2a5-d04cb0fc14c4",  -- HUM_F_CLT_Humans_Pants_A2
        ["3c3c6f48-c2b0-17f5-0f96-fade875b8b03"] = "e960ca79-8bbf-55cb-97f4-c48bcf1d6853",  -- HUM_F_CLT_MiddleClass_Body_A_0
        ["b6a9e089-b4d1-58a7-59a7-21a63ec1e3dc"] = "135dbb1f-7167-5209-afad-ceb69decba26",  -- HUM_F_CLT_MiddleClass_Body_A_1
        ["d94b896f-5e09-f0aa-c158-1496fa2cd809"] = "490ffcd0-4197-5d5d-bee8-0ca894bdb379",  -- HUM_F_CLT_MiddleClass_Body_A_2
        ["988f7d2e-a2f9-0be5-70d6-8e2852fb565e"] = "12181046-492e-5866-9798-1d7e6a559446",  -- HUM_F_CLT_MiddleClass_Body_B
        ["f0fa5d54-87bc-cd18-fb3f-52559917ab28"] = "9f6274db-f9bf-5bf3-947a-01c20209cbe5",  -- HUM_F_CLT_EPI_MiddleClass_Body_B
        ["6ab2470f-4430-f08e-c20d-1b44a1671d71"] = "ae9e62d4-3f7f-52b3-b68f-00f237e1be8d",  -- HUM_F_CLT_MiddleClass_Body_C
        ["5299aedc-02ac-40cb-906b-c2144e3543e8"] = "79e30800-ccd0-5c8a-b2c8-d3ca08aa4a52",  -- HUM_F_CLT_Mizora_Body_A
        ["056e67fb-7722-4e59-9e1c-b75180177509"] = "1003ac67-7e9f-52c0-88b3-c9e16f36ee3b",  -- HUM_F_CLT_Nymph_Dress
        ["b0cde6e3-83bb-62e3-4c9b-c0ee256fc951"] = "d045a4b4-44c8-55bc-bd16-7b018cf895b4",  -- HUM_F_CLT_Pants_A
        ["037f2658-0f94-a1f3-6162-3ab3ef46ef9f"] = "54c362e6-c039-5dcb-a182-60f3d3f8f06d",  -- HUM_F_CLT_Pants_Torn_A
        ["437ba6c8-16f3-a51d-d33f-496b886e7377"] = "cc304980-1a94-52cb-8bab-85e66ce35f79",  -- HUM_F_CLT_Pants_B
        ["9ac53050-ed2f-32e2-361f-2ac4a849247c"] = "53bcdbed-54a9-5c88-9ecd-4171eeeca79c",  -- HUM_F_CLT_Pants_C
        ["814be387-c446-a05e-1ab8-c1a22bfbfb88"] = "b0610ea8-69b7-5ed1-84ab-b07b33069477",  -- HUM_F_CLT_Pants_Torn_C
        ["6ac9cad5-111e-33ff-3eda-ecffc3f8977d"] = "1b026cdf-d42d-5458-b752-bb97599b161b",  -- HUM_F_CLT_Pants_Courtesan_A
        ["2d0f8f38-2383-125f-eb37-02d0916958d1"] = "7e8401be-0483-5203-b3c0-56df9fd46cfb",  -- HUM_F_CLT_Pants_D
        ["8dbbdbea-3435-d58f-00e5-ffc390e1f1d8"] = "a4f2a60d-bf74-5047-8cee-af268850e87e",  -- HUM_F_CLT_Pants_E
        ["ac0d8966-439e-890c-c363-4cc3a06673a8"] = "6fc251ee-8ec5-589a-b0d0-25e88b66a4c3",  -- HUM_F_CLT_Pants_F
        ["ddded88b-7eae-8063-c28b-29747f85b921"] = "962df85e-c69e-5a50-98dc-b01622f9c2cd",  -- HUM_F_CLT_Pants_G
        ["073bcd0e-0fca-bc1a-6abc-2cb9f94d8ec6"] = "e01af2bd-8836-5d0e-b281-83f21792c7d4",  -- HUM_F_CLT_Pants_Torn_G
        ["680e2bc4-eb37-2dbd-955e-ae510a4e1743"] = "bc62a95b-e113-5975-9282-b70bb22c3fd4",  -- HUM_F_CLT_Pants_H_Twitch
        ["9c9e4cb9-e1b2-ebce-e984-4324f4c9b69c"] = "3c4e8d60-67e0-54b8-96a9-55de7b0c5d1f",  -- HUM_F_CLT_Pants_H
        ["8f8751f9-bb4d-6e95-1883-567ef89578aa"] = "9eb2004a-64de-5990-bd47-a093e13ec9fe",  -- HUM_F_CLT_Pants_H_Short
        ["9bb0a1f0-3db4-314e-5725-d1c7f3e30557"] = "5300c16a-ea43-582d-bd38-136125018c88",  -- HUM_F_CLT_Refugees_Corset_A
        ["410a4505-7032-e0f3-3825-96e5bca7352c"] = "dce8938b-74cb-5581-b8f5-a4627d831c19",  -- HUM_F_CLT_Refugees_Corset_B
        ["38ab17d2-15d3-252f-d0ec-3866011c31cc"] = "bb0794ef-b3b2-5d28-98f5-170e472c813b",  -- HUM_F_CLT_Refugees_Pants
        ["93d267af-f36e-8383-5d22-4b95bf38f321"] = "14453e50-d676-5f54-8475-845d0f66b6ae",  -- HUM_F_CLT_Refugees_Pants_Torn
        ["4d196657-a569-7e5e-b883-adb32bf7c17a"] = "cf97d0f7-1ade-5f1d-93f9-c9280b33c1ce",  -- HUM_F_CLT_Refugees_Skirt_A
        ["ac711a8a-3264-13f8-3d4f-39cc454ec168"] = "e0a7e0b9-cc11-57af-bc41-e724b12e360b",  -- HUM_F_CLT_Refugees_Skirt_B
        ["c129ed42-df0f-1f7b-098a-d9e5b425b7b7"] = "3017f316-3d8b-5099-8bb4-8d1bdb71ba05",  -- HUM_F_CLT_Refugees_Skirt_C
        ["7dccd203-9d87-f011-b48b-095c94a802c7"] = "1c9c2cb3-d3d2-551d-8e1c-17738fec50af",  -- HUM_F_CLT_Rich_F_Body
        ["997602e8-8406-46d1-5bb3-800c5478a46b"] = "499b9e34-6785-5785-8492-2a4b8a9b3186",  -- HUM_F_CLT_Rich_D_Body
        ["d68214cf-e2bf-f120-9ef3-1f850a9246b5"] = "559d233b-8e85-52c6-b081-4a86de4832e1",  -- HUM_F_CLT_Rich_E_Body
        ["025db7fc-0c5b-5072-e988-9880c7010a7f"] = "6054e102-fb0f-5b89-b689-45e7fe7a9133",  -- HUM_F_CLT_Rich_D_Pants
        ["e2e0e9e3-8082-07aa-0284-930015839327"] = "4fa3e7af-f0d9-509c-9535-fef61fda2512",  -- HUM_F_CLT_Rich_F_Pants
        ["d3c152cc-56e3-4561-4321-518f6f21546c"] = "a6b9fd31-e7ef-5420-a835-33366e97920b",  -- HUM_F_CLT_Rich_Dress_A_Body
        ["15d6efbf-1aae-0dcd-bcfc-834a86c9e011"] = "9faa2ef0-eb70-52f6-a770-93bfc12ab41c",  -- HUM_F_CLT_Rich_Dress_A_Body_2
        ["c92f9f3c-712f-8c7f-6a0d-4d4516fd0737"] = "18e9e6d5-20e8-505b-bdbe-669ee6c8ea53",  -- HUM_F_CLT_Rich_Dress_A_Body_3
        ["b1ac04ac-8d6e-8733-889e-52278f7bd5ef"] = "df12491b-9b2f-5b85-9ccf-026f0316f4bb",  -- HUM_F_CLT_Rich_Dress_B
        ["b925d640-eb8e-9ef6-7561-2c1db074df4f"] = "4f66e00e-50ec-590c-b2cc-dda9be65d0fd",  -- HUM_F_CLT_Rich_Dress_B_Accessories
        ["4aa3396b-85b4-ccfc-055d-c45a2b9ffcb8"] = "eb307c6a-27db-5703-9154-81520f21e6a0",  -- HUM_F_CLT_Rich_Dress_B_Shirt
        ["a1fc20ac-2abc-8f45-6435-f6f7b98f4a19"] = "bd160a29-fd21-51db-9e3a-94d1be949ace",  -- HUM_F_CLT_Rich_Pants_A
        ["e84b91c8-6d62-d46f-8a1a-0b87191f62dc"] = "8a4f5046-0ade-5460-b02e-d7946a3f7a0d",  -- HUM_F_CLT_Rich_Shirt_A_Pants
        ["927cfa94-1fb6-3a04-0db5-11195fb37ae3"] = "12a88589-c46e-5302-ae38-9a175e7305cd",  -- HUM_F_CLT_Circus_Pants_B
        ["dab58757-2da5-f75c-5e35-396a5b4f3be4"] = "bb104d09-05c8-5d09-9bc7-5d9323393a6d",  -- HUM_F_CLT_Rich_Shirt_A_Body
        ["5c046b60-41a2-28b2-eea3-7267b7ce52e5"] = "66fedf75-fd75-5ee5-9400-3d1683989548",  -- HUM_F_CLT_Circus_Dress_A
        ["8b02460a-147e-9e0a-02c6-4df064e68c09"] = "f1201a12-4c11-576e-a645-66fa1ca3ae43",  -- HUM_F_CLT_Shirt_Courtesan_A_Corset_A
        ["678cb240-d96f-5bbb-29ce-39d9d32de01f"] = "b29d2a97-2a56-5dbb-afa2-fb98ecc52e15",  -- HUM_F_CLT_Shirt_Courtesan_A_Corset_B
        ["d4badd19-dde6-ebb1-810f-8c7cf1c73a27"] = "ddcb8d80-7d65-5224-8570-8e99694dc9c3",  -- HUM_F_CLT_Shirt_Courtesan_A_Corset_E
        ["bf06fc6a-82f0-a561-d26b-9023042beacd"] = "cb6fdaed-751c-5c05-af78-245e9e3f7791",  -- HUM_F_CLT_Shirt_Courtesan_A_Corset_Twitch
        ["f4cd5679-9a06-30ae-c8b5-97dcccf7896f"] = "6125498b-8c8c-58b0-ab6d-580ff3ee726a",  -- HUM_F_CLT_Shirt_D_Corset_B
        ["f89199e3-6801-a4ef-32dc-11c1d7521ddf"] = "c6d403df-314a-5607-811b-76a4c08267e1",  -- HUM_F_CLT_Shirt_D_Corset_Alfira
        ["f994d29a-7e3e-dbc2-e577-99b6869c413b"] = "9cd3a613-754a-5f79-a9ea-145f15185c6f",  -- HUM_F_CLT_Shirt_H_Corset_B
        ["c4f40a4a-5e87-eb9c-da5e-d268f1761083"] = "8f2f0361-a3d7-5a23-aff2-9c5d607e798e",  -- HUM_F_CLT_Shirt_H_Corset_E
        ["898a98d7-9100-d842-68e6-093d201ac6f8"] = "834f1526-96de-5c77-b4a9-c3b5debad893",  -- HUM_F_CLT_Skirt_A
        ["ecf67d32-6eb7-b67d-a7bd-847367f24e8b"] = "27c40a70-6d7e-53b0-9fe0-8e48fed81203",  -- HUM_F_CLT_Skirt_A_Spring
        ["05986d42-16ec-c7b6-c1ed-0bd21d03df83"] = "5ed59016-b454-5d60-9713-6724ca5faf4d",  -- HUM_F_CLT_Skirt_B
        ["4018e880-fb09-b84c-85dd-f8701eee1bbb"] = "1ec8f5d1-2cbc-54d9-8245-8b5d5a52c3c4",  -- HUM_F_CLT_Skirt_B_Mayrina
        ["1039260c-c726-ed05-8785-6ead6bb7b3b0"] = "ca11164a-5a71-5517-a71e-3143f8dab48d",  -- HUM_F_CLT_Skirt_C
        ["5e4726c4-048d-b195-9e9e-dd983d5016b0"] = "66088d90-0107-556f-a44c-d441315865bd",  -- HUM_F_CLT_Skirt_Courtesan_A
        ["13297b57-278a-4b8b-f469-859ebff773a7"] = "36d2c278-6966-5aee-b6b8-8a6b7e2553a4",  -- HUM_F_CLT_Skirt_Courtesan_B
        ["c0968035-1291-f945-bd4b-3b0514e52bff"] = "09361871-bd6e-5d79-b980-a1391c55fd8e",  -- HUM_F_CLT_Torn_Body_A
        ["11634ec6-d3fe-1a2b-5ffb-85dcda9a48f6"] = "bdaf2219-41b1-56ad-be37-1390580f20ab",  -- HUM_F_CLT_Worker_Body
        ["dda05feb-d0ab-4399-a0e7-34b5213bd4a3"] = "b7b3840c-6dab-596d-acd3-c0c56b7e2749",  -- HUM_F_CLT_Worker_Pants
        ["e073aabb-ce90-3e7a-a59f-79f36b40dfb6"] = "41cadde8-2366-5683-970b-84dfed8d6f78",  -- HUM_F_Nurse_A_Legs_Bandages
        ["89bc4da1-7904-faca-aadd-d30ee6e33ee1"] = "bae10ee5-1860-550d-8fc8-609eb8a27b12",  -- HUM_F_ARM_Nightsong_A_Body_OLD
        -- CLASS1 (W-B1, 2026-07-26): BCBPak redefines these vanilla VRs in place;
        -- these are clean-vanilla clones (SourceFile = Larian's own GR2).
        -- CONFIRMED IN-GAME by !cm_visdump, vanilla mode, BCBPak installed:
        --   att[5] VR=6682ffad-... src=.../Generated/Public/BCBPak/.../HUM_F_CLT_Camp_Shirt_A.GR2
        -- while body and trousers (which HAVE refit entries) both tracked the mode.
        -- Gated on BCBPak presence via BASE_VANILLA, which snapshots this whole
        -- subtable at load (see :1464). There is no CLASS1_KEYS set -- REV 2 of
        -- _apply_class1_to_lua.py dropped it as redundant.
        -- vanilla ONLY. sbbf is affected by the same passthrough but fixing it
        -- needs 77 deformed meshes -- deferred to v1.3 (Alan, 2026-07-26).
        ["9fd5fd68-bcae-5be6-3232-062490e3c488"] = "f5c15c6d-be04-5394-8da1-2e07bc892473",  -- HUM_F_ARM_Astarion_Shirt
        ["c6253618-9059-e04c-0833-735bd172184e"] = "9fc60a94-9719-5c0b-8cd0-9cc54ce36e63",  -- HUM_F_ARM_Bandit_D_Jacket
        ["9ecefef0-cf8c-87a3-d2ca-62606e1a3f32"] = "7acbede7-3e79-5cf6-95d7-17e8d50f4276",  -- HUM_F_ARM_BarbarianMagical_A_Belt
        ["3f7cef8d-f5fc-4b8a-21dc-4f34d002a88b"] = "d8be7656-f757-5f2e-955a-3417c80ff23b",  -- HUM_F_ARM_Bard_Sleeves
        ["443780e8-54a1-5d21-a9e2-fb651ccc173d"] = "c18211ca-418f-57fd-ae0e-9dfc05626bf2",  -- HUM_F_ARM_Bhaal_A_Waist
        ["607f5d1c-57b2-3e0e-fd13-64909a094752"] = "9c90c761-a623-5252-9898-b6aaefe367b2",  -- HUM_F_ARM_ChainShirt_Shadowheart_A_Sleeves_A
        ["d04cf0d3-e776-852c-afa8-dc9d191578c4"] = "bdff610d-6279-5579-a4d6-971823802cca",  -- HUM_F_ARM_ChainShirt_Shadowheart_A_Sleeves_B
        ["3e79df3a-b55b-f4bb-c84d-213b3d28c082"] = "bb28c43c-0e09-5809-8249-baa17428cb76",  -- HUM_F_ARM_Cloth_Magic_A_Bandage
        ["f65f5c50-677b-0da7-e7f8-4496f2585401"] = "bf910484-82b1-5131-a387-78625fcddf26",  -- HUM_F_ARM_Cloth_Magic_A_Pieces
        ["60e61fbf-0b59-555a-5269-a72376c980cd"] = "9aed2c31-b817-57bc-921b-af5325dc1bf3",  -- HUM_F_ARM_Cult_Absolute_Tabard_A
        ["34b36570-b019-3cef-1729-6398e05ac7ee"] = "d97e17bc-6ae9-5d39-b215-525d54d9f53d",  -- HUM_F_ARM_FlamingFist_HalfPlate_A_0_Tabard
        ["633022b3-d96a-70e8-20c1-538de72db7e1"] = "4eb5439e-64df-5cdd-aa17-3d7945dd6142",  -- HUM_F_ARM_FlamingFist_HalfPlate_Marcus_Tabard
        ["f1fb6cd4-e35b-d4c3-06d7-64e28ccb4c0e"] = "a2ddfc83-d344-5e0c-8f60-3e8bae5d26e8",  -- HUM_F_ARM_FlamingFist_Leather_Sleeves
        ["d7295df4-bc18-0d50-397f-2547f2997741"] = "c0c6ec39-2839-5880-b2df-a183861bca16",  -- HUM_F_ARM_Jaheira_Robe
        -- [MOONSHADOW FIX 2026-07-27] removed from class-1: these Leather_A sleeve pieces belong to multi-piece
        -- outfits (Moonshadow Armor Alt); the vanilla clone mixed proportions with the BCB-refit body/pants,
        -- and BCBPak's own override for 84195a60 is an EMPTY mesh -> missing piece. Restored to passthrough
        -- (pre-v4.16 tested baseline). 84195a60 = Alan-confirmed regression; 54bc906f = its sibling sleeves.
        -- ["54bc906f-60ae-8ee5-2ac8-1a25117ff4e7"] = "d82a9591-d45c-52c6-93a1-6617117efb3a",  -- HUM_F_ARM_Leather_A_2_Sleeves
        -- ["84195a60-f6e8-fa8f-bb53-1c3599d0954c"] = "b5e15e03-13b2-5989-94a7-cab17c33d791",  -- HUM_F_ARM_Leather_A_Sleeves
        ["366af0d3-dd14-89bb-0474-80a6b884638f"] = "920c65d6-5748-564f-b6d0-8bfba997ca87",  -- HUM_F_ARM_Orin_Jewelry_Player
        ["52495c86-346a-6954-b6f2-578208bd5637"] = "ba073f55-dca6-52aa-8432-325d3a854bb0",  -- HUM_F_ARM_Robe_C_UnderShirt
        ["b4348095-0191-8bf0-cd0e-e210993674b6"] = "cb227097-41c1-5f72-9017-941e7962028b",  -- HUM_F_ARM_Robe_Umberlee_A_Accessories_B
        ["947458d6-da8d-b629-4f77-111581b2712f"] = "f2c21ead-bcc1-55b0-86a5-428d5a85cff1",  -- HUM_F_ARM_Robe_Umberlee_A_Accessories_C
        ["71eff4ac-87d0-e559-f4ca-a76a7597fcb9"] = "583ff967-dfb4-5ad0-bf4d-1d4237375221",  -- HUM_F_ARM_Robe_Umberlee_A_Shoulderpads_A
        ["3eae5046-b712-e68c-2168-d16012c2bda1"] = "d4509f13-346c-577d-a389-7daeaade272f",  -- HUM_F_ARM_Robe_Umberlee_A_Underwear_A
        -- [MOONSHADOW FIX 2026-07-27] removed from class-1 (tested-family item that rendered fine pre-remap;
        -- remapping changed a look that already passed). Restored to passthrough.
        -- ["238f0743-6fcd-f788-358f-c892160b3e68"] = "cce433d6-2153-5313-a147-074fb5dd0b34",  -- HUM_F_ARM_StuddedLeather_A_1_Body1
        ["4c6a422a-6512-fa86-658c-30e99406f943"] = "a17d5a34-eb88-55d3-88ac-800f82fc8bff",  -- HUM_F_CLT_Camp_Citizen_Shirt_B
        ["6682ffad-1f04-3e05-660f-6d20c8c3772c"] = "de927ecd-7801-5932-adb4-dab9e73a43b8",  -- HUM_F_CLT_Camp_Shirt_A
        ["7d2ea148-347c-d31a-2f54-2e4ea0401b6a"] = "321750d8-67b6-57fd-b90f-43c6c53ce621",  -- HUM_F_CLT_Camp_Shirt_B
        ["76879699-6811-451d-316b-d67a8824fc98"] = "348dabd4-8c7f-5ed7-a508-5574aaee0013",  -- HUM_F_CLT_Camp_Shirt_C
        ["d600fd55-1a80-25fd-98d4-aaddfdb3b90d"] = "bc75a14a-8741-5dfe-bc8e-317c29df1f41",  -- HUM_F_CLT_Camp_Shirt_D
        ["9bdc9e17-7f4d-d3ff-1e29-04c93d39bdb1"] = "a55927cd-ce0d-5274-852b-ddd3209fe94a",  -- HUM_F_CLT_Camp_Shirt_E
        ["31428c0b-7f8b-a6e1-3272-558b2ffd7a83"] = "59464617-e5b0-5eb7-a22b-d833907b35aa",  -- HUM_F_CLT_Circus_Jacket_A
        ["48d6a6c4-0570-2436-492a-f93c8e787d01"] = "10404827-7d63-5f0b-a77b-638df2ddef90",  -- HUM_F_CLT_Circus_Shirt_A
        ["48375b27-db2a-cd01-9de1-4245a3811a07"] = "27f4d390-88e9-52d8-b165-a4df2c4dc926",  -- HUM_F_CLT_Circus_Shirt_B
        ["3f331b5d-6ec3-2600-1e3b-d5746a88af7d"] = "bf498a6c-e095-5a53-8d06-a87745f64aae",  -- HUM_F_CLT_Circus_Shirt_B_1
        ["89fc2d48-e474-e859-5fa2-f3f47c35962d"] = "4cfd1700-1cd0-5063-abb3-93fcc7f1e72e",  -- HUM_F_CLT_Circus_Shirt_C
        ["9e81a487-2468-347d-9d7e-ee35282448f8"] = "967596e8-d325-5bdd-ba25-19a7d15778b0",  -- HUM_F_CLT_Circus_Shirt_J
        ["f62105ae-2388-54c6-e834-31f490df7b49"] = "c373a960-7001-563b-b4c0-22399741e5e9",  -- HUM_F_CLT_Circus_Shirt_K
        ["d4fd883c-1370-e111-736e-67dfbab7139f"] = "946a41d7-5f8c-548a-8d82-9d4b9c0d7b8d",  -- HUM_F_CLT_Daisy_Playsuit_A
        ["edf95138-e356-5a4f-3a2d-e2cbc07c33c0"] = "0734d752-1fb3-5fa9-9450-e4574200564a",  -- HUM_F_CLT_Doublet_A
        ["66de53c5-2170-c8c2-9061-a411d5e256ea"] = "c184b665-d8ed-5658-96db-01ddcb6b9b0a",  -- HUM_F_CLT_Doublet_Rich_A
        ["66fe0115-ae82-854c-6501-b32c4032c448"] = "722dfc58-1e4a-5911-9272-1bf395a1cedf",  -- HUM_F_CLT_Doublet_Rich_B
        ["737e78a2-3317-8d01-48a8-0a6ba0a8fb3c"] = "5dc4566f-29b3-51a2-9ded-10069340b47e",  -- HUM_F_CLT_Doublet_Torn_A
        ["8b303896-afc6-36b0-d25a-70e8cbd0cd7f"] = "fa5cc8b2-edc4-5f0c-911e-0180436e0f6c",  -- HUM_F_CLT_Humans_Shirt_A
        ["73c1e8f2-a765-eab5-011f-350a7f2ef33b"] = "ad1dc308-30b6-52ba-9edb-df9bf195e720",  -- HUM_F_CLT_Humans_Shirt_A2
        ["13c6fa13-ef7c-df18-b462-ad880d7233c8"] = "87ec4271-eb84-5e5d-8886-43660078dff9",  -- HUM_F_CLT_Jacket_A
        ["2e42d72a-e2e4-f081-9b6f-afa5f827366f"] = "98f073fb-590e-5544-9340-ed9b1f7595ca",  -- HUM_F_CLT_Jacket_C
        ["34a5b970-a7c0-b622-b4f5-9ff960cfb059"] = "54720f2f-faa9-5949-aa4d-a0332657c11f",  -- HUM_F_CLT_Jacket_D
        ["c23faa1e-05da-6685-f1f0-b064946f9d7d"] = "069cd10b-b8a6-512b-b4e8-e5da8adbbd68",  -- HUM_F_CLT_Jacket_E
        ["2987b0a2-c428-ecff-1280-26ab0cf47d83"] = "5549fa09-9736-554b-86b9-21ff34f2cd9b",  -- HUM_F_CLT_Jacket_E2
        ["84fb4180-3407-f5d5-3d77-c80f3125dddf"] = "d31c726e-6de5-5492-9238-53e90fa9b088",  -- HUM_F_CLT_Jacket_Torn_A
        ["01e718e9-8992-312f-dc73-082846ac972e"] = "589a9ff4-0f58-5226-9941-4ca6a4cbbde9",  -- HUM_F_CLT_Refugees_Jacket
        ["20e07fc7-8550-069f-7271-db030aec1a3c"] = "7f381d1a-89d8-538f-a6da-888cc4d9c2af",  -- HUM_F_CLT_Refugees_Shirt_A
        ["a5512e5f-3b52-2c29-d19d-fe6465c5819e"] = "45e738c0-e063-5939-a291-8f0d9e82fee6",  -- HUM_F_CLT_Refugees_Shirt_A_1
        ["94e1c917-9b46-afa4-6733-e0daff97ae98"] = "f403972a-59d1-59bc-9164-de026eb5827a",  -- HUM_F_CLT_Refugees_Shirt_B
        ["436e0c5c-826b-5686-d6f0-b98503bf5a8d"] = "0a967ecf-38b6-5c9c-8cbc-38cb7d727a05",  -- HUM_F_CLT_Rich_Shirt_A_Trim_A
        ["cf140f3e-d8aa-137c-659d-047f0fe80de3"] = "3720af2d-102e-5731-ac77-0f30c0741dea",  -- HUM_F_CLT_Rich_Shirt_A_Trim_B
        ["8f6c726e-0264-e29e-4924-3982682de64b"] = "3b3d2215-3772-5e01-a9ef-c767965af9ba",  -- HUM_F_CLT_Robe_Ilmater
        ["f156291e-fcf6-ff37-9e89-cd83abf3cc15"] = "5e7b9f1a-a342-5dfe-8752-557bc0be60e3",  -- HUM_F_CLT_Shirt_A
        ["c1e76ac0-21f2-4e6b-265e-5ca4ed03ca27"] = "583ce5f6-0ede-5e4a-8880-afac9aa00bc5",  -- HUM_F_CLT_Shirt_B
        ["00795a8a-3e73-036c-6d43-72560a9c403b"] = "bf655236-1507-5935-b5b2-40184196574c",  -- HUM_F_CLT_Shirt_C
        ["fa7e57fe-59b7-5e83-4dbc-8359db5b931f"] = "b28927c1-8867-50b1-b4ea-595573d58037",  -- HUM_F_CLT_Shirt_C_1
        ["0ed30320-35a1-2e07-c94b-e1ad0b908f99"] = "f6444cd6-6624-5190-ab1f-128f3a4da907",  -- HUM_F_CLT_Shirt_Cook_A
        ["f37a4733-de54-2fb5-5faf-bc3249f07bfc"] = "1b07cadf-45bd-5a45-ad09-bbeab38da895",  -- HUM_F_CLT_Shirt_Cook_Torn_A
        ["ef4f61fc-224e-22fe-7e3c-a9eae4c08e94"] = "072f4aa3-ee42-57f6-b9c7-37d213a7e168",  -- HUM_F_CLT_Shirt_Courtesan_A
        ["bd02a60a-3bae-98e2-435f-60c1580c2a90"] = "9264fa72-72f0-5cc1-b639-2eacc93fb91f",  -- HUM_F_CLT_Shirt_D
        ["9a04af56-0092-cc5b-8940-6c848b7da5d0"] = "0db935e2-7be8-5872-9fd0-7f07570264ed",  -- HUM_F_CLT_Shirt_E
        ["bef59a75-5a3e-b4a0-77f5-3116910ca944"] = "03d49071-fa2f-5b47-bd73-e14b2ff8f55a",  -- HUM_F_CLT_Shirt_F
        ["f5d3d9f0-fb61-e7ec-a278-930ea7c286a4"] = "f64b7f72-828b-5354-ba90-8ef33c5d86ba",  -- HUM_F_CLT_Shirt_G
        ["f6e56693-8397-db61-0b70-4b7d072b3896"] = "94ff070e-f952-5431-bfb7-24af4283899c",  -- HUM_F_CLT_Shirt_H
        ["ba08fa53-4972-772a-48aa-cca2bd93c39d"] = "ffa2e316-0629-5f60-9f5b-2aafecd6ed2b",  -- HUM_F_CLT_Shirt_I
        ["ad195e3f-8399-f77a-b999-a1ca70f1040d"] = "54c5320c-c42d-5794-b5f1-3076b587007c",  -- HUM_F_CLT_Shirt_J
        ["1a6ded21-70a7-a64d-8a3e-bd2b4118849e"] = "e5d58541-aba8-5086-8324-eed4bf0cb0ed",  -- HUM_F_CLT_Shirt_Torn_A
        ["da9cba7e-1246-c328-06cb-e92d76f236eb"] = "81989ecf-ba22-532a-814c-04f888361a11",  -- HUM_F_CLT_Shirt_Torn_C
        ["d5336987-990f-4544-a9dd-303cda4aa035"] = "d5f8948b-e242-5a90-aa0c-7061327a1d73",  -- HUM_F_CLT_Tunic_A
        ["f9c1a759-87f1-900f-0111-e628bdea4da4"] = "94e96cc4-6e80-5655-b074-611e63a22921",  -- HUM_F_CLT_Tunic_B
        ["24f998e5-2341-c834-e104-f99619c89d78"] = "5d028b3a-9a83-5163-91c2-52c11487ce09",  -- HUM_F_CLT_Tunic_C
        ["c1ddf743-5f23-acfc-62e1-049e61b43ec3"] = "6370dc07-ee9c-52d7-b159-2d7d9650c892",  -- HUM_F_CLT_Tunic_D
        ["9096cac7-7d3e-917d-47ca-5cd6998c0886"] = "b7703829-5ee2-563b-94b9-5a2d1c3ed002",  -- HUM_F_CLT_Tunic_Torn_C
    },
    sbbf = {
        ["02964f77-c398-423b-a5e9-f7810243811c"] = "7a9547fe-98e0-5256-bbc1-557f76e50aaf", -- HUM_F_ARM_Adventurer_Body_A [GLB]
        ["ed8e5366-bfa5-91c4-9eae-9ef39f402214"] = "bf9c1d6d-cc14-57d6-95ec-179e95ea1d07", -- HUM_F_ARM_Astarion_Body [GLB]
        ["7187c0c1-3752-5d43-9858-7b72fdb0fa3c"] = "7e774abe-ba83-517f-886b-d0e816da508e", -- HUM_F_ARM_Astarion_Pants [GLB]
        ["51ae8337-9dd3-8552-f4c2-85e755a44503"] = "68c6e0e1-1748-514e-9e52-42c09d364990", -- HUM_F_ARM_BG_Watch_A_Pants [GLB]
        ["3a2f737e-8f3d-a59b-d457-36e89775d423"] = "62b7f63e-cd15-5cda-9795-bbb009974f6b", -- HUM_F_ARM_BG_Watch_B_Pants [GLB]
        ["f395018f-ffb4-03e8-add9-ed9698fb1e51"] = "35088634-9df3-53b5-9748-fa221bff67b7", -- HUM_F_ARM_BG_Watch_C_Pants [GLB]
        ["a2edea05-8d9d-4d60-c128-6484fec0727c"] = "e43c7005-ab47-573c-a851-c0f88d82bd90", -- HUM_F_ARM_BG_Watch_Leather_A_Body [DAE]
        ["6bcaace7-2b7f-f347-bbbf-b7f6de1b406c"] = "ae9a25c6-a995-5bfc-8d92-5347831df52f", -- HUM_F_ARM_BG_Watch_Leather_B_Body [DAE]
        ["7eecdfb8-78f4-791c-dcdb-dce69bcf89a4"] = "43dc6151-2518-52b2-ad56-fd1742c2ce34", -- HUM_F_ARM_BG_Watch_Metal_A_Body [GLB]
        ["73eaa7e2-e2c4-bb99-8cdd-c02bce1979f7"] = "f22f22b8-9154-58fd-992d-f79c5e264116", -- HUM_F_ARM_Bandit_A_Body [GLB]
        ["c18aac16-80cf-b3a1-7a68-2321e4e7f26d"] = "0ca58def-a823-588f-b15e-77218f9243e2", -- HUM_F_ARM_Bandit_A_Long_Body [GLB]
        ["4bf4a998-d2ae-a670-b31b-6efff35a28a4"] = "01917393-94f6-5d92-82c9-3e8cb2444797", -- HUM_F_ARM_Bandit_A_Pants [GLB]
        ["2ec28d08-14cd-cf28-a750-ce566d791ef8"] = "a6cf89b8-dc7e-5f58-95df-011b63ccf0ea", -- HUM_F_ARM_Bandit_B_Body [GLB]
        ["fe22e643-1266-a94a-0b42-eba64f922d8b"] = "ab2f5ee8-fb45-5b74-91a8-2e78fca49da7", -- HUM_F_ARM_Bandit_C_Body [GLB]
        ["904fbbc1-fca5-af69-66b0-f883728baf77"] = "4f97dbfd-2f5d-5ccf-b942-74ed9e172412", -- HUM_F_ARM_Bandit_C_Body_Accessories [GLB]
        ["5b042a61-3dcc-4a82-a2bf-b710f04abb81"] = "28527987-a7b1-5cdd-b251-5c02fbcdd810", -- HUM_F_ARM_Bandit_D_Body [GLB]
        ["aa476663-1b31-19af-8e56-d071a91b74e8"] = "c4d58243-4b3b-504d-b5ba-f354c7803f3a", -- HUM_F_ARM_Bandit_D_Body_Belt_A [GLB]
        ["67cf64e2-d4df-d5c8-c988-bbe24c9ab0ef"] = "353d42de-9227-50c6-ab3f-3aae3acfc660", -- HUM_F_ARM_Bandit_D_Body_Belt_B [GLB]
        ["d2f744a0-4d40-1da3-bc2d-188cab1cf9cc"] = "1d89df23-7721-5a0c-b4e7-58a75d3e20f4", -- HUM_F_ARM_Bane_Light_Body_A [GLB]
        ["c6f30055-6e56-88ec-afff-8b16e0861797"] = "1c95c8b9-c8d2-5f81-b86d-dbe6bae3d60a", -- HUM_F_ARM_Bane_Light_Body_B [GLB]
        ["c390c1b4-9592-e7bd-45c7-25de362c39d0"] = "a8a612c9-cbb5-588c-806d-081312380944", -- HUM_F_ARM_Bane_Light_Pants_A [GLB]
        ["070fb86b-3b1c-07b6-bda6-ae3f54e6202c"] = "f10920bb-af88-5546-bbb2-de8c3ae19539", -- HUM_F_ARM_Bane_Plate_Body_B [GLB]
        ["4e6a8fd0-0f1b-97d5-2938-156505003b0c"] = "f3cd3b6f-4f3b-532b-9b79-4beb3ee241cc", -- HUM_F_ARM_Bane_Plate_Body_A [GLB]
        ["dde52dc3-cb63-0d90-393e-f3d9c3b8967b"] = "f3aa570c-0d61-50ae-b572-0653e02d4b4a", -- HUM_F_ARM_Bane_Robe_Body_A [DAE]
        ["3fb7ea07-c5dc-954b-c58a-a8ec276ace28"] = "3eed28e8-ab42-5e11-9829-5fdf482343de", -- HUM_F_ARM_Bane_Robe_Body_A_Sleeve [GLB]
        ["6671bb2f-ab3c-ce01-30c5-05ab81e64ec4"] = "a3d901aa-bea1-5b17-a11e-bc6b7d7b23f3", -- HUM_F_ARM_Bane_Robe_Body_A_Sleeves [GLB]
        ["577e0453-07bb-c66e-33b1-7bee394c1a7f"] = "d63887a0-10d3-558b-97d3-621beaa64a4c", -- HUM_F_ARM_BarbarianMagical_A_Body [GLB]
        ["089ee9e1-e764-38dd-c742-fd905f976f13"] = "190101d8-e0de-5278-a84b-3acb9a90fcd6", -- HUM_F_ARM_BarbarianMagical_A_Chest [GLB]
        ["7723fc3b-12a2-9f4f-d753-adaf00b281ec"] = "66da3c3b-98cd-530a-b4e1-d6836a849250", -- HUM_F_ARM_BarbarianMagical_A_Pants [GLB]
        ["bcdf262d-b528-2448-76cb-3444588738a4"] = "58cf9943-9806-5c6b-89b4-cfb617a32e43", -- HUM_F_ARM_BarbarianMagical_B_Body [GLB]
        ["0aed3d1c-709d-3f1e-71f1-1134ba9e060e"] = "58295042-5741-52bc-a1a4-779eccae584b", -- HUM_F_ARM_BarbarianMagical_B_Chest [GLB]
        ["40c284ef-a371-eec7-a27a-dd277dee03cb"] = "42393c10-c55d-51f6-b730-e7bc29d1bb5b", -- HUM_F_ARM_BarbarianMagical_B_Pants [GLB]
        ["991c652e-3aa8-f8b1-609a-f8bd87b28636"] = "82a2abac-c938-5131-93d8-36a18b8fd495", -- HUM_F_ARM_Barbarian_A_Body [GLB]
        ["1b60efd1-c080-f02e-4b7c-988699485ae0"] = "46c15984-cf1d-5acf-abdc-d16c70cc4d1c", -- HUM_F_ARM_Barbarian_A_Pants [GLB]
        ["11a29e17-99fd-0db5-ec2e-d90a40ec5b1f"] = "56123760-543c-5891-b0d3-1bda2ca9d5a8", -- HUM_F_ARM_Barbarian_Karlach_A_Body [GLB]
        ["7cc5cafc-2bb8-3627-97e0-125d2c4fd084"] = "d1f78c8d-014c-5779-a67e-ae9196add595", -- HUM_F_ARM_Barbarian_Karlach_A_Pants [GLB]
        ["34fbe3a5-7d74-c705-a42c-4e9922fa12fc"] = "9026c6f4-c373-582e-998c-158484ce66b4", -- HUM_F_ARM_Bard_BodyBot [GLB]
        ["69bf1065-75ae-2930-33b8-ac4a5bdde0ad"] = "6baedaad-46f5-549e-b1ee-45db348947f3", -- HUM_F_ARM_Bard_BodyTop [GLB]
        ["29153218-c410-bd1e-b23d-d615ead06201"] = "e463fa37-dfa7-5740-899b-04a258ea1148", -- HUM_F_ARM_Bard_Pants [GLB]
        ["a8b54d83-bbba-1c0c-a3a0-f8143409b018"] = "953fa796-67ef-5567-9f79-4140cd60338e", -- HUM_F_ARM_Bhaal_A_Body [GLB]
        ["aa09792f-4f55-dd17-c2f5-7ca30642a95c"] = "74f84fda-0801-5762-8de9-ac9401bcf0b5", -- HUM_F_ARM_Bhaal_A_Pants [GLB]
        ["f8c9f76d-d57e-d818-f028-6be46ef6ac5a"] = "7d5ae585-ce1c-5c22-80e6-8ccd2916bddf", -- HUM_F_ARM_Bhaal_Rags_Body [GLB]
        ["5e07542e-8dd0-ef58-ef8e-f9c92a9a5670"] = "afc26052-d669-5547-ab8f-8bba9e4bf8fe", -- HUM_F_ARM_Bhaal_Rags_Pants [GLB]
        ["9a255759-35b9-2aca-77d4-b8b331091887"] = "ee7ae0fe-79e4-5286-a9ee-a4d71d1ed2dc", -- HUM_F_ARM_BreastPlate_A_0_Body [GLB]
        ["40d6023f-73cc-cf97-7b7c-e0efa5ef2252"] = "e0044fda-6868-55df-a3c0-214b44d78750", -- HUM_F_ARM_BreastPlate_A_1_Body [GLB]
        ["41f442ce-a9dd-57b1-8703-c0612de681ba"] = "a9f220ac-8e40-5eb6-9583-027a2c2b5107", -- HUM_F_ARM_BreastPlate_A_2_Body [GLB]
        ["2d76e68d-122c-ca1b-eae6-2754d6f2a427"] = "05cdb4f5-0b30-5061-a398-c2e04dcbaba0", -- HUM_F_ARM_Breastplate_A_1_Pants [GLB]
        ["52a0a341-e040-3d36-14cf-9ddbb1964d86"] = "98309ebf-c9a4-5702-8501-994ddac7ca53", -- HUM_F_ARM_Breastplate_A_0_Pants [GLB]
        ["7842adad-0d32-2845-321a-ae53e02759c7"] = "ec4a251c-4717-51b9-8efb-db026ab5af61", -- HUM_F_ARM_Breastplate_A_2_Pants [GLB]
        ["4b220494-227c-2286-06e7-81f5aa621fbc"] = "4383abef-b21c-5189-9c8e-25b0b9146943", -- HUM_F_ARM_ChainMail_A_0_Body [GLB]
        ["746d3091-9b4e-05d2-d6e3-990e88b4e697"] = "44bd3ae9-e978-59f9-9c6b-d6d9c242f1d0", -- HUM_F_ARM_ChainMail_A_1_Body [GLB]
        ["ea647791-dae1-f65a-4045-d971868d70a7"] = "4b15278e-12cd-59bb-b994-64fe832a661c", -- HUM_F_ARM_FlamingFist_ChainMail_A_1_Body [GLB]
        ["7a0a8086-cf8a-8526-7196-3f96c1a31764"] = "b97721db-7629-58ff-b9e8-f0e9cae9c114", -- HUM_F_ARM_ChainMail_A_2_Body [GLB]
        ["57aa9036-497a-bc54-7889-763bcf0f5ecd"] = "d245a166-bbaf-5b46-8718-aeb367c94f88", -- HUM_F_ARM_ChainMail_A_Pants [GLB]
        ["c977d6cf-90ba-08f5-0d6a-96bfcbc2ff37"] = "d0519f3f-9a7f-52f2-a9e4-38339444cf4a", -- HUM_F_ARM_ChainShirt_A_0_Body [DAE]
        ["e5b5a50e-2200-ee2a-2cac-1868323d3c2b"] = "0de508ba-9859-57cf-880b-a9ea8db42396", -- HUM_F_ARM_ChainShirt_A_1_Body [DAE]
        ["adc9638c-946d-f253-fab5-a2185780e38e"] = "b1ba5235-dacc-5273-9dcd-8387a17711e1", -- HUM_F_ARM_ChainShirt_A_2_Body [DAE]
        ["c18914df-2ecd-7418-df18-e27521d89e07"] = "970d50bf-651f-55e1-a576-79720b6dcffd", -- HUM_F_ARM_ChainShirt_B_0_Body [GLB]
        ["f6000495-b090-d2fc-1d8c-8b3269ac469d"] = "2f52aac1-99bb-582b-8848-0d2a180029b3", -- HUM_F_ARM_ChainShirt_B_0_Broken_Body [GLB]
        ["f8be761d-9160-c57d-fd57-436735b91403"] = "b96d80fc-175c-5ff3-8af3-672222ab126c", -- HUM_F_ARM_ChainShirt_B_1_Body [DAE]
        ["9a04bfd8-2a6f-a2b6-6c18-3921a81df32e"] = "600f4343-2f8d-5d0c-a961-7ae8ede74de8", -- HUM_F_ARM_ChainShirt_B_2_Body [GLB]
        ["7f17b0c8-69dc-799f-457f-aa9b0edf87cf"] = "f9468ccc-9e67-5b7a-8e0a-0ed09977a2b2", -- HUM_F_ARM_ChainShirt_B_2_Pants [GLB]
        ["86beb015-ba3b-e2f5-8fc1-a13eaae763ed"] = "537599da-baab-5804-9445-af76324566e7", -- HUM_F_ARM_ChainShirt_B_Broken_Pants [GLB]
        ["2a24cc0a-bf6a-042b-3d02-237596da3a02"] = "cffaea21-4a50-5b39-a730-b51fa0b5b176", -- HUM_F_ARM_ChainShirt_B_Pants [GLB]
        ["46d2d271-a292-6511-ab69-b5b3fb8d4732"] = "633d64cc-a46e-59ad-a43c-2f4ee4aab224", -- HUM_F_ARM_ChainShirt_Shadowheart_A_Body [GLB]
        ["355acc60-c8ae-129a-f9b8-fd46d66a9cd9"] = "a9e26620-db16-5903-ba5d-a1f73788d0e5", -- HUM_F_ARM_Cloth_Magic_A_Chest [GLB]
        ["7626ae1c-1f46-fc33-f267-fa42d6f00a5f"] = "14ce04bf-5a33-53e2-9e29-effbb8f3f058", -- HUM_F_ARM_Cloth_Magic_A_Pants [GLB]
        ["75fe0fe7-8b43-7c04-d6ff-559601640e7b"] = "472b5796-2a5c-599f-b2e7-89a21abd830a", -- HUM_F_ARM_Cloth_Magic_B_Chest [GLB]
        ["fcfff744-87aa-18d1-71b6-dd3dde8ffd2f"] = "890f64a6-1d88-55b4-b71c-3c6b327fa38d", -- HUM_F_ARM_Cloth_Magic_C_Chest [GLB]
        ["d1228194-ed35-a085-f73b-469f46be1a63"] = "ea067bc7-9c33-5df4-8d71-7cdb393ba551", -- HUM_F_ARM_Cloth_Magic_B_Pants [GLB]
        ["d1c28da5-1518-5565-e948-546ff74f14b9"] = "ffaef2b4-b12d-5eb9-adc8-457c2e971302", -- HUM_F_ARM_Cult_Absolute_Body_A [GLB]
        ["40c6743d-7f7b-9a36-ea69-ee5be3fd42ef"] = "bbf8dbe8-590d-5e6f-b466-c5ded5fca4b6", -- HUM_F_ARM_Cult_Absolute_Body_B [GLB]
        ["e936b4b2-5c11-ff4a-a9b4-7a744844e508"] = "e33d170e-f49f-5e40-9b1f-318a6a0efc60", -- HUM_F_ARM_Cult_Absolute_Body_C [GLB]
        ["4fad5d72-61e3-a66d-5789-5adb266d5262"] = "1539c17f-4508-5c74-b9c0-6d652240e3c2", -- HUM_F_ARM_Cult_Absolute_Pants_A [GLB]
        ["f593ca9c-fb69-ce98-58b2-d240acb832ee"] = "449e72a4-61fa-5e71-b34f-baa04aae6db4", -- HUM_F_ARM_Cult_Absolute_Pants_B [GLB]
        ["92904542-5941-883f-5ef9-64ed849223c3"] = "14f6cf06-628d-583f-b41e-07994306e7bf", -- HUM_F_ARM_Cult_Absolute_Robe_Body_A [DAE]
        ["223c2250-b8d2-02f8-7d81-3a5dd8aba412"] = "71554aeb-4e63-5292-9176-81d49693e284", -- HUM_F_ARM_Cult_Absolute_Robe_Body_A_Belt_A [GLB]
        ["9423615d-6287-ba55-b5ac-9120d68abbf9"] = "aadaa391-5321-533a-b2b8-48e3fe27238a", -- HUM_F_ARM_Cult_Absolute_Robe_Body_B [DAE]
        ["ab01e06f-c22c-4389-6d09-170408da0397"] = "863a45c3-ac02-5c9a-9bea-c9930175c24d", -- HUM_F_ARM_Cult_Absolute_Robe_Body_C [DAE]
        ["7ac2ee68-c81a-5acb-bc20-0dd74798d4ca"] = "fb9baa28-e650-56ba-b24c-dbafe6e2be59", -- HUM_F_ARM_Cult_Absolute_Skirt_A [GLB]
        ["8f018691-9ad2-8fda-e332-4625fdc9be38"] = "49a3bb44-1170-508a-ae6e-af82757dcdd3", -- HUM_F_ARM_Cult_Absolute_Skirt_B [GLB]
        ["6d3ff410-6a56-1570-945b-c9400294efd3"] = "d7532aae-77af-5035-9da5-1b5f64244a7a", -- HUM_F_ARM_Daisy_Body [GLB]
        ["8629e0f0-bf23-f8d7-aa26-059bdee2f274"] = "27259904-7152-58bb-9b01-2d2071afc9e1", -- HUM_F_ARM_Daisy_Pants [GLB]
        ["47550623-1e6d-c1ee-8d8b-c104e3212add"] = "798acf39-0f12-5de1-806e-87040c91d3a4", -- HUM_F_ARM_Shadowheart_Dark_Justiciar_Body_A [GLB]
        ["64f991ff-b533-4095-7fe7-68484ec99438"] = "b4c0b969-fe08-5499-9a14-02396dfbb93a", -- HUM_F_ARM_Dark_Justiciar_A_0_Body [GLB]
        ["5878c12d-03ae-58e1-3010-76819284ebd1"] = "9c768f55-8358-51d3-94fb-852f329928c2", -- HUM_F_ARM_Dark_Justiciar_A_1_Body [GLB]
        ["ae75ef0b-1265-48c8-b295-62d0d140fe44"] = "6049e4bc-2b2d-5f99-8dc0-a9751bc5477b", -- HUM_F_ARM_Shadowheart_Dark_Justiciar_Pants_A [GLB]
        ["b639f736-82cf-9765-bf2c-4b55725e1fdf"] = "a8cf1238-d8d1-54ce-b8f1-983643167851", -- HUM_F_ARM_Dark_Justiciar_A_Pants [GLB]
        ["da47419f-1174-c82e-a26e-e813f658d0c9"] = "06beb7c5-23b2-50e3-bc05-fcb2cd3658d3", -- HUM_F_ARM_Dark_Justiciar_Damaged_A_0_Body [GLB]
        ["a79c23c2-d7fd-f97d-f7c2-72b699efb3ed"] = "e09be067-40f7-5705-b05a-6de2201fd0ea", -- HUM_F_ARM_Demon_A_Body [GLB]
        ["abd56050-e481-c65c-e113-a097267fc46b"] = "f30b3930-ec8d-5e70-952d-cb0c5a4dadf2", -- HUM_F_ARM_Demon_A_Pants [GLB]
        ["20b5ba6a-3d8c-1190-8f3e-693a16c0bd2d"] = "92d487f3-6b77-5e8e-b4a5-61d8b0a8c5de", -- HUM_F_ARM_Desire_Dress [GLB]
        ["af423ae5-de48-9fed-6ea7-982d4c822dc4"] = "8473d190-c5b6-5b93-9066-d756382488d6", -- HUM_F_ARM_Desire_Pants [GLB]
        ["7a3000df-92f1-be0d-b367-0a6916bd2a7d"] = "d74ce824-cafe-565a-9c44-fb5175204f5e", -- HUM_F_ARM_Devils_Blacksmith_Body [GLB]
        ["ae3551af-f085-6a5e-cd1f-2d73903c3c73"] = "a1634550-65ae-5af8-837c-0b28264e9932", -- HUM_F_ARM_Devils_Blacksmith_Pants [GLB]
        ["9691c75a-8cee-b6df-b212-f4ce74886bd1"] = "03773220-7d7f-5c7b-b4cd-e875618a9e35", -- HUM_F_ARM_Devils_Blacksmith_Pants_B [GLB]
        ["8523fbab-d973-bbfb-7aa2-2449a7587996"] = "f4c0a1cc-3ac8-52a1-987b-126b06e0e721", -- HUM_F_ARM_DrowLeather_A_Body [GLB]
        ["aba6f4a5-c062-6481-afd8-7be4c19e3877"] = "a85169c3-68f4-56ba-858e-ce2b1ad5f091", -- HUM_F_ARM_DrowLeather_A_Pants [GLB]
        ["5e46bd3c-6ecf-dda1-e5ec-defa96bd9eff"] = "2cd4ed01-1394-59fa-aa08-117326b5c602", -- HUM_F_ARM_DrowLeather_B_Body [GLB]
        ["f2efe983-d13d-0da6-34a8-d6a6dbd5f328"] = "cf14a9c1-0b4c-5a25-ad5f-d8fd0f60b060", -- HUM_F_ARM_DrowLeather_B_Pants [GLB]
        ["eee49ed4-6498-d170-da59-46b1cedcefbc"] = "fbd9d09d-4bcb-5e26-9fb0-65f5a9f2c01b", -- HUM_F_ARM_DrowLeather_C_Body [GLB]
        ["8a1afa94-327f-2d6c-ac2c-dd8de339c225"] = "9f385dbd-d4a0-5273-a46b-c6bd6e3ec7c2", -- HUM_F_ARM_Druid_A_Body [GLB]
        ["f358cebf-6795-3bc5-adb9-463015af6888"] = "d8384bcd-96d7-5745-9063-9109d9cda897", -- HUM_F_ARM_Druid_A_Body_Leaves [GLB]
        ["86c56da4-ddad-22d9-4375-bb8800380fc4"] = "400eec0d-7442-5a2c-bf72-0111dd2088ac", -- HUM_F_ARM_Druid_B_1_Pants [GLB]
        ["10f69796-9490-29fd-074b-a8d14b2a94f2"] = "dfc4fc58-4085-5b40-814a-406549c2b8fa", -- HUM_F_ARM_Druid_B_2_Pants [GLB]
        ["3f27e356-0f04-0b9c-3363-19d59d648f09"] = "5ef0f7e2-d758-5981-98a9-e5971ca2fd9c", -- HUM_F_ARM_Druid_B_Body [GLB]
        ["70385c52-b782-a539-aae9-a5bde03aef61"] = "30d0bde6-fcbc-5610-aa7d-e65aa7a7d367", -- HUM_F_ARM_Druid_C_2_Body [GLB]
        ["b6b27f8b-060c-1f74-4557-1ca70aa83783"] = "253aaec8-4cc8-56d1-b488-845ed32da3b5", -- HUM_F_ARM_Druid_C_Body [GLB]
        ["30751bdc-98e5-4e70-2d73-5d17ad6a766a"] = "448a6555-4f1e-5ebb-9d5b-956087a6807a", -- HUM_F_ARM_DwarvenPlate_A_Body [GLB]
        ["72c1578a-153a-5e91-b98e-b895ef850102"] = "e6e7e814-d897-579d-88b6-ee10902b104d", -- HUM_F_ARM_DwarvenPlate_A_Pants [GLB]
        ["ab0f614d-c855-6eaa-c6e7-5802bdcdd944"] = "f8ebff37-a69e-52ce-aea3-9ce008dc2941", -- HUM_F_ARM_EPI_Robe_Shar_Body_A [GLB]
        ["f94c451b-bfa1-9fa5-eee3-6acf1d1a073c"] = "4f40079d-23cb-5402-ba49-20e47b9d9290", -- HUM_F_ARM_Elven_ChainShirt_Body [GLB]
        ["ab162662-4ed3-3c46-6fc9-2269b9e96c45"] = "8cc3efaf-24c1-5041-a890-2076e0888fa8", -- HUM_F_ARM_Elven_Umberlee_Chainshirt_Body [GLB]
        ["4efcdd6b-63a1-f238-b40d-9eeba145e4b5"] = "27e05455-d49f-5e44-b015-890b49a5c576", -- HUM_F_ARM_FlamingFist_Halfplate_A_0_Body_Pin [GLB]
        ["5ad493a4-3b43-ac38-120f-3a306218d9c8"] = "9868dfcc-96ee-5785-b72d-652d6ade67a5", -- HUM_F_ARM_FlamingFist_HalfPlate_A_1_Body [GLB]
        ["6444108d-0e23-fbe5-a27d-e86f31330b34"] = "6a4f9534-4a15-5ffd-8bfb-b69bb248d6da", -- HUM_F_ARM_FlamingFist_Halfplate_A_0_Body [GLB]
        ["782867e4-a17b-89a2-5556-ad3d70d66489"] = "3988f829-1eff-58da-8ce7-3d405b43c010", -- HUM_F_ARM_FlamingFist_Halfplate_Marcus_Body [GLB]
        ["d2cd78eb-2199-a0b2-1fd3-cc95cc4785ff"] = "6799408e-2049-58b4-ab49-f348533bfe40", -- HUM_F_ARM_FlamingFist_Leather_Body [GLB]
        ["06590900-7c2f-8087-4121-18d84631b106"] = "c3496ba0-c74d-5721-9ffb-dfc2d118bdb5", -- HUM_F_ARM_FlamingFist_Robe_Body [GLB]
        ["ddfe0903-7361-3e46-50e9-ef1a77dfd057"] = "36fd535f-52d4-5426-9fc9-c42e0557e446", -- HUM_F_ARM_FlamingFist_Scalemail_Body [GLB]
        ["75e5b7e7-3c17-6a19-c3db-6c94084dff4f"] = "28a7f7b8-d902-5556-ad08-e7a35726be7a", -- HUM_F_ARM_Githyanki_HalfPlate_A_Body [GLB]
        ["dde1397d-d127-00a9-6c0f-39f924f4d777"] = "9660a6c4-7402-53ed-988d-e95ec0208b9e", -- HUM_F_ARM_Githyanki_HalfPlate_Leather_A_Body [GLB]
        ["fdbfa9ae-c140-9270-0b8c-d8e475e9d767"] = "ab46c05e-408c-54b6-9fb1-e0a8f8c4eef8", -- HUM_F_ARM_Githyanki_HalfPlate_A_Pants [GLB]
        ["640e0bc8-f648-f14a-cbb1-6e762e498ae9"] = "5826fc95-a925-530a-b23f-2f57c7fabbf0", -- HUM_F_ARM_Githyanki_HalfPlate_B_Body [GLB]
        ["87ed8561-ee52-8cc2-fae7-b375940d23fe"] = "d44831c6-1dc4-51e5-9caa-3e84bd5a8593", -- HUM_F_ARM_Githyanki_HalfPlate_Leather_B_Body [GLB]
        ["281249cf-2236-1738-2646-2ec5082b51e2"] = "c26fefda-3f1e-532d-824f-79805864ac78", -- HUM_F_ARM_Githyanki_HalfPlate_B_Pants [GLB]
        ["7ed2928d-4e3c-bb5d-bc13-10b3abf14823"] = "73d65a4f-a511-5472-b086-312965510306", -- HUM_F_ARM_Gortash_Body_Jacket [GLB]
        ["165491b8-6344-efc1-ad62-b8a6547c1052"] = "3046a5cb-aa18-523a-b0ce-2e8bb69d37a4", -- HUM_F_ARM_Gortash_Body_Skirt [GLB]
        ["8234a9bb-3b79-4691-459f-024ec60ab109"] = "c6db8d99-1660-5d90-a82c-7417ef42ee7a", -- HUM_F_ARM_HalfPlate_A_1_Body [GLB]
        ["f0fa736a-804a-5bee-3aa8-dcc130c01f38"] = "22eb0aca-7f90-5000-b045-30e56097b0c4", -- HUM_F_ARM_HalfPlate_A_0_Body [GLB]
        ["d8e274b7-5bd8-70a0-0d1d-bfe17aae40d2"] = "e13530f2-cb61-5dec-acc8-7117acbfa917", -- HUM_F_ARM_HalfPlate_A_2_Body [GLB]
        ["05a76972-4b7c-7b02-a5bd-5ad8f664b7e7"] = "4db64954-e074-563a-8e8c-48c9921ebee4", -- HUM_F_ARM_HalfPlate_A_1_Body_Shoulderpads [GLB]
        ["0d1e9563-5fef-e704-5c71-273dd0a5bb5d"] = "a6929c62-f4aa-5b22-813d-d862341457b8", -- HUM_F_ARM_HalfPlate_A_0_Body_Shoulderpads [GLB]
        ["dcfaaada-b1b2-21bd-bffb-e4f0059bac19"] = "eb8354fd-2a75-5ea9-a0ad-4ccbdfc1cf10", -- HUM_F_ARM_HalfPlate_A_2_Body_Shoulderpads [GLB]
        ["89d15a0f-20e0-8309-922f-f9e6fd3a408a"] = "14205d11-a9d7-5f50-839c-2bac27b07800", -- HUM_F_ARM_HalfPlate_A_1_Pants [GLB]
        ["addcf306-1dc0-041e-8035-f17ce2a511cf"] = "bc1e3454-28d6-5757-92c7-7ca65861a349", -- HUM_F_ARM_HalfPlate_A_2_Pants [GLB]
        ["f689fa3d-8047-77e7-cf71-4cddcd476748"] = "f63d71b1-89f3-57d3-a44e-0244d0cf2c68", -- HUM_F_ARM_HalfPlate_A_0_Pants [GLB]
        ["8163e3db-992f-5232-0d93-3e115d1c5325"] = "5ed3feed-b575-5259-b5bc-1f0681155f40", -- HUM_F_ARM_HalfPlate_B_0_Body [GLB]
        ["d5d8886f-255e-c24d-1b53-627b86a57f85"] = "998ca606-5b86-5618-86cb-19be4127c361", -- HUM_F_ARM_HalfPlate_B_0_Skirt [GLB]
        ["0d9ccc2a-2877-0aa4-34e7-515ca1a25c68"] = "fa713764-243c-5270-b378-1b126a64c160", -- HUM_F_ARM_HalfPlate_B_1_Body [GLB]
        ["018611dd-f4a5-09bb-2239-9ee9b04996ea"] = "670354ee-1047-5361-92b1-3d47aa905895", -- HUM_F_ARM_HalfPlate_B_2_Pants [GLB]
        ["364e4254-fd0d-a55f-8822-9ff105c6b55b"] = "ad0ca97b-d1f4-59ae-a64e-b430e591682b", -- HUM_F_ARM_HalfPlate_B_1_Pants [GLB]
        ["e08a82f1-c191-09be-3223-989d4d2c69fe"] = "11ff0607-1a78-5181-a0a6-1ad4b0230e66", -- HUM_F_ARM_HalfPlate_B_0_Pants [GLB]
        ["6b7c0656-2be7-75c9-a99c-132aef475bfb"] = "54eaa40e-68d7-50b8-8778-8687b4f31cfc", -- HUM_F_ARM_HalfPlate_B_1_Skirt [GLB]
        ["9e0dda43-4f5d-db94-98fd-d4188eb558a4"] = "2f1ae8a1-c269-5c68-afa4-ee03a1c4305a", -- HUM_F_ARM_HalfPlate_B_2_Body [GLB]
        ["f0057ae6-6efb-9b6a-9849-feb67cdfc48a"] = "1acadf3c-5a4e-57cc-9944-c564b200adad", -- HUM_F_ARM_HalfPlate_B_2_Skirt [GLB]
        ["28b9efee-0da6-f29d-1f00-6977155b8fb5"] = "a4bae38e-e912-5f22-85d7-e008de5aa597", -- HUM_F_ARM_HalfPlate_EndGame_Body [GLB]
        ["01e98505-64e9-81bb-4419-9b27c451aff9"] = "2cadd201-95bd-5421-91fa-d0347c833774", -- HUM_F_ARM_HalfPlate_EndGame_Pants [GLB]
        ["33c3502d-8ef5-b4ab-059f-7a4f8cbfefc7"] = "f3197f44-2afc-5cbf-89ff-fffd868baab5", -- HUM_F_ARM_Hide_A_0_Body [GLB]
        ["f6399f9e-19ae-cbad-d113-f72ac1574b19"] = "dd28d288-5934-56a1-8ba7-bf6eebdace4d", -- HUM_F_ARM_Hide_A_1_Body [GLB]
        ["3e6b87e1-4b57-50f3-a06b-7c3ced1bb4ef"] = "05e1b3f6-b5e8-52e1-b4c8-1e221624d209", -- HUM_F_ARM_Hide_A_2_Body [DAE]
        ["cb592497-afb7-f684-0daa-4af5b81c186c"] = "27f5dd43-a264-59b5-8c04-0a613e1e4e96", -- HUM_F_ARM_Hide_Druid_1 [DAE]
        ["e62bf9cd-7779-92c1-df3e-99c3de5df172"] = "96993a70-0599-5af3-81b1-4ebb8f3aa387", -- HUM_F_ARM_Hide_A_Pants_A [GLB]
        ["5efbe777-69e7-97e0-e59b-beece8550742"] = "df8f0480-9d5c-5d1a-92ee-2a70cc54f5a3", -- HUM_F_ARM_Hide_A_Pants_B [GLB]
        ["d21c0b33-ae6a-7e31-c749-6e2ee855700c"] = "d24ffa45-4d90-5146-929b-aaf614664218", -- HUM_F_ARM_Infernal_Robe_Pants [GLB]
        ["fdea9130-9c3a-aa7a-66a1-8e5dec87a1c6"] = "2c2ee3ca-519c-5fce-a1ee-0bbb2e9e3091", -- HUM_F_ARM_Isobel_A_Pants [GLB]
        ["32f77742-2d5e-39a8-3b6b-6541fa09e05d"] = "922f5cec-0eab-5fe0-939a-dcc7ca78c8e3", -- HUM_F_ARM_Isobel_A_Body [GLB]
        ["00b5bc65-3298-0d52-1200-6377414e1fc7"] = "f8fceb34-c999-5144-9324-f4bfb80f21d8", -- HUM_F_ARM_Infernal_Robe_Body [GLB]
        ["c911aacc-69b4-a52f-77ac-ae2ea41c72d7"] = "bb722259-b268-5f35-87c3-bed76d1235a6", -- HUM_F_ARM_Isobel_A_Robe_Body [GLB]
        ["21041aa7-c364-e341-60a2-c7ae861bca79"] = "e79b4673-7bd0-5ae8-aa6f-ac7c5c1cb738", -- HUM_F_ARM_Isobel_A_Robe_Skirt [GLB]
        ["2dccb52f-cb96-13c4-0241-7ac9c8a69d81"] = "397b9340-9596-5a90-ad30-a582b457cc9e", -- HUM_F_ARM_Jaheira_Pants [GLB]
        ["d0336146-7ecc-0b01-520b-98985a34c0ba"] = "91fa7348-d691-57b7-97da-9ca12b5839db", -- HUM_F_ARM_Jaheira_Skirt [GLB]
        ["1ae5d864-e9b7-be32-5f04-88da2699fb97"] = "02437b4e-3861-5d2c-b480-f5f387bcdb36", -- HUM_F_ARM_Karlach_Epilogue_Player_Body [DAE]
        ["fb084ed8-92e2-e11e-db79-2d22069c7a67"] = "a97b8c4b-4f56-5b83-8bc3-f0e78b39b09a", -- HUM_F_ARM_Ketheric_Body_A [GLB]
        ["03a18f12-cda7-40be-fbf2-707cd5fdd806"] = "16a9214c-436b-5f6c-a3ac-eeaf3281abff", -- HUM_F_ARM_Ketheric_Pants_A [GLB]
        ["79ce64fd-01f6-f04e-4386-83018e3321a6"] = "f3e43559-780e-5399-8a09-468e67cb157f", -- HUM_F_ARM_Laezel_Githyanki_HalfPlate_A_Body [GLB]
        ["b601d974-bdcc-4653-ba7c-58ef45a0c5e4"] = "baad1839-58c3-57d9-9634-470af4d3d05c", -- HUM_F_ARM_Laezel_Githyanki_HalfPlate_Broken_A_Body [GLB]
        ["956e11cc-41da-9e43-036b-c59a70c1b945"] = "d40c4b38-6ccb-52ef-a86b-73da0951f27a", -- HUM_F_ARM_Leather_A_1_Body [GLB]
        ["d6f8ef96-3674-39c6-3e7a-73f94bdd5595"] = "f47eff01-7242-56dd-95cd-7d9d43810caf", -- HUM_F_ARM_FlamingFist_Leather_Pants [GLB]
        ["f29af014-91cb-f1a8-3b6f-d59de4ae8e91"] = "c2e59b63-4efd-5645-8bf1-113488f9fec2", -- HUM_F_ARM_Leather_A_1_Pants [GLB]
        ["b36b4826-00a5-0a1a-f1e7-1e13fb7192db"] = "85538c5f-cca6-5fa7-89e0-545cecd9c2b8", -- HUM_F_ARM_Leather_A_2_Body [GLB]
        ["a8b2d37c-aee8-7458-c570-638c830d31d1"] = "06a73a45-ab54-5d23-af37-cece39958ed5", -- HUM_F_ARM_Leather_A_2_Pants [GLB]
        ["e4bd0d2b-0160-f802-3429-7bb4b305a613"] = "f9082b50-dfe7-5668-806c-e8e8f59faa05", -- HUM_F_ARM_Leather_A_2_Guild_Pants [GLB]
        ["66bcfba0-cea0-504f-2790-053dc8cb0bbf"] = "cab99f1a-0cf6-543b-8802-bafc60aef246", -- HUM_F_ARM_Leather_A_Body [GLB]
        ["27e35669-4d7c-b39a-6476-abbff870074c"] = "96456f70-c609-5581-9866-cb737d627200", -- HUM_F_ARM_Leather_A_Pants [GLB]
        ["a506a44a-d295-01b5-37f2-c19e33aa62c9"] = "408b2f6f-bd5a-596f-8e5d-2ae935aed02a", -- HUM_F_CLT_Drow_Pants_A [GLB]
        ["1e87abcb-c98a-538a-c9a1-00df18b91355"] = "cd62ce69-6bab-544d-b323-7fd264255ca6", -- HUM_F_ARM_Leather_Old_A_Body [GLB]
        ["aeedba01-02a7-25ec-bca5-b314ba4c4fee"] = "61ad50ea-89e7-5e12-a7a6-7064f67d4265", -- HUM_F_ARM_Leather_Old_A_Pants [GLB]
        ["3693fa90-0f57-6cb7-d8e9-b46d64a14e70"] = "8a948cc0-49f4-5714-9fd5-d5a902aab163", -- HUM_F_ARM_Leather_Old_A_Pants_B [GLB]
        ["6d5c83a6-cce9-4dff-6735-a7e015bdc82c"] = "089fe6df-1ed7-5353-8ac0-0e317106497c", -- HUM_F_ARM_Leather_Old_A_Pants_B_Kneepads [GLB]
        ["0ff48dde-2f79-77e4-a76b-4e119f8ed081"] = "44d8197c-957f-50aa-b124-d8010f836d1e", -- HUM_F_ARM_Magic_Monk_B_Body [GLB]
        ["ca714562-2c20-67e8-8db8-34ee8e354534"] = "2d012a15-8dee-589f-93f5-e8944884c609", -- HUM_F_ARM_Magic_Monk_Body [GLB]
        ["c3070973-5315-4061-70a3-c81b7af8992e"] = "cb993a1c-0fd5-510a-b762-63e8e3b675d9", -- HUM_F_ARM_Magic_Monk_Pants [GLB]
        ["52372a10-326b-b2af-4b35-f5cc5919cb2e"] = "3e0a822c-9f58-57c7-bde7-4c98a055de96", -- HUM_F_ARM_Magic_Monk_Pants_Scarf [GLB]
        ["49926d18-9968-fe7d-cd69-8d69b3888a58"] = "3e1dcc02-b36e-569a-aa54-cfea33bf94d3", -- HUM_F_ARM_Mindflayer_Body_A [GLB]
        ["beae81d8-4251-f077-4463-0cf6e541f71f"] = "3bce46c8-60c1-5c93-83af-a025da8c5cbf", -- HUM_F_ARM_Mindflayer_Pants_A [GLB]
        ["49551064-df2d-4baa-bf8d-48893db8af50"] = "f8163970-b603-57cf-b69e-16f8ed8cf9c8", -- HUM_F_ARM_Mindflayer_Skirt_A [GLB]
        ["ff401e93-8d2f-4bb2-66f6-a1d879f38ad2"] = "bd66def2-86f7-563a-b154-ea41e52ab7e2", -- HUM_F_ARM_Monk_A_Body [DAE]
        ["48a70a5d-f440-ab7d-f0a7-308d3a6d830f"] = "f8fcbd79-5f54-5edc-8266-1548fac3d010", -- HUM_F_ARM_Monk_A_Pants [GLB]
        ["7d323252-e866-db48-dff8-ba787efef763"] = "c8d34c4f-fd4f-57d6-b7b4-5c3e5a376058", -- HUM_F_ARM_Myrkul_A_Body [GLB]
        ["a570519e-f495-8f55-108d-8f8a076b562a"] = "2b949107-6a0c-5b5e-a569-72f0e2e58bde", -- HUM_F_ARM_Myrkul_A_Pants [GLB]
        ["adf969ed-6b7d-f4a9-c743-4856e552b246"] = "b5afc454-21f5-5429-ac6a-40c26636f4c1", -- HUM_F_ARM_Myrkul_B_Body [GLB]
        ["507bb7aa-294b-0e8c-ca3a-ca5bf52e5caf"] = "fb08d39b-ad70-5356-a6c2-4568eaf9a4d5", -- HUM_F_ARM_Myrkul_Plate_Body_A [GLB]
        ["a5ad64ac-5d73-a959-60e5-22a13c19445c"] = "41382d54-a60e-5c3e-ad84-aea2065cb652", -- HUM_F_ARM_Myrkul_Plate_Body_C [GLB]
        ["c7d97828-bd40-e39f-8f6b-ee87bb5de187"] = "0f63b967-12aa-5522-b81b-983d8fe7a1e1", -- HUM_F_ARM_Myrkul_Plate_Body_D [GLB]
        ["5eddf203-8eb5-9db0-5eba-60c77f765c02"] = "c3180c3a-d849-590e-9d24-d4b310301cb4", -- HUM_F_ARM_Myrkul_Plate_Pants_A [GLB]
        ["d2cbe9dd-1de9-541f-aa9e-03d32f1bd3d2"] = "9701fcaa-6769-52aa-b6f1-eb5f80ab6e87", -- HUM_F_ARM_NightsongPrison_Body [DAE]
        ["93399195-5282-44b9-9d98-bb288faedc52"] = "4efdb174-c344-5575-90d2-d89e58b6a722", -- HUM_F_ARM_NightsongPrison_Pants [GLB]
        ["4db1eff0-08f1-c83b-eb61-2e40c837f1e7"] = "9be511ba-3b74-5f05-9174-8a345ae9f301", -- HUM_F_ARM_Nightsong_Body [GLB]
        ["8f81b249-93b0-cd99-c27c-3b6987232f19"] = "fb9fa6dd-1779-5493-9113-281ad0863da3", -- HUM_F_ARM_Orin_Body [GLB]
        ["a22984e8-b28c-46e9-5862-930af7b7b136"] = "07afa513-8931-508f-9ea9-effa48f9301d", -- HUM_F_ARM_Orin_Body_Player [GLB]
        ["092db3bc-9cbc-87aa-c21c-d0016f80bbc7"] = "6969fb42-e111-5752-bca5-87bbfd2c583f", -- HUM_F_ARM_Orin_Pants [GLB]
        ["f6d6d155-6390-a211-e86b-73a977b9738a"] = "6c572add-3f93-5935-bd56-93c561593335", -- HUM_F_ARM_Orin_Pants_Player [GLB]
        ["113bae24-e267-5982-59ed-1454a41cce60"] = "517520da-bd44-5843-b58a-078604cca6f7", -- HUM_F_ARM_Padded_A_0_Body [GLB]
        ["9ea94d2f-f341-1cb4-a780-d9724474758d"] = "209be1dc-488b-5eef-b15b-286f36d63c30", -- HUM_F_ARM_Padded_A_0_Body_Broken [GLB]
        ["e4865cdc-10de-62ec-aedb-ac32b7973dee"] = "0bff0ce6-00ca-5ff4-83c5-80b100af92b2", -- HUM_F_ARM_Padded_A_0_Pants_Broken [GLB]
        ["057b7784-3ae7-1c5a-e404-d502b6602bae"] = "dbd030a9-9e97-5914-8b95-feb7f2b21559", -- HUM_F_ARM_Padded_A_1_Body [GLB]
        ["f9a9aa02-5ceb-1ff8-beac-5ff9a3243f41"] = "0f03095a-fd30-5c6c-a5bd-170230329e91", -- HUM_F_ARM_Padded_A_1_Body_B [GLB]
        ["6b3bf5e0-d886-8646-0623-2fcff33a3695"] = "2d04964a-5c02-5ef0-b613-58972f7a9df6", -- HUM_F_ARM_Padded_A_1_Body_Spring [GLB]
        ["74bb8dd6-2010-f90d-caa1-a172ad5c4a95"] = "ddfec7ab-8b59-5d1e-92a6-972f5f188c3b", -- HUM_F_ARM_Padded_A_2_Body [GLB]
        ["29b64740-a9cf-d0f4-c536-0bd7b631e710"] = "bac4209f-ef83-56b7-86fa-783ac2994c82", -- HUM_F_ARM_Padded_A_2_Body_B [GLB]
        ["c80e582d-0f68-62a3-bc89-5738d2000319"] = "057298f3-5d01-520d-9eab-9f8f099010bc", -- HUM_F_ARM_Padded_A_Pants [GLB]
        ["e704163f-d9ea-6dbe-c897-b44b042f1769"] = "9ed88c7d-63ee-5d63-a25a-d6e6ece36f9a", -- HUM_F_ARM_PlateMail_A_0_Body [GLB]
        ["9b33ece1-b01d-74f8-7ef1-4183cd80220c"] = "6feb4827-c5ad-56de-9a7c-0814c7f8f15f", -- HUM_F_ARM_PlateMail_A_0_Skirt [GLB]
        ["a7cf3830-d44f-a31a-9e90-ffb00e718078"] = "fb6ec1c0-4ddb-5c8b-ae0c-b5a7b35a2882", -- HUM_F_ARM_Paladin_Oathbreaker_Platemail_Body [GLB]
        ["b457d115-a6f7-7f10-f674-7eea94896eb9"] = "d817c686-857a-5dde-bb39-ef25baa91202", -- HUM_F_ARM_PlateMail_A_1_Body [GLB]
        ["5f58f18f-ec6b-10c3-8462-0603dca6e573"] = "dcdf5c55-c500-5b7b-875a-01f333b6901c", -- HUM_F_ARM_PlateMail_A_1_Skirt [GLB]
        ["f8c8854d-1f75-7595-932f-5bcc78051351"] = "8fd44f2b-bfd9-56f4-8bf5-18c27bb4cc3d", -- HUM_F_ARM_Paladin_Oathbreaker_Platemail_Skirt [GLB]
        ["04a5084e-efe5-f61d-5a28-577b059cbaaf"] = "611da3c6-44fa-5d09-99f9-333fa8fd03f3", -- HUM_F_ARM_PlateMail_A_2_Body [GLB]
        ["153fafa5-944d-9f49-c1ac-bc96ebc81383"] = "9d5fb797-84ce-57bb-915c-44375029dcf0", -- HUM_F_ARM_PlateMail_A_2_Skirt [GLB]
        ["4961b222-0434-2ce6-8cbd-67c36c2f9896"] = "8d1c4a33-708b-5b73-808a-344917b34b79", -- HUM_F_ARM_Paladin_Oathbreaker_Platemail_Pants [GLB]
        ["94a4cbf4-39d7-5e7d-5429-bf6530cbb7b4"] = "8e5b16d8-dfe9-560a-92a0-f94b80c19e64", -- HUM_F_ARM_PlateMail_A_Pants [GLB]
        ["92c2ecdc-30be-dde9-ed3f-0bf056394331"] = "58e3c70a-2228-543b-a741-ebc946cc2515", -- HUM_F_ARM_Platemail_B_Body [GLB]
        ["11c721c2-e56f-ddd0-24f1-684ccceeee0a"] = "d668c2c9-dbb8-5be9-b785-e62a5f71b229", -- HUM_F_ARM_Ravengard_A_Body [GLB]
        ["006159ea-8880-6589-52ef-313fc228ee26"] = "c44be36b-adf5-5eb1-a72a-ba45f2790a63", -- HUM_F_ARM_RingMail_A_0_Body [DAE]
        ["f8f01df9-1fd5-f92d-a62d-432da17ba1a6"] = "974d50f6-11f0-572b-83a8-fbd9e9b1022e", -- HUM_F_ARM_RingMail_A_0_Skirt [GLB]
        ["d3482469-a43e-8de3-88f2-e5a8907c95d6"] = "3d320c54-61e1-5d11-a172-4aebd13dd910", -- HUM_F_ARM_RingMail_A_1_Body [GLB]
        ["e86250ad-54b5-29a0-1383-321dfd77115c"] = "33217e84-764a-5f2e-ab6f-aed146760f7a", -- HUM_F_ARM_RingMail_A_1_Skirt [GLB]
        ["9f06b0f7-1d68-85f0-3b4c-276fab55a1f9"] = "86578739-6c8f-5c33-81f8-04876781cc6d", -- HUM_F_ARM_RingMail_A_2_Body [DAE]
        ["571adfc4-0033-449a-9be6-9602bdd35d04"] = "0d274f7a-166c-56c8-b766-03660eef926f", -- HUM_F_ARM_RingMail_A_2_Skirt [GLB]
        ["9f847c1c-25bc-5417-942e-c78986e5071c"] = "e5774227-2a9c-55cf-9189-0f9e3de63495", -- HUM_F_ARM_RingMail_A_Pants [GLB]
        ["5b4c8f52-5336-6b43-96bf-7ae2cde81e1c"] = "ce052800-28e1-592a-ae37-d3daae1ad64b", -- HUM_F_ARM_RingMail_B_Body [DAE]
        ["ad28b80d-799e-60f3-ecd8-8c8d64fdb28e"] = "e6b1dc38-420b-5b3f-8883-a7828702390e", -- HUM_F_ARM_RingMail_B_Pants [GLB]
        ["a0e71abf-5235-6bbd-a52b-f1e898b7dfab"] = "46638118-3c70-53eb-982b-238d3c805780", -- HUM_F_ARM_RingMail_B_Skirt [GLB]
        ["d27d9b6e-fa2f-34f1-c17a-94eb2b63a087"] = "2d1ef648-5ed0-5026-9be7-c10e1c3bae5a", -- HUM_F_ARM_RingMail_C_Skirt [GLB]
        ["095be887-6b9d-c7c4-ea62-4ab6d0b513d6"] = "69e485eb-9cd1-59e1-bc12-b2a8b5bf8612", -- HUM_F_ARM_Robe_Fire_A_Body [GLB]
        ["2c5d9266-8a99-7143-754c-fc2b57422c01"] = "c6fd4338-258a-5e62-a419-4a993e0993f1", -- HUM_F_ARM_Robe_A_1_Body [GLB]
        ["78b1b1b1-1bba-0a46-8577-72c74903575d"] = "bff71c8d-88b2-5a93-8655-5242ed4b6653", -- HUM_F_ARM_Robe_Frost_A_Body [GLB]
        ["eecab0b0-f7bf-77c4-761f-c07325ea0c43"] = "889d6ba9-3d4e-53e1-a360-7c1238f0c5cf", -- HUM_F_ARM_Robe_A_Body_Satin [GLB]
        ["69649acf-f219-d2b9-8cba-d044263f00bb"] = "ebabf2b8-f7af-5e2d-af30-6450fb58dd6a", -- HUM_F_ARM_Robe_A_CloseQuarter [GLB]
        ["4084d9c1-de9e-bb68-f0bc-0395ad80357b"] = "6e73f553-b96c-5f10-88c9-ee836c77fe01", -- HUM_F_ARM_Robe_A_Body [GLB]
        ["c4347cae-8638-4f27-d847-d848a587869f"] = "6611c40c-a3e1-59c2-9ae5-b55fdfbe377d", -- HUM_F_ARM_Robe_B_2_Body [GLB]
        ["fb2968d6-a8a5-571a-f803-8b91a2cd5346"] = "95dc91a6-5fed-586a-a42e-426d4933f450", -- HUM_F_ARM_Robe_B_Body [GLB]
        ["11749113-6fe4-1593-6981-be73277484a8"] = "1197d083-d189-5543-bcc3-4b15afc2f1b0", -- HUM_F_ARM_Robe_B_Wizard_Body [GLB]
        ["324ccffb-b76c-ddf9-c133-058cbab4a5de"] = "2d9c601c-acd8-5dec-a180-6e0ae10c2abb", -- HUM_F_ARM_Robe_B_Undead_Body [GLB]
        ["2482f256-6050-4e01-2620-05c9525297aa"] = "40ef4ed5-2476-500a-a2ba-17957551213c", -- HUM_F_ARM_Robe_C_0_Body [GLB]
        ["26ff5e8a-4077-c579-c3ef-e1304554b3e1"] = "0d07ebd8-b47a-53cf-ab6f-d64de1505672", -- HUM_F_ARM_Robe_C_1_Body [GLB]
        ["55b92629-3026-3563-b3b5-df3d033efcb3"] = "5ff7eec0-5e8b-5373-8e59-20a0ca73a4fe", -- HUM_F_ARM_Robe_C_2_Body [GLB]
        ["04741d75-66f6-e766-18a8-2c07f326ca13"] = "12e18a7e-1b33-538c-b8fa-1451a0c45661", -- HUM_F_ARM_Robe_C_3_Body [GLB]
        ["25a13ce8-126b-e0b8-44b4-133b2cfeeaf1"] = "635b1cc4-9293-50a7-a550-0517f30c8491", -- HUM_F_ARM_Robe_SpellResistance_Body [GLB]
        ["0aabb3a8-eed7-b19b-24da-5e9d82b266fd"] = "40423b98-dfeb-5a49-a93f-da1db8083cf9", -- HUM_F_ARM_Robe_D_Body [GLB]
        ["66dab175-f470-b1d7-60a8-1fe553f12ea7"] = "351c4f4b-ea2b-5254-b8f3-1c665310eb57", -- HUM_F_ARM_Robe_E_Body [GLB]
        ["c9ed14a2-99f2-57c9-9542-c2867dec37ef"] = "3f981e39-baca-55ec-8ca7-bdb46fc5f52d", -- HUM_F_ARM_Robe_E_SpiderQueen_Body [GLB]
        ["7831d6c6-8324-1d9f-6909-96165a057ec4"] = "9be3f11c-e43c-5a6b-964d-7485b7145cd4", -- HUM_F_ARM_Robe_EndGame_A_Body [GLB]
        ["ff43d550-a7af-63a1-dd6e-731e525376e0"] = "7b0ca87a-c8af-5a62-9dad-21d1b1928778", -- HUM_F_ARM_Robe_Lorroakan_A_Body [GLB]
        ["96dab08a-eb0c-2ffe-6c36-7566ab78e346"] = "dadbe925-69d0-5223-8058-534ab8436267", -- HUM_F_ARM_Robe_Lorroakan_Body [GLB]
        ["1ae5d16d-de79-6e1d-331f-c11d75dbbaf5"] = "a376f832-c488-56e9-aa2f-c98f67982c49", -- HUM_F_ARM_Robe_Shar_Body_A [GLB]
        ["338fcd6b-71c1-a991-26a2-db02dee1a5af"] = "8d3d7e40-44c7-5c9c-8351-205760c5df53", -- HUM_F_ARM_Robe_Shar_Body_Viconia [GLB]
        ["cd5de58b-6dd3-55c6-748e-ad71cad54c39"] = "4d524681-5d00-5e65-b813-18bb92da4b51", -- HUM_F_ARM_Robe_Shar_Body_B [GLB]
        ["b6811b31-25f6-c4bc-5e93-ec0ab37a1677"] = "7966c70d-eca9-58b0-9f86-e4709dbfcb53", -- HUM_F_ARM_Robe_Shar_Pants_A [GLB]
        ["209f6f56-54f8-d4e9-35af-70867c839c67"] = "376099df-9ea3-5b24-a04d-4a548ba578b0", -- HUM_F_CLT_Camp_Shar_Pant [GLB]
        ["958458e2-45af-5996-a365-25d258c17a2b"] = "98cf3741-f59c-5b24-a36f-ffc7f056fc65", -- HUM_F_ARM_Camp_Citizen_Pants_B [GLB]
        ["f0c533e2-e10f-5fea-a143-065df33e6fa1"] = "1bc4fe89-1f73-501c-a72b-c95f43b22387", -- HUM_F_ARM_Robe_Shar_Pants_B [GLB]
        ["f62dfa70-6b63-feb1-3bae-059a77ded1ff"] = "136e0739-c675-50d8-bc2d-f3c48e9e88ff", -- HUM_F_ARM_Robe_Shar_Skirt [GLB]
        ["0fe2e1a1-da35-e2e8-5c87-d2ad15e24208"] = "5fa54bf5-c764-54cc-9e0c-27fdc06a9864", -- HUM_F_ARM_Robe_Umberlee_A_Body [GLB]
        ["b74bc9d1-2c02-7bc1-97e2-ba6b66d91db6"] = "e450c474-ac59-5997-a6f5-bfbdaababb27", -- HUM_F_ARM_Robe_Umberlee_A_Body_B [GLB]
        ["e3a982a7-113d-e13f-deef-97625f44d46a"] = "36ef0706-a40c-5d6c-a422-cb01adc49645", -- HUM_F_ARM_Robe_Umberlee_A_Pants [GLB]
        ["2321fb4f-010e-495d-18c0-c2facb6f6241"] = "7542e63e-7fe3-59ff-b412-eb805f00258d", -- HUM_F_ARM_Robe_Umberlee_B_Body [GLB]
        ["0fdaf2c1-cf92-f263-0048-56e93238a5cc"] = "71dd28ae-12b0-5420-8da6-ea36aadc05b5", -- HUM_F_ARM_Scalemail_A_0_Body [GLB]
        ["a6e89a85-dca1-816e-265d-eed5c5a54b96"] = "46dfe246-19b0-5d41-b06f-371f538dfe37", -- HUM_F_ARM_Scalemail_A_1_Body [GLB]
        ["9d613fa9-9188-e036-5470-d590d3aca811"] = "3b733763-8886-5c49-a6cd-05829752b05a", -- HUM_F_ARM_Scalemail_A_2_Body [GLB]
        ["4bdb8690-5acb-95da-abae-6b41a9fd4aa4"] = "0df1a11c-a810-584f-9d39-1a0a24e94ece", -- HUM_F_ARM_Scalemail_A_Pants_A [GLB]
        ["3fb3ab1c-786d-c5e0-f31f-8104cc8e377b"] = "a0eed05a-f1fb-5e4c-8f9e-01f1540af856", -- HUM_F_ARM_Scalemail_A_Pants_B [GLB]
        ["fe430473-6b87-a1e5-2f39-085b1942542f"] = "817fe960-7ee8-522d-bf04-f30e48b00adc", -- HUM_F_ARM_Scalemail_Adamantine_A_Body [GLB]
        ["623d949f-6b7d-05ba-d20f-c7633495eb24"] = "095b07a1-ff5d-52a7-a59d-8028ac15e5b4", -- HUM_F_ARM_Scalemail_Adamantine_A_Pants [GLB]
        ["370b0a8d-ee6d-93aa-aca6-9ea018bbb4a7"] = "e36ed0f0-8281-57ca-b99d-5e1eea7018e8", -- HUM_F_ARM_Scalemail_B_0_Body [GLB]
        ["17a8d09a-f6df-0187-aac6-be01f0089f65"] = "61847cf6-7b33-5f94-85c7-45879baebcd4", -- HUM_F_ARM_Scalemail_Paladin_OathOfDevotion_Body [GLB]
        ["fb901e95-3101-ff63-a628-e6d95c0a62e4"] = "45f3e3e9-90f5-55d0-a034-e431cbf9a398", -- HUM_F_ARM_Scalemail_Paladin_OathOfAncients_Body [GLB]
        ["97d65c4c-d6fa-bd7d-1a15-ca63a4bb1831"] = "e6bac8f9-e068-578b-b8be-05e5bf520c77", -- HUM_F_ARM_Scalemail_Paladin_OathOfVengeance_Body [GLB]
        ["d7196f12-bfcb-84d7-b96d-088284ef2a7f"] = "547715f8-d466-5719-bc6b-5511a2c1bafd", -- HUM_F_ARM_Scalemail_Paladin_OathOfCrown_Body [GLB]
        ["433b08ba-302c-2edf-1064-d0aae20eaf35"] = "5b53e0fb-3532-5c8d-9534-21a72690b990", -- HUM_F_ARM_Society_Of_Brilliance_A_Body [GLB]
        ["12ae1e17-9cc8-6c8c-cf35-ff4a3bb0ecc0"] = "a89e370c-72f6-5e45-a620-a4821b109a4c", -- HUM_F_ARM_Splint_A_0_Body [GLB]
        ["e5eb5555-364d-16af-caea-8dd79c0d8945"] = "74689db1-fc02-5f6f-b45b-70323003bdfc", -- HUM_F_ARM_Splint_A_1_Body [GLB]
        ["789678af-6c03-8bf5-f3df-afef3cb52dd4"] = "b49bcdaa-b630-5fde-b2ec-2d46642aa0bc", -- HUM_F_ARM_Splint_A_1_Pants [GLB]
        ["53ab8b43-8c16-cfcf-a198-48c3dd856b48"] = "24fe1317-377a-5f89-b40d-ea0fd4eaa5e8", -- HUM_F_ARM_Splint_A_2_Body [GLB]
        ["e8185a07-77c6-6cbc-1ec6-ab4ee246fbe6"] = "f09996e3-b474-5df2-ab75-b278627dc12a", -- HUM_F_ARM_Splint_A_2_Pants [GLB]
        ["ad128db4-9ce5-0a9b-d5a5-86692c87bcf2"] = "ce1e1555-17b3-5ec1-be93-21b757fabcdc", -- HUM_F_ARM_Splint_Adamantine_Body [GLB]
        ["2141e5d9-dc21-ad0d-40dc-71e333819a26"] = "341b23a1-dc0a-58c0-a786-407f186ad4a1", -- HUM_F_ARM_Splint_Adamantine_Pants [GLB]
        ["bac9739c-6ed7-621c-fe61-009a44a7cf75"] = "dbf8d05c-7f79-5813-a7f1-c1e487fa63ef", -- HUM_F_ARM_StuddedLeather_A_0_Body [DAE]
        ["b3b87fc5-acda-80b8-2c26-9e797b99a7de"] = "f01ee766-89b5-5851-940d-5b9f60aceec1", -- HUM_F_ARM_StuddedLeather_A_0_Pants [GLB]
        ["9d67986d-21ae-401b-9837-ee4e003e1a5e"] = "aa9196d9-09eb-5a31-b83b-b990b8f38b05", -- HUM_F_ARM_StuddedLeather_A_1_Body [GLB]
        ["da8139a1-a58f-e2a1-62a4-bcf3bf409080"] = "ddbcdc31-3f1a-5406-b3d6-09464f72022f", -- HUM_F_ARM_StuddedLeather_A_1_Pants [GLB]
        ["eafe8199-bd10-0dca-ba1f-66b34fd1e363"] = "d1e64633-0aac-50d4-a1fb-ed9ccf2837b1", -- HUM_F_ARM_StuddedLeather_A_2_Pants [GLB]
        ["e8b7426f-669d-a781-9f3d-d006ffb031ac"] = "b740d5c2-ec74-5ef5-96a7-6b64e1598dc1", -- HUM_F_ARM_StuddedLeather_A_2_Body [GLB]
        ["d3151f1b-56af-bb04-6bba-c4c9b48104f8"] = "725c7908-053b-5106-8ed9-0ecc048e2b55", -- HUM_F_ARM_StuddedLeather_B_Body [GLB]
        ["d6d2f87a-e8dc-0102-7cd3-61d0922efff2"] = "58429f6e-2fbe-54bd-9504-991f6221e33e", -- HUM_F_ARM_StuddedLeather_C_Body [GLB]
        ["c403d4ba-9b22-ce02-7f87-71ea1628fb65"] = "b871cfb4-aada-56cf-87ce-a8877030206a", -- HUM_F_ARM_StuddedLeather_Minsc_Body_A [GLB]
        ["1f0df787-f318-50ee-1ba3-db54078b310e"] = "7ab48dfd-6f93-53a8-9f4b-28610050a55b", -- HUM_F_CLT_Alfira_Skirt [DAE]
        ["a8f45b55-911e-a40a-e501-02022bb63a41"] = "8aafb84c-bcbd-59d8-890c-8a766768432d", -- HUM_F_CLT_Bard_Body_A_1 [GLB]
        ["d6bafee0-4aee-5322-8a49-84179673cd96"] = "01c7f17a-d245-5e78-b732-399fdc11f8a3", -- HUM_F_CLT_Bard_Body_A [GLB]
        ["7f3ec09b-8ade-1772-8fc5-822a43e4e991"] = "8d62af71-1211-5aaf-8bf0-a128628b1eea", -- HUM_F_CLT_Bard_Pants_A [GLB]
        ["befe91a5-3a8a-e604-ae8d-d4413759b38c"] = "63b195d6-994f-5a36-acd9-d5f15c074a0f", -- HUM_F_CLT_Bard_Pants_A_1 [GLB]
        ["ee42f623-c004-c1aa-dab1-7d86e8178895"] = "765cf772-5f91-52c7-854b-3996be4bc5df", -- HUM_F_CLT_Bard_Skirt_A [DAE]
        ["0f4c63b4-df59-c729-156f-08cc9a3c8a00"] = "14b29eae-0f75-5897-a39a-04dab9957d1a", -- HUM_F_CLT_Blacksmith_Body [GLB]
        ["27d62490-3434-1ccc-35c8-59a8c73ad2ad"] = "8e04a044-664f-5d81-8b26-96e36a48e388", -- HUM_F_CLT_Blacksmith_Pants [GLB]
        ["dc75dded-74b2-1b63-5ed4-8cfaacbaf80a"] = "f6e12357-4176-542b-b48e-b587f781d251", -- HUM_F_CLT_Camp_Deva_A_Body_A [GLB]
        ["435d32fc-9994-9f17-aa79-f76cb3ae300a"] = "e1c773aa-8137-5c7e-89e7-caf084bce7cf", -- HUM_F_CLT_Camp_Halsin_Body [GLB]
        ["888a24d5-650d-d4a4-be6e-7b48828e69c4"] = "1b046a6d-2c19-5519-a707-555c576666c9", -- HUM_F_CLT_Camp_Jaheira_Body_A [GLB]
        ["dd7e1cf2-fab0-ca8f-980b-4e439ae31c9f"] = "83b42dae-93b2-5fc0-aa88-7c574f09207e", -- HUM_F_CLT_Camp_Jaheira_Pants_A [GLB]
        ["dcd947da-9f4b-ab17-7112-c0c95a4dacfb"] = "84b5006d-5c3f-5a51-89f5-61f993a7c57d", -- HUM_F_CLT_Camp_Karlach_A_Pants [GLB]
        ["611146cb-b98b-9ed1-78ee-1c24feee45d1"] = "adf7391d-cf92-57b7-8bb5-9a28630dcb3e", -- HUM_F_CLT_Camp_Minsc_Body [GLB]
        ["0fc38c91-a4a2-d9b6-da09-c1d55ab9a6b3"] = "b0e46270-ec50-56c5-aaf6-71e5a940f862", -- HUM_F_CLT_Camp_Minsc_Body_Ragged [GLB]
        ["2c25ec83-c34c-2e15-d4ff-5cf35b0bb655"] = "5ec362c4-d6f2-5253-ad1a-5d48003c12e5", -- HUM_F_CLT_Camp_Minsc_Pants_A [GLB]
        ["a85bb322-f3ee-fec9-06d7-cd3d8aacd25d"] = "ceb2c7aa-6229-5630-8439-2c881f0f043f", -- HUM_F_CLT_Camp_Minsc_Pants_B [GLB]
        ["26ff17f0-8620-8c71-02b5-70c7977065d8"] = "0f90426d-55e2-5279-99b3-89655104f2c6", -- HUM_F_CLT_Camp_Outfit_Astarion_Body [GLB]
        ["372f4870-d222-39b7-a801-4d226551175c"] = "1dd858c0-ab13-5657-88b0-0a6169df5059", -- HUM_F_CLT_Camp_Outfit_Laezel_Pants [GLB]
        ["99e0150f-659c-a90c-253a-b8529fdf2717"] = "f37b4e3a-a787-56b1-aeaf-4729cc41729e", -- HUM_F_CLT_Camp_Shar_Body [GLB]
        ["2156b7db-04a6-ce24-559e-67bec253f4b5"] = "3ee64dd6-590b-50ec-bc5f-b743b2bb6d6f", -- HUM_F_CLT_Circus_Pants_C [DAE]
        ["0ccd9020-100d-5c2e-5dec-e1d279d906bb"] = "69208300-dbe9-58f9-82a2-32a911f9b069", -- HUM_F_CLT_Circus_Pants_D [GLB]
        ["d1774c69-1642-40df-f5f6-f027dec0f5f2"] = "5812048b-81bb-5ec7-993a-07ca03fb6453", -- HUM_F_CLT_Circus_Pants_E [GLB]
        ["db5197fa-3e0c-90cb-b023-6a3f969eba2b"] = "a0a92cc9-1d37-56b9-a70b-a0ae3044c56d", -- HUM_F_CLT_Corset_A [GLB]
        ["4093b106-0202-8695-3930-c8ef8abc2256"] = "c4c4d566-2f00-54f9-8fb8-5bb716e72d51", -- HUM_F_CLT_Corset_C [GLB]
        ["406bdd29-ef4e-c58a-bc1d-10863f1f5acc"] = "c1c0ac99-e1f5-5c91-943c-718dc3d74788", -- HUM_F_CLT_Corset_Courtesan_A [GLB]
        ["015d97e7-0cb8-6744-039f-e4f4f4fc828d"] = "b523582c-61b4-5ce4-910c-d9bafa5bb801", -- HUM_F_CLT_Daisy_Dress_Gale_God [DAE]
        ["61782326-731c-e242-105b-bb81f9ba719e"] = "fdf9a806-83b5-5106-ab9e-7920d04c84af", -- HUM_F_CLT_Daisy_Dress_A [DAE]
        ["b7240d70-2bad-4d2f-3796-26686410a339"] = "345c9ad7-cb51-5731-8d48-dd899622d363", -- HUM_F_CLT_Daisy_Dress_White_A [DAE]
        ["ff62821d-7630-0787-6d2f-0434ff48f27b"] = "26bda5d5-26c8-58b1-8b73-1f2f30aaf6c7", -- HUM_F_CLT_Daisy_Dress_A_Accessories [GLB]
        ["27748f4d-ad84-964d-34b4-e46ff3257a4d"] = "f1f7073b-79ed-5ac1-b8fb-5779af5352c9", -- HUM_F_CLT_Daisy_Dress_Accessories_Gale_God [GLB]
        ["941d5ebe-0409-fef6-28e1-d90ef3a31b52"] = "f48bfcc6-c642-5a05-8082-a57dea6065f3", -- HUM_F_CLT_Daisy_Dress_Cape_Gale_God [GLB]
        ["b7c9aec9-bbe2-340a-82ad-a0fdc0394c82"] = "310f8552-f954-5e35-b558-80cc3e099743", -- HUM_F_CLT_Daisy_Dress_Cape [GLB]
        ["870ca9d0-b98a-e0fe-6c45-6286c7b8cbea"] = "8bbc0bbb-b09a-5ba2-b51b-94893fcb0506", -- HUM_F_CLT_Doublet_Rich_C_Body [DAE]
        ["bdbb424a-131c-1a30-ce25-4584c7fd153e"] = "ae68dbf5-ed9d-5f47-adbe-7e57c6d4b2b6", -- HUM_F_CLT_Doublet_Rich_C_Body_1 [DAE]
        ["30627639-4730-ab00-6160-3ec475cd35a9"] = "307641f9-99ba-59ac-a988-833d42afac08", -- HUM_F_CLT_Doublet_Rich_C_Skirt_A [GLB]
        ["458f51b4-07b3-0678-8879-75ed4f79fc78"] = "c51157e2-f6b0-5a95-bb2b-28189c824bf3", -- HUM_F_CLT_Doublet_Rich_C_Skirt_A_1 [GLB]
        ["d0e176ae-0389-66ac-5eda-3120e92752f8"] = "15dcfb01-f942-5e10-af5e-d1aedb6ef808", -- HUM_F_CLT_Doublet_Rich_C_Skirt_B_1 [GLB]
        ["e241a911-80fd-a32b-58e9-be4194873eaf"] = "01834124-f62f-5574-8b8e-fd330b13677d", -- HUM_F_CLT_Doublet_Rich_C_Skirt_B [GLB]
        ["0461fcfa-910d-18a9-a1b3-b5b32eb4243c"] = "510eb850-4ff0-5943-bc76-b1443c022cb5", -- HUM_F_CLT_Drow_Body_A [GLB]
        ["feea0381-4abd-9c88-139a-fbdff203761c"] = "48038485-20f7-5cb1-996b-1b4c37b47e8f", -- HUM_F_CLT_Drow_Body_B [GLB]
        ["1ecc06a0-cc2f-a841-8ed3-ac5b7b90350a"] = "2aaf9c17-2cfc-5619-8988-925b300ca776", -- HUM_F_CLT_Humans_Pants_A [GLB]
        ["7b247806-5fe3-8fa7-2733-d0d2486e55e0"] = "9488165a-8e26-5808-bef0-1be4aa772553", -- HUM_F_CLT_Humans_Pants_A2 [GLB]
        ["3c3c6f48-c2b0-17f5-0f96-fade875b8b03"] = "e52a3bcf-2004-53b7-991a-9013dd16b38a", -- HUM_F_CLT_MiddleClass_Body_A_0 [GLB]
        ["b6a9e089-b4d1-58a7-59a7-21a63ec1e3dc"] = "e3bb10d5-c7ab-5abd-9924-0430391c41f2", -- HUM_F_CLT_MiddleClass_Body_A_1 [GLB]
        ["d94b896f-5e09-f0aa-c158-1496fa2cd809"] = "f2350dc2-d69d-597d-a9d2-e48a1dd64a7e", -- HUM_F_CLT_MiddleClass_Body_A_2 [GLB]
        ["988f7d2e-a2f9-0be5-70d6-8e2852fb565e"] = "fb3f36fd-c288-5d17-a6c8-af1ca77e7d56", -- HUM_F_CLT_MiddleClass_Body_B [GLB]
        ["f0fa5d54-87bc-cd18-fb3f-52559917ab28"] = "f2fe616d-4660-5f39-89ee-a5bc7e838a66", -- HUM_F_CLT_EPI_MiddleClass_Body_B [GLB]
        ["6ab2470f-4430-f08e-c20d-1b44a1671d71"] = "a8d3e6f7-2c5d-5633-ac3b-955653cd90a4", -- HUM_F_CLT_MiddleClass_Body_C [GLB]
        ["5299aedc-02ac-40cb-906b-c2144e3543e8"] = "2d867d75-a8ed-5391-b202-8996f423f8a2", -- HUM_F_CLT_Mizora_Body_A [GLB]
        ["056e67fb-7722-4e59-9e1c-b75180177509"] = "1c4c54e4-8556-5b1e-a421-637c15cb9b36", -- HUM_F_CLT_Nymph_Dress [DAE]
        ["b0cde6e3-83bb-62e3-4c9b-c0ee256fc951"] = "aeed7085-7fa9-5278-acb9-18f042ba3a53", -- HUM_F_CLT_Pants_A [GLB]
        ["037f2658-0f94-a1f3-6162-3ab3ef46ef9f"] = "4806bd96-c07e-5072-a235-3fc394d1ade2", -- HUM_F_CLT_Pants_Torn_A [GLB]
        ["437ba6c8-16f3-a51d-d33f-496b886e7377"] = "0612821c-9c03-599a-aaa2-7cc6b2693b50", -- HUM_F_CLT_Pants_B [GLB]
        ["9ac53050-ed2f-32e2-361f-2ac4a849247c"] = "694b7024-0aa3-5b6f-bde9-8449111a54b4", -- HUM_F_CLT_Pants_C [GLB]
        ["814be387-c446-a05e-1ab8-c1a22bfbfb88"] = "5033614c-b1b0-51b6-a51a-0378f665eb1a", -- HUM_F_CLT_Pants_Torn_C [GLB]
        ["6ac9cad5-111e-33ff-3eda-ecffc3f8977d"] = "42800634-6f03-5d43-893c-00663d8c7d91", -- HUM_F_CLT_Pants_Courtesan_A [GLB]
        ["2d0f8f38-2383-125f-eb37-02d0916958d1"] = "c80ccb2d-4327-5b0d-b7e0-1b492437182c", -- HUM_F_CLT_Pants_D [GLB]
        ["8dbbdbea-3435-d58f-00e5-ffc390e1f1d8"] = "17df4c56-526b-51a4-a5fa-c072b2cf3737", -- HUM_F_CLT_Pants_E [GLB]
        ["ac0d8966-439e-890c-c363-4cc3a06673a8"] = "00703db5-e3a1-5537-8488-bb1f425f86cf", -- HUM_F_CLT_Pants_F [GLB]
        ["ddded88b-7eae-8063-c28b-29747f85b921"] = "e23f935d-dab9-50c6-8f89-8f1019b48cc0", -- HUM_F_CLT_Pants_G [GLB]
        ["073bcd0e-0fca-bc1a-6abc-2cb9f94d8ec6"] = "022892d9-f304-562c-bb84-e327c4f0f579", -- HUM_F_CLT_Pants_Torn_G [GLB]
        ["680e2bc4-eb37-2dbd-955e-ae510a4e1743"] = "26abb65e-6da2-5a82-af49-acc32ea68bd9", -- HUM_F_CLT_Pants_H_Twitch [GLB]
        ["9c9e4cb9-e1b2-ebce-e984-4324f4c9b69c"] = "f3173d58-5096-585b-8d85-b69406debab0", -- HUM_F_CLT_Pants_H [GLB]
        ["8f8751f9-bb4d-6e95-1883-567ef89578aa"] = "9a1231dc-2197-5849-8c01-a7233643c475", -- HUM_F_CLT_Pants_H_Short [GLB]
        ["9bb0a1f0-3db4-314e-5725-d1c7f3e30557"] = "00e4d8bf-33d9-5629-8658-c3e6881fc552", -- HUM_F_CLT_Refugees_Corset_A [GLB]
        ["410a4505-7032-e0f3-3825-96e5bca7352c"] = "43f03741-b87c-5e03-9788-0904aaf20bda", -- HUM_F_CLT_Refugees_Corset_B [GLB]
        ["38ab17d2-15d3-252f-d0ec-3866011c31cc"] = "9a279819-77ab-56e9-9942-92f682a6f5ae", -- HUM_F_CLT_Refugees_Pants [GLB]
        ["93d267af-f36e-8383-5d22-4b95bf38f321"] = "5d0ec4be-90ba-5534-958e-6bd174e6257d", -- HUM_F_CLT_Refugees_Pants_Torn [GLB]
        ["4d196657-a569-7e5e-b883-adb32bf7c17a"] = "ef715b3e-eafa-5c42-a610-1966711ee1c1", -- HUM_F_CLT_Refugees_Skirt_A [GLB]
        ["ac711a8a-3264-13f8-3d4f-39cc454ec168"] = "4395e643-c03f-54e1-a29b-9cdb2768e09b", -- HUM_F_CLT_Refugees_Skirt_B [GLB]
        ["c129ed42-df0f-1f7b-098a-d9e5b425b7b7"] = "e7071a6b-9119-53bd-ac77-449506bb8652", -- HUM_F_CLT_Refugees_Skirt_C [GLB]
        ["7dccd203-9d87-f011-b48b-095c94a802c7"] = "6e218127-1264-5719-8764-a56e08affe6c", -- HUM_F_CLT_Rich_F_Body [GLB]
        ["997602e8-8406-46d1-5bb3-800c5478a46b"] = "f2f4ed07-b74d-572f-a8e8-732179b99ebd", -- HUM_F_CLT_Rich_D_Body [GLB]
        ["d68214cf-e2bf-f120-9ef3-1f850a9246b5"] = "1aed76bb-3573-51f5-9504-2ba2670e9ed9", -- HUM_F_CLT_Rich_E_Body [GLB]
        ["025db7fc-0c5b-5072-e988-9880c7010a7f"] = "5390576d-36a8-54ca-82b0-b3e12867d4e3", -- HUM_F_CLT_Rich_D_Pants [GLB]
        ["e2e0e9e3-8082-07aa-0284-930015839327"] = "9a2e1cae-bb99-5f85-a737-83ea076a4bb9", -- HUM_F_CLT_Rich_F_Pants [GLB]
        ["d3c152cc-56e3-4561-4321-518f6f21546c"] = "fbfd3ffa-f96c-5f6d-99ff-e20a11f3eeb3", -- HUM_F_CLT_Rich_Dress_A_Body [DAE]
        ["15d6efbf-1aae-0dcd-bcfc-834a86c9e011"] = "0c1e2ee5-0bce-5388-87ef-53d2483a7004", -- HUM_F_CLT_Rich_Dress_A_Body_2 [DAE]
        ["c92f9f3c-712f-8c7f-6a0d-4d4516fd0737"] = "12b85baa-f12f-5df7-82dd-d14beb4106b9", -- HUM_F_CLT_Rich_Dress_A_Body_3 [DAE]
        ["b1ac04ac-8d6e-8733-889e-52278f7bd5ef"] = "118aba3c-a62c-5240-b657-b0b07c0164f5", -- HUM_F_CLT_Rich_Dress_B [GLB]
        ["b925d640-eb8e-9ef6-7561-2c1db074df4f"] = "41862c97-25fd-52a5-80f8-11b3200f5be8", -- HUM_F_CLT_Rich_Dress_B_Accessories [DAE]
        ["4aa3396b-85b4-ccfc-055d-c45a2b9ffcb8"] = "928006ac-7027-580c-8971-b293b5ca49fa", -- HUM_F_CLT_Rich_Dress_B_Shirt [GLB]
        ["a1fc20ac-2abc-8f45-6435-f6f7b98f4a19"] = "f724fad4-6613-5889-8e4f-eb15dc4c3cd8", -- HUM_F_CLT_Rich_Pants_A [GLB]
        ["e84b91c8-6d62-d46f-8a1a-0b87191f62dc"] = "dc13cf69-51e8-52b9-89b6-897e21af6384", -- HUM_F_CLT_Rich_Shirt_A_Pants [GLB]
        ["927cfa94-1fb6-3a04-0db5-11195fb37ae3"] = "d1ed7a28-83a7-5206-8bbd-1fb7870dd22a", -- HUM_F_CLT_Circus_Pants_B [GLB]
        ["dab58757-2da5-f75c-5e35-396a5b4f3be4"] = "8edf2ac1-fa9b-5f8e-9bd8-fa98acb920df", -- HUM_F_CLT_Rich_Shirt_A_Body [GLB]
        ["5c046b60-41a2-28b2-eea3-7267b7ce52e5"] = "f2ff0188-4d1d-5027-89e5-5a47f2da2570", -- HUM_F_CLT_Circus_Dress_A [GLB]
        ["8b02460a-147e-9e0a-02c6-4df064e68c09"] = "44b2df02-1fd8-5601-a86a-2315993667bf", -- HUM_F_CLT_Shirt_Courtesan_A_Corset_A [GLB]
        ["678cb240-d96f-5bbb-29ce-39d9d32de01f"] = "239b7078-b7bf-5bb7-bffc-8037c0762dd0", -- HUM_F_CLT_Shirt_Courtesan_A_Corset_B [GLB]
        ["d4badd19-dde6-ebb1-810f-8c7cf1c73a27"] = "e232e4b4-5ba8-5aa8-b429-b04e41e7724a", -- HUM_F_CLT_Shirt_Courtesan_A_Corset_E [GLB]
        ["bf06fc6a-82f0-a561-d26b-9023042beacd"] = "2a01e437-9c89-54af-99fa-490ec3fab514", -- HUM_F_CLT_Shirt_Courtesan_A_Corset_Twitch [GLB]
        ["f4cd5679-9a06-30ae-c8b5-97dcccf7896f"] = "653dabd3-a5ef-5f11-b52a-491410e3231e", -- HUM_F_CLT_Shirt_D_Corset_B [GLB]
        ["f89199e3-6801-a4ef-32dc-11c1d7521ddf"] = "677509e2-7cf1-5a1b-9c95-9637be9ed77c", -- HUM_F_CLT_Shirt_D_Corset_Alfira [GLB]
        ["f994d29a-7e3e-dbc2-e577-99b6869c413b"] = "28602e3a-4c1a-56fa-ad54-74e7346603ec", -- HUM_F_CLT_Shirt_H_Corset_B [GLB]
        ["c4f40a4a-5e87-eb9c-da5e-d268f1761083"] = "4f6859f9-6a38-58c7-b5e0-251fd049e654", -- HUM_F_CLT_Shirt_H_Corset_E [GLB]
        ["898a98d7-9100-d842-68e6-093d201ac6f8"] = "ce0c110c-e22b-58b5-922a-11a88755d9e5", -- HUM_F_CLT_Skirt_A [GLB]
        ["ecf67d32-6eb7-b67d-a7bd-847367f24e8b"] = "f2f5cb22-2364-546a-b9c3-c0bbddc9ed94", -- HUM_F_CLT_Skirt_A_Spring [GLB]
        ["05986d42-16ec-c7b6-c1ed-0bd21d03df83"] = "c0f60443-b8b6-5e9a-8826-4a41b090c3f1", -- HUM_F_CLT_Skirt_B [GLB]
        ["4018e880-fb09-b84c-85dd-f8701eee1bbb"] = "670fcce8-7da6-5961-b7ea-9b5e165656d7", -- HUM_F_CLT_Skirt_B_Mayrina [GLB]
        ["1039260c-c726-ed05-8785-6ead6bb7b3b0"] = "8490fbe8-2d6b-5349-afd2-4aaabebbb0a1", -- HUM_F_CLT_Skirt_C [GLB]
        ["5e4726c4-048d-b195-9e9e-dd983d5016b0"] = "113b37f6-66a0-5727-83f0-65f8c39ca455", -- HUM_F_CLT_Skirt_Courtesan_A [GLB]
        ["13297b57-278a-4b8b-f469-859ebff773a7"] = "6c9f930f-16ee-5207-a27d-0b009475ec26", -- HUM_F_CLT_Skirt_Courtesan_B [GLB]
        ["c0968035-1291-f945-bd4b-3b0514e52bff"] = "58cafe31-e1fa-5ce2-bc8b-b09429a4d728", -- HUM_F_CLT_Torn_Body_A [GLB]
        ["11634ec6-d3fe-1a2b-5ffb-85dcda9a48f6"] = "11cb92f7-3fad-57fc-a2da-5688a06d4fb3", -- HUM_F_CLT_Worker_Body [GLB]
        ["dda05feb-d0ab-4399-a0e7-34b5213bd4a3"] = "222fa5e5-b282-533c-87de-e00e02889379", -- HUM_F_CLT_Worker_Pants [DAE]
        ["e073aabb-ce90-3e7a-a59f-79f36b40dfb6"] = "3acf140c-b3ee-52e8-83d1-2c065a1862c3", -- HUM_F_Nurse_A_Legs_Bandages [GLB]
        ["89bc4da1-7904-faca-aadd-d30ee6e33ee1"] = "12fbf609-ddb5-57e6-ba70-135b8f23ca43", -- HUM_F_ARM_Nightsong_A_Body_OLD [GLB]
    },
    bcb = {
        ["02964f77-c398-423b-a5e9-f7810243811c"] = "156d913d-8f83-5014-943b-4380b507a0cc", -- HUM_F_ARM_Adventurer_Body_A [GLB]
        ["ed8e5366-bfa5-91c4-9eae-9ef39f402214"] = "06873e5b-a05e-5e0e-8ec0-f7363a203415", -- HUM_F_ARM_Astarion_Body [GLB]
        ["7187c0c1-3752-5d43-9858-7b72fdb0fa3c"] = "cc3d0c3e-a3a5-56f4-b5c8-1f2003455fd0", -- HUM_F_ARM_Astarion_Pants [GLB]
        ["51ae8337-9dd3-8552-f4c2-85e755a44503"] = "a5e0a00b-de0e-5aab-bb53-b535ebda37d5", -- HUM_F_ARM_BG_Watch_A_Pants [GLB]
        ["3a2f737e-8f3d-a59b-d457-36e89775d423"] = "1a45a84a-df5c-5a26-9f67-7bdc9c630ad1", -- HUM_F_ARM_BG_Watch_B_Pants [GLB]
        ["f395018f-ffb4-03e8-add9-ed9698fb1e51"] = "4e69d906-19b0-5b8f-9d0e-89bad74f059f", -- HUM_F_ARM_BG_Watch_C_Pants [GLB]
        ["a2edea05-8d9d-4d60-c128-6484fec0727c"] = "80c1daa4-cecf-5dc1-8c8a-1b7ab599395c", -- HUM_F_ARM_BG_Watch_Leather_A_Body [DAE]
        ["6bcaace7-2b7f-f347-bbbf-b7f6de1b406c"] = "5e1dbdc4-c18f-5d1b-9be2-a18c93754875", -- HUM_F_ARM_BG_Watch_Leather_B_Body [DAE]
        ["7eecdfb8-78f4-791c-dcdb-dce69bcf89a4"] = "df47a756-123c-5d50-930c-e8f855fe45e2", -- HUM_F_ARM_BG_Watch_Metal_A_Body [GLB]
        ["73eaa7e2-e2c4-bb99-8cdd-c02bce1979f7"] = "cd18bcc7-506d-5cca-9d2c-92445d6fd4ea", -- HUM_F_ARM_Bandit_A_Body [GLB]
        ["c18aac16-80cf-b3a1-7a68-2321e4e7f26d"] = "c87d7547-4be2-50e6-b019-7e8d317659d7", -- HUM_F_ARM_Bandit_A_Long_Body [GLB]
        ["4bf4a998-d2ae-a670-b31b-6efff35a28a4"] = "332361a5-87fb-52c7-85dd-8391ddb96d12", -- HUM_F_ARM_Bandit_A_Pants [GLB]
        ["2ec28d08-14cd-cf28-a750-ce566d791ef8"] = "31d4eb21-4b3e-5dfe-af4e-ea81f4911bcf", -- HUM_F_ARM_Bandit_B_Body [GLB]
        ["fe22e643-1266-a94a-0b42-eba64f922d8b"] = "39d3d694-ea66-57b6-829a-5afb319b65f6", -- HUM_F_ARM_Bandit_C_Body [GLB]
        ["904fbbc1-fca5-af69-66b0-f883728baf77"] = "5058a074-4299-573e-944a-1867aaf4b087", -- HUM_F_ARM_Bandit_C_Body_Accessories [GLB]
        ["5b042a61-3dcc-4a82-a2bf-b710f04abb81"] = "f7f0818a-9532-5493-abbc-e591f013f0c0", -- HUM_F_ARM_Bandit_D_Body [GLB]
        ["aa476663-1b31-19af-8e56-d071a91b74e8"] = "54f2266a-f48e-53f2-b6eb-8e1a4fa1183a", -- HUM_F_ARM_Bandit_D_Body_Belt_A [GLB]
        ["67cf64e2-d4df-d5c8-c988-bbe24c9ab0ef"] = "352dd7ab-059c-556a-b9bc-c9a4901caeb8", -- HUM_F_ARM_Bandit_D_Body_Belt_B [GLB]
        ["d2f744a0-4d40-1da3-bc2d-188cab1cf9cc"] = "0fcf4781-de6b-5229-92c9-38e49a141cdd", -- HUM_F_ARM_Bane_Light_Body_A [GLB]
        ["c6f30055-6e56-88ec-afff-8b16e0861797"] = "f6af7225-ce05-5f5b-9198-6b26b1612eff", -- HUM_F_ARM_Bane_Light_Body_B [GLB]
        ["c390c1b4-9592-e7bd-45c7-25de362c39d0"] = "29217a92-a0c6-5db3-a079-0fa3acd7b50c", -- HUM_F_ARM_Bane_Light_Pants_A [GLB]
        ["070fb86b-3b1c-07b6-bda6-ae3f54e6202c"] = "aa9aba74-959e-5d31-aa64-b9c5a395b443", -- HUM_F_ARM_Bane_Plate_Body_B [GLB]
        ["4e6a8fd0-0f1b-97d5-2938-156505003b0c"] = "a842fe00-79c6-5173-89ec-a5e53c2c4f21", -- HUM_F_ARM_Bane_Plate_Body_A [GLB]
        ["dde52dc3-cb63-0d90-393e-f3d9c3b8967b"] = "6e02b6e2-4516-5549-80ee-80c61eb346b3", -- HUM_F_ARM_Bane_Robe_Body_A [DAE]
        ["3fb7ea07-c5dc-954b-c58a-a8ec276ace28"] = "349905c6-9fee-5e3c-a58a-a403cda97f5e", -- HUM_F_ARM_Bane_Robe_Body_A_Sleeve [GLB]
        ["6671bb2f-ab3c-ce01-30c5-05ab81e64ec4"] = "f73a6583-d3c1-59ff-9825-9d2d86f312b4", -- HUM_F_ARM_Bane_Robe_Body_A_Sleeves [GLB]
        ["577e0453-07bb-c66e-33b1-7bee394c1a7f"] = "5cc9d6d3-c65a-5895-8db3-bf303bc0df47", -- HUM_F_ARM_BarbarianMagical_A_Body [GLB]
        ["089ee9e1-e764-38dd-c742-fd905f976f13"] = "b8de67b2-cc5b-507c-bdd8-21ff56985e6f", -- HUM_F_ARM_BarbarianMagical_A_Chest [GLB]
        ["7723fc3b-12a2-9f4f-d753-adaf00b281ec"] = "708b83f6-4151-5310-9e9b-5f962654c80b", -- HUM_F_ARM_BarbarianMagical_A_Pants [GLB]
        ["bcdf262d-b528-2448-76cb-3444588738a4"] = "5e38fcae-f34e-5fde-8891-21da17ef442a", -- HUM_F_ARM_BarbarianMagical_B_Body [GLB]
        ["0aed3d1c-709d-3f1e-71f1-1134ba9e060e"] = "473e6fdb-0c9f-589e-b76a-99122c4701bb", -- HUM_F_ARM_BarbarianMagical_B_Chest [GLB]
        ["40c284ef-a371-eec7-a27a-dd277dee03cb"] = "b6dabec5-986e-5d85-b91f-017d7e8a3354", -- HUM_F_ARM_BarbarianMagical_B_Pants [GLB]
        ["991c652e-3aa8-f8b1-609a-f8bd87b28636"] = "59ff817e-dd7b-5a95-8ee8-a735062d0962", -- HUM_F_ARM_Barbarian_A_Body [GLB]
        ["1b60efd1-c080-f02e-4b7c-988699485ae0"] = "e5110231-4a3b-52a4-8ca5-ee18f401be79", -- HUM_F_ARM_Barbarian_A_Pants [GLB]
        ["11a29e17-99fd-0db5-ec2e-d90a40ec5b1f"] = "d51e276b-f79d-5559-9ede-f89a990366b4", -- HUM_F_ARM_Barbarian_Karlach_A_Body [GLB]
        ["7cc5cafc-2bb8-3627-97e0-125d2c4fd084"] = "c9ac8274-a9bc-5ed7-b7b2-f608bd8cae13", -- HUM_F_ARM_Barbarian_Karlach_A_Pants [GLB]
        ["34fbe3a5-7d74-c705-a42c-4e9922fa12fc"] = "22f2c4d0-f2c9-5595-b09f-f442045fe294", -- HUM_F_ARM_Bard_BodyBot [GLB]
        ["69bf1065-75ae-2930-33b8-ac4a5bdde0ad"] = "e578b6b0-e7cc-5dce-b437-af9514a8cd5f", -- HUM_F_ARM_Bard_BodyTop [GLB]
        ["29153218-c410-bd1e-b23d-d615ead06201"] = "452af3e8-da1f-5e62-907b-6280d0292ee9", -- HUM_F_ARM_Bard_Pants [GLB]
        ["a8b54d83-bbba-1c0c-a3a0-f8143409b018"] = "afb4d0fe-5efb-5dbd-9cea-83062af8f1f4", -- HUM_F_ARM_Bhaal_A_Body [GLB]
        ["aa09792f-4f55-dd17-c2f5-7ca30642a95c"] = "0de204e7-6504-571b-bc35-6ff5db07e128", -- HUM_F_ARM_Bhaal_A_Pants [GLB]
        ["f8c9f76d-d57e-d818-f028-6be46ef6ac5a"] = "d08b8347-9bab-5bf1-9257-c928d8e5d86b", -- HUM_F_ARM_Bhaal_Rags_Body [GLB]
        ["5e07542e-8dd0-ef58-ef8e-f9c92a9a5670"] = "2c580354-1178-5103-addc-72b5ff6581c0", -- HUM_F_ARM_Bhaal_Rags_Pants [GLB]
        ["9a255759-35b9-2aca-77d4-b8b331091887"] = "488f9fd0-b4d8-56d1-8ad8-45c8756b87eb", -- HUM_F_ARM_BreastPlate_A_0_Body [GLB]
        ["40d6023f-73cc-cf97-7b7c-e0efa5ef2252"] = "43309960-6149-5292-914a-e42f676ddbde", -- HUM_F_ARM_BreastPlate_A_1_Body [GLB]
        ["41f442ce-a9dd-57b1-8703-c0612de681ba"] = "8e4acc50-5cae-588b-9de0-d00f6069fbae", -- HUM_F_ARM_BreastPlate_A_2_Body [GLB]
        ["2d76e68d-122c-ca1b-eae6-2754d6f2a427"] = "75eebbb9-d34e-5482-88c5-6aad3d3a7dfb", -- HUM_F_ARM_Breastplate_A_1_Pants [GLB]
        ["52a0a341-e040-3d36-14cf-9ddbb1964d86"] = "e5c3da49-77d7-5b53-93e6-f79007a35e50", -- HUM_F_ARM_Breastplate_A_0_Pants [GLB]
        ["7842adad-0d32-2845-321a-ae53e02759c7"] = "7031bf99-bf12-5e39-96a6-cc2d53cfed9b", -- HUM_F_ARM_Breastplate_A_2_Pants [GLB]
        ["4b220494-227c-2286-06e7-81f5aa621fbc"] = "e6514e04-9dcc-5a77-abde-983ccb1b8c6c", -- HUM_F_ARM_ChainMail_A_0_Body [GLB]
        ["746d3091-9b4e-05d2-d6e3-990e88b4e697"] = "2f501c08-8179-5dae-8e10-434bde831cf5", -- HUM_F_ARM_ChainMail_A_1_Body [GLB]
        ["ea647791-dae1-f65a-4045-d971868d70a7"] = "1767e829-7c75-55bc-8614-0d0e383755ee", -- HUM_F_ARM_FlamingFist_ChainMail_A_1_Body [GLB]
        ["7a0a8086-cf8a-8526-7196-3f96c1a31764"] = "3746d871-53e0-5f02-99bc-ded1d3c9a166", -- HUM_F_ARM_ChainMail_A_2_Body [GLB]
        ["57aa9036-497a-bc54-7889-763bcf0f5ecd"] = "687c7c85-6778-5dbb-be22-bf26ca6f8e21", -- HUM_F_ARM_ChainMail_A_Pants [GLB]
        ["c977d6cf-90ba-08f5-0d6a-96bfcbc2ff37"] = "14991af6-8f26-5792-b53c-a6cd893bf77b", -- HUM_F_ARM_ChainShirt_A_0_Body [DAE]
        ["e5b5a50e-2200-ee2a-2cac-1868323d3c2b"] = "818a7c42-c0dd-520d-8c39-bcbcc43ee350", -- HUM_F_ARM_ChainShirt_A_1_Body [DAE]
        ["adc9638c-946d-f253-fab5-a2185780e38e"] = "87d17952-b3f2-5d31-80c4-0fa53aeeaf2a", -- HUM_F_ARM_ChainShirt_A_2_Body [DAE]
        ["c18914df-2ecd-7418-df18-e27521d89e07"] = "d1e5d087-9f79-5021-a2da-8940dddf496b", -- HUM_F_ARM_ChainShirt_B_0_Body [GLB]
        ["f6000495-b090-d2fc-1d8c-8b3269ac469d"] = "4975e083-3988-5676-9ed9-d8fd558bb1c8", -- HUM_F_ARM_ChainShirt_B_0_Broken_Body [GLB]
        ["f8be761d-9160-c57d-fd57-436735b91403"] = "a01ba119-f2a5-5d35-bac2-891cfa3586a2", -- HUM_F_ARM_ChainShirt_B_1_Body [DAE]
        ["9a04bfd8-2a6f-a2b6-6c18-3921a81df32e"] = "3d0be30c-fdf2-571e-9d39-1d74f95efa06", -- HUM_F_ARM_ChainShirt_B_2_Body [GLB]
        ["7f17b0c8-69dc-799f-457f-aa9b0edf87cf"] = "b21e0b83-d782-5818-8bcc-42b38c23d140", -- HUM_F_ARM_ChainShirt_B_2_Pants [GLB]
        ["86beb015-ba3b-e2f5-8fc1-a13eaae763ed"] = "6b7c3c46-1c43-5570-98be-be6550fe8699", -- HUM_F_ARM_ChainShirt_B_Broken_Pants [GLB]
        ["2a24cc0a-bf6a-042b-3d02-237596da3a02"] = "ad9eae17-02bb-59f3-b649-80b62f5fa658", -- HUM_F_ARM_ChainShirt_B_Pants [GLB]
        ["46d2d271-a292-6511-ab69-b5b3fb8d4732"] = "726ca934-6e01-5b9b-a39e-ba50005cfdd2", -- HUM_F_ARM_ChainShirt_Shadowheart_A_Body [GLB]
        ["355acc60-c8ae-129a-f9b8-fd46d66a9cd9"] = "8606c8ec-85d4-5609-9d15-6d8bb125530f", -- HUM_F_ARM_Cloth_Magic_A_Chest [GLB]
        ["7626ae1c-1f46-fc33-f267-fa42d6f00a5f"] = "d38af671-8f58-5768-bcfb-99e66a748e16", -- HUM_F_ARM_Cloth_Magic_A_Pants [GLB]
        ["75fe0fe7-8b43-7c04-d6ff-559601640e7b"] = "9c01ad76-f6e8-5f0d-bc82-6c562a0db9ff", -- HUM_F_ARM_Cloth_Magic_B_Chest [GLB]
        ["fcfff744-87aa-18d1-71b6-dd3dde8ffd2f"] = "649757bc-6e66-5ddf-8783-c8ee9e2e355b", -- HUM_F_ARM_Cloth_Magic_C_Chest [GLB]
        ["d1228194-ed35-a085-f73b-469f46be1a63"] = "3d45ac94-7ad1-57ad-9ad6-fefa8c37a955", -- HUM_F_ARM_Cloth_Magic_B_Pants [GLB]
        ["d1c28da5-1518-5565-e948-546ff74f14b9"] = "fbf88e4c-7659-5825-a750-2c94668f7387", -- HUM_F_ARM_Cult_Absolute_Body_A [GLB]
        ["40c6743d-7f7b-9a36-ea69-ee5be3fd42ef"] = "108ca799-e2b8-52ff-a324-e84a6b51814d", -- HUM_F_ARM_Cult_Absolute_Body_B [GLB]
        ["e936b4b2-5c11-ff4a-a9b4-7a744844e508"] = "e696c36d-3613-5cea-896f-c4589d5945e9", -- HUM_F_ARM_Cult_Absolute_Body_C [GLB]
        ["4fad5d72-61e3-a66d-5789-5adb266d5262"] = "3da7854c-6940-531e-96bd-6268f33b0c00", -- HUM_F_ARM_Cult_Absolute_Pants_A [GLB]
        ["f593ca9c-fb69-ce98-58b2-d240acb832ee"] = "a4c62bcb-d44d-50ed-8c6b-7c3bf6efe8f8", -- HUM_F_ARM_Cult_Absolute_Pants_B [GLB]
        ["92904542-5941-883f-5ef9-64ed849223c3"] = "694b74ec-a4b1-523a-b06f-44d8557543ee", -- HUM_F_ARM_Cult_Absolute_Robe_Body_A [DAE]
        ["223c2250-b8d2-02f8-7d81-3a5dd8aba412"] = "0a0660df-fe3a-54cf-b6ad-fcb8f8545b17", -- HUM_F_ARM_Cult_Absolute_Robe_Body_A_Belt_A [GLB]
        ["9423615d-6287-ba55-b5ac-9120d68abbf9"] = "a31d7454-b62b-5219-a027-1da9ffaa3f6d", -- HUM_F_ARM_Cult_Absolute_Robe_Body_B [DAE]
        ["ab01e06f-c22c-4389-6d09-170408da0397"] = "a577adbe-63a0-5fa5-bde6-dbf2e17d196c", -- HUM_F_ARM_Cult_Absolute_Robe_Body_C [DAE]
        ["7ac2ee68-c81a-5acb-bc20-0dd74798d4ca"] = "0b114a41-7c9d-5a50-9cbc-71c7f74f5328", -- HUM_F_ARM_Cult_Absolute_Skirt_A [GLB]
        ["8f018691-9ad2-8fda-e332-4625fdc9be38"] = "3dcf704f-d4cd-5945-9f9d-fd664bbe9497", -- HUM_F_ARM_Cult_Absolute_Skirt_B [GLB]
        ["6d3ff410-6a56-1570-945b-c9400294efd3"] = "e9644d9d-796f-57f8-afd6-0d7c5ef810d0", -- HUM_F_ARM_Daisy_Body [GLB]
        ["8629e0f0-bf23-f8d7-aa26-059bdee2f274"] = "40b438c9-d2aa-500b-adea-d3dd6fd58e4b", -- HUM_F_ARM_Daisy_Pants [GLB]
        ["47550623-1e6d-c1ee-8d8b-c104e3212add"] = "ac6c1525-dc25-5056-85b8-b7e11eefc296", -- HUM_F_ARM_Shadowheart_Dark_Justiciar_Body_A [GLB]
        ["64f991ff-b533-4095-7fe7-68484ec99438"] = "40842be0-c2ac-558c-a72e-71fcbe81df8d", -- HUM_F_ARM_Dark_Justiciar_A_0_Body [GLB]
        ["5878c12d-03ae-58e1-3010-76819284ebd1"] = "df82686d-dafe-52ab-bbc1-b3deaeeae82a", -- HUM_F_ARM_Dark_Justiciar_A_1_Body [GLB]
        ["ae75ef0b-1265-48c8-b295-62d0d140fe44"] = "47a71945-b55f-59ea-b396-649d8e91254f", -- HUM_F_ARM_Shadowheart_Dark_Justiciar_Pants_A [GLB]
        ["b639f736-82cf-9765-bf2c-4b55725e1fdf"] = "40042cc2-51cd-5228-a150-20a7b29401f3", -- HUM_F_ARM_Dark_Justiciar_A_Pants [GLB]
        ["da47419f-1174-c82e-a26e-e813f658d0c9"] = "f9b90da0-380b-5eaf-9a0b-b4c135099e06", -- HUM_F_ARM_Dark_Justiciar_Damaged_A_0_Body [GLB]
        ["a79c23c2-d7fd-f97d-f7c2-72b699efb3ed"] = "b1e8a5d0-83c3-5e0d-8f10-fa114bc03cbe", -- HUM_F_ARM_Demon_A_Body [GLB]
        ["abd56050-e481-c65c-e113-a097267fc46b"] = "46d5d027-5feb-5864-b9d7-c119b28a2661", -- HUM_F_ARM_Demon_A_Pants [GLB]
        ["20b5ba6a-3d8c-1190-8f3e-693a16c0bd2d"] = "e15dc709-fdfa-5359-8e2c-a17433374c17", -- HUM_F_ARM_Desire_Dress [GLB]
        ["af423ae5-de48-9fed-6ea7-982d4c822dc4"] = "3d2c4dcf-3e6f-5eb0-994c-5cd39d0cfa7f", -- HUM_F_ARM_Desire_Pants [GLB]
        ["7a3000df-92f1-be0d-b367-0a6916bd2a7d"] = "d330a9ac-0781-5e67-b70f-6f8335a109c3", -- HUM_F_ARM_Devils_Blacksmith_Body [GLB]
        ["ae3551af-f085-6a5e-cd1f-2d73903c3c73"] = "078fd149-1590-5cd6-9405-d62be5a82a7f", -- HUM_F_ARM_Devils_Blacksmith_Pants [GLB]
        ["9691c75a-8cee-b6df-b212-f4ce74886bd1"] = "9b136c1c-112c-5dce-8e8f-bf25373c896c", -- HUM_F_ARM_Devils_Blacksmith_Pants_B [GLB]
        ["8523fbab-d973-bbfb-7aa2-2449a7587996"] = "7f56ed59-21a2-52ce-af50-a5cba77d97af", -- HUM_F_ARM_DrowLeather_A_Body [GLB]
        ["aba6f4a5-c062-6481-afd8-7be4c19e3877"] = "c8a51704-e15f-5882-9c77-22da295e3843", -- HUM_F_ARM_DrowLeather_A_Pants [GLB]
        ["5e46bd3c-6ecf-dda1-e5ec-defa96bd9eff"] = "368a869e-efe4-5a28-83d4-242145946cb8", -- HUM_F_ARM_DrowLeather_B_Body [GLB]
        ["f2efe983-d13d-0da6-34a8-d6a6dbd5f328"] = "34886077-9349-5bb6-b890-fd7b96b1d527", -- HUM_F_ARM_DrowLeather_B_Pants [GLB]
        ["eee49ed4-6498-d170-da59-46b1cedcefbc"] = "f891fd2f-9bdf-55d4-8deb-966ee6d0aafd", -- HUM_F_ARM_DrowLeather_C_Body [GLB]
        ["8a1afa94-327f-2d6c-ac2c-dd8de339c225"] = "c4cb7720-f08f-5666-a7c8-323c46ed5f24", -- HUM_F_ARM_Druid_A_Body [GLB]
        ["f358cebf-6795-3bc5-adb9-463015af6888"] = "148b5511-5385-5627-9aee-93bedd63f2be", -- HUM_F_ARM_Druid_A_Body_Leaves [GLB]
        ["86c56da4-ddad-22d9-4375-bb8800380fc4"] = "6f666d5e-93aa-5ed9-97f0-635494572437", -- HUM_F_ARM_Druid_B_1_Pants [GLB]
        ["10f69796-9490-29fd-074b-a8d14b2a94f2"] = "b992755b-d531-5642-97a5-c50449b30e28", -- HUM_F_ARM_Druid_B_2_Pants [GLB]
        ["3f27e356-0f04-0b9c-3363-19d59d648f09"] = "e75a0967-0255-53e4-9922-8f5b83b68be3", -- HUM_F_ARM_Druid_B_Body [GLB]
        ["70385c52-b782-a539-aae9-a5bde03aef61"] = "fbf18199-d5a6-5883-b13c-5e00c6030dca", -- HUM_F_ARM_Druid_C_2_Body [GLB]
        ["b6b27f8b-060c-1f74-4557-1ca70aa83783"] = "ddaf1ffe-6a66-5f87-9081-b48194b85152", -- HUM_F_ARM_Druid_C_Body [GLB]
        ["30751bdc-98e5-4e70-2d73-5d17ad6a766a"] = "c761c802-aa0c-5080-a741-e6cf22a89368", -- HUM_F_ARM_DwarvenPlate_A_Body [GLB]
        ["72c1578a-153a-5e91-b98e-b895ef850102"] = "42e3263d-2aa8-5765-b1a2-bcedcf86f3f1", -- HUM_F_ARM_DwarvenPlate_A_Pants [GLB]
        ["ab0f614d-c855-6eaa-c6e7-5802bdcdd944"] = "5b2a6613-b965-5405-b658-aaf95d39ad67", -- HUM_F_ARM_EPI_Robe_Shar_Body_A [GLB]
        ["f94c451b-bfa1-9fa5-eee3-6acf1d1a073c"] = "2419cfad-352f-5910-995f-f8af0bf2d3f6", -- HUM_F_ARM_Elven_ChainShirt_Body [GLB]
        ["ab162662-4ed3-3c46-6fc9-2269b9e96c45"] = "64d73709-7efd-52c6-8ec6-53e5cb96cbcb", -- HUM_F_ARM_Elven_Umberlee_Chainshirt_Body [GLB]
        ["4efcdd6b-63a1-f238-b40d-9eeba145e4b5"] = "6b665fdf-5bd7-57ae-88ce-0210ae87b1b8", -- HUM_F_ARM_FlamingFist_Halfplate_A_0_Body_Pin [GLB]
        ["5ad493a4-3b43-ac38-120f-3a306218d9c8"] = "bff2c18d-d576-5b17-b09d-235bc84be265", -- HUM_F_ARM_FlamingFist_HalfPlate_A_1_Body [GLB]
        ["6444108d-0e23-fbe5-a27d-e86f31330b34"] = "15c1bfdd-df16-5a94-8a8f-c5e50e3c5acb", -- HUM_F_ARM_FlamingFist_Halfplate_A_0_Body [GLB]
        ["782867e4-a17b-89a2-5556-ad3d70d66489"] = "72b16c38-23c2-5299-885d-2fee5721a19c", -- HUM_F_ARM_FlamingFist_Halfplate_Marcus_Body [GLB]
        ["d2cd78eb-2199-a0b2-1fd3-cc95cc4785ff"] = "6f9e1155-4d0e-572a-91c0-7fbf6d4c2b19", -- HUM_F_ARM_FlamingFist_Leather_Body [GLB]
        ["06590900-7c2f-8087-4121-18d84631b106"] = "63d6d4ae-d150-573a-967c-a63572c93856", -- HUM_F_ARM_FlamingFist_Robe_Body [GLB]
        ["ddfe0903-7361-3e46-50e9-ef1a77dfd057"] = "377648d4-dbd3-5cbd-ac6b-233328bac43f", -- HUM_F_ARM_FlamingFist_Scalemail_Body [GLB]
        ["75e5b7e7-3c17-6a19-c3db-6c94084dff4f"] = "ccaec6cc-2790-5713-8e2e-832254a905c1", -- HUM_F_ARM_Githyanki_HalfPlate_A_Body [GLB]
        ["dde1397d-d127-00a9-6c0f-39f924f4d777"] = "85e1516f-464c-5ea3-94c3-d445734f8cff", -- HUM_F_ARM_Githyanki_HalfPlate_Leather_A_Body [GLB]
        ["fdbfa9ae-c140-9270-0b8c-d8e475e9d767"] = "e6c97705-f66e-56ea-8541-488048ed3eb7", -- HUM_F_ARM_Githyanki_HalfPlate_A_Pants [GLB]
        ["640e0bc8-f648-f14a-cbb1-6e762e498ae9"] = "1aa83ce8-ff6c-596f-aec3-087bdb3ec756", -- HUM_F_ARM_Githyanki_HalfPlate_B_Body [GLB]
        ["87ed8561-ee52-8cc2-fae7-b375940d23fe"] = "d48d0df9-a831-57ff-b6bc-5ecdce330ca8", -- HUM_F_ARM_Githyanki_HalfPlate_Leather_B_Body [GLB]
        ["281249cf-2236-1738-2646-2ec5082b51e2"] = "38a1c389-0be7-5f2e-98ce-03fceea907de", -- HUM_F_ARM_Githyanki_HalfPlate_B_Pants [GLB]
        ["7ed2928d-4e3c-bb5d-bc13-10b3abf14823"] = "e2a42201-fa6c-5732-8141-5a56006ce93b", -- HUM_F_ARM_Gortash_Body_Jacket [GLB]
        ["165491b8-6344-efc1-ad62-b8a6547c1052"] = "83f35356-7285-5ab4-914b-8061b566ce5f", -- HUM_F_ARM_Gortash_Body_Skirt [GLB]
        ["8234a9bb-3b79-4691-459f-024ec60ab109"] = "62c21954-0d84-5130-9307-0d5eac5a2606", -- HUM_F_ARM_HalfPlate_A_1_Body [GLB]
        ["f0fa736a-804a-5bee-3aa8-dcc130c01f38"] = "f0554301-d997-5808-be51-b457f5f3886b", -- HUM_F_ARM_HalfPlate_A_0_Body [GLB]
        ["d8e274b7-5bd8-70a0-0d1d-bfe17aae40d2"] = "c70fdb59-5da6-56ee-9158-ccc30c85f617", -- HUM_F_ARM_HalfPlate_A_2_Body [GLB]
        ["05a76972-4b7c-7b02-a5bd-5ad8f664b7e7"] = "c9948656-449d-51aa-9a23-2819530a882d", -- HUM_F_ARM_HalfPlate_A_1_Body_Shoulderpads [GLB]
        ["0d1e9563-5fef-e704-5c71-273dd0a5bb5d"] = "d04c1422-7543-5cbb-bc40-c07cc99939e4", -- HUM_F_ARM_HalfPlate_A_0_Body_Shoulderpads [GLB]
        ["dcfaaada-b1b2-21bd-bffb-e4f0059bac19"] = "4a6b9bfc-e43b-52f6-840a-26c93ed3dcda", -- HUM_F_ARM_HalfPlate_A_2_Body_Shoulderpads [GLB]
        ["89d15a0f-20e0-8309-922f-f9e6fd3a408a"] = "04f76045-fdb3-5627-ba97-80bac5c11d3f", -- HUM_F_ARM_HalfPlate_A_1_Pants [GLB]
        ["addcf306-1dc0-041e-8035-f17ce2a511cf"] = "5dba05b1-46a7-5fae-8542-95486034f04b", -- HUM_F_ARM_HalfPlate_A_2_Pants [GLB]
        ["f689fa3d-8047-77e7-cf71-4cddcd476748"] = "c03de6df-8aa6-577d-a512-e4b2c2527ec2", -- HUM_F_ARM_HalfPlate_A_0_Pants [GLB]
        ["8163e3db-992f-5232-0d93-3e115d1c5325"] = "c6769268-cdfa-5fe0-8303-668697fb456e", -- HUM_F_ARM_HalfPlate_B_0_Body [GLB]
        ["d5d8886f-255e-c24d-1b53-627b86a57f85"] = "863beb4e-446e-5a84-a3e1-73e92bcc6b11", -- HUM_F_ARM_HalfPlate_B_0_Skirt [GLB]
        ["0d9ccc2a-2877-0aa4-34e7-515ca1a25c68"] = "a5de46ea-21a6-5b85-bd94-0dbb0f6fa4b7", -- HUM_F_ARM_HalfPlate_B_1_Body [GLB]
        ["018611dd-f4a5-09bb-2239-9ee9b04996ea"] = "97f89f02-dc28-5164-ad90-1eaa1b6d6453", -- HUM_F_ARM_HalfPlate_B_2_Pants [GLB]
        ["364e4254-fd0d-a55f-8822-9ff105c6b55b"] = "f0c6395b-114e-57a6-aed1-8d6eda387651", -- HUM_F_ARM_HalfPlate_B_1_Pants [GLB]
        ["e08a82f1-c191-09be-3223-989d4d2c69fe"] = "4be8ce6c-ac98-586b-b607-709796d5f8ee", -- HUM_F_ARM_HalfPlate_B_0_Pants [GLB]
        ["6b7c0656-2be7-75c9-a99c-132aef475bfb"] = "084c09a3-62df-5491-8dc9-9ce003cb3ec0", -- HUM_F_ARM_HalfPlate_B_1_Skirt [GLB]
        ["9e0dda43-4f5d-db94-98fd-d4188eb558a4"] = "d5212b63-f640-5fe4-ae23-cd042c8338a7", -- HUM_F_ARM_HalfPlate_B_2_Body [GLB]
        ["f0057ae6-6efb-9b6a-9849-feb67cdfc48a"] = "fb9c5334-fd99-568a-ae4b-bde45ba2885a", -- HUM_F_ARM_HalfPlate_B_2_Skirt [GLB]
        ["28b9efee-0da6-f29d-1f00-6977155b8fb5"] = "4386ddc9-c837-5850-9f5e-c743924cd67a", -- HUM_F_ARM_HalfPlate_EndGame_Body [GLB]
        ["01e98505-64e9-81bb-4419-9b27c451aff9"] = "77c4124c-d6ac-5bf5-9b5d-91088a86a25e", -- HUM_F_ARM_HalfPlate_EndGame_Pants [GLB]
        ["33c3502d-8ef5-b4ab-059f-7a4f8cbfefc7"] = "06c6ca4a-65ad-524b-9668-b86a75503411", -- HUM_F_ARM_Hide_A_0_Body [GLB]
        ["f6399f9e-19ae-cbad-d113-f72ac1574b19"] = "4ada5e24-5c4c-5fd8-9871-ab73ce517868", -- HUM_F_ARM_Hide_A_1_Body [GLB]
        ["3e6b87e1-4b57-50f3-a06b-7c3ced1bb4ef"] = "9a9801e1-3a0c-5b9b-a7e7-454b22b3a9dc", -- HUM_F_ARM_Hide_A_2_Body [DAE]
        ["cb592497-afb7-f684-0daa-4af5b81c186c"] = "984a1f39-a58a-5010-80cc-89063d75f325", -- HUM_F_ARM_Hide_Druid_1 [DAE]
        ["e62bf9cd-7779-92c1-df3e-99c3de5df172"] = "6845e9bb-fcdf-5f62-8f74-306f1c13ddf0", -- HUM_F_ARM_Hide_A_Pants_A [GLB]
        ["5efbe777-69e7-97e0-e59b-beece8550742"] = "4c410353-37c0-5a4b-90c3-607877bdcddc", -- HUM_F_ARM_Hide_A_Pants_B [GLB]
        ["d21c0b33-ae6a-7e31-c749-6e2ee855700c"] = "7b020111-e907-59f7-a210-f64d41c59e30", -- HUM_F_ARM_Infernal_Robe_Pants [GLB]
        ["fdea9130-9c3a-aa7a-66a1-8e5dec87a1c6"] = "37b783f6-41db-5230-83ee-079f86fb2c48", -- HUM_F_ARM_Isobel_A_Pants [GLB]
        ["32f77742-2d5e-39a8-3b6b-6541fa09e05d"] = "b1346115-eb67-5053-ae06-0eeaca7cacd4", -- HUM_F_ARM_Isobel_A_Body [GLB]
        ["00b5bc65-3298-0d52-1200-6377414e1fc7"] = "824d67af-6de2-5f55-afe5-672ef7af1b92", -- HUM_F_ARM_Infernal_Robe_Body [GLB]
        ["c911aacc-69b4-a52f-77ac-ae2ea41c72d7"] = "dec18a3a-0d55-56c0-9c16-a63cf10b4b44", -- HUM_F_ARM_Isobel_A_Robe_Body [GLB]
        ["21041aa7-c364-e341-60a2-c7ae861bca79"] = "aa8ba6c0-be50-5a2e-a2a3-96913757a584", -- HUM_F_ARM_Isobel_A_Robe_Skirt [GLB]
        ["2dccb52f-cb96-13c4-0241-7ac9c8a69d81"] = "41757efb-71ef-51d2-9a39-53c4fb1894b0", -- HUM_F_ARM_Jaheira_Pants [GLB]
        ["d0336146-7ecc-0b01-520b-98985a34c0ba"] = "30ecc028-6a7b-5934-85ed-ce4c2d01b168", -- HUM_F_ARM_Jaheira_Skirt [GLB]
        ["1ae5d864-e9b7-be32-5f04-88da2699fb97"] = "0478eb85-d6a4-5945-adbb-0b7fccfe9efa", -- HUM_F_ARM_Karlach_Epilogue_Player_Body [DAE]
        ["fb084ed8-92e2-e11e-db79-2d22069c7a67"] = "da25812c-4c70-5368-b67c-bc54b6200e7a", -- HUM_F_ARM_Ketheric_Body_A [GLB]
        ["03a18f12-cda7-40be-fbf2-707cd5fdd806"] = "112be205-08e7-5523-8c75-c1edb80100fd", -- HUM_F_ARM_Ketheric_Pants_A [GLB]
        ["79ce64fd-01f6-f04e-4386-83018e3321a6"] = "354cfe12-0189-5bd3-a601-b1069dc7d85c", -- HUM_F_ARM_Laezel_Githyanki_HalfPlate_A_Body [GLB]
        ["b601d974-bdcc-4653-ba7c-58ef45a0c5e4"] = "4d8b6fae-1411-530b-ba9a-b189b0778d40", -- HUM_F_ARM_Laezel_Githyanki_HalfPlate_Broken_A_Body [GLB]
        ["956e11cc-41da-9e43-036b-c59a70c1b945"] = "88774d3f-4436-51e9-8f9f-c64cb3a45cd9", -- HUM_F_ARM_Leather_A_1_Body [GLB]
        ["d6f8ef96-3674-39c6-3e7a-73f94bdd5595"] = "870bfc15-c251-5837-af50-dc6b360ba8e9", -- HUM_F_ARM_FlamingFist_Leather_Pants [GLB]
        ["f29af014-91cb-f1a8-3b6f-d59de4ae8e91"] = "c86d4c8d-0dfa-5c12-bc8c-9d4fdef816e2", -- HUM_F_ARM_Leather_A_1_Pants [GLB]
        ["b36b4826-00a5-0a1a-f1e7-1e13fb7192db"] = "127e0f23-91d9-5051-935b-4bbb153b1f01", -- HUM_F_ARM_Leather_A_2_Body [GLB]
        ["a8b2d37c-aee8-7458-c570-638c830d31d1"] = "41255b5c-67a4-5353-a0c2-94006bf6f20d", -- HUM_F_ARM_Leather_A_2_Pants [GLB]
        ["e4bd0d2b-0160-f802-3429-7bb4b305a613"] = "91a0d1fd-5024-5e37-8f01-7ababf50b100", -- HUM_F_ARM_Leather_A_2_Guild_Pants [GLB]
        ["66bcfba0-cea0-504f-2790-053dc8cb0bbf"] = "1d93dcae-d266-5a29-8c62-92190cac114b", -- HUM_F_ARM_Leather_A_Body [GLB]
        ["27e35669-4d7c-b39a-6476-abbff870074c"] = "eb8ebde1-56f1-5f83-970b-12ee3559e153", -- HUM_F_ARM_Leather_A_Pants [GLB]
        ["a506a44a-d295-01b5-37f2-c19e33aa62c9"] = "9ec812c9-9bf2-57ba-ba68-37631169b357", -- HUM_F_CLT_Drow_Pants_A [GLB]
        ["1e87abcb-c98a-538a-c9a1-00df18b91355"] = "44c97695-e190-5f4c-a2dd-28ac7f522ab0", -- HUM_F_ARM_Leather_Old_A_Body [GLB]
        ["aeedba01-02a7-25ec-bca5-b314ba4c4fee"] = "6ab2e236-c36d-5031-a57f-84747176c3b7", -- HUM_F_ARM_Leather_Old_A_Pants [GLB]
        ["3693fa90-0f57-6cb7-d8e9-b46d64a14e70"] = "a3ecbb94-16cd-52e2-9f49-a0528546aef1", -- HUM_F_ARM_Leather_Old_A_Pants_B [GLB]
        ["6d5c83a6-cce9-4dff-6735-a7e015bdc82c"] = "15d75bb0-96fe-58b8-962a-6477644ed3d0", -- HUM_F_ARM_Leather_Old_A_Pants_B_Kneepads [GLB]
        ["0ff48dde-2f79-77e4-a76b-4e119f8ed081"] = "71c6e800-aed3-59cb-9747-8581b12ed937", -- HUM_F_ARM_Magic_Monk_B_Body [GLB]
        ["ca714562-2c20-67e8-8db8-34ee8e354534"] = "f96537ad-c25f-5ff4-9e63-f2f57abc9fb1", -- HUM_F_ARM_Magic_Monk_Body [GLB]
        ["c3070973-5315-4061-70a3-c81b7af8992e"] = "781edbe3-ebee-5cfd-b322-05814b558bfc", -- HUM_F_ARM_Magic_Monk_Pants [GLB]
        ["52372a10-326b-b2af-4b35-f5cc5919cb2e"] = "5200cf8f-ff09-535a-8375-c8a4e7bd4273", -- HUM_F_ARM_Magic_Monk_Pants_Scarf [GLB]
        ["49926d18-9968-fe7d-cd69-8d69b3888a58"] = "7c4548f9-850d-51ec-aa53-b1c6180003af", -- HUM_F_ARM_Mindflayer_Body_A [GLB]
        ["beae81d8-4251-f077-4463-0cf6e541f71f"] = "563fbeff-151e-515d-9bee-249a24e8da1b", -- HUM_F_ARM_Mindflayer_Pants_A [GLB]
        ["49551064-df2d-4baa-bf8d-48893db8af50"] = "441e930f-3210-51b0-910c-54e4f9f034c3", -- HUM_F_ARM_Mindflayer_Skirt_A [GLB]
        ["ff401e93-8d2f-4bb2-66f6-a1d879f38ad2"] = "44968c14-acf2-516b-964b-646e7a1f6152", -- HUM_F_ARM_Monk_A_Body [DAE]
        ["48a70a5d-f440-ab7d-f0a7-308d3a6d830f"] = "ab6bf660-786e-58b0-9050-44e6ac55fae3", -- HUM_F_ARM_Monk_A_Pants [GLB]
        ["7d323252-e866-db48-dff8-ba787efef763"] = "f9784b41-a071-58f2-bcac-0df2f5bf5df2", -- HUM_F_ARM_Myrkul_A_Body [GLB]
        ["a570519e-f495-8f55-108d-8f8a076b562a"] = "ba60389a-f6f8-54cd-b7c2-d93ce92cb3cb", -- HUM_F_ARM_Myrkul_A_Pants [GLB]
        ["adf969ed-6b7d-f4a9-c743-4856e552b246"] = "28eb125e-d3a0-5ef2-8ce2-191be3235682", -- HUM_F_ARM_Myrkul_B_Body [GLB]
        ["507bb7aa-294b-0e8c-ca3a-ca5bf52e5caf"] = "12e0a60c-66c5-5a0c-b0ca-f3b7d539aea7", -- HUM_F_ARM_Myrkul_Plate_Body_A [GLB]
        ["a5ad64ac-5d73-a959-60e5-22a13c19445c"] = "a0af98a9-e3ae-58fa-9e70-1db80ce3f478", -- HUM_F_ARM_Myrkul_Plate_Body_C [GLB]
        ["c7d97828-bd40-e39f-8f6b-ee87bb5de187"] = "c66b962d-ce91-5e97-ba6e-4f56f0ecb275", -- HUM_F_ARM_Myrkul_Plate_Body_D [GLB]
        ["5eddf203-8eb5-9db0-5eba-60c77f765c02"] = "dce0c044-718e-56e7-9901-34e6a4827acf", -- HUM_F_ARM_Myrkul_Plate_Pants_A [GLB]
        ["d2cbe9dd-1de9-541f-aa9e-03d32f1bd3d2"] = "9d4a37cb-ed73-59be-83cb-2d864dd8418b", -- HUM_F_ARM_NightsongPrison_Body [DAE]
        ["93399195-5282-44b9-9d98-bb288faedc52"] = "ea8d29bb-8837-5b49-95d6-091159486b12", -- HUM_F_ARM_NightsongPrison_Pants [GLB]
        ["4db1eff0-08f1-c83b-eb61-2e40c837f1e7"] = "367bfe5b-997a-5af8-810f-4b1e0376f69b", -- HUM_F_ARM_Nightsong_Body [GLB]
        ["8f81b249-93b0-cd99-c27c-3b6987232f19"] = "e9c7f291-6176-5a75-8d00-2e8f1db1e031", -- HUM_F_ARM_Orin_Body [GLB]
        ["a22984e8-b28c-46e9-5862-930af7b7b136"] = "887590e3-68eb-5709-a5a1-cde5bddbd311", -- HUM_F_ARM_Orin_Body_Player [GLB]
        ["092db3bc-9cbc-87aa-c21c-d0016f80bbc7"] = "76857970-1158-5c72-85e9-4c220b31b43e", -- HUM_F_ARM_Orin_Pants [GLB]
        ["f6d6d155-6390-a211-e86b-73a977b9738a"] = "35203893-ec25-50f3-bf51-a496a25a31c1", -- HUM_F_ARM_Orin_Pants_Player [GLB]
        ["113bae24-e267-5982-59ed-1454a41cce60"] = "60be11de-088e-5f0e-9cec-2816019ca87d", -- HUM_F_ARM_Padded_A_0_Body [GLB]
        ["9ea94d2f-f341-1cb4-a780-d9724474758d"] = "ab55e31e-c83b-5a6d-99c6-3116008dcc9c", -- HUM_F_ARM_Padded_A_0_Body_Broken [GLB]
        ["e4865cdc-10de-62ec-aedb-ac32b7973dee"] = "867bbe1e-58d9-5459-a0d7-92a7af407aaa", -- HUM_F_ARM_Padded_A_0_Pants_Broken [GLB]
        ["057b7784-3ae7-1c5a-e404-d502b6602bae"] = "e597b8d8-4936-544c-bfe7-d478335df6ce", -- HUM_F_ARM_Padded_A_1_Body [GLB]
        ["f9a9aa02-5ceb-1ff8-beac-5ff9a3243f41"] = "c03d9e8e-815f-54f3-8ff3-699868cab159", -- HUM_F_ARM_Padded_A_1_Body_B [GLB]
        ["6b3bf5e0-d886-8646-0623-2fcff33a3695"] = "08ddef90-0ad2-5178-8a92-6cb0fdad8f95", -- HUM_F_ARM_Padded_A_1_Body_Spring [GLB]
        ["74bb8dd6-2010-f90d-caa1-a172ad5c4a95"] = "2f4e949f-9fed-5c1c-9006-413a6639ff16", -- HUM_F_ARM_Padded_A_2_Body [GLB]
        ["29b64740-a9cf-d0f4-c536-0bd7b631e710"] = "e2acf6e3-bd1b-540b-8d25-44d0bd9d1d5f", -- HUM_F_ARM_Padded_A_2_Body_B [GLB]
        ["c80e582d-0f68-62a3-bc89-5738d2000319"] = "e17db53b-fa8f-5514-993a-4cf4babb25f4", -- HUM_F_ARM_Padded_A_Pants [GLB]
        ["e704163f-d9ea-6dbe-c897-b44b042f1769"] = "994fabfb-8e5d-5078-97c7-04033af8a924", -- HUM_F_ARM_PlateMail_A_0_Body [GLB]
        ["9b33ece1-b01d-74f8-7ef1-4183cd80220c"] = "c73085ee-183a-5771-93c8-fa91076e04fa", -- HUM_F_ARM_PlateMail_A_0_Skirt [GLB]
        ["a7cf3830-d44f-a31a-9e90-ffb00e718078"] = "862f85d4-43df-5a43-b7c2-d158a6a7ea00", -- HUM_F_ARM_Paladin_Oathbreaker_Platemail_Body [GLB]
        ["b457d115-a6f7-7f10-f674-7eea94896eb9"] = "7c42dabd-3a23-50a7-9c72-c4fcd553789d", -- HUM_F_ARM_PlateMail_A_1_Body [GLB]
        ["5f58f18f-ec6b-10c3-8462-0603dca6e573"] = "cb7c98cb-be66-544e-aeb0-a9dd256aa7ea", -- HUM_F_ARM_PlateMail_A_1_Skirt [GLB]
        ["f8c8854d-1f75-7595-932f-5bcc78051351"] = "676905cd-a6ea-5acd-8726-db3459939ac0", -- HUM_F_ARM_Paladin_Oathbreaker_Platemail_Skirt [GLB]
        ["04a5084e-efe5-f61d-5a28-577b059cbaaf"] = "0d287110-8804-560d-826d-f284242d4b8d", -- HUM_F_ARM_PlateMail_A_2_Body [GLB]
        ["153fafa5-944d-9f49-c1ac-bc96ebc81383"] = "141a5166-9f4f-57d6-a142-43fd206492af", -- HUM_F_ARM_PlateMail_A_2_Skirt [GLB]
        ["4961b222-0434-2ce6-8cbd-67c36c2f9896"] = "5c70cacb-b420-5c84-97c4-3cb12ccdf618", -- HUM_F_ARM_Paladin_Oathbreaker_Platemail_Pants [GLB]
        ["94a4cbf4-39d7-5e7d-5429-bf6530cbb7b4"] = "70a75a70-8ed0-514b-87cb-5ab08447b8e9", -- HUM_F_ARM_PlateMail_A_Pants [GLB]
        ["92c2ecdc-30be-dde9-ed3f-0bf056394331"] = "eeeae181-bdc4-5f4c-be10-738c3fbd34b5", -- HUM_F_ARM_Platemail_B_Body [GLB]
        ["11c721c2-e56f-ddd0-24f1-684ccceeee0a"] = "3c7c58f5-7d3d-5caf-8847-c735a9ef3755", -- HUM_F_ARM_Ravengard_A_Body [GLB]
        ["006159ea-8880-6589-52ef-313fc228ee26"] = "2536f344-f4fb-50bf-a187-91cf77b34af2", -- HUM_F_ARM_RingMail_A_0_Body [DAE]
        ["f8f01df9-1fd5-f92d-a62d-432da17ba1a6"] = "3af2f765-c09b-5d02-a97b-33aa7d174824", -- HUM_F_ARM_RingMail_A_0_Skirt [GLB]
        ["d3482469-a43e-8de3-88f2-e5a8907c95d6"] = "81434bb8-1567-551e-a22b-1e416f5e752e", -- HUM_F_ARM_RingMail_A_1_Body [GLB]
        ["e86250ad-54b5-29a0-1383-321dfd77115c"] = "a4078acd-386b-5b5f-916a-8852fd3df985", -- HUM_F_ARM_RingMail_A_1_Skirt [GLB]
        ["9f06b0f7-1d68-85f0-3b4c-276fab55a1f9"] = "e524ed3b-be45-5529-97de-1b4756ec2f22", -- HUM_F_ARM_RingMail_A_2_Body [DAE]
        ["571adfc4-0033-449a-9be6-9602bdd35d04"] = "23124b9b-a65a-58a6-becf-7ed92096bf15", -- HUM_F_ARM_RingMail_A_2_Skirt [GLB]
        ["9f847c1c-25bc-5417-942e-c78986e5071c"] = "5d38d93b-40b7-5538-b428-24e33647eaf0", -- HUM_F_ARM_RingMail_A_Pants [GLB]
        ["5b4c8f52-5336-6b43-96bf-7ae2cde81e1c"] = "e661e50e-3eb3-53da-bea8-fb6eeea0ac35", -- HUM_F_ARM_RingMail_B_Body [DAE]
        ["ad28b80d-799e-60f3-ecd8-8c8d64fdb28e"] = "9ed2642b-fb82-566c-b47a-ff1bb63e9525", -- HUM_F_ARM_RingMail_B_Pants [GLB]
        ["a0e71abf-5235-6bbd-a52b-f1e898b7dfab"] = "e70f34a1-e6fc-5ba2-aa85-0affa5414e93", -- HUM_F_ARM_RingMail_B_Skirt [GLB]
        ["d27d9b6e-fa2f-34f1-c17a-94eb2b63a087"] = "5e521f01-c759-5f1a-8b2a-766ed476afa6", -- HUM_F_ARM_RingMail_C_Skirt [GLB]
        ["095be887-6b9d-c7c4-ea62-4ab6d0b513d6"] = "e81acdcf-e299-5409-80a3-84d98d268472", -- HUM_F_ARM_Robe_Fire_A_Body [GLB]
        ["2c5d9266-8a99-7143-754c-fc2b57422c01"] = "abf91b33-bb6d-5a50-b831-506bb657445b", -- HUM_F_ARM_Robe_A_1_Body [GLB]
        ["78b1b1b1-1bba-0a46-8577-72c74903575d"] = "cff003bf-c5f1-5fa6-80b5-b928b874d8ba", -- HUM_F_ARM_Robe_Frost_A_Body [GLB]
        ["eecab0b0-f7bf-77c4-761f-c07325ea0c43"] = "07c87c44-f2e9-5f73-868a-a7bae2fc6238", -- HUM_F_ARM_Robe_A_Body_Satin [GLB]
        ["69649acf-f219-d2b9-8cba-d044263f00bb"] = "de65e29d-2472-5974-abe0-e9163648d643", -- HUM_F_ARM_Robe_A_CloseQuarter [GLB]
        ["4084d9c1-de9e-bb68-f0bc-0395ad80357b"] = "a4357a32-8224-57bf-a671-be73e751ad52", -- HUM_F_ARM_Robe_A_Body [GLB]
        ["c4347cae-8638-4f27-d847-d848a587869f"] = "2fad750f-f19c-581c-8ced-e3c25ce0bf62", -- HUM_F_ARM_Robe_B_2_Body [GLB]
        ["fb2968d6-a8a5-571a-f803-8b91a2cd5346"] = "c2bd0061-1d42-514b-98b2-c531913fb69a", -- HUM_F_ARM_Robe_B_Body [GLB]
        ["11749113-6fe4-1593-6981-be73277484a8"] = "ec391a49-8469-58e7-bcbd-c9c9909bb1d6", -- HUM_F_ARM_Robe_B_Wizard_Body [GLB]
        ["324ccffb-b76c-ddf9-c133-058cbab4a5de"] = "f270c03c-c304-5b35-9f22-ca755c68cc54", -- HUM_F_ARM_Robe_B_Undead_Body [GLB]
        ["2482f256-6050-4e01-2620-05c9525297aa"] = "79639f2f-9868-53cd-bde2-1a7abb482965", -- HUM_F_ARM_Robe_C_0_Body [GLB]
        ["26ff5e8a-4077-c579-c3ef-e1304554b3e1"] = "dc845ec1-0547-50a5-92b3-e60185a7df07", -- HUM_F_ARM_Robe_C_1_Body [GLB]
        ["55b92629-3026-3563-b3b5-df3d033efcb3"] = "3e6f7963-3608-5647-9936-f90b92a27b33", -- HUM_F_ARM_Robe_C_2_Body [GLB]
        ["04741d75-66f6-e766-18a8-2c07f326ca13"] = "30f6f9f7-d2a7-5528-af8a-fbc3a782c6ba", -- HUM_F_ARM_Robe_C_3_Body [GLB]
        ["25a13ce8-126b-e0b8-44b4-133b2cfeeaf1"] = "5187eaa7-8173-5366-9d31-b00925ed769d", -- HUM_F_ARM_Robe_SpellResistance_Body [GLB]
        ["0aabb3a8-eed7-b19b-24da-5e9d82b266fd"] = "9ea7a630-322c-5926-ae4f-30f0ad664cd0", -- HUM_F_ARM_Robe_D_Body [GLB]
        ["66dab175-f470-b1d7-60a8-1fe553f12ea7"] = "6efde1f0-64ba-5b31-bb25-305ad55890c3", -- HUM_F_ARM_Robe_E_Body [GLB]
        ["c9ed14a2-99f2-57c9-9542-c2867dec37ef"] = "892696a7-3346-5c3f-bc96-ee5a30c21e3e", -- HUM_F_ARM_Robe_E_SpiderQueen_Body [GLB]
        ["7831d6c6-8324-1d9f-6909-96165a057ec4"] = "46500973-c9aa-5dbf-ab4d-d865eab778f3", -- HUM_F_ARM_Robe_EndGame_A_Body [GLB]
        ["ff43d550-a7af-63a1-dd6e-731e525376e0"] = "a8a7b699-3e93-5bd7-aa55-b7c3143e45ff", -- HUM_F_ARM_Robe_Lorroakan_A_Body [GLB]
        ["96dab08a-eb0c-2ffe-6c36-7566ab78e346"] = "8e09dcee-31f5-5370-a8b8-9d7eefbfed92", -- HUM_F_ARM_Robe_Lorroakan_Body [GLB]
        ["1ae5d16d-de79-6e1d-331f-c11d75dbbaf5"] = "0a8de154-f387-5ba4-a4ba-9d92d1e5cdd1", -- HUM_F_ARM_Robe_Shar_Body_A [GLB]
        ["338fcd6b-71c1-a991-26a2-db02dee1a5af"] = "0119498f-4cc1-5d66-bb74-a7a0738367cb", -- HUM_F_ARM_Robe_Shar_Body_Viconia [GLB]
        ["cd5de58b-6dd3-55c6-748e-ad71cad54c39"] = "ee1a0bb7-ec07-52bd-8055-22bfec014ed3", -- HUM_F_ARM_Robe_Shar_Body_B [GLB]
        ["b6811b31-25f6-c4bc-5e93-ec0ab37a1677"] = "e2fd10e3-6f83-537e-b131-f9387a1b858f", -- HUM_F_ARM_Robe_Shar_Pants_A [GLB]
        ["209f6f56-54f8-d4e9-35af-70867c839c67"] = "f5a2ae36-980e-5545-82d4-5b7c49e89c0f", -- HUM_F_CLT_Camp_Shar_Pant [GLB]
        ["958458e2-45af-5996-a365-25d258c17a2b"] = "56bfdd59-b2d0-541a-ab8f-0a023242cabf", -- HUM_F_ARM_Camp_Citizen_Pants_B [GLB]
        ["f0c533e2-e10f-5fea-a143-065df33e6fa1"] = "d1acb01d-453d-53c9-8579-e5176590a7e4", -- HUM_F_ARM_Robe_Shar_Pants_B [GLB]
        ["f62dfa70-6b63-feb1-3bae-059a77ded1ff"] = "f366eab3-6681-52ca-a6e7-60070ccf4ada", -- HUM_F_ARM_Robe_Shar_Skirt [GLB]
        ["0fe2e1a1-da35-e2e8-5c87-d2ad15e24208"] = "c4ce77f4-7af4-571f-bfa8-7c4600375189", -- HUM_F_ARM_Robe_Umberlee_A_Body [GLB]
        ["b74bc9d1-2c02-7bc1-97e2-ba6b66d91db6"] = "037a26b2-c566-51ac-ad84-914c3aa5dd44", -- HUM_F_ARM_Robe_Umberlee_A_Body_B [GLB]
        ["e3a982a7-113d-e13f-deef-97625f44d46a"] = "23a7698f-f709-5c72-9dfa-ac151b10fec1", -- HUM_F_ARM_Robe_Umberlee_A_Pants [GLB]
        ["2321fb4f-010e-495d-18c0-c2facb6f6241"] = "90a881d9-a2d6-53df-b08c-a5b0b2ba27fe", -- HUM_F_ARM_Robe_Umberlee_B_Body [GLB]
        ["0fdaf2c1-cf92-f263-0048-56e93238a5cc"] = "9f5352e9-52dd-5105-8110-fe03003b3af5", -- HUM_F_ARM_Scalemail_A_0_Body [GLB]
        ["a6e89a85-dca1-816e-265d-eed5c5a54b96"] = "425c028d-1b12-55ce-99c3-9751ccb3ce3e", -- HUM_F_ARM_Scalemail_A_1_Body [GLB]
        ["9d613fa9-9188-e036-5470-d590d3aca811"] = "eefbeab9-670f-5850-b783-062d367168a2", -- HUM_F_ARM_Scalemail_A_2_Body [GLB]
        ["4bdb8690-5acb-95da-abae-6b41a9fd4aa4"] = "7d4bf27c-feaf-5add-a100-b4a536ae66d1", -- HUM_F_ARM_Scalemail_A_Pants_A [GLB]
        ["3fb3ab1c-786d-c5e0-f31f-8104cc8e377b"] = "d3fd6b62-73a7-5c1a-afdb-a6682f7c0895", -- HUM_F_ARM_Scalemail_A_Pants_B [GLB]
        ["fe430473-6b87-a1e5-2f39-085b1942542f"] = "0f92fd43-c1f6-5682-a1be-75d39582f410", -- HUM_F_ARM_Scalemail_Adamantine_A_Body [GLB]
        ["623d949f-6b7d-05ba-d20f-c7633495eb24"] = "ac6658eb-1c54-5d4a-b995-372bd36243a5", -- HUM_F_ARM_Scalemail_Adamantine_A_Pants [GLB]
        ["370b0a8d-ee6d-93aa-aca6-9ea018bbb4a7"] = "66aeade9-aedf-5cc0-8b46-e1996e51ee35", -- HUM_F_ARM_Scalemail_B_0_Body [GLB]
        ["17a8d09a-f6df-0187-aac6-be01f0089f65"] = "3946cb5d-68ef-5051-aead-2b86e7f52dc5", -- HUM_F_ARM_Scalemail_Paladin_OathOfDevotion_Body [GLB]
        ["fb901e95-3101-ff63-a628-e6d95c0a62e4"] = "89ac4b14-8949-5241-bf6d-6b7399aa6352", -- HUM_F_ARM_Scalemail_Paladin_OathOfAncients_Body [GLB]
        ["97d65c4c-d6fa-bd7d-1a15-ca63a4bb1831"] = "fbdc59b5-4e1a-5b25-be8f-07375d8b2fc5", -- HUM_F_ARM_Scalemail_Paladin_OathOfVengeance_Body [GLB]
        ["d7196f12-bfcb-84d7-b96d-088284ef2a7f"] = "752807d0-d9a3-5428-843d-2283a3330a01", -- HUM_F_ARM_Scalemail_Paladin_OathOfCrown_Body [GLB]
        ["433b08ba-302c-2edf-1064-d0aae20eaf35"] = "58e54e1c-ffde-54b3-b9b8-edfa8f7ccf6b", -- HUM_F_ARM_Society_Of_Brilliance_A_Body [GLB]
        ["12ae1e17-9cc8-6c8c-cf35-ff4a3bb0ecc0"] = "559416db-64d0-5c46-abbb-1efd5ab1a942", -- HUM_F_ARM_Splint_A_0_Body [GLB]
        ["e5eb5555-364d-16af-caea-8dd79c0d8945"] = "effa2c80-76ac-575d-9e29-d704d2a128d1", -- HUM_F_ARM_Splint_A_1_Body [GLB]
        ["789678af-6c03-8bf5-f3df-afef3cb52dd4"] = "305a5303-ebb8-5078-b8f8-7f6301f2fd4d", -- HUM_F_ARM_Splint_A_1_Pants [GLB]
        ["53ab8b43-8c16-cfcf-a198-48c3dd856b48"] = "8d9492b9-066c-50dc-a373-010a6de9b08e", -- HUM_F_ARM_Splint_A_2_Body [GLB]
        ["e8185a07-77c6-6cbc-1ec6-ab4ee246fbe6"] = "d1f73331-1fa1-5348-889b-987e156345aa", -- HUM_F_ARM_Splint_A_2_Pants [GLB]
        ["ad128db4-9ce5-0a9b-d5a5-86692c87bcf2"] = "42025d9f-0886-5034-a7a5-0b9992879e72", -- HUM_F_ARM_Splint_Adamantine_Body [GLB]
        ["2141e5d9-dc21-ad0d-40dc-71e333819a26"] = "e4242da8-0c1b-5f58-8294-a70d12b200d1", -- HUM_F_ARM_Splint_Adamantine_Pants [GLB]
        ["bac9739c-6ed7-621c-fe61-009a44a7cf75"] = "4ae48ecd-951c-5c97-b460-47a457b6b3dc", -- HUM_F_ARM_StuddedLeather_A_0_Body [DAE]
        ["b3b87fc5-acda-80b8-2c26-9e797b99a7de"] = "95e570f3-c4d5-565f-bb90-35f0d440187a", -- HUM_F_ARM_StuddedLeather_A_0_Pants [GLB]
        ["9d67986d-21ae-401b-9837-ee4e003e1a5e"] = "37ee7722-491a-54c5-a7f4-e1677a6fa730", -- HUM_F_ARM_StuddedLeather_A_1_Body [GLB]
        ["da8139a1-a58f-e2a1-62a4-bcf3bf409080"] = "de2fe2ef-b745-543d-adcf-25ea348996a2", -- HUM_F_ARM_StuddedLeather_A_1_Pants [GLB]
        ["eafe8199-bd10-0dca-ba1f-66b34fd1e363"] = "0d46e5df-e111-5fc0-a994-acecf986f8b5", -- HUM_F_ARM_StuddedLeather_A_2_Pants [GLB]
        ["e8b7426f-669d-a781-9f3d-d006ffb031ac"] = "af07616b-0e35-5ff7-a7f8-499b9a0a9331", -- HUM_F_ARM_StuddedLeather_A_2_Body [GLB]
        ["d3151f1b-56af-bb04-6bba-c4c9b48104f8"] = "a5172fd7-4448-5faf-8556-c3166804903d", -- HUM_F_ARM_StuddedLeather_B_Body [GLB]
        ["d6d2f87a-e8dc-0102-7cd3-61d0922efff2"] = "7d2ecda8-3604-5303-9719-aacda7b77603", -- HUM_F_ARM_StuddedLeather_C_Body [GLB]
        ["c403d4ba-9b22-ce02-7f87-71ea1628fb65"] = "a9084a33-e60a-5bab-9c86-2109d6c604d9", -- HUM_F_ARM_StuddedLeather_Minsc_Body_A [GLB]
        ["1f0df787-f318-50ee-1ba3-db54078b310e"] = "5fa211eb-b870-58f8-a247-81f84446b293", -- HUM_F_CLT_Alfira_Skirt [DAE]
        ["a8f45b55-911e-a40a-e501-02022bb63a41"] = "6a6526d6-c04f-55c2-bdb3-1b922d5aaec9", -- HUM_F_CLT_Bard_Body_A_1 [GLB]
        ["d6bafee0-4aee-5322-8a49-84179673cd96"] = "d19339e0-d257-5493-a1a3-6a70a22e44b9", -- HUM_F_CLT_Bard_Body_A [GLB]
        ["7f3ec09b-8ade-1772-8fc5-822a43e4e991"] = "4ff3a72a-de45-5940-8c06-13e1741c5489", -- HUM_F_CLT_Bard_Pants_A [GLB]
        ["befe91a5-3a8a-e604-ae8d-d4413759b38c"] = "b7b864c9-c54e-5b46-a47b-49f9d7404924", -- HUM_F_CLT_Bard_Pants_A_1 [GLB]
        ["ee42f623-c004-c1aa-dab1-7d86e8178895"] = "54fade7f-892e-5170-b741-f6637c2a3a80", -- HUM_F_CLT_Bard_Skirt_A [DAE]
        ["0f4c63b4-df59-c729-156f-08cc9a3c8a00"] = "6d4b97d0-47d0-50d3-a6fd-2e78bffc4344", -- HUM_F_CLT_Blacksmith_Body [GLB]
        ["27d62490-3434-1ccc-35c8-59a8c73ad2ad"] = "8a522850-5cc0-58b3-872b-402506c64d93", -- HUM_F_CLT_Blacksmith_Pants [GLB]
        ["dc75dded-74b2-1b63-5ed4-8cfaacbaf80a"] = "8e2c7dff-31d1-53a2-a3b3-64bd5d1ba109", -- HUM_F_CLT_Camp_Deva_A_Body_A [GLB]
        ["435d32fc-9994-9f17-aa79-f76cb3ae300a"] = "78507ca2-3f03-5550-be8c-fba0c878b7d4", -- HUM_F_CLT_Camp_Halsin_Body [GLB]
        ["888a24d5-650d-d4a4-be6e-7b48828e69c4"] = "3139d355-3cb2-5c04-b364-a319d4af2e89", -- HUM_F_CLT_Camp_Jaheira_Body_A [GLB]
        ["dd7e1cf2-fab0-ca8f-980b-4e439ae31c9f"] = "a66f36df-e3a7-5840-8afc-137e414d4d94", -- HUM_F_CLT_Camp_Jaheira_Pants_A [GLB]
        ["dcd947da-9f4b-ab17-7112-c0c95a4dacfb"] = "2c7446e0-83f9-5432-98f2-caa0ca99ffd3", -- HUM_F_CLT_Camp_Karlach_A_Pants [GLB]
        ["611146cb-b98b-9ed1-78ee-1c24feee45d1"] = "c861b041-0861-55ec-ac45-43cca1c2cc90", -- HUM_F_CLT_Camp_Minsc_Body [GLB]
        ["0fc38c91-a4a2-d9b6-da09-c1d55ab9a6b3"] = "f10de21b-4593-59d4-ba31-d7d15101183a", -- HUM_F_CLT_Camp_Minsc_Body_Ragged [GLB]
        ["2c25ec83-c34c-2e15-d4ff-5cf35b0bb655"] = "d4ba3a30-5271-543a-9ee6-19b94cf9072e", -- HUM_F_CLT_Camp_Minsc_Pants_A [GLB]
        ["a85bb322-f3ee-fec9-06d7-cd3d8aacd25d"] = "2f59af8f-9b90-574d-9524-c2c807c76077", -- HUM_F_CLT_Camp_Minsc_Pants_B [GLB]
        ["26ff17f0-8620-8c71-02b5-70c7977065d8"] = "4b71cc75-4db0-56fe-91a8-1c1ab39363f8", -- HUM_F_CLT_Camp_Outfit_Astarion_Body [GLB]
        ["372f4870-d222-39b7-a801-4d226551175c"] = "dde5f1c0-4853-592c-a958-f30c6f825be9", -- HUM_F_CLT_Camp_Outfit_Laezel_Pants [GLB]
        ["99e0150f-659c-a90c-253a-b8529fdf2717"] = "61b79d29-9855-5702-a662-385ef0fa0beb", -- HUM_F_CLT_Camp_Shar_Body [GLB]
        ["2156b7db-04a6-ce24-559e-67bec253f4b5"] = "edede835-020a-5bd1-9fae-5d5dd986093d", -- HUM_F_CLT_Circus_Pants_C [DAE]
        ["0ccd9020-100d-5c2e-5dec-e1d279d906bb"] = "bd1c4e4e-cc5a-58f1-ae2a-478d30522716", -- HUM_F_CLT_Circus_Pants_D [GLB]
        ["d1774c69-1642-40df-f5f6-f027dec0f5f2"] = "de76718a-3ff5-53af-97cb-6ba735bc2eb6", -- HUM_F_CLT_Circus_Pants_E [GLB]
        ["db5197fa-3e0c-90cb-b023-6a3f969eba2b"] = "6f28dacd-d902-5311-8d72-723aa4cfdd64", -- HUM_F_CLT_Corset_A [GLB]
        ["4093b106-0202-8695-3930-c8ef8abc2256"] = "79e758b3-f20d-5bee-99fd-0c4a5adf9935", -- HUM_F_CLT_Corset_C [GLB]
        ["406bdd29-ef4e-c58a-bc1d-10863f1f5acc"] = "a00d35e6-2dd0-5254-aabe-17119ed0b0f6", -- HUM_F_CLT_Corset_Courtesan_A [GLB]
        ["015d97e7-0cb8-6744-039f-e4f4f4fc828d"] = "9b758bdd-ae77-5960-b6ea-246769405c69", -- HUM_F_CLT_Daisy_Dress_Gale_God [DAE]
        ["61782326-731c-e242-105b-bb81f9ba719e"] = "7f0426cd-256d-54f0-a0db-0d0416d4be06", -- HUM_F_CLT_Daisy_Dress_A [DAE]
        ["b7240d70-2bad-4d2f-3796-26686410a339"] = "5cdf106f-9cf4-5419-af69-a2066bc1f371", -- HUM_F_CLT_Daisy_Dress_White_A [DAE]
        ["ff62821d-7630-0787-6d2f-0434ff48f27b"] = "a93aebaa-fa75-57b4-8adc-6ffec2466ad4", -- HUM_F_CLT_Daisy_Dress_A_Accessories [GLB]
        ["27748f4d-ad84-964d-34b4-e46ff3257a4d"] = "13d1da35-5e38-5d37-b8bb-df94a71f087f", -- HUM_F_CLT_Daisy_Dress_Accessories_Gale_God [GLB]
        ["941d5ebe-0409-fef6-28e1-d90ef3a31b52"] = "8d4bd662-2a91-5961-825a-ddcde1cfbd94", -- HUM_F_CLT_Daisy_Dress_Cape_Gale_God [GLB]
        ["b7c9aec9-bbe2-340a-82ad-a0fdc0394c82"] = "2d4c1716-a632-5fc7-bc46-2ffafa423fbb", -- HUM_F_CLT_Daisy_Dress_Cape [GLB]
        ["870ca9d0-b98a-e0fe-6c45-6286c7b8cbea"] = "3b5004a1-303d-5643-9203-a7950b070e01", -- HUM_F_CLT_Doublet_Rich_C_Body [DAE]
        ["bdbb424a-131c-1a30-ce25-4584c7fd153e"] = "87286b69-18af-5ad7-bd74-9080f3e19652", -- HUM_F_CLT_Doublet_Rich_C_Body_1 [DAE]
        ["30627639-4730-ab00-6160-3ec475cd35a9"] = "b7731fc7-5d1d-5b76-bd96-31a0be9a8789", -- HUM_F_CLT_Doublet_Rich_C_Skirt_A [GLB]
        ["458f51b4-07b3-0678-8879-75ed4f79fc78"] = "4918939f-a44a-5690-8eeb-d70d9823ecdd", -- HUM_F_CLT_Doublet_Rich_C_Skirt_A_1 [GLB]
        ["d0e176ae-0389-66ac-5eda-3120e92752f8"] = "33799390-e2ce-555e-97c4-7951f19228b2", -- HUM_F_CLT_Doublet_Rich_C_Skirt_B_1 [GLB]
        ["e241a911-80fd-a32b-58e9-be4194873eaf"] = "c7c6b3bf-57ab-5929-85fa-e3347d45dbf9", -- HUM_F_CLT_Doublet_Rich_C_Skirt_B [GLB]
        ["0461fcfa-910d-18a9-a1b3-b5b32eb4243c"] = "052bfd88-8752-54ca-a933-a535ef15feb1", -- HUM_F_CLT_Drow_Body_A [GLB]
        ["feea0381-4abd-9c88-139a-fbdff203761c"] = "4a5e4ffc-945f-5631-9b1a-21b8f8afac1d", -- HUM_F_CLT_Drow_Body_B [GLB]
        ["1ecc06a0-cc2f-a841-8ed3-ac5b7b90350a"] = "7eab09eb-10c5-5a95-a88a-2efb9eb83a66", -- HUM_F_CLT_Humans_Pants_A [GLB]
        ["7b247806-5fe3-8fa7-2733-d0d2486e55e0"] = "f9cfd010-5b6c-5b4d-9ba2-1f8a619bf82d", -- HUM_F_CLT_Humans_Pants_A2 [GLB]
        ["3c3c6f48-c2b0-17f5-0f96-fade875b8b03"] = "1928a16c-8560-55d5-b542-0be82ed16ae1", -- HUM_F_CLT_MiddleClass_Body_A_0 [GLB]
        ["b6a9e089-b4d1-58a7-59a7-21a63ec1e3dc"] = "4e3c72cb-3cf4-5735-a3a4-c6d56bce5669", -- HUM_F_CLT_MiddleClass_Body_A_1 [GLB]
        ["d94b896f-5e09-f0aa-c158-1496fa2cd809"] = "ec20c1ed-93ec-53c8-862d-20820736c8d1", -- HUM_F_CLT_MiddleClass_Body_A_2 [GLB]
        ["988f7d2e-a2f9-0be5-70d6-8e2852fb565e"] = "6c700454-74ae-5f6a-9156-5d0fa7be4396", -- HUM_F_CLT_MiddleClass_Body_B [GLB]
        ["f0fa5d54-87bc-cd18-fb3f-52559917ab28"] = "bd85827e-6e7a-50c7-a46f-f73a1fe189df", -- HUM_F_CLT_EPI_MiddleClass_Body_B [GLB]
        ["6ab2470f-4430-f08e-c20d-1b44a1671d71"] = "7dcd0a61-8e80-5aac-a267-12ebdb8493de", -- HUM_F_CLT_MiddleClass_Body_C [GLB]
        ["5299aedc-02ac-40cb-906b-c2144e3543e8"] = "5f23f3de-46a3-56e7-968d-56c3de034d1c", -- HUM_F_CLT_Mizora_Body_A [GLB]
        ["056e67fb-7722-4e59-9e1c-b75180177509"] = "3948ad6b-2ecb-56a2-8d6e-2586c4f92bce", -- HUM_F_CLT_Nymph_Dress [DAE]
        ["b0cde6e3-83bb-62e3-4c9b-c0ee256fc951"] = "4c4f4500-d883-5008-adef-374f25071d61", -- HUM_F_CLT_Pants_A [GLB]
        ["037f2658-0f94-a1f3-6162-3ab3ef46ef9f"] = "5d946f74-ca94-53bc-bb1a-1c16e843052f", -- HUM_F_CLT_Pants_Torn_A [GLB]
        ["437ba6c8-16f3-a51d-d33f-496b886e7377"] = "5d491268-31a1-5035-8cca-d3c72fcd2c5b", -- HUM_F_CLT_Pants_B [GLB]
        ["9ac53050-ed2f-32e2-361f-2ac4a849247c"] = "1550eca2-eea1-5f3f-b52b-977cb43c6ad1", -- HUM_F_CLT_Pants_C [GLB]
        ["814be387-c446-a05e-1ab8-c1a22bfbfb88"] = "ff16f868-b3ba-59a5-b946-bfcd8d19dc27", -- HUM_F_CLT_Pants_Torn_C [GLB]
        ["6ac9cad5-111e-33ff-3eda-ecffc3f8977d"] = "952acbd8-faba-57f4-87e3-f54e4faff375", -- HUM_F_CLT_Pants_Courtesan_A [GLB]
        ["2d0f8f38-2383-125f-eb37-02d0916958d1"] = "d078d901-d7a5-5623-8982-0d51ad3bea52", -- HUM_F_CLT_Pants_D [GLB]
        ["8dbbdbea-3435-d58f-00e5-ffc390e1f1d8"] = "aaa39f01-2cd1-5031-9297-239b75a5ca33", -- HUM_F_CLT_Pants_E [GLB]
        ["ac0d8966-439e-890c-c363-4cc3a06673a8"] = "1e55b1bb-9444-580a-9159-55f14da9447c", -- HUM_F_CLT_Pants_F [GLB]
        ["ddded88b-7eae-8063-c28b-29747f85b921"] = "5e980e4e-aab1-5d79-84fe-58bc597b309b", -- HUM_F_CLT_Pants_G [GLB]
        ["073bcd0e-0fca-bc1a-6abc-2cb9f94d8ec6"] = "1493d0dc-f366-5857-8657-20ba3ae1dfa7", -- HUM_F_CLT_Pants_Torn_G [GLB]
        ["680e2bc4-eb37-2dbd-955e-ae510a4e1743"] = "ae18f025-ffbe-5718-8541-a4e91cdcdf87", -- HUM_F_CLT_Pants_H_Twitch [GLB]
        ["9c9e4cb9-e1b2-ebce-e984-4324f4c9b69c"] = "e5fe9250-a81d-59c2-a269-3f4752cc8bb6", -- HUM_F_CLT_Pants_H [GLB]
        ["8f8751f9-bb4d-6e95-1883-567ef89578aa"] = "6eab178d-6fd1-5081-b59d-5b6749ca49d9", -- HUM_F_CLT_Pants_H_Short [GLB]
        ["9bb0a1f0-3db4-314e-5725-d1c7f3e30557"] = "5b20a009-6b0f-5917-9a85-fb03a933dbe2", -- HUM_F_CLT_Refugees_Corset_A [GLB]
        ["410a4505-7032-e0f3-3825-96e5bca7352c"] = "85cc05ae-9616-53bf-a724-e196b9b6c834", -- HUM_F_CLT_Refugees_Corset_B [GLB]
        ["38ab17d2-15d3-252f-d0ec-3866011c31cc"] = "52d6a0ef-614e-5892-a86f-e17b0a944ef3", -- HUM_F_CLT_Refugees_Pants [GLB]
        ["93d267af-f36e-8383-5d22-4b95bf38f321"] = "75a111f2-c206-5f9b-aa09-7f0d00aa05b6", -- HUM_F_CLT_Refugees_Pants_Torn [GLB]
        ["4d196657-a569-7e5e-b883-adb32bf7c17a"] = "62a166df-fe79-5e02-87d9-91fda1508633", -- HUM_F_CLT_Refugees_Skirt_A [GLB]
        ["ac711a8a-3264-13f8-3d4f-39cc454ec168"] = "a02f75ad-1024-5401-8820-1857e0e28128", -- HUM_F_CLT_Refugees_Skirt_B [GLB]
        ["c129ed42-df0f-1f7b-098a-d9e5b425b7b7"] = "b83266d3-f876-5e4c-bfa8-9d698eb957b0", -- HUM_F_CLT_Refugees_Skirt_C [GLB]
        ["7dccd203-9d87-f011-b48b-095c94a802c7"] = "aca0f2d2-c146-5c99-a146-df4e29d402c4", -- HUM_F_CLT_Rich_F_Body [GLB]
        ["997602e8-8406-46d1-5bb3-800c5478a46b"] = "8c1ce5a2-7a1d-52e9-9f5c-40ba60d29138", -- HUM_F_CLT_Rich_D_Body [GLB]
        ["d68214cf-e2bf-f120-9ef3-1f850a9246b5"] = "3ef6f439-5515-5182-9d1a-c0ebf58a6421", -- HUM_F_CLT_Rich_E_Body [GLB]
        ["025db7fc-0c5b-5072-e988-9880c7010a7f"] = "7f2e7d09-566d-5bc9-827e-53ce00e539d4", -- HUM_F_CLT_Rich_D_Pants [GLB]
        ["e2e0e9e3-8082-07aa-0284-930015839327"] = "68e4a96b-1d3f-5212-b0d0-53941b75188d", -- HUM_F_CLT_Rich_F_Pants [GLB]
        ["d3c152cc-56e3-4561-4321-518f6f21546c"] = "408fd683-915d-5455-8459-da6eab56aff6", -- HUM_F_CLT_Rich_Dress_A_Body [DAE]
        ["15d6efbf-1aae-0dcd-bcfc-834a86c9e011"] = "4b9b5942-549e-55f4-b875-dc6365c0347d", -- HUM_F_CLT_Rich_Dress_A_Body_2 [DAE]
        ["c92f9f3c-712f-8c7f-6a0d-4d4516fd0737"] = "5f77ed51-6f9d-5252-a893-2b2949eacd09", -- HUM_F_CLT_Rich_Dress_A_Body_3 [DAE]
        ["b1ac04ac-8d6e-8733-889e-52278f7bd5ef"] = "893beef1-e7ca-5f61-bd7a-d6827bdd1454", -- HUM_F_CLT_Rich_Dress_B [GLB]
        ["b925d640-eb8e-9ef6-7561-2c1db074df4f"] = "2064d187-4be0-57fe-9631-64b1c227090c", -- HUM_F_CLT_Rich_Dress_B_Accessories [DAE]
        ["4aa3396b-85b4-ccfc-055d-c45a2b9ffcb8"] = "fbe8a695-9266-5bd4-8184-3c043ed5048c", -- HUM_F_CLT_Rich_Dress_B_Shirt [GLB]
        ["a1fc20ac-2abc-8f45-6435-f6f7b98f4a19"] = "470cd8e0-d602-595b-9c76-48fe2b916a6c", -- HUM_F_CLT_Rich_Pants_A [GLB]
        ["e84b91c8-6d62-d46f-8a1a-0b87191f62dc"] = "a9027c42-5069-5df0-8355-2d458b34d3c9", -- HUM_F_CLT_Rich_Shirt_A_Pants [GLB]
        ["927cfa94-1fb6-3a04-0db5-11195fb37ae3"] = "d4e5aa42-c51c-5398-8e55-12a49da09537", -- HUM_F_CLT_Circus_Pants_B [GLB]
        ["dab58757-2da5-f75c-5e35-396a5b4f3be4"] = "19907220-9177-5fe7-b31a-ff0da2ff73dc", -- HUM_F_CLT_Rich_Shirt_A_Body [GLB]
        ["5c046b60-41a2-28b2-eea3-7267b7ce52e5"] = "5f1d5e89-208d-5eb1-8132-09600473b583", -- HUM_F_CLT_Circus_Dress_A [GLB]
        ["8b02460a-147e-9e0a-02c6-4df064e68c09"] = "5535c674-e639-5db4-89b8-04db291b356a", -- HUM_F_CLT_Shirt_Courtesan_A_Corset_A [GLB]
        ["678cb240-d96f-5bbb-29ce-39d9d32de01f"] = "1997dd00-a953-50cf-8b7c-2723edb1bdbb", -- HUM_F_CLT_Shirt_Courtesan_A_Corset_B [GLB]
        ["d4badd19-dde6-ebb1-810f-8c7cf1c73a27"] = "197cc45a-18de-5ce3-93df-5b3142d99f3f", -- HUM_F_CLT_Shirt_Courtesan_A_Corset_E [GLB]
        ["bf06fc6a-82f0-a561-d26b-9023042beacd"] = "b571548f-06b6-5808-9905-9086660d64be", -- HUM_F_CLT_Shirt_Courtesan_A_Corset_Twitch [GLB]
        ["f4cd5679-9a06-30ae-c8b5-97dcccf7896f"] = "017ae648-b284-57d1-add3-df7e51e1af9e", -- HUM_F_CLT_Shirt_D_Corset_B [GLB]
        ["f89199e3-6801-a4ef-32dc-11c1d7521ddf"] = "5b948e19-87c0-5ca7-8dd7-bef84823384a", -- HUM_F_CLT_Shirt_D_Corset_Alfira [GLB]
        ["f994d29a-7e3e-dbc2-e577-99b6869c413b"] = "c438a80c-980b-5c62-8c5a-40e9528fcca8", -- HUM_F_CLT_Shirt_H_Corset_B [GLB]
        ["c4f40a4a-5e87-eb9c-da5e-d268f1761083"] = "66b139d2-10aa-543a-8312-280330222456", -- HUM_F_CLT_Shirt_H_Corset_E [GLB]
        ["898a98d7-9100-d842-68e6-093d201ac6f8"] = "46d600bc-88b6-5815-b265-0ce1bf56b100", -- HUM_F_CLT_Skirt_A [GLB]
        ["ecf67d32-6eb7-b67d-a7bd-847367f24e8b"] = "dd200b2d-0546-5321-a4d3-28717815075c", -- HUM_F_CLT_Skirt_A_Spring [GLB]
        ["05986d42-16ec-c7b6-c1ed-0bd21d03df83"] = "e5995c07-22ef-5abd-8ce1-f8c43ac4db6c", -- HUM_F_CLT_Skirt_B [GLB]
        ["4018e880-fb09-b84c-85dd-f8701eee1bbb"] = "a60088fa-1b47-5d5d-b382-673cf073361e", -- HUM_F_CLT_Skirt_B_Mayrina [GLB]
        ["1039260c-c726-ed05-8785-6ead6bb7b3b0"] = "25fb1079-7d09-5d48-aa03-16b297ca9e84", -- HUM_F_CLT_Skirt_C [GLB]
        ["5e4726c4-048d-b195-9e9e-dd983d5016b0"] = "7fc0c04b-09a4-54ac-93d2-d8fcca283881", -- HUM_F_CLT_Skirt_Courtesan_A [GLB]
        ["13297b57-278a-4b8b-f469-859ebff773a7"] = "4a7d7d6b-60da-5305-8d54-1ad5b59fd44d", -- HUM_F_CLT_Skirt_Courtesan_B [GLB]
        ["c0968035-1291-f945-bd4b-3b0514e52bff"] = "a5f1af42-75ec-546e-be33-d3a6bf6fe79c", -- HUM_F_CLT_Torn_Body_A [GLB]
        ["11634ec6-d3fe-1a2b-5ffb-85dcda9a48f6"] = "c3818c44-992b-5cb7-acd6-553dfe43b673", -- HUM_F_CLT_Worker_Body [GLB]
        ["dda05feb-d0ab-4399-a0e7-34b5213bd4a3"] = "e8a19543-b53b-575e-84f7-9e40c2212c92", -- HUM_F_CLT_Worker_Pants [DAE]
        ["e073aabb-ce90-3e7a-a59f-79f36b40dfb6"] = "5f26207c-82de-54d7-b72b-6b16ef623906", -- HUM_F_Nurse_A_Legs_Bandages [GLB]
        ["89bc4da1-7904-faca-aadd-d30ee6e33ee1"] = "e48875a9-4af0-50e9-8474-3392b9dfbeb3", -- HUM_F_ARM_Nightsong_A_Body_OLD [GLB]
    },
}

-- ---------------------------------------------------------------------------
-- BCBPak PRESENCE GATE (2026-07-26, Alan's rule: "changes related to BCBPak
-- should be made ONLY if BCBPak is present; no other part of the mod affected").
--
-- GATED: the BASE entries of the `vanilla` subtable, and nothing else.
-- Those clean-vanilla clones exist for one reason -- BCBPak REDEFINES vanilla
-- VisualResource nodes IN PLACE (same GUID, SourceFile re-pointed at
-- Generated/Public/BCBPak/...). Our clones carry a fresh GUID and Larian's own
-- SourceFile, so they win and the user sees vanilla. With BCBPak ABSENT there is
-- nothing to defeat: the remap becomes a no-op that still substitutes our clone
-- GUIDs for Larian's and -- the real hazard -- would equally defeat ANY OTHER
-- mod that redefines the same VR node. The 77 class-1 additions widen that
-- surface onto common civilian clothes (Shirt_A-J, Tunic_A-D, Doublet_*,
-- Jacket_*, Camp_Shirt_A-E, Camp_Citizen_Shirt_B, Circus_*) -- exactly what
-- clothing replacers target.
-- (Corrected 2026-07-26: the count is 77, not 81 -- `refit_by_vr_class1.json`
-- "count": 77 and 77 V12_INCLUDE rows in CLASS1_vanilla_gap_2026-07-26.tsv.
-- "BASE_Vanity_Body" was named here in error: that string appears in NO source
-- file, roster, or bank in this build tree.
-- STATUS 2026-07-26 (later): class-1 was reverted, then RE-APPLIED after
-- !cm_visdump confirmed the defect in game -- vanilla mode, BCBPak installed,
-- VR 6682ffad-... resolving to Generated/Public/BCBPak/.../HUM_F_CLT_Camp_Shirt_A.GR2
-- while body and trousers tracked the mode correctly. The 77 are LIVE in the
-- `vanilla` subtable. This paragraph describes an ACTIVE set, and the gate below
-- is what keeps those clone GUIDs off non-BCBPak users.)
--
-- NOT GATED (1) -- `sbbf` / `bcb`. ClothMorph's OWN refits, shipped whole in base
-- Content. Verified 2026-07-26: [PAK]_ClothMorph_Refits and _Refits_BCB reference
-- only Generated/Public/ClothMorphContent; zero BCBPak vpaths. The BCB body SHAPE
-- is a base feature that must keep working for users who do not own BCBPak.
-- ("the BCB part" is ambiguous between the BCBPak ADD-ON and the BCB body MODE;
-- only the former depends on BCBPak.)
--
-- NOT GATED (2) -- vanilla entries merged at runtime by TryMergeExternal.
-- Caught by adversarial review 2026-07-26: ClothMorphSCO registers 129 `vanilla`
-- entries whose job is to escape **BCBScantily**'s in-place redefinitions
-- (ClothMorphSCO_Build_Report_2026-07-16.md:20). BCBScantily
-- (75934b95-f697-4d5b-890c-fe198b799484) is a DIFFERENT MOD from BCBPak
-- (1d24059d-...). A blanket `choice == "vanilla"` gate would disable SCO's
-- defence based on the presence of an unrelated mod. Hence BASE_VANILLA below:
-- the gate is keyed per-VR on the base key set snapshotted at load time, so
-- anything merged later passes through untouched. Any future add-on that needs
-- its own presence gate must implement it against ITS OWN source mod.
--
-- Degradation when gated off: the original VR passes through -- identical to the
-- existing F1 and OPTOUT contracts. Nothing is invisible; the shipped
-- [PAK]_ClothMorph_Refits_Vanilla bank simply goes unreferenced.
--
-- API: Ext.Mod.GetLoadOrder() verified populating in this BG3SE build
-- (2026-07-25 CMLO dump, _bcbfull_work\ACTIVE_MODLIST_SE_2026-07-25.tsv, 1,493
-- rows). Probed ONCE from the existing SessionLoaded handler; no new
-- subscription, no per-tick cost.
-- ---------------------------------------------------------------------------
M.BCBPAK_UUID = "1d24059d-ff23-4a79-8892-57c85d512416"

-- Snapshot of the BASE vanilla keys, taken now -- before any external mod can
-- merge into M.REFIT_BY_VR.vanilla. Only these are gateable.
local BASE_VANILLA = {}
for k in pairs(M.REFIT_BY_VR.vanilla or {}) do BASE_VANILLA[tostring(k):lower()] = true end

local bcbpakPresent = nil   -- tri-state: nil = not yet probed
local probeWarned   = false -- warn ONCE per session, not ~6000x (one per BuildArray)

-- Returns true/false. Cached after the first successful probe.
--
-- 2026-07-26 (adversarial review S2): the failure state is NO LONGER LATCHED.
-- It used to set probeFailed=true and short-circuit for the rest of the session,
-- so a single empty GetLoadOrder() at SessionLoaded permanently pinned the answer
-- to "PRESENT". With class-1 the gated surface grew from 405 armour VRs to 482
-- including common civilian clothes, which is exactly the surface this gate exists
-- to keep our clone GUIDs off for non-BCBPak users. Now every call re-probes until
-- one succeeds; only the WARNING is latched, which is what the ~6000x concern was
-- actually about.
function M.HasBCBPak()
    if bcbpakPresent ~= nil then return bcbpakPresent end
    local want, found, seen, first = M.BCBPAK_UUID:lower(), false, 0, nil
    local ok = pcall(function()
        for _, u in ipairs(Ext.Mod.GetLoadOrder() or {}) do
            seen = seen + 1
            if first == nil then first = tostring(u) end
            if tostring(u):lower() == want then found = true; break end
        end
    end)
    -- seen == 0 means the API returned nothing usable. Treating that as
    -- "absent" would silently strip the remap from a genuine BCBPak user, so
    -- it counts as a probe failure, not a negative result. NOT cached -- retry
    -- on the next call (e.g. after LevelGameplayStarted, when mods are settled).
    if not ok or seen == 0 then
        if not probeWarned then
            probeWarned = true
            Warn("HasBCBPak: load-order probe unusable (ok=" .. tostring(ok)
                 .. ", entries=" .. tostring(seen) .. "); assuming PRESENT (fail-safe)."
                 .. " Will retry on later calls.")
        end
        return true
    end
    bcbpakPresent = found
    -- S3: log the first entry verbatim. If a future SE build returns objects
    -- instead of UUID strings, `seen > 0` but nothing ever matches, and the gate
    -- would silently disable class-1 for a real BCBPak user while logging a
    -- confident "NOT present". This line makes that diagnosable from the log.
    if not found then
        Log("HasBCBPak: no match; first load-order entry was <" .. tostring(first)
            .. "> (expect a bare UUID string).")
    end
    Log("BCBPak " .. (found and "DETECTED" or "NOT present") .. " (" .. seen
        .. " modules) -> base vanilla-VR remap " .. (found and "ENABLED" or "DISABLED")
        .. "; sbbf/bcb and external refits unaffected.")
    return bcbpakPresent
end

-- Test/console hook (!cm_bcbpak). nil clears the cache so the next call
-- re-probes. Changing the value re-runs the vanilla pass, because arrays already
-- injected under the minted key are otherwise stale and InjectTemplate's
-- present-check would block re-injection -- the same trap RepassAfterExternalMerge
-- was added to fix. Without this, a forced toggle would report a bogus PASS.
function M.SetBCBPakPresent(v)
    local prev = bcbpakPresent
    bcbpakPresent = (v == nil) and nil or (v and true or false)
    probeWarned = false
    Log("HasBCBPak override -> " .. tostring(bcbpakPresent) .. " (was " .. tostring(prev) .. ")")
    if M.HasBCBPak() ~= (prev == true) then
        -- force=true bypasses PassDone, same contract as RepassAfterExternalMerge.
        pcall(function() M.RunBlanketPass("vanilla", true) end)
        pcall(function() M.ReapplyAll() end)
        Log("HasBCBPak change -> vanilla pass re-run.")
    end
end

-- ---------------------------------------------------------------------------
-- Internals
-- ---------------------------------------------------------------------------
local PassDone = {}      -- [choice] = true once the blanket pass ran this session
local Stats    = { injected = 0, refits = 0, skipped = 0, templates = 0 }

local VISUAL_SLOTS = { "Breast", "VanityBody", "Cloak", "Helmet", "Gloves", "Boots", "Underwear" }

local function lc(s) return tostring(s or ""):lower() end

-- Walk the DefaultParent chain from raceGuid; return the first Visuals array
-- found on eq (as a plain Lua string array), or nil.
local function EffectiveVisuals(eq, raceGuid)
    local r = lc(raceGuid)
    local hops = 0
    while r ~= "" and hops < 6 do
        local arr
        pcall(function() arr = eq.Visuals[r] end)
        if arr ~= nil then
            local out = {}
            local okC = pcall(function()
                for _, v in ipairs(arr) do out[#out + 1] = tostring(v) end
            end)
            if okC and #out > 0 then return out end
        end
        r = PARENT[r]
        hops = hops + 1
    end
    return nil
end

-- Resolve a Visual resource's GR2 basename without extension (for refit
-- replacement matching). nil on fail. NOTE: VisualResource has NO .Name
-- property in bg3se (confirmed in-game 2026-07-04) - SourceFile is the
-- reliable identifier (also used by cm_checkbody).
local function VisualSourceBase(id)
    local base
    pcall(function()
        local res = Ext.Resource.Get(tostring(id), "Visual")
        if res ~= nil and res.SourceFile ~= nil then
            local sf = tostring(res.SourceFile):gsub("\\", "/")
            base = sf:match("([^/]+)$") or sf
            base = base:gsub("%.[Gg][Rr]2$", "")
        end
    end)
    return base
end

-- Build the array to inject for one template: source-copy, swapping any vanilla
-- VisualResource id that has a refit (REFIT_BY_VR) for its minted refit id.
-- Per-VR keying => materially correct even when a GR2 is shared by multiple VRs.
-- templateId kept in the signature for logging/back-compat; not used for matching.
-- F1 (v4.13): set true only when CheckContentPresence proves the ClothMorphContent
-- VisualBank is absent. Default false => BuildArray behaves EXACTLY as before
-- (zero change in the normal, content-present case).
M._ContentAbsent = false

-- Base-map canaries captured NOW, at module load, BEFORE any external add-on
-- refits are merged into M.REFIT_BY_VR (those merge later via
-- RegisterExternalRefits). CheckContentPresence probes THESE deterministic
-- base ids only, so (a) an add-on with unresolved meshes can never make the
-- base content look "absent".
-- CORRECTION 2026-07-26 (review S6): the old claim here -- "the probe set is
-- stable, not a nondeterministic pairs() window" -- was FALSE. The loop below is
-- literally `for _, refit in pairs(map)` with a break at 6, so which six get
-- sampled depends on table hash order and changed when class-1 added 77 keys.
-- It does not matter for the absent/present verdict (M._ContentAbsent only fires
-- when ALL 18 fail to resolve, and the sbbf/bcb canaries are unaffected), but it
-- is NOT a per-key guarantee: a Content pak missing only the class-1 bank would
-- pass this check and still render those 77 garments invisible. That case is
-- prevented by deploy ORDER (Content before Runtime) + live-SHA verification in
-- _v416_repack_deploy.ps1, not by this probe.
M._BASE_CANARIES = (function()
    local out = {}
    for _, choice in ipairs({ "vanilla", "sbbf", "bcb" }) do
        local map = M.REFIT_BY_VR[choice]
        local n = 0
        if type(map) == "table" then
            for _, refit in pairs(map) do
                out[#out + 1] = tostring(refit)
                n = n + 1
                if n >= 6 then break end
            end
        end
    end
    return out
end)()

local function BuildArray(choice, templateId, srcArr)
    local map = M.REFIT_BY_VR[choice]
    if map == nil then return srcArr, false end
    local out, isRefit = {}, false
    -- BCBPak gate (2026-07-26): hoisted out of the loop; HasBCBPak is cached.
    -- Only the BASE vanilla keys are gateable -- externally merged vanilla
    -- entries (e.g. ClothMorphSCO's 129, which defend against BCBScantily, a
    -- DIFFERENT mod) must never be disabled by BCBPak's absence.
    local gateBaseVanilla = (choice == "vanilla") and (not M.HasBCBPak())
    for _, vid in ipairs(srcArr) do
        local key = lc(vid)
        local refit = map[key]
        if gateBaseVanilla and BASE_VANILLA[key] then refit = nil end
        -- F1 guard: if the content pak is proven absent, pass the ORIGINAL VR
        -- through (visible vanilla look) instead of a minted id that would
        -- resolve to nothing (invisible). Normal case: _ContentAbsent=false.
        if refit ~= nil and not M._ContentAbsent then
            out[#out + 1] = tostring(refit)
            isRefit = true
        else
            out[#out + 1] = vid
        end
    end
    return out, isRefit
end

-- F1 (v4.13): confirm ClothMorphContent's VisualBank is actually loaded. The
-- base refit map points at minted VRs that live in that pak; if the user
-- disabled/removed it, injected refits resolve to nothing => invisible gear.
-- Called from BootstrapServer's LevelGameplayStarted (resources guaranteed
-- loaded). Probes up to 8 base-map minted ids; if NONE resolve, flip
-- M._ContentAbsent so BuildArray degrades to visible pass-through, force a
-- rebuilding re-pass of any minted choices, and warn loudly. Zero effect when
-- content is present (the normal case).
function M.CheckContentPresence()
    local probed, resolved = 0, 0
    for _, refit in ipairs(M._BASE_CANARIES or {}) do
        probed = probed + 1
        local ok = false
        pcall(function() ok = Ext.Resource.Get(refit, "Visual") ~= nil end)
        if ok then resolved = resolved + 1 end
    end
    M._ContentAbsent = (probed > 0 and resolved == 0)
    if M._ContentAbsent then
        Warn("ClothMorphContent VisualBank NOT found (probed " .. tostring(probed)
            .. " base-map refit ids, 0 resolved). Clothing refits DISABLED to avoid "
            .. "invisible gear - garments keep their original (vanilla) look. Enable/"
            .. "install the ClothMorphContent pak and load it below ClothMorphRuntime.")
        for choice in pairs(M.MINTED or {}) do
            pcall(function() M.RunBlanketPass(choice, true) end)
        end
    else
        Log(("ClothMorphContent presence OK (probed %d base-map ids, %d resolved).")
            :format(probed, resolved))
    end
    return not M._ContentAbsent
end

-- OPT-OUT (2026-07-06, option 2 for hybrid modded outfits): root-template IDs
-- (lowercase) excluded from vanilla-VR remapping. For these templates the
-- minted key receives a VERBATIM copy of the source visuals array, so a hybrid
-- item (custom top + vanilla body/pants VRs) keeps its author-fitted look on a
-- flipped character instead of mixing proportions. Seeded from
-- PersistentVars.OptoutTemplates by BootstrapServer at SessionLoaded and
-- updated live by M.SetOptout (!cm_optout).
M.OPTOUT = {}

-- BAKED-BODY EXCLUSION (v4.12, 2026-07-20). Root-template ids (lowercase) of
-- BCB garments that carry their OWN nude-body mesh baked into the garment GR2
-- (detected at build time by a NKD_Body/_adjust_Mesh submesh; e.g. Full Metal
-- Dress = CorsetSkirtArm). For these we leave the garment UNTOUCHED so it works
-- exactly as the original BCB mod: consulted in InjectTemplate exactly like an
-- opt-out (minted key = VERBATIM source array, no refit swap) for ALL bodies,
-- and BootstrapServer keeps them OUT of REVEALING_TORSO so the nude override is
-- stripped under them. Extend this list from the build-time baked-body scan.
M.BAKED_EXCLUDE = {
    ["20bf6831-84ff-42d1-aa18-a97dc3f96a6a"] = true, -- HUM_F_CLT_CorsetSkirtArm_KEL (Full Metal Dress) - bakes HUM_F_NKD_Body_A_adjust_Mesh1
}

-- DEFAULT (BUILT-IN) PER-(item x body) OPT-OUT (2026-07-07, MCT_Design_v1.md
-- section 4 rule). Keyed by body choice -> set of ROOT-TEMPLATE ids (lowercase)
-- that ship opted-out by default for THAT body only. Consulted alongside the
-- live M.OPTOUT set in InjectTemplate: an entry here makes the item's minted
-- key a VERBATIM copy of its source visuals (no vanilla-VR remap) for that
-- body, exactly as if the user had run !cm_optout - but persistently and with
-- no console command. The live !cm_optout (M.OPTOUT) can still add MORE
-- opt-outs at runtime; this table is only the built-in baseline.
--
-- SEEDED ENTRY - "Moonshadow Armor (Alt)" (BW_Moonshadow mod
-- e14e3421-80bb-564a-edc5-5985be28fad4), an M-B hybrid: its Human-Female
-- Visuals array = vanilla Leather_A_Body VR 66bcfba0 + Leather_A_Pants VR
-- 27e35669 (BOTH in REFIT_BY_VR -> normally remapped) + custom top VR
-- 84195a60 (absent from REFIT_BY_VR -> passes through). On BCB the remap gives
-- a crop-top look Alan LIKES (KEEP -> bcb stays empty here). On SBBF the same
-- remap CLIPS (opt out -> verbatim). The mod ships three body-armor variants
-- (Body_A/_B/_C) that share this identical HF hybrid structure, so all three
-- are listed to guarantee the "(Alt)" variant is covered on SBBF regardless of
-- which display name maps to which template; BCB behavior is unchanged. No
-- other mod/item is affected (opt-out is keyed on these template ids only).
M.DEFAULT_OPTOUT_BY_BODY = {
    sbbf = {
        -- v4.18 (2026-07-27): SBBF opt-out REMOVED for Moonshadow. The verbatim
        -- opt-out, with BCBPak installed, resolved these VRs to BCBPak's in-place
        -- meshes (revealing Leather_A_Pants + EMPTY 84195a60) = Alan's "no pants".
        -- Removing the opt-out lets Body(66bcfba0)->cab99f1a and Pants(27e35669)->
        -- 96456f70 remap to our SBBF clones (pants restored). The 2026-07-07 note
        -- warned the remap may clip slightly; Alan chose pants-with-possible-clip
        -- over no-pants (2026-07-27). 84195a60 custom top stays passthrough/empty
        -- (no SBBF clone) -> v1.3: mint it + co-deform for a clean fit. bcb still
        -- NOT opted out (crop-top look Alan likes is unchanged).
        -- ["3b692a26-cd94-4adf-8d8c-ea26219b78e3"] = true, -- BW_Moonshadow_Body_A
        -- ["e1904108-e88c-4f0d-b4c9-f9d696af62f5"] = true, -- BW_Moonshadow_Body_B
        -- ["fae28f64-33f7-4514-9d20-e9780c501538"] = true, -- BW_Moonshadow_Body_C
    },
    bcb = {},
}

-- Inject our minted key into ONE template's Equipment.Visuals (idempotent).
-- Returns "injected" | "refit" | "present" | "skipped".
-- srcRace (optional, H2 fix 2026-07-06): race key to source the array from;
-- defaults to SOURCE_RACE (Human F). Equip-time callers retry with the
-- character's ORIGINAL EquipmentRace so items without an HF visuals entry
-- render vanilla-shaped instead of INVISIBLE on a flipped character.
-- overwrite (optional): rewrite the minted key even if present (used by
-- SetOptout so a toggle takes effect without a fresh session).
local function InjectTemplate(choice, t, srcRace, overwrite)
    local minted = M.MINTED[choice]
    if minted == nil or t == nil then return "skipped" end
    local eq
    pcall(function() eq = t.Equipment end)
    if eq == nil or eq.Visuals == nil then return "skipped" end
    local existing
    pcall(function() existing = eq.Visuals[minted] end)
    if existing ~= nil and not overwrite then return "present" end
    local src = EffectiveVisuals(eq, srcRace or M.SOURCE_RACE)
    if src == nil then return "skipped" end
    local id = ""
    pcall(function() id = tostring(t.Id) end)
    local arr, isRefit
    local defBody = M.DEFAULT_OPTOUT_BY_BODY[choice]
    if M.BAKED_EXCLUDE[lc(id)] or M.OPTOUT[lc(id)] or (defBody and defBody[lc(id)]) then
        arr, isRefit = src, false  -- baked-body-excluded / opted out (live or built-in default): verbatim copy, no vanilla-VR remap
    else
        arr, isRefit = BuildArray(choice, id, src)
    end
    local okW = pcall(function() eq.Visuals[minted] = arr end)
    if not okW then
        Warn("InjectTemplate: write failed on " .. tostring(id))
        return "skipped"
    end
    return isRefit and "refit" or "injected"
end

-- ---------------------------------------------------------------------------
-- M.RunBlanketPass(choice) - iterate every root template with Equipment and
-- inject the minted key (P3: MANDATORY before any flip). Idempotent; ~once
-- per session (template writes survive savegame loads within the session).
-- ---------------------------------------------------------------------------
function M.RunBlanketPass(choice, force)
    choice = choice or "sbbf"
    if PassDone[choice] and not force then
        Log("BlanketPass(" .. choice .. "): already ran this session (use force to re-run).")
        return true
    end
    local minted = M.MINTED[choice]
    if minted == nil then Warn("BlanketPass: no minted GUID for '" .. tostring(choice) .. "'"); return false end
    local t0 = Ext.Utils.MonotonicTime()
    local all
    local okAll = pcall(function() all = Ext.Template.GetAllRootTemplates() end)
    if not okAll or all == nil then
        Warn("BlanketPass: GetAllRootTemplates failed.")
        return false
    end
    Stats = { injected = 0, refits = 0, skipped = 0, present = 0, templates = 0 }
    for _, t in pairs(all) do
        local isItem = false
        pcall(function() isItem = (t.TemplateType == "item") end)
        if isItem then
            Stats.templates = Stats.templates + 1
            -- v4.10: force also OVERWRITES already-injected arrays (needed so a
            -- forced re-pass picks up externally registered refit entries; the
            -- old force only bypassed PassDone and then hit the present-gate).
            local r = InjectTemplate(choice, t, nil, force)
            if     r == "injected" then Stats.injected = Stats.injected + 1
            elseif r == "refit"    then Stats.refits   = Stats.refits + 1
            elseif r == "present"  then Stats.present  = Stats.present + 1
            else                        Stats.skipped  = Stats.skipped + 1 end
        end
    end
    PassDone[choice] = true
    local ms = Ext.Utils.MonotonicTime() - t0
    Log(("BlanketPass(%s): %d item templates; injected=%d refit=%d present=%d skipped(no HF visuals)=%d in %d ms.")
        :format(choice, Stats.templates, Stats.injected, Stats.refits, Stats.present, Stats.skipped, ms))
    return true
end

-- Belt-and-braces for the child-template gotcha: inject on the template the
-- item entity ACTUALLY carries (may be a child that redeclares Equipment).
local function InjectEquippedItem(choice, itemGuid, srcRace)
    local t
    pcall(function()
        local e = Ext.Entity.Get(itemGuid)
        if e ~= nil and e.ServerItem ~= nil then t = e.ServerItem.Template end
    end)
    if t == nil then return "skipped" end
    return InjectTemplate(choice, t, srcRace)
end

-- H2 fix (2026-07-06): equip-time injection with original-race fallback.
-- "skipped" from the HF pass means the template has Equipment.Visuals but no
-- HF entry (race-specific / masc-only / some modded items) -> without a minted
-- key the item renders INVISIBLE on a flipped character. Retry sourcing from
-- the character's original EquipmentRace; warn loudly if still uncovered.
local function InjectEquippedItemWithFallback(choice, itemGuid, origRace, where)
    local r = InjectEquippedItem(choice, itemGuid)
    if r == "skipped" and origRace ~= nil and origRace ~= "" then
        r = InjectEquippedItem(choice, itemGuid, lc(origRace))
        if r == "injected" or r == "refit" then
            Log(("%s: no HF visuals for item %s - injected via original race %s (fallback)."):format(
                tostring(where), tostring(itemGuid), tostring(origRace)))
        end
    end
    if r == "skipped" then
        Warn(("%s: item %s has NO visuals entry usable for '%s' - it will render INVISIBLE on this flipped character."):format(
            tostring(where), tostring(itemGuid), tostring(choice)))
    end
    return r
end

-- M.SetOptout(itemGuid, on): toggle remap opt-out for the item's ROOT template
-- and re-inject every minted key immediately (overwrite) so the change shows
-- without a new session. Returns the template id (for persistence) or nil.
function M.SetOptout(itemGuid, on)
    local t
    pcall(function()
        local e = Ext.Entity.Get(itemGuid)
        if e ~= nil and e.ServerItem ~= nil then t = e.ServerItem.Template end
    end)
    if t == nil then Warn("SetOptout: no ServerItem.Template for " .. tostring(itemGuid)); return nil end
    local id = ""
    pcall(function() id = tostring(t.Id) end)
    if id == "" or id == "nil" then Warn("SetOptout: template has no Id"); return nil end
    M.OPTOUT[lc(id)] = (on and true) or nil
    for choice, _ in pairs(M.MINTED) do
        local r = InjectTemplate(choice, t, nil, true)
        Log(("SetOptout: template %s optout=%s; '%s' key re-injected -> %s"):format(
            id, tostring(on), tostring(choice), tostring(r)))
    end
    return id
end

local function SweepEquipped(choice, char, origRace)
    for _, slot in ipairs(VISUAL_SLOTS) do
        local it
        pcall(function() it = Osi.GetEquippedItem(char, slot) end)
        if it ~= nil and it ~= "" then
            local r = InjectEquippedItemWithFallback(choice, it, origRace, "SweepEquipped")
            if r == "injected" or r == "refit" then
                Log(("SweepEquipped: injected child/instance template for %s item %s"):format(slot, tostring(it)))
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Per-character flip / restore.
-- ---------------------------------------------------------------------------
local function GetTemplate(char)
    local t
    pcall(function()
        local e = Ext.Entity.Get(char)
        if e ~= nil and e.ServerCharacter ~= nil then t = e.ServerCharacter.Template end
    end)
    return t
end

function M.ReadEquipRace(char)
    local t = GetTemplate(char)
    if t == nil then return nil end
    local g
    pcall(function() g = tostring(t.EquipmentRace) end)
    return g
end

-- Is this character's ORIGINAL EquipmentRace in the Human-Female family
-- (v1 eligibility)? Walk the parent chain to SOURCE_RACE.
function M.IsEligible(origRace)
    local r = lc(origRace)
    local hops = 0
    while r ~= "" and hops < 6 do
        if r == M.SOURCE_RACE then return true end
        r = PARENT[r] or ""
        hops = hops + 1
    end
    return false
end

-- Re-equip the character's visual slots to force the engine to re-resolve
-- equipment visuals against the (new) EquipmentRace. Unequip all, then equip
-- back on a short timer (immediate fallback if Ext.Timer is unavailable).
function M.RefreshEquipment(char)
    local items = {}
    for _, slot in ipairs(VISUAL_SLOTS) do
        pcall(function()
            local it = Osi.GetEquippedItem(char, slot)
            if it ~= nil and it ~= "" then items[#items + 1] = it end
        end)
    end
    if #items == 0 then Log("RefreshEquipment: nothing equipped in visual slots."); return end
    for _, it in ipairs(items) do pcall(function() Osi.Unequip(char, it) end) end
    local function reequip()
        for _, it in ipairs(items) do pcall(function() Osi.Equip(char, it) end) end
        Log(("RefreshEquipment: re-equipped %d item(s) on %s."):format(#items, tostring(char)))
    end
    local okT = pcall(function() Ext.Timer.WaitFor(250, reequip) end)
    if not okT then reequip() end
end

-- M.SetClothed(char, choice, pvRec): flip ("sbbf") or restore ("vanilla").
-- pvRec is the PersistentVars.Bodies[char] record (owned by BootstrapServer);
-- we store ClothedChoice + OrigEquipRace on it.
function M.SetClothed(char, choice, pvRec)
    if char == nil or pvRec == nil then Warn("SetClothed: missing char/record"); return false end
    local t = GetTemplate(char)
    if t == nil then Warn("SetClothed: no ServerCharacter.Template for " .. tostring(char)); return false end
    local cur = M.ReadEquipRace(char)

    -- "off" = restore the character's TRUE original EquipmentRace (the revert /
    -- uninstall / hand-back path; called by !cm_revert). 2026-07-15: the
    -- user-facing "vanilla" body CHOICE is no longer this branch - it is now a
    -- MINTED flip (MINTED.vanilla, falls through below) so it serves our clean
    -- vanilla clothing and OVERRIDES BCB's global in-place VR override. Only
    -- "off" restores the original ER.
    if choice == "off" then
        -- Recovery: if we never captured the original (corrupted save where the
        -- minted ER persisted), fall back to the KNOWN_ORIG table so revert can
        -- still work. Manual override: !cm_seterace <guid> (M.ForceSetEquipRace).
        local orig = pvRec.OrigEquipRace or M.KNOWN_ORIG[lc(char)]
        if orig == nil then
            Warn("SetClothed(off): no recorded original AND no KNOWN_ORIG entry - "
                .. "cannot restore. Use !cm_seterace <origGuid> to recover this character.")
            -- C2 fix (2026-07-06): do NOT mark vanilla / return success here. The live
            -- ER is still minted; recording "vanilla" would make the next session skip
            -- the blanket pass entirely and render all equipment invisible with no
            -- automatic recovery. Keep the prior ClothedChoice and flag for recovery.
            pvRec.NeedsRecovery = true
            return false
        end
        if pvRec.OrigEquipRace == nil then
            pvRec.OrigEquipRace = orig  -- persist the recovered value
            Log("SetClothed(off): recovered original from KNOWN_ORIG -> " .. tostring(orig))
        end
        local okW = pcall(function() t.EquipmentRace = orig end)
        if not okW then Warn("SetClothed(off): restore write failed."); return false end
        pvRec.ClothedChoice = "off"
        pvRec.NeedsRecovery = nil
        Log(("SetClothed: %s restored EquipmentRace %s -> %s."):format(tostring(char), tostring(cur), tostring(orig)))
        M.RefreshEquipment(char)
        return true
    end

    local minted = M.MINTED[choice]
    if minted == nil then
        Warn(("SetClothed: '%s' has no minted EquipmentRace (no clothed assets yet)."):format(tostring(choice)))
        return false
    end
    -- Record the original once (never overwrite with our own minted GUID).
    local isMintedCur = false
    for _, g in pairs(M.MINTED) do if lc(cur) == lc(g) then isMintedCur = true break end end
    if pvRec.OrigEquipRace == nil then
        if not isMintedCur then
            pvRec.OrigEquipRace = cur  -- normal path: stash the true original
        else
            -- Corrupted state: cur is ALREADY our minted GUID and we never
            -- stashed the original (the write persisted from a prior session).
            -- Recover from KNOWN_ORIG so revert stays possible; otherwise warn
            -- loudly - the character needs !cm_seterace <origGuid> to recover.
            local rec = M.KNOWN_ORIG[lc(char)]
            if rec ~= nil then
                pvRec.OrigEquipRace = rec
                Warn(("SetClothed: cur already minted with no orig recorded; recovered orig %s from KNOWN_ORIG for %s.")
                    :format(tostring(rec), tostring(char)))
            else
                Warn(("SetClothed: cur already minted with no orig recorded for %s and NO KNOWN_ORIG entry - "
                    .. "revert will be impossible until you run !cm_seterace <origGuid>."):format(tostring(char)))
            end
        end
    end
    if not M.IsEligible(pvRec.OrigEquipRace or cur) then
        -- v1 fallback: origin companions carry persona-specific EquipmentRace
        -- GUIDs that are NOT in the 24-entry family map (P2 probe 2026-07-01:
        -- Shadowheart's ER 76217761-... is unidentified). Accept the flip if
        -- CharacterCreationStats says BT1 Feminine Regular (bt=1, bs=0) -
        -- the HF-based injected arrays fit that body family.
        local bt, bs
        pcall(function()
            local e = Ext.Entity.Get(char)
            local ccs = e and e.CharacterCreationStats or nil
            if ccs ~= nil then bt, bs = tostring(ccs.BodyType), tostring(ccs.BodyShape) end
        end)
        if bt == "1" and bs == "0" then
            Log(("SetClothed: EquipmentRace %s not in family map, but CCS says BT1/BS0 - accepting via fallback.")
                :format(tostring(pvRec.OrigEquipRace or cur)))
        else
            Warn(("SetClothed: original EquipmentRace %s not in the Human-Female family and CCS bt=%s bs=%s - v1 scope refuses the flip.")
                :format(tostring(pvRec.OrigEquipRace or cur), tostring(bt), tostring(bs)))
            return false
        end
    end
    -- P3 mandate: injection BEFORE the flip - blanket pass + equipped sweep.
    M.RunBlanketPass(choice, false)
    SweepEquipped(choice, char, pvRec.OrigEquipRace or cur)
    local okW = pcall(function() t.EquipmentRace = minted end)
    if not okW then Warn("SetClothed: EquipmentRace write failed."); return false end
    pvRec.ClothedChoice = choice
    Log(("SetClothed: %s EquipmentRace %s -> %s (orig recorded: %s)."):format(
        tostring(char), tostring(cur), tostring(minted), tostring(pvRec.OrigEquipRace)))
    M.RefreshEquipment(char)
    return true
end

-- Re-apply all persisted clothed choices (after level load / savegame load).
-- Template writes are NOT save-persistent, so this runs the pass + re-flips.
function M.ReapplyAll(bodies, reason)
    local n = 0
    for char, rec in pairs(bodies or {}) do
        if rec.ClothedChoice ~= nil and M.MINTED[rec.ClothedChoice] ~= nil then  -- 2026-07-15: gate on MINTED (incl. vanilla), not ~="vanilla"
            local cur = M.ReadEquipRace(char)
            local minted = M.MINTED[rec.ClothedChoice]
            if minted ~= nil then
                if lc(cur) ~= lc(minted) then
                    if M.SetClothed(char, rec.ClothedChoice, rec) then n = n + 1 end
                else
                    -- C1 fix (2026-07-06): the minted ER PERSISTED in the save (origin/
                    -- player templates persist the write), but Equipment.Visuals
                    -- injections are session-only. Skipping here left every worn item
                    -- resolving an unregistered ER key -> INVISIBLE. Re-run the pass +
                    -- equipped sweep even though the ER value already matches.
                    M.RunBlanketPass(rec.ClothedChoice, false)
                    SweepEquipped(rec.ClothedChoice, char, rec.OrigEquipRace)
                    n = n + 1
                end
            end
        end
    end
    if n > 0 then Log(("ReapplyAll(%s): re-applied %d clothed flip(s)."):format(tostring(reason), n)) end
    return n
end

-- On-equip hook: if a managed, flipped character equips an item whose template
-- lacks our key (modded item / child template), inject and re-render that item.
function M.OnEquipped(item, char, rec)
    if rec == nil or rec.ClothedChoice == nil or M.MINTED[rec.ClothedChoice] == nil then return end  -- 2026-07-15: gate on MINTED (incl. vanilla)
    local r = InjectEquippedItemWithFallback(rec.ClothedChoice, item, rec.OrigEquipRace, "OnEquipped")
    if r == "injected" or r == "refit" then
        Log("OnEquipped: late-injected template for " .. tostring(item) .. "; re-equipping to refresh.")
        pcall(function() Osi.Unequip(char, item) end)
        local okT = pcall(function() Ext.Timer.WaitFor(250, function() pcall(function() Osi.Equip(char, item) end) end) end)
        if not okT then pcall(function() Osi.Equip(char, item) end) end
    end
end

-- ---------------------------------------------------------------------------
-- M.ForceSetEquipRace(char, guid, pvRec) - manual recovery. Writes an arbitrary
-- EquipmentRace onto the character's template, records it as the original, marks
-- the clothed half vanilla, and refreshes. Used by !cm_seterace to un-stick a
-- character whose original ER was lost (corrupted save), and to VERIFY a
-- candidate original GUID in-game before trusting it in KNOWN_ORIG.
-- ---------------------------------------------------------------------------
function M.ForceSetEquipRace(char, guid, pvRec)
    if char == nil or guid == nil or guid == "" then
        Warn("ForceSetEquipRace: missing char/guid"); return false
    end
    local t = GetTemplate(char)
    if t == nil then Warn("ForceSetEquipRace: no ServerCharacter.Template for " .. tostring(char)); return false end
    local cur = M.ReadEquipRace(char)
    local okW = pcall(function() t.EquipmentRace = guid end)
    if not okW then Warn("ForceSetEquipRace: write failed."); return false end
    if pvRec ~= nil then
        pvRec.OrigEquipRace = guid   -- treat the written value as the known-good original
        pvRec.ClothedChoice = "off"  -- 2026-07-15: restore/recovery state (NOT the minted "vanilla" flip) so a reload doesn't re-flip and undo the recovery
    end
    Log(("ForceSetEquipRace: %s EquipmentRace %s -> %s (recorded as orig; clothed=off).")
        :format(tostring(char), tostring(cur), tostring(guid)))
    M.RefreshEquipment(char)
    return true
end

-- ---------------------------------------------------------------------------
-- Diagnostics
-- ---------------------------------------------------------------------------
function M.DumpStatus(char, rec)
    Log("---- cm_erstatus ----")
    Log("  Character     : " .. tostring(char))
    Log("  EquipmentRace : " .. tostring(M.ReadEquipRace(char)))
    rec = rec or {}
    Log("  ClothedChoice : " .. tostring(rec.ClothedChoice or "vanilla"))
    Log("  OrigEquipRace : " .. tostring(rec.OrigEquipRace or "(not recorded)"))
    Log("  PassDone      : sbbf=" .. tostring(PassDone.sbbf == true))
    Log(("  LastPass      : templates=%d injected=%d refit=%d present=%d skipped=%d")
        :format(Stats.templates or 0, Stats.injected or 0, Stats.refits or 0, Stats.present or 0, Stats.skipped or 0))
    for _, slot in ipairs(VISUAL_SLOTS) do
        local it, tid, hasKey
        pcall(function() it = Osi.GetEquippedItem(char, slot) end)
        if it ~= nil and it ~= "" then
            pcall(function()
                local e = Ext.Entity.Get(it)
                local t = e and e.ServerItem and e.ServerItem.Template or nil
                if t ~= nil then
                    tid = tostring(t.Id)
                    if t.Equipment ~= nil and t.Equipment.Visuals ~= nil then
                        hasKey = (t.Equipment.Visuals[M.MINTED.sbbf] ~= nil)
                    end
                end
            end)
            Log(("  %-10s tmpl=%s mintedKey=%s"):format(slot, tostring(tid), tostring(hasKey)))
        end
    end
    Log("---------------------")
end

-- ---------------------------------------------------------------------------
-- EXTERNAL REFIT REGISTRATION (v4.10, 2026-07-16 - optional content-pak hook,
-- first consumer: ClothMorphSCO). An add-on's own SE module calls
--   Mods.ClothMorphRuntime.RegisterExternalRefits("SCO", maps)
-- where maps = { vanilla={ [vrId]=mintedId }, sbbf={...}, bcb={...} }.
-- B2 guard (resolve-before-flip): a key is only merged after its minted id
-- resolves as a Visual resource; unresolved entries are queued and retried
-- once at LevelGameplayStarted (resources guaranteed loaded), then dropped
-- with a warning. A dropped entry means BuildArray passes the ORIGINAL VR
-- through - items degrade to their vanilla look, never invisible.
-- Base-map keys are never overwritten (collisions logged, base kept).
-- Keys are raw lowercase strings, NOT parsed as UUIDs (SCO ships two
-- malformed-but-functional resource ids).
-- ---------------------------------------------------------------------------
M._ExternalPending = {}

-- Provenance (v4.13, Feature 2): optional per-source info recorded by
-- RegisterExternalRefits' 3rd arg. Used by CheckExternalSources to warn when a
-- flagged source mod is absent or has drifted since its refits were generated.
-- { [sourceName] = { sourceModUuid, sourceModVersion, flagSha256, credit } }
M.ExternalSources = {}

local function TryMergeExternal(sourceName, choice, vid, refit)
    local dst = M.REFIT_BY_VR[choice]
    if dst == nil then return "badchoice" end
    local key = lc(vid)
    local resolved = false
    pcall(function()
        resolved = Ext.Resource.Get(tostring(refit), "Visual") ~= nil
    end)
    if not resolved then return "unresolved" end
    if dst[key] ~= nil and lc(dst[key]) ~= lc(refit) then return "collision" end
    dst[key] = tostring(refit)
    return "added"
end

-- After merging entries for a choice whose blanket pass ALREADY ran this
-- session, the injected minted-key arrays are stale (built without the new
-- entries) and InjectTemplate's present-gate blocks a plain re-run. Force a
-- rebuilding re-pass for exactly those choices. (Reviewer blocker B1
-- 2026-07-16: without this, SCO refits silently die after save reload.)
local function RepassAfterExternalMerge(choices)
    for choice in pairs(choices) do
        if PassDone[choice] then
            Log(("External refits merged into '%s' after its blanket pass - forcing a rebuilding re-pass."):format(choice))
            pcall(function() M.RunBlanketPass(choice, true) end)
        end
    end
end

function M.RegisterExternalRefits(sourceName, maps, info)
    if type(maps) ~= "table" then
        Warn(("RegisterExternalRefits(%s): maps is not a table"):format(tostring(sourceName)))
        return false
    end
    -- v4.13 provenance: record optional info (backward-compatible; SCO passes nil).
    if type(info) == "table" then
        M.ExternalSources[tostring(sourceName)] = info
    end
    local added, pending, collided, badchoice = 0, 0, 0, 0
    local touched = {}
    for choice, map in pairs(maps) do
        if type(map) == "table" then
            for vid, refit in pairs(map) do
                local r = TryMergeExternal(sourceName, choice, vid, refit)
                if r == "added" then added = added + 1; touched[choice] = true
                elseif r == "collision" then collided = collided + 1
                elseif r == "badchoice" then badchoice = badchoice + 1
                else
                    pending = pending + 1
                    M._ExternalPending[#M._ExternalPending + 1] =
                        { source = tostring(sourceName), choice = choice, vid = vid, refit = refit }
                end
            end
        end
    end
    Log(("RegisterExternalRefits(%s): added=%d pending(unresolved)=%d collided(base kept)=%d badChoice=%d")
        :format(tostring(sourceName), added, pending, collided, badchoice))
    if added > 0 then RepassAfterExternalMerge(touched) end
    return added > 0 or pending > 0
end

-- Retry queued entries once resources are certain to be loaded. Called from
-- BootstrapServer's LevelGameplayStarted listener BEFORE ReapplyAll.
function M.RetryPendingExternalRefits()
    if #M._ExternalPending == 0 then return end
    local added, dropped = 0, 0
    local touched = {}
    for _, e in ipairs(M._ExternalPending) do
        local r = TryMergeExternal(e.source, e.choice, e.vid, e.refit)
        if r == "added" then added = added + 1; touched[e.choice] = true
        else
            dropped = dropped + 1
            Warn(("External refit DROPPED (%s/%s): %s -> %s (%s) - item falls back to original VR")
                :format(tostring(e.source), tostring(e.choice), tostring(e.vid), tostring(e.refit), r))
        end
    end
    Log(("RetryPendingExternalRefits: added=%d dropped=%d"):format(added, dropped))
    M._ExternalPending = {}
    if added > 0 then RepassAfterExternalMerge(touched) end
end

-- v4.13 provenance check. For each registered external source that supplied a
-- sourceModUuid, log if that mod is now ABSENT (refits still render from the
-- add-on's own bundled meshes, like SCO) or warn if its version differs from
-- what the refits were generated against. Log-only; never blocks. SE API names
-- (Ext.Mod.IsModLoaded / Ext.Mod.GetMod().Info.ModVersion) and the ModVersion
-- format are unverified (plan O7): all wrapped in pcall, and the version compare
-- is skipped unless ModVersion is a plain string/number, so an API/format change
-- degrades to a silent skip rather than a false "updated" warning.
function M.CheckExternalSources()
    for name, info in pairs(M.ExternalSources or {}) do
        if type(info) == "table" and info.sourceModUuid ~= nil then
            local loaded = false
            pcall(function() loaded = Ext.Mod.IsModLoaded(tostring(info.sourceModUuid)) == true end)
            if not loaded then
                Log(("External source '%s': source mod %s not loaded; its refits still "
                    .. "render from bundled meshes."):format(tostring(name), tostring(info.sourceModUuid)))
            elseif info.sourceModVersion ~= nil then
                local ver
                pcall(function()
                    local m = Ext.Mod.GetMod(tostring(info.sourceModUuid))
                    ver = m and m.Info and m.Info.ModVersion
                end)
                if (type(ver) == "string" or type(ver) == "number")
                   and tostring(ver) ~= tostring(info.sourceModVersion) then
                    Warn(("External source '%s' updated since refits were generated "
                        .. "(was %s, now %s); refits may not match new/changed items.")
                        :format(tostring(name), tostring(info.sourceModVersion), tostring(ver)))
                end
            end
        end
    end
end

return M
