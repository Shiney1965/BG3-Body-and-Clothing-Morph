# Body and Clothing Morph — Garment Coverage Lists (v1.3)
Generated from the v1.2 build data and updated for v1.3 (Divine list-package / batch reports). Names are the mod's
internal mesh names (the in-game item name may differ). Counts are exact as of this build.

## Summary
| Segment | Included | Excluded / kept prior look | Requires |
|---|---|---|---|
| Base-game garments — Vanilla / SBBF / BCB (**main pak `ClothMorphRuntime`**) | 343 meshes / 1,321 active refits (479 Vanilla, 437 SBBF, 405 BCB) | see notes | — |
| BCB add-on (ClothMorphBCB) | 154 morphed to Vanilla+SBBF | 27 excluded | BCBPak (Nexus 2351) |
| SCO add-on (ClothMorphSCO) | 79 meshes, each in an SBBF and a BCB cut | 16 ship SCO's original mesh (see KNOWN_ISSUES_v1.3.md) | SCO (Nexus 2617) |

---

## 1. Base-game garments — Vanilla / SBBF / BCB (main pak `ClothMorphRuntime`) — 405 garment visual mappings

_In v1.3 these ship inside `ClothMorphRuntime.pak`; the separate `ClothMorphContent.pak` is retired. The mesh list below is unchanged — every visual mapping survived the merge. The 405 mappings are backed by 343 distinct mesh files, because outfit variants often share a mesh._
Every listed mesh is refit to the Vanilla, SBBF, and BCB body. (A garment such as an outfit may
appear as several meshes — body, sleeves, pants.) Documented exclusions: the *Shar Leggings +
Oathbreaker Heels* outfit (morph does not apply in testing) and *Full Metal Dress / CorsetSkirtArm*
(bakes its own body; renders its original look by design).

<details><summary>Show all 405 Vanilla/SBBF meshes</summary>

- HUM_F_ARM_Adventurer_Body_A
- HUM_F_ARM_Astarion_Body
- HUM_F_ARM_Astarion_Pants
- HUM_F_ARM_BG_Watch_A_Pants
- HUM_F_ARM_BG_Watch_B_Pants
- HUM_F_ARM_BG_Watch_C_Pants
- HUM_F_ARM_BG_Watch_Leather_A_Body [DAE]
- HUM_F_ARM_BG_Watch_Leather_B_Body [DAE]
- HUM_F_ARM_BG_Watch_Metal_A_Body
- HUM_F_ARM_Bandit_A_Body
- HUM_F_ARM_Bandit_A_Long_Body
- HUM_F_ARM_Bandit_A_Pants
- HUM_F_ARM_Bandit_B_Body
- HUM_F_ARM_Bandit_C_Body
- HUM_F_ARM_Bandit_C_Body_Accessories
- HUM_F_ARM_Bandit_D_Body
- HUM_F_ARM_Bandit_D_Body_Belt_A
- HUM_F_ARM_Bandit_D_Body_Belt_B
- HUM_F_ARM_Bane_Light_Body_A
- HUM_F_ARM_Bane_Light_Body_B
- HUM_F_ARM_Bane_Light_Pants_A
- HUM_F_ARM_Bane_Plate_Body_A
- HUM_F_ARM_Bane_Plate_Body_B
- HUM_F_ARM_Bane_Robe_Body_A [DAE]
- HUM_F_ARM_Bane_Robe_Body_A_Sleeve
- HUM_F_ARM_Bane_Robe_Body_A_Sleeves
- HUM_F_ARM_BarbarianMagical_A_Body
- HUM_F_ARM_BarbarianMagical_A_Chest
- HUM_F_ARM_BarbarianMagical_A_Pants
- HUM_F_ARM_BarbarianMagical_B_Body
- HUM_F_ARM_BarbarianMagical_B_Chest
- HUM_F_ARM_BarbarianMagical_B_Pants
- HUM_F_ARM_Barbarian_A_Body
- HUM_F_ARM_Barbarian_A_Pants
- HUM_F_ARM_Barbarian_Karlach_A_Body
- HUM_F_ARM_Barbarian_Karlach_A_Pants
- HUM_F_ARM_Bard_BodyBot
- HUM_F_ARM_Bard_BodyTop
- HUM_F_ARM_Bard_Pants
- HUM_F_ARM_Bhaal_A_Body
- HUM_F_ARM_Bhaal_A_Pants
- HUM_F_ARM_Bhaal_Rags_Body
- HUM_F_ARM_Bhaal_Rags_Pants
- HUM_F_ARM_BreastPlate_A_0_Body
- HUM_F_ARM_BreastPlate_A_1_Body
- HUM_F_ARM_BreastPlate_A_2_Body
- HUM_F_ARM_Breastplate_A_0_Pants
- HUM_F_ARM_Breastplate_A_1_Pants
- HUM_F_ARM_Breastplate_A_2_Pants
- HUM_F_ARM_Camp_Citizen_Pants_B
- HUM_F_ARM_ChainMail_A_0_Body
- HUM_F_ARM_ChainMail_A_1_Body
- HUM_F_ARM_ChainMail_A_2_Body
- HUM_F_ARM_ChainMail_A_Pants
- HUM_F_ARM_ChainShirt_A_0_Body [DAE]
- HUM_F_ARM_ChainShirt_A_1_Body [DAE]
- HUM_F_ARM_ChainShirt_A_2_Body [DAE]
- HUM_F_ARM_ChainShirt_B_0_Body
- HUM_F_ARM_ChainShirt_B_0_Broken_Body
- HUM_F_ARM_ChainShirt_B_1_Body [DAE]
- HUM_F_ARM_ChainShirt_B_2_Body
- HUM_F_ARM_ChainShirt_B_2_Pants
- HUM_F_ARM_ChainShirt_B_Broken_Pants
- HUM_F_ARM_ChainShirt_B_Pants
- HUM_F_ARM_ChainShirt_Shadowheart_A_Body
- HUM_F_ARM_Cloth_Magic_A_Chest
- HUM_F_ARM_Cloth_Magic_A_Pants
- HUM_F_ARM_Cloth_Magic_B_Chest
- HUM_F_ARM_Cloth_Magic_B_Pants
- HUM_F_ARM_Cloth_Magic_C_Chest
- HUM_F_ARM_Cult_Absolute_Body_A
- HUM_F_ARM_Cult_Absolute_Body_B
- HUM_F_ARM_Cult_Absolute_Body_C
- HUM_F_ARM_Cult_Absolute_Pants_A
- HUM_F_ARM_Cult_Absolute_Pants_B
- HUM_F_ARM_Cult_Absolute_Robe_Body_A [DAE]
- HUM_F_ARM_Cult_Absolute_Robe_Body_A_Belt_A
- HUM_F_ARM_Cult_Absolute_Robe_Body_B [DAE]
- HUM_F_ARM_Cult_Absolute_Robe_Body_C [DAE]
- HUM_F_ARM_Cult_Absolute_Skirt_A
- HUM_F_ARM_Cult_Absolute_Skirt_B
- HUM_F_ARM_Daisy_Body
- HUM_F_ARM_Daisy_Pants
- HUM_F_ARM_Dark_Justiciar_A_0_Body
- HUM_F_ARM_Dark_Justiciar_A_1_Body
- HUM_F_ARM_Dark_Justiciar_A_Pants
- HUM_F_ARM_Dark_Justiciar_Damaged_A_0_Body
- HUM_F_ARM_Demon_A_Body
- HUM_F_ARM_Demon_A_Pants
- HUM_F_ARM_Desire_Dress
- HUM_F_ARM_Desire_Pants
- HUM_F_ARM_Devils_Blacksmith_Body
- HUM_F_ARM_Devils_Blacksmith_Pants
- HUM_F_ARM_Devils_Blacksmith_Pants_B
- HUM_F_ARM_DrowLeather_A_Body
- HUM_F_ARM_DrowLeather_A_Pants
- HUM_F_ARM_DrowLeather_B_Body
- HUM_F_ARM_DrowLeather_B_Pants
- HUM_F_ARM_DrowLeather_C_Body
- HUM_F_ARM_Druid_A_Body
- HUM_F_ARM_Druid_A_Body_Leaves
- HUM_F_ARM_Druid_B_1_Pants
- HUM_F_ARM_Druid_B_2_Pants
- HUM_F_ARM_Druid_B_Body
- HUM_F_ARM_Druid_C_2_Body
- HUM_F_ARM_Druid_C_Body
- HUM_F_ARM_DwarvenPlate_A_Body
- HUM_F_ARM_DwarvenPlate_A_Pants
- HUM_F_ARM_EPI_Robe_Shar_Body_A
- HUM_F_ARM_Elven_ChainShirt_Body
- HUM_F_ARM_Elven_Umberlee_Chainshirt_Body
- HUM_F_ARM_FlamingFist_ChainMail_A_1_Body
- HUM_F_ARM_FlamingFist_HalfPlate_A_1_Body
- HUM_F_ARM_FlamingFist_Halfplate_A_0_Body
- HUM_F_ARM_FlamingFist_Halfplate_A_0_Body_Pin
- HUM_F_ARM_FlamingFist_Halfplate_Marcus_Body
- HUM_F_ARM_FlamingFist_Leather_Body
- HUM_F_ARM_FlamingFist_Leather_Pants
- HUM_F_ARM_FlamingFist_Robe_Body
- HUM_F_ARM_FlamingFist_Scalemail_Body
- HUM_F_ARM_Githyanki_HalfPlate_A_Body
- HUM_F_ARM_Githyanki_HalfPlate_A_Pants
- HUM_F_ARM_Githyanki_HalfPlate_B_Body
- HUM_F_ARM_Githyanki_HalfPlate_B_Pants
- HUM_F_ARM_Githyanki_HalfPlate_Leather_A_Body
- HUM_F_ARM_Githyanki_HalfPlate_Leather_B_Body
- HUM_F_ARM_Gortash_Body_Jacket
- HUM_F_ARM_Gortash_Body_Skirt
- HUM_F_ARM_HalfPlate_A_0_Body
- HUM_F_ARM_HalfPlate_A_0_Body_Shoulderpads
- HUM_F_ARM_HalfPlate_A_0_Pants
- HUM_F_ARM_HalfPlate_A_1_Body
- HUM_F_ARM_HalfPlate_A_1_Body_Shoulderpads
- HUM_F_ARM_HalfPlate_A_1_Pants
- HUM_F_ARM_HalfPlate_A_2_Body
- HUM_F_ARM_HalfPlate_A_2_Body_Shoulderpads
- HUM_F_ARM_HalfPlate_A_2_Pants
- HUM_F_ARM_HalfPlate_B_0_Body
- HUM_F_ARM_HalfPlate_B_0_Pants
- HUM_F_ARM_HalfPlate_B_0_Skirt
- HUM_F_ARM_HalfPlate_B_1_Body
- HUM_F_ARM_HalfPlate_B_1_Pants
- HUM_F_ARM_HalfPlate_B_1_Skirt
- HUM_F_ARM_HalfPlate_B_2_Body
- HUM_F_ARM_HalfPlate_B_2_Pants
- HUM_F_ARM_HalfPlate_B_2_Skirt
- HUM_F_ARM_HalfPlate_EndGame_Body
- HUM_F_ARM_HalfPlate_EndGame_Pants
- HUM_F_ARM_Hide_A_0_Body
- HUM_F_ARM_Hide_A_1_Body
- HUM_F_ARM_Hide_A_2_Body [DAE]
- HUM_F_ARM_Hide_A_Pants_A
- HUM_F_ARM_Hide_A_Pants_B
- HUM_F_ARM_Hide_Druid_1 [DAE]
- HUM_F_ARM_Infernal_Robe_Body
- HUM_F_ARM_Infernal_Robe_Pants
- HUM_F_ARM_Isobel_A_Body
- HUM_F_ARM_Isobel_A_Pants
- HUM_F_ARM_Isobel_A_Robe_Body
- HUM_F_ARM_Isobel_A_Robe_Skirt
- HUM_F_ARM_Jaheira_Pants
- HUM_F_ARM_Jaheira_Skirt
- HUM_F_ARM_Karlach_Epilogue_Player_Body [DAE]
- HUM_F_ARM_Ketheric_Body_A
- HUM_F_ARM_Ketheric_Pants_A
- HUM_F_ARM_Laezel_Githyanki_HalfPlate_A_Body
- HUM_F_ARM_Laezel_Githyanki_HalfPlate_Broken_A_Body
- HUM_F_ARM_Leather_A_1_Body
- HUM_F_ARM_Leather_A_1_Pants
- HUM_F_ARM_Leather_A_2_Body
- HUM_F_ARM_Leather_A_2_Guild_Pants
- HUM_F_ARM_Leather_A_2_Pants
- HUM_F_ARM_Leather_A_Body
- HUM_F_ARM_Leather_A_Pants
- HUM_F_ARM_Leather_Old_A_Body
- HUM_F_ARM_Leather_Old_A_Pants
- HUM_F_ARM_Leather_Old_A_Pants_B
- HUM_F_ARM_Leather_Old_A_Pants_B_Kneepads
- HUM_F_ARM_Magic_Monk_B_Body
- HUM_F_ARM_Magic_Monk_Body
- HUM_F_ARM_Magic_Monk_Pants
- HUM_F_ARM_Magic_Monk_Pants_Scarf
- HUM_F_ARM_Mindflayer_Body_A
- HUM_F_ARM_Mindflayer_Pants_A
- HUM_F_ARM_Mindflayer_Skirt_A
- HUM_F_ARM_Monk_A_Body [DAE]
- HUM_F_ARM_Monk_A_Pants
- HUM_F_ARM_Myrkul_A_Body
- HUM_F_ARM_Myrkul_A_Pants
- HUM_F_ARM_Myrkul_B_Body
- HUM_F_ARM_Myrkul_Plate_Body_A
- HUM_F_ARM_Myrkul_Plate_Body_C
- HUM_F_ARM_Myrkul_Plate_Body_D
- HUM_F_ARM_Myrkul_Plate_Pants_A
- HUM_F_ARM_NightsongPrison_Body [DAE]
- HUM_F_ARM_NightsongPrison_Pants
- HUM_F_ARM_Nightsong_A_Body_OLD
- HUM_F_ARM_Nightsong_Body
- HUM_F_ARM_Orin_Body
- HUM_F_ARM_Orin_Body_Player
- HUM_F_ARM_Orin_Pants
- HUM_F_ARM_Orin_Pants_Player
- HUM_F_ARM_Padded_A_0_Body
- HUM_F_ARM_Padded_A_0_Body_Broken
- HUM_F_ARM_Padded_A_0_Pants_Broken
- HUM_F_ARM_Padded_A_1_Body
- HUM_F_ARM_Padded_A_1_Body_B
- HUM_F_ARM_Padded_A_1_Body_Spring
- HUM_F_ARM_Padded_A_2_Body
- HUM_F_ARM_Padded_A_2_Body_B
- HUM_F_ARM_Padded_A_Pants
- HUM_F_ARM_Paladin_Oathbreaker_Platemail_Body
- HUM_F_ARM_Paladin_Oathbreaker_Platemail_Pants
- HUM_F_ARM_Paladin_Oathbreaker_Platemail_Skirt
- HUM_F_ARM_PlateMail_A_0_Body
- HUM_F_ARM_PlateMail_A_0_Skirt
- HUM_F_ARM_PlateMail_A_1_Body
- HUM_F_ARM_PlateMail_A_1_Skirt
- HUM_F_ARM_PlateMail_A_2_Body
- HUM_F_ARM_PlateMail_A_2_Skirt
- HUM_F_ARM_PlateMail_A_Pants
- HUM_F_ARM_Platemail_B_Body
- HUM_F_ARM_Ravengard_A_Body
- HUM_F_ARM_RingMail_A_0_Body [DAE]
- HUM_F_ARM_RingMail_A_0_Skirt
- HUM_F_ARM_RingMail_A_1_Body
- HUM_F_ARM_RingMail_A_1_Skirt
- HUM_F_ARM_RingMail_A_2_Body [DAE]
- HUM_F_ARM_RingMail_A_2_Skirt
- HUM_F_ARM_RingMail_A_Pants
- HUM_F_ARM_RingMail_B_Body [DAE]
- HUM_F_ARM_RingMail_B_Pants
- HUM_F_ARM_RingMail_B_Skirt
- HUM_F_ARM_RingMail_C_Skirt
- HUM_F_ARM_Robe_A_1_Body
- HUM_F_ARM_Robe_A_Body
- HUM_F_ARM_Robe_A_Body_Satin
- HUM_F_ARM_Robe_A_CloseQuarter
- HUM_F_ARM_Robe_B_2_Body
- HUM_F_ARM_Robe_B_Body
- HUM_F_ARM_Robe_B_Undead_Body
- HUM_F_ARM_Robe_B_Wizard_Body
- HUM_F_ARM_Robe_C_0_Body
- HUM_F_ARM_Robe_C_1_Body
- HUM_F_ARM_Robe_C_2_Body
- HUM_F_ARM_Robe_C_3_Body
- HUM_F_ARM_Robe_D_Body
- HUM_F_ARM_Robe_E_Body
- HUM_F_ARM_Robe_E_SpiderQueen_Body
- HUM_F_ARM_Robe_EndGame_A_Body
- HUM_F_ARM_Robe_Fire_A_Body
- HUM_F_ARM_Robe_Frost_A_Body
- HUM_F_ARM_Robe_Lorroakan_A_Body
- HUM_F_ARM_Robe_Lorroakan_Body
- HUM_F_ARM_Robe_Shar_Body_A
- HUM_F_ARM_Robe_Shar_Body_B
- HUM_F_ARM_Robe_Shar_Body_Viconia
- HUM_F_ARM_Robe_Shar_Pants_A
- HUM_F_ARM_Robe_Shar_Pants_B
- HUM_F_ARM_Robe_Shar_Skirt
- HUM_F_ARM_Robe_SpellResistance_Body
- HUM_F_ARM_Robe_Umberlee_A_Body
- HUM_F_ARM_Robe_Umberlee_A_Body_B
- HUM_F_ARM_Robe_Umberlee_A_Pants
- HUM_F_ARM_Robe_Umberlee_B_Body
- HUM_F_ARM_Scalemail_A_0_Body
- HUM_F_ARM_Scalemail_A_1_Body
- HUM_F_ARM_Scalemail_A_2_Body
- HUM_F_ARM_Scalemail_A_Pants_A
- HUM_F_ARM_Scalemail_A_Pants_B
- HUM_F_ARM_Scalemail_Adamantine_A_Body
- HUM_F_ARM_Scalemail_Adamantine_A_Pants
- HUM_F_ARM_Scalemail_B_0_Body
- HUM_F_ARM_Scalemail_Paladin_OathOfAncients_Body
- HUM_F_ARM_Scalemail_Paladin_OathOfCrown_Body
- HUM_F_ARM_Scalemail_Paladin_OathOfDevotion_Body
- HUM_F_ARM_Scalemail_Paladin_OathOfVengeance_Body
- HUM_F_ARM_Shadowheart_Dark_Justiciar_Body_A
- HUM_F_ARM_Shadowheart_Dark_Justiciar_Pants_A
- HUM_F_ARM_Society_Of_Brilliance_A_Body
- HUM_F_ARM_Splint_A_0_Body
- HUM_F_ARM_Splint_A_1_Body
- HUM_F_ARM_Splint_A_1_Pants
- HUM_F_ARM_Splint_A_2_Body
- HUM_F_ARM_Splint_A_2_Pants
- HUM_F_ARM_Splint_Adamantine_Body
- HUM_F_ARM_Splint_Adamantine_Pants
- HUM_F_ARM_StuddedLeather_A_0_Body [DAE]
- HUM_F_ARM_StuddedLeather_A_0_Pants
- HUM_F_ARM_StuddedLeather_A_1_Body
- HUM_F_ARM_StuddedLeather_A_1_Pants
- HUM_F_ARM_StuddedLeather_A_2_Body
- HUM_F_ARM_StuddedLeather_A_2_Pants
- HUM_F_ARM_StuddedLeather_B_Body
- HUM_F_ARM_StuddedLeather_C_Body
- HUM_F_ARM_StuddedLeather_Minsc_Body_A
- HUM_F_CLT_Alfira_Skirt [DAE]
- HUM_F_CLT_Bard_Body_A
- HUM_F_CLT_Bard_Body_A_1
- HUM_F_CLT_Bard_Pants_A
- HUM_F_CLT_Bard_Pants_A_1
- HUM_F_CLT_Bard_Skirt_A [DAE]
- HUM_F_CLT_Blacksmith_Body
- HUM_F_CLT_Blacksmith_Pants
- HUM_F_CLT_Camp_Deva_A_Body_A
- HUM_F_CLT_Camp_Halsin_Body
- HUM_F_CLT_Camp_Jaheira_Body_A
- HUM_F_CLT_Camp_Jaheira_Pants_A
- HUM_F_CLT_Camp_Karlach_A_Pants
- HUM_F_CLT_Camp_Minsc_Body
- HUM_F_CLT_Camp_Minsc_Body_Ragged
- HUM_F_CLT_Camp_Minsc_Pants_A
- HUM_F_CLT_Camp_Minsc_Pants_B
- HUM_F_CLT_Camp_Outfit_Astarion_Body
- HUM_F_CLT_Camp_Outfit_Laezel_Pants
- HUM_F_CLT_Camp_Shar_Body
- HUM_F_CLT_Camp_Shar_Pant
- HUM_F_CLT_Circus_Dress_A
- HUM_F_CLT_Circus_Pants_B
- HUM_F_CLT_Circus_Pants_C [DAE]
- HUM_F_CLT_Circus_Pants_D
- HUM_F_CLT_Circus_Pants_E
- HUM_F_CLT_Corset_A
- HUM_F_CLT_Corset_C
- HUM_F_CLT_Corset_Courtesan_A
- HUM_F_CLT_Daisy_Dress_A [DAE]
- HUM_F_CLT_Daisy_Dress_A_Accessories
- HUM_F_CLT_Daisy_Dress_Accessories_Gale_God
- HUM_F_CLT_Daisy_Dress_Cape
- HUM_F_CLT_Daisy_Dress_Cape_Gale_God
- HUM_F_CLT_Daisy_Dress_Gale_God [DAE]
- HUM_F_CLT_Daisy_Dress_White_A [DAE]
- HUM_F_CLT_Doublet_Rich_C_Body [DAE]
- HUM_F_CLT_Doublet_Rich_C_Body_1 [DAE]
- HUM_F_CLT_Doublet_Rich_C_Skirt_A
- HUM_F_CLT_Doublet_Rich_C_Skirt_A_1
- HUM_F_CLT_Doublet_Rich_C_Skirt_B
- HUM_F_CLT_Doublet_Rich_C_Skirt_B_1
- HUM_F_CLT_Drow_Body_A
- HUM_F_CLT_Drow_Body_B
- HUM_F_CLT_Drow_Pants_A
- HUM_F_CLT_EPI_MiddleClass_Body_B
- HUM_F_CLT_Humans_Pants_A
- HUM_F_CLT_Humans_Pants_A2
- HUM_F_CLT_MiddleClass_Body_A_0
- HUM_F_CLT_MiddleClass_Body_A_1
- HUM_F_CLT_MiddleClass_Body_A_2
- HUM_F_CLT_MiddleClass_Body_B
- HUM_F_CLT_MiddleClass_Body_C
- HUM_F_CLT_Mizora_Body_A
- HUM_F_CLT_Nymph_Dress [DAE]
- HUM_F_CLT_Pants_A
- HUM_F_CLT_Pants_B
- HUM_F_CLT_Pants_C
- HUM_F_CLT_Pants_Courtesan_A
- HUM_F_CLT_Pants_D
- HUM_F_CLT_Pants_E
- HUM_F_CLT_Pants_F
- HUM_F_CLT_Pants_G
- HUM_F_CLT_Pants_H
- HUM_F_CLT_Pants_H_Short
- HUM_F_CLT_Pants_H_Twitch
- HUM_F_CLT_Pants_Torn_A
- HUM_F_CLT_Pants_Torn_C
- HUM_F_CLT_Pants_Torn_G
- HUM_F_CLT_Refugees_Corset_A
- HUM_F_CLT_Refugees_Corset_B
- HUM_F_CLT_Refugees_Pants
- HUM_F_CLT_Refugees_Pants_Torn
- HUM_F_CLT_Refugees_Skirt_A
- HUM_F_CLT_Refugees_Skirt_B
- HUM_F_CLT_Refugees_Skirt_C
- HUM_F_CLT_Rich_D_Body
- HUM_F_CLT_Rich_D_Pants
- HUM_F_CLT_Rich_Dress_A_Body [DAE]
- HUM_F_CLT_Rich_Dress_A_Body_2 [DAE]
- HUM_F_CLT_Rich_Dress_A_Body_3 [DAE]
- HUM_F_CLT_Rich_Dress_B
- HUM_F_CLT_Rich_Dress_B_Accessories [DAE]
- HUM_F_CLT_Rich_Dress_B_Shirt
- HUM_F_CLT_Rich_E_Body
- HUM_F_CLT_Rich_F_Body
- HUM_F_CLT_Rich_F_Pants
- HUM_F_CLT_Rich_Pants_A
- HUM_F_CLT_Rich_Shirt_A_Body
- HUM_F_CLT_Rich_Shirt_A_Pants
- HUM_F_CLT_Shirt_Courtesan_A_Corset_A
- HUM_F_CLT_Shirt_Courtesan_A_Corset_B
- HUM_F_CLT_Shirt_Courtesan_A_Corset_E
- HUM_F_CLT_Shirt_Courtesan_A_Corset_Twitch
- HUM_F_CLT_Shirt_D_Corset_Alfira
- HUM_F_CLT_Shirt_D_Corset_B
- HUM_F_CLT_Shirt_H_Corset_B
- HUM_F_CLT_Shirt_H_Corset_E
- HUM_F_CLT_Skirt_A
- HUM_F_CLT_Skirt_A_Spring
- HUM_F_CLT_Skirt_B
- HUM_F_CLT_Skirt_B_Mayrina
- HUM_F_CLT_Skirt_C
- HUM_F_CLT_Skirt_Courtesan_A
- HUM_F_CLT_Skirt_Courtesan_B
- HUM_F_CLT_Torn_Body_A
- HUM_F_CLT_Worker_Body
- HUM_F_CLT_Worker_Pants [DAE]
- HUM_F_Nurse_A_Legs_Bandages

</details>

---

## 2. BCB add-on (ClothMorphBCB) — 154 included, 27 excluded
Requires **BCBPak by Sindae (Nexus 2351)**. Included garments are morphed so BCB outfits fit the
Vanilla and SBBF bodies (they keep their native fit on the BCB body).

### Included (154)

<details><summary>Show all 154 included BCB garments</summary>

- HUM_F_ARM_AnimeEndGamePlate_KEL
- HUM_F_ARM_Authority_KneeHigh_Stiletto_KEL
- HUM_F_ARM_Authority_KneeHigh_Stiletto_KEL2
- HUM_F_ARM_Bandit_D_Body_Belt_A_KEL
- HUM_F_ARM_Bandit_D_Body_Sleeves_KEL
- HUM_F_ARM_Bandit_D_Jacket_BCB_KEL
- HUM_F_ARM_Bane_Light_Body_A_Topless_KEL
- HUM_F_ARM_Cult_Absolute_Scarf_A_KEL
- HUM_F_ARM_Cult_Absolute_Skirt_A_KEL
- HUM_F_ARM_Devils_Blacksmith_Tit_KEL
- HUM_F_ARM_ElfPallyArmourOnly_BCB_KEL
- HUM_F_ARM_ElfPallyBodysuitOnly_BCB_KEL
- HUM_F_ARM_ElfPallyCleavage_BCB_KEL
- HUM_F_ARM_ElfPally_ArmsLegs_BCB_KEL
- HUM_F_ARM_ElfPally_BCB_KEL
- HUM_F_ARM_ElvenChainScantily_KEL
- HUM_F_ARM_Elven_Umberlee_ChainShirt_Body_KEL
- HUM_F_ARM_GithyankiAccessoryA_BCB_KEL
- HUM_F_ARM_GithyankiAccessoryA_BCB_KEL
- HUM_F_ARM_GithyankiAccessoryA_Skimpy_BCB_KEL
- HUM_F_ARM_GothicCorset_BCB_KEL
- HUM_F_ARM_HalfPlate_EndGame_Pants_KEL
- HUM_F_ARM_Jaheira_Skirt_KEL
- HUM_F_ARM_Mindflayer_BodySuit_BCB_KEL
- HUM_F_ARM_Monk_A_Body_ForSkirtC_KEL
- HUM_F_ARM_MyrkulBBody_Wider_BCB_KEL
- HUM_F_ARM_Nightsong_A_Body_KEL
- HUM_F_ARM_Orin_Body_KEL2
- HUM_F_ARM_Orin_Pants_KEL2
- HUM_F_ARM_PaddedA2_PirateSkirt_BCB_KEL
- HUM_F_ARM_PaddedA2_Pirate_BCB_KEL
- HUM_F_ARM_PlateMail_A_2_Body_KEL
- HUM_F_ARM_PlatePants_LeatherSkirt_BCB_KEL
- HUM_F_ARM_Platemail_B_Body_KEL
- HUM_F_ARM_PlatmailB_Princess_KEL
- HUM_F_ARM_PlatmailB_Princess_SkirtOnly_KEL
- HUM_F_ARM_PrincessDressLong_BCB_KEL
- HUM_F_ARM_RingmailA0_Body_Revealing_BCB_KEL
- HUM_F_ARM_RobeA2Body_BCB_KEL
- HUM_F_ARM_RobeA2Body_BCB_KEL
- HUM_F_ARM_RobeC2_Top_KEL
- HUM_F_ARM_RobeC3_Top_KEL
- HUM_F_ARM_RobeWizard_KEL
- HUM_F_ARM_Robe_C_0_Body_KEL
- HUM_F_ARM_Robe_C_2_Body_KEL
- HUM_F_ARM_Robe_EndGame_A_Tit_KEL
- HUM_F_ARM_UmberleeB_Robe_KEL
- HUM_F_CLT_AbsoluteSkirts_Leggings_Outfit_KEL
- HUM_F_CLT_AzureDress_BCB_KEL
- HUM_F_CLT_Bandages_A_KEL
- HUM_F_CLT_BattleNunHood_KEL
- HUM_F_CLT_BattleNunNoHood_KEL
- HUM_F_CLT_BikiniFull_KEL
- HUM_F_CLT_BikiniTop_KEL
- HUM_F_CLT_BlackDress_ShortPhysics_BCB_KEL
- HUM_F_CLT_BlackDress_Short_BCB_KEL
- HUM_F_CLT_BodySuitFullFullBody_BCB_KEL
- HUM_F_CLT_BodySuitFullFullBody_Fishnet_BCB_KEL
- HUM_F_CLT_BodySuitReverse_BCB_KEL
- HUM_F_CLT_BodySuitReverse_Window_BCB_KEL
- HUM_F_CLT_Boyfriend_Shirt_KEL
- HUM_F_CLT_BusinessLadySkimpy2_BCB_KEL
- HUM_F_CLT_BusinessLadySkimpy_BCB_KEL
- HUM_F_CLT_BusinessLady_BCB_KEL
- HUM_F_CLT_CambionWings_BCB_KEL
- HUM_F_CLT_Camp_Deva_Skirt_KEL
- HUM_F_CLT_Camp_Jaheira_Body_A_ForSkirtC_KEL
- HUM_F_CLT_ClubTop_BCB_KEL
- HUM_F_CLT_ClubTop_BCB_KEL
- HUM_F_CLT_CuteTopOnly_BCB_KEL
- HUM_F_CLT_DVACatSuit_HighLeggings_KEL
- HUM_F_CLT_DVACatSuit_KEL
- HUM_F_CLT_Daisy_Dress_A_Accessories_KEL
- HUM_F_CLT_Daisy_Dress_Tit_KEL
- HUM_F_CLT_DancerCloth_BCB_KEL
- HUM_F_CLT_DancerCloth_CorsetBody_KEL
- HUM_F_CLT_DancerCloth_Split_BCB_KEL__0990qqc2
- HUM_F_CLT_DancerNeckJewelGlow_BCB_KEL
- HUM_F_CLT_DancerNeckJewel_BCB_KEL
- HUM_F_CLT_DancerPantiesBCB_KEL
- HUM_F_CLT_Dog_Collar_A_KEL
- HUM_F_CLT_DoubleHeartLegBands_BCB_KEL
- HUM_F_CLT_DreamSkirt_KEL
- HUM_F_CLT_DreamSkirt_Low_BCB_KEL
- HUM_F_CLT_DuchessDawnFull_Nightreign_BCB_KEL
- HUM_F_CLT_DuchessDawnHalf_Nightreign_BCB_KEL
- HUM_F_CLT_ElegantKeeper_BCB_KEL
- HUM_F_CLT_FlaredPants_LowRise_CrotchFix_BCB_KEL
- HUM_F_CLT_FlaredPants_LowRise_CrotchFix_BCB_KEL
- HUM_F_CLT_FullBodySuit_BCB_KEL
- HUM_F_CLT_GTYCaretakerRobe_BCB_KEL
- HUM_F_CLT_GothBody_TopBraUndies_BCBCleavage_KEL
- HUM_F_CLT_GothBody_TopBraUndies_BCBCleavage_KEL
- HUM_F_CLT_GothBody_Top_BCBCleavage_KEL
- HUM_F_CLT_GothBody_Top_BCBCleavage_KEL
- HUM_F_CLT_GothBody_Top_BCBCleavage_KEL
- HUM_F_CLT_GothBody_UndiesOnly_BCBCleavage_KEL
- HUM_F_CLT_GothicChoker_BCB_KEL
- HUM_F_CLT_GothicCorset_RefSkirtB_BCB_KEL
- HUM_F_CLT_GothicDressFull_BCB_KEL
- HUM_F_CLT_GothicDressTop_BCB_KEL
- HUM_F_CLT_HighPanties_BCB_KEL
- HUM_F_CLT_HoushouMarine_BCB_KEL
- HUM_F_CLT_HumanShirtA_LeggingsBeltDaisyDress_KEL
- HUM_F_CLT_HumansShirtA_SharPants_CorsetBody_KEL
- HUM_F_CLT_Humans_Collar_A_KEL
- HUM_F_CLT_Humans_Shirt_A_KEL
- HUM_F_CLT_JewleryBody_BeadUnderwear_BCB_KEL
- HUM_F_CLT_KeeperDressOnly_BCB_KEL
- HUM_F_CLT_KeeperDressOnly_BCB_KEL
- HUM_F_CLT_LeggingsBeltDaisyDress_KEL
- HUM_F_CLT_LeotardCustom_BCB_KEL
- HUM_F_CLT_MaidDressBottom_BCB_KEL
- HUM_F_CLT_MarikaDress_CorsetBody_KEL
- HUM_F_CLT_MarikaDress_CorsetBody_KEL
- HUM_F_CLT_MarineMiniSkirt_BCB_KEL
- HUM_F_CLT_MiddleClass_Body_A_0_Cleavage_KEL
- HUM_F_CLT_Mizora_DressLong_KEL
- HUM_F_CLT_Mizora_DressLong_Sleveless_KEL
- HUM_F_CLT_Mizora_Dress_KEL
- HUM_F_CLT_Nymph_Dress2_KEL
- HUM_F_CLT_PantsH_LowRise_BCB_KEL
- HUM_F_CLT_PixieDress_BCB_KEL
- HUM_F_CLT_PixieDress_BCB_KEL
- HUM_F_CLT_Priest_Of_Loviatar_Body_KEL
- HUM_F_CLT_Priest_Of_Loviatar_Shoulderpads_KEL
- HUM_F_CLT_RecluseBaseAlt_Nightreign_BCB_KEL
- HUM_F_CLT_RecluseBase_Nightreign_BCB_KEL
- HUM_F_CLT_RecluseDawn_Full_Nightreign_BCB_KEL
- HUM_F_CLT_RecluseDawn_Half_Nightreign_BCB_KEL
- HUM_F_CLT_Recluse_Loincloth_Nightreign_BCB_KEL
- HUM_F_CLT_Refugees_Jacket_KEL
- HUM_F_CLT_ReverseBunny_BCB_KEL
- HUM_F_CLT_RichShirtA_CorsetA_KEL
- HUM_F_CLT_Rich_Dress_A_Top_KEL
- HUM_F_CLT_Rich_Dress_B_Short_KEL
- HUM_F_CLT_RobeSkirtC_JacketE_KEL
- HUM_F_CLT_ScantilyGithThong_BCB_KEL
- HUM_F_CLT_SharLeggings_KEL
- HUM_F_CLT_ShartChainTop_PaddedPants_CorsetBody_KEL
- HUM_F_CLT_Shirt_E_Mayrina_KEL
- HUM_F_CLT_SkankyOutfit_BCB_KEL
- HUM_F_CLT_Skirt_B_Mayrina_KEL
- HUM_F_CLT_Skirt_C_Long_KEL
- HUM_F_CLT_Skirt_C_Short_KEL
- HUM_F_CLT_Skirt_Courtesan_B_KEL
- HUM_F_CLT_TankTopLoose_KEL
- HUM_F_CLT_TankTop_KEL
- HUM_F_CLT_ThongStandaloneWider_BCB_KEL
- HUM_F_CLT_ThongStandaloneWider_BCB_KEL
- HUM_F_CLT_ThongStandalone_BCB_KEL
- HUM_F_CLT_TinyBikini_BCB_KEL
- HUM_F_CLT_ZombieTunic_BCB_KEL
- HUM_F_NKD_HighPolyTest_KEL

</details>

### Excluded (27)

These use a complex multi-submesh layout with no vertex-order-preserving conversion path in the
current toolchain; they are candidates for a future update.

| Garment | Reason |
|---|---|
| HUM_F_ARM_GTYOrpheusSet_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| HUM_F_ARM_GTYOrpheusSet_Skimpy_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| HUM_F_ARM_Orin_Jewelry_KEL2 | Path-B could not map (reordered/ambiguous verts) |
| HUM_F_CLT_Apron_Cook_A_Revealing_KEL | Path-B could not map (reordered/ambiguous verts) |
| HUM_F_CLT_BlackDress_LegSlitTrans_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| HUM_F_CLT_BlackDress_LegSlit_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| HUM_F_CLT_BodySuitReverse_Skirtless_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| HUM_F_CLT_BodySuitReverse_Window_Skirtless_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| HUM_F_CLT_BreastArmour_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| HUM_F_CLT_CutTopBanditBeltSunSkirt_BCB_KEL | no GLB (both routes failed) |
| HUM_F_CLT_DancerMetal_BCB_KEL | no GLB (both routes failed) |
| HUM_F_CLT_DancerPiercings_CorsetBody_KEL | no GLB (both routes failed) |
| HUM_F_CLT_JewleryBody_BodyPieces_BCB_KEL | no GLB (both routes failed) |
| HUM_F_CLT_JewleryBody_BodyPieces_Cloth_BCB_KEL | no GLB (both routes failed) |
| HUM_F_CLT_JewleryBody_MizoraPieces_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| HUM_F_CLT_JewleryBody_MizoraPieces_Cloth_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| HUM_F_CLT_KeeperManteauOnly_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| HUM_F_CLT_SundressSkirtOnly_BanditBelt_BCB_KEL | no GLB (both routes failed) |
| HUM_F_CLT_SundressSkirtOnly_BanditBelt_HighWaist_BCB_KEL | no GLB (both routes failed) |
| HUM_F_CLT_Sundress_BCB_KEL | no GLB (both routes failed) |
| HUM_F_CLT_TinyShortsTop_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| HUM_F_CLT_VampirellaOutfit_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| HUM_F_CLT_WitchHat_Nightreign_KEL | no GLB (both routes failed) |
| HUM_F_Desire_Dress_Feathers_KEL | Path-B could not map (reordered/ambiguous verts) |
| HUM_F_Desire_Dress_KEL | Path-B could not map (reordered/ambiguous verts) |
| MMY_HUM_F_ARM_Accessories_C_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |
| MMY_HUM_F_ARM_Laces_C_BCB_KEL | Path-B could not map (reordered/ambiguous verts) |

---

## 3. SCO add-on (ClothMorphSCO) — 79 garment meshes
Requires **Scantily Clad Camp Outfits (SCO) by Crosscrusade (Nexus 2617)**.

The add-on ships **79 meshes in each of its SBBF and BCB folders**. The two groups below record whether the v1.2 SBBF chest-aperture fix could be applied to a garment.

**New in v1.3:** the skin-tightening pass was re-run over the **BCB** cuts as well as the SBBF ones. Across the 33 byte-comparable garments, 32 changed and the count of problem vertices fell **2,187 → 122 (−94.4 %)**, with no garment regressing.

⚠ **16 of the garments in the second group ship SCO's original, unrefitted mesh in every mode** and therefore clip on SBBF and BCB. That is a pipeline limitation, not a fit choice — see `KNOWN_ISSUES_v1.3.md`.

### Received the improved SBBF fit in v1.2 (58)

<details><summary>Show all 58 improved SCO garments</summary>

- HUM_F_ARM_Agility_Armor
- HUM_F_ARM_Agility_Armor_Alt
- HUM_F_ARM_Bhaalist_Armor_Alt
- HUM_F_ARM_Demon_Armor
- HUM_F_ARM_Demon_Armor_Alt
- HUM_F_ARM_Dominion_Robe
- HUM_F_ARM_Dream_Armor
- HUM_F_ARM_Dream_Armor_Alt
- HUM_F_ARM_Druid_Robe
- HUM_F_ARM_Druid_Robe_Alt
- HUM_F_ARM_Emperor_Armor
- HUM_F_ARM_Emperor_Armor_Alt
- HUM_F_ARM_Githyanki_Armor
- HUM_F_ARM_Githyanki_Armor_Alt
- HUM_F_ARM_Jaheira_Robe
- HUM_F_ARM_Jaheira_Robe_Type_C
- HUM_F_ARM_Jergal_Robe
- HUM_F_ARM_Jergal_Robe_Alt
- HUM_F_ARM_Justiciar_Armor
- HUM_F_ARM_Justiciar_Armor_Alt
- HUM_F_ARM_Ketheric_Armor
- HUM_F_ARM_Ketheric_Armor_Alt
- HUM_F_ARM_Leather_Bondage_Armor
- HUM_F_ARM_Monk_Robe
- HUM_F_ARM_Monk_Robe_Alt
- HUM_F_ARM_Nightsong_Armor
- HUM_F_ARM_Nightsong_Armor_Alt
- HUM_F_ARM_Oathbreaker_Armor
- HUM_F_ARM_Oathbreaker_Armor_Alt
- HUM_F_ARM_Scalemail_Armor
- HUM_F_ARM_Scalemail_Armor_Alt
- HUM_F_ARM_Selunite_Robe
- HUM_F_ARM_Selunite_Robe_Alt
- HUM_F_ARM_Snare_Armor
- HUM_F_ARM_Snare_Armor_Alt
- HUM_F_ARM_Soul_Vest
- HUM_F_ARM_Soul_Vest_Alt
- HUM_F_ARM_Soul_Vest_Type_C
- HUM_F_ARM_Soul_Vest_Type_D
- HUM_F_ARM_Viconia_Robe_Alt
- HUM_F_ARM_Vlaakith_Armor
- HUM_F_OFT_Alfira_Dress
- HUM_F_OFT_Alfira_Dress_Alt
- HUM_F_OFT_Bard_Dress
- HUM_F_OFT_Bard_Dress_Alt
- HUM_F_OFT_Collector_Attire
- HUM_F_OFT_Collector_Attire_Alt
- HUM_F_OFT_Dominion_Bodysuit
- HUM_F_OFT_Dribbles_Costume
- HUM_F_OFT_Dribbles_Costume_Alt
- HUM_F_OFT_Dryad_Dress
- HUM_F_OFT_Dryad_Dress_Alt
- HUM_F_OFT_Mizora_Dress
- HUM_F_OFT_Mizora_Dress_Alt
- HUM_F_OFT_Nurse_Dress
- HUM_F_OFT_Nurse_Dress_Alt
- HUM_F_OFT_Surgeon_Attire_Type_C
- HUM_F_OFT_Surgeon_Attire_Type_D

</details>

### Did not receive the v1.2 SBBF fit (18)

**16 of these ship SCO's original mesh in every mode** — they use the same complex-mesh layout as the BCB exclusions and have no conversion path, so no offset or tightening pass can help them. They are the ones most likely to clip visibly on SBBF and BCB; Surgeon's Attire, Orin's and the Butler suit are the commonly reported examples.

The remaining two — the *Wavemother Robe* variants — are a different case: they were reverted to their previously-shipped SBBF mesh in v1.2 after a new fit clipped, and have since been re-fitted.

- HUM_F_ARM_Automaton_Prosthesis
- HUM_F_ARM_Automaton_Prosthesis_Alt
- HUM_F_ARM_Chainshirt_Armor
- HUM_F_ARM_Desiree_Robe
- HUM_F_ARM_Desiree_Robe_Alt
- HUM_F_ARM_Orin_Armor
- HUM_F_OFT_Butler_Suit
- HUM_F_OFT_Butler_Suit_Alt
- HUM_F_OFT_Decadent_Attire
- HUM_F_OFT_Decadent_Attire_Alt
- HUM_F_OFT_Jannath_Robe
- HUM_F_OFT_Jannath_Robe_Alt
- HUM_F_OFT_Mizora_Dress_Type_D
- HUM_F_OFT_Mizora_Dress_Type_E
- HUM_F_OFT_Surgeon_Attire
- HUM_F_OFT_Surgeon_Attire_Alt
- HUM_F_ARM_Wavemother_Robe
- HUM_F_ARM_Wavemother_Robe_Alt

---

## Notes on counts

- **405** is the number of base-game garment *visual mappings* refit for the BCB body, not the number of mesh files. The main pak carries **343** distinct garment meshes in each of its SBBF and BCB folders; several outfit variants share one mesh.
- **Active refit counts, counted from `EquipRace.lua`'s `REFIT_BY_VR` map in this build:**
  **479 Vanilla, 437 SBBF, 405 BCB = 1,321.**
- ⚠ *A different count of 482 / 1,324 is also derivable, and is not an error in either direction.*
  The visual banks **define** 482 Vanilla resources (405 + 77 clean-vanilla clones), but **three**
  of those clones — `84195a60`, `54bc906f`, `238f0743`, the Moonshadow Armor pieces — are
  deliberately commented out of the refit map and pass through unchanged, after a BCBPak override
  was found to supply an empty mesh. So 482 resources exist, **479 refits actually fire**. The
  user-facing number is the one that fires. Do not "correct" 479 to 482.
- The SCO add-on ships **79** meshes per body folder. The v1.2 counts of 76/58/18 above describe the SCO *source* garments the v1.2 fit pass operated on.
- The BCB add-on is **unchanged from v1.2**; its 154/27 split is unmodified.
