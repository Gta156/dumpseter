--[[ ==========================================================================
     BlackLight Dumpsters — Core Settings
     --------------------------------------------------------------------------
     Everything related to the base scavenging loop lives here.
     Progression / minigame tuning lives in shared/settings_progression.lua
     All player facing wording lives in shared/locale.lua (Settings.Text)
========================================================================== ]]

Settings = {}

-- --------------------------------------------------------------------------
--  GENERAL
-- --------------------------------------------------------------------------

Settings.DiagnosticMode = false        -- Verbose console output + visible debug zones. Keep false on live servers.
Settings.ContainerRefreshMinutes = 10  -- Minutes a single container stays depleted before it can be rifled again.

Settings.StrictEntityValidation = true -- Server-side verification that the searched entity truly exists. (Disable only if your anticheat objects.)

Settings.RestrictToJobs = false        -- false = everyone may scavenge. Otherwise: 'garbage' or { 'garbage', 'sanitation' }
Settings.ContainerStorageEnabled = true -- Persistent per-container stash inventories.

Settings.WipeStorageOnRestart = false  -- true = container stashes are emptied every resource restart.

-- --------------------------------------------------------------------------
--  CONCEALMENT (climbing inside a skip)
-- --------------------------------------------------------------------------

Settings.ConcealmentEnabled = true  -- Allow players to climb inside skips to hide.
Settings.ExitLiftHeight = 0.5       -- Extra Z applied on exit (raise it if players clip through floors on your map).
Settings.ConcealmentNoise = true    -- Periodic rustling audio so hidden players can be discovered.

Settings.UseProgressBars = false    -- Progress bars instead of raw timed animations. Experimental — leave false unless tested.

-- --------------------------------------------------------------------------
--  MISHAPS (what can go wrong mid-search)
-- --------------------------------------------------------------------------

Settings.Mishaps = {
    Enabled              = true, -- Master switch for all bad outcomes.
    VerminEnabled        = true, -- Rodent / masked-bandit encounters.
    SharpsEnabled        = true, -- Discarded syringe encounters.
    MishapChance         = 35,   -- Percent chance any given search goes badly.
    SharpsChance         = 30,   -- Percent chance a mishap turns out to be a syringe prick.
    SharpsEffectSeconds  = 90,   -- How long the syringe intoxication lingers.
    VerminChance         = 80,   -- Percent chance a mishap is a rodent/bandit (rolled after the syringe roll).
    SharpsHealthCost     = 20,   -- HP lost to a syringe prick.
    GenericHealthCost    = 10,   -- HP lost to a plain, uneventful mishap.
    VerminHealthCost     = 5,    -- HP lost to a rodent bite.
    BanditChance         = 70,   -- Percent chance the vermin is a masked bandit rather than a rodent.
    BanditHealthCost     = 25,   -- HP lost to a masked bandit mauling.
}

-- --------------------------------------------------------------------------
--  TERRITORIAL VAGRANTS
-- --------------------------------------------------------------------------

Settings.HostileVagrantsEnabled = true -- Nearby street dwellers may defend their turf.
Settings.HostileVagrantRadius = 25     -- Metres. NOTE: automatically doubled when looting encampment props.

Settings.VagrantModels = {
    'a_m_m_tramp_01',
    'a_m_m_trampbeac_01',
    'A_M_M_Hillbilly_02',
    'A_M_M_RurMeth_01',
    'A_M_M_Salton_01',
    'A_M_M_Salton_02',
    'A_M_M_Salton_03',
    'A_M_M_Salton_04',
    'a_f_m_skidrow_01',
    'a_f_m_trampbeac_01',
    'a_f_o_salton_01',
    'a_f_y_hippie_01',
    'a_f_y_rurmeth_01',
    'a_m_m_skidrow_01',
    'a_m_o_tramp_01',
    'a_m_o_beach_01',
    'a_m_o_salton_01',
    'a_m_o_soucent_02',
    'a_m_o_soucent_03',
    'a_m_y_methhead_01',
    'a_m_y_salton_01',
}

-- --------------------------------------------------------------------------
--  LOOT TABLES
--  `rarity` is 1-100 — the HIGHER the number the LESS often it is drawn.
-- --------------------------------------------------------------------------

Settings.LootRoll = {
    minPicks = 1, -- Fewest distinct entries pulled per successful search.
    maxPicks = 4, -- Most distinct entries pulled per successful search.
}

Settings.SeasideBinLoot = {
    { name = "plastic",        metadata = {}, min = 1, max = 5, rarity = 25 },
    { name = "iron",           metadata = {}, min = 1, max = 3, rarity = 50 },
    { name = "fish",           metadata = {}, min = 1, max = 1, rarity = 25 },
    { name = "treasuremap",    metadata = {}, min = 1, max = 1, rarity = 75 },
    { name = "empty_weed_bag", metadata = {}, min = 1, max = 1, rarity = 25 },
    { name = "vodka",          metadata = {}, min = 1, max = 1, rarity = 50 },
    { name = "whiskey",        metadata = {}, min = 1, max = 1, rarity = 50 },
    { name = "tequila",        metadata = {}, min = 1, max = 1, rarity = 50 },
    { name = "lighter",        metadata = {}, min = 1, max = 1, rarity = 25 },
    { name = "lockpick",       metadata = {}, min = 1, max = 1, rarity = 25 },
    { name = "pizza",          metadata = {}, min = 1, max = 1, rarity = 25 },
    -- ADD AS MANY AS YOU LIKE
}

Settings.SeasideBinTreasure = {
    { name = "diamond_ring", metadata = {}, min = 1, max = 1, rarity = 40 },
    { name = "gold",         metadata = {}, min = 1, max = 2, rarity = 50 },
    { name = "rolex",        metadata = {}, min = 1, max = 1, rarity = 75 },
    { name = "goldchain",    metadata = {}, min = 1, max = 1, rarity = 75 },
    -- ADD AS MANY AS YOU LIKE
}

Settings.SeasideBinTreasureChance = 5 -- Percent chance of an extra treasure roll.

-- --------------------------------------------------------

Settings.SkipLoot = {
    { name = "steel",    metadata = {}, min = 1, max = 6, rarity = 25 },
    { name = "aluminum", metadata = {}, min = 1, max = 3, rarity = 50 },
    { name = "tequila",  metadata = {}, min = 1, max = 1, rarity = 25 },
    { name = "lighter",  metadata = {}, min = 1, max = 1, rarity = 25 },
    { name = "lockpick", metadata = {}, min = 1, max = 1, rarity = 25 },
    { name = "rubber",   metadata = {}, min = 1, max = 6, rarity = 25 },
    { name = "wood",     metadata = {}, min = 1, max = 3, rarity = 50 },
    { name = "acetone",  metadata = {}, min = 1, max = 1, rarity = 25 },
    { name = "bread",    metadata = {}, min = 1, max = 1, rarity = 25 },
    -- ADD AS MANY AS YOU LIKE
}

Settings.SkipTreasure = {
    { name = "10k_goldchain",          metadata = {}, min = 1, max = 1, rarity = 40 },
    { name = "trojan_usb",             metadata = {}, min = 1, max = 1, rarity = 50 },
    { name = "goldbar",                metadata = {}, min = 1, max = 1, rarity = 60 },
    { name = "cryptostick",            metadata = {}, min = 1, max = 1, rarity = 65 },
    { name = "weapon_hobo_pipe",       metadata = {}, min = 1, max = 1, rarity = 70 },
    { name = "weapon_hobo_plank",      metadata = {}, min = 1, max = 1, rarity = 75 },
    { name = "weapon_hobo_oldmachete", metadata = {}, min = 1, max = 1, rarity = 80 },
    { name = "weapon_hobo_toilet",     metadata = {}, min = 1, max = 1, rarity = 85 },
    { name = "weapon_hobo_rebar",      metadata = {}, min = 1, max = 1, rarity = 90 },
    -- ADD AS MANY AS YOU LIKE
}

Settings.SkipTreasureChance = 10 -- Percent chance of an extra treasure roll.

-- --------------------------------------------------------

Settings.WasteBinLoot = {
    { name = "empty_weed_bag", metadata = {}, min = 1, max = 1, rarity = 15 },
    { name = "lighter",        metadata = {}, min = 1, max = 1, rarity = 20 },
    { name = "bread",          metadata = {}, min = 1, max = 1, rarity = 25 },
    { name = "wood",           metadata = {}, min = 1, max = 3, rarity = 40 },
    { name = "potato",         metadata = {}, min = 1, max = 1, rarity = 50 },
    { name = "orange",         metadata = {}, min = 1, max = 1, rarity = 75 },
    { name = "mushroom",       metadata = {}, min = 1, max = 1, rarity = 80 },
    -- ADD AS MANY AS YOU LIKE
}

Settings.WasteBinTreasure = {
    { name = "diamond",            metadata = {}, min = 1, max = 1, rarity = 60 },
    { name = "casino_chips",       metadata = {}, min = 1, max = 1, rarity = 70 },
    { name = "weed_joint",         metadata = {}, min = 1, max = 1, rarity = 75 },
    { name = "meth",               metadata = {}, min = 1, max = 1, rarity = 85 },
    { name = "weapon_hobo_pipe",   metadata = {}, min = 1, max = 1, rarity = 90 },
    { name = "weapon_hobo_sponge", metadata = {}, min = 1, max = 1, rarity = 95 },
    -- ADD AS MANY AS YOU LIKE
}

Settings.WasteBinTreasureChance = 15 -- Percent chance of an extra treasure roll.

-- --------------------------------------------------------

Settings.EncampmentLoot = {
    { name = "empty_weed_bag", metadata = {}, min = 1, max = 1, rarity = 25 },
    { name = "vodka",          metadata = {}, min = 1, max = 1, rarity = 50 },
    { name = "water",          metadata = {}, min = 1, max = 1, rarity = 25 },
    { name = "acetone",        metadata = {}, min = 1, max = 1, rarity = 50 },
    { name = "lighter",        metadata = {}, min = 1, max = 1, rarity = 25 },
    { name = "cigarette",      metadata = {}, min = 1, max = 1, rarity = 25 },
    { name = "potato",         metadata = {}, min = 1, max = 1, rarity = 25 },
    { name = "orange",         metadata = {}, min = 1, max = 1, rarity = 25 },
    -- ADD AS MANY AS YOU LIKE
}

Settings.EncampmentTreasure = {
    { name = "casino_chips",           metadata = {}, min = 1, max = 1, rarity = 70 },
    { name = "weapon_bat",             metadata = {}, min = 1, max = 1, rarity = 75 },
    { name = "meth",                   metadata = {}, min = 1, max = 3, rarity = 80 },
    { name = "crack_1oz",              metadata = {}, min = 1, max = 1, rarity = 85 },
    { name = "weapon_hobo_plank",      metadata = {}, min = 1, max = 1, rarity = 90 },
    { name = "weapon_hobo_oldmachete", metadata = {}, min = 1, max = 1, rarity = 95 },
    { name = "weapon_hobo_mop",        metadata = {}, min = 1, max = 1, rarity = 98 },
    -- ADD AS MANY AS YOU LIKE
}

Settings.EncampmentTreasureChance = 2 -- Percent chance of an extra treasure roll.

-- --------------------------------------------------------

Settings.RefuseSackLoot = {
    { name = "acetone",        metadata = {}, min = 1, max = 1, rarity = 50 },
    { name = "lighter",        metadata = {}, min = 1, max = 1, rarity = 25 },
    { name = "garden_sheers",  metadata = {}, min = 1, max = 1, rarity = 40 },
    { name = "lettuce",        metadata = {}, min = 1, max = 1, rarity = 25 },
    { name = "tomato",         metadata = {}, min = 1, max = 1, rarity = 25 },
    { name = "potato",         metadata = {}, min = 1, max = 1, rarity = 25 },
    { name = "orange",         metadata = {}, min = 1, max = 1, rarity = 25 },
    { name = "mushroom",       metadata = {}, min = 1, max = 1, rarity = 30 },
    { name = "empty_weed_bag", metadata = {}, min = 1, max = 1, rarity = 25 },
    { name = "vodka",          metadata = {}, min = 1, max = 1, rarity = 50 },
    { name = "water",          metadata = {}, min = 1, max = 1, rarity = 25 },
    -- ADD AS MANY AS YOU LIKE
}

Settings.RefuseSackTreasure = {
    { name = "diamond",           metadata = {}, min = 1, max = 1, rarity = 50 },
    { name = "casino_chips",      metadata = {}, min = 1, max = 1, rarity = 60 },
    { name = "weed_joint",        metadata = {}, min = 1, max = 1, rarity = 75 },
    { name = "phone",             metadata = {}, min = 1, max = 1, rarity = 80 },
    { name = "weapon_hobo_plank", metadata = {}, min = 1, max = 1, rarity = 90 },
    { name = "weapon_hobo_shard", metadata = {}, min = 1, max = 1, rarity = 95 },
    -- ADD AS MANY AS YOU LIKE
}

Settings.RefuseSackTreasureChance = 15 -- Percent chance of an extra treasure roll.

-- --------------------------------------------------------------------------
--  CONTAINER STORAGE CAPACITY
-- --------------------------------------------------------------------------

Settings.SeasideBinSlots  = 3
Settings.SeasideBinWeight = 10000

Settings.SkipSlots  = 12
Settings.SkipWeight = 50000

Settings.WasteBinSlots  = 4
Settings.WasteBinWeight = 12000

Settings.EncampmentSlots  = 5
Settings.EncampmentWeight = 15000

-- --------------------------------------------------------------------------
--  SIGNATURE LOOT DISTRICTS
--  Search inside one of these and you may pull its bespoke loot instead.
-- --------------------------------------------------------------------------

Settings.SignatureLootDistricts = {
    {
        name = "Burgershot", -- Names MUST be unique.
        coords = vector3(-1179.7351, -904.6566, 13.5210),
        radius = 5.0,
        chance = 75,          -- Percent chance the district table is used instead of the default table.
        watched = true,       -- Someone might place a call to the authorities.
        informantChance = 100,-- Percent chance the call actually goes through.
        alertJobs = { 'police', 'burgershot' }, -- Jobs notified by the informant.
        items = {
            { name = "bs_burger",      metadata = { quality = 10 }, min = 1, max = 1 },
            { name = "bs_fries",       metadata = { quality = 10 }, min = 1, max = 1 },
            { name = "bs_drink",       metadata = { quality = 10 }, min = 1, max = 1 },
            { name = "lettuce",        metadata = { quality = 10 }, min = 1, max = 1 },
            { name = "tomato",         metadata = { quality = 10 }, min = 1, max = 1 },
            { name = "potato",         metadata = {}, min = 1, max = 1 },
            { name = "empty_weed_bag", metadata = {}, min = 1, max = 1 },
            -- ADD AS MANY ITEMS AS YOU LIKE
        },
    },

    {
        name = "Industrial",
        coords = vector3(722.1307, -729.4524, 26.1094),
        radius = 100.0,
        chance = 30,
        watched = false,
        informantChance = false,
        alertJobs = {},
        items = {
            { name = "steel",    metadata = {}, min = 1, max = 7 },
            { name = "plastic",  metadata = {}, min = 1, max = 7 },
            { name = "aluminum", metadata = {}, min = 1, max = 7 },
            { name = "copper",   metadata = {}, min = 1, max = 7 },
            { name = "iron",     metadata = {}, min = 1, max = 7 },
            { name = "steel",    metadata = {}, min = 1, max = 7 },
            { name = "glass",    metadata = {}, min = 1, max = 7 },
            { name = "rubber",   metadata = {}, min = 1, max = 7 },
            { name = "wood",     metadata = {}, min = 1, max = 7 },
            -- ADD AS MANY ITEMS AS YOU LIKE
        },
    },

    {
        name = "Grove",
        coords = vector3(107.2442, -1941.9656, 20.8037),
        radius = 50.0,
        chance = 10,
        watched = false,
        informantChance = false,
        alertJobs = {},
        items = {
            { name = "lockpick",       metadata = {}, min = 1, max = 1 },
            { name = "empty_weed_bag", metadata = {}, min = 1, max = 1 },
            { name = "coke_baggy",     metadata = {}, min = 1, max = 1 },
            { name = "weapon_knife",   metadata = {}, min = 1, max = 1 },
            { name = "pistol_ammo",    metadata = {}, min = 1, max = 1 },
            { name = "glass",          metadata = {}, min = 1, max = 1 },
            { name = "weed_joint",     metadata = {}, min = 1, max = 1 },
            { name = "phone",          metadata = {}, min = 1, max = 1 },
            -- ADD AS MANY ITEMS AS YOU LIKE
        },
    },

    {
        name = "SuperRareSpot",
        coords = vector3(169.5135, -1224.2314, 29.3662),
        radius = 10.0,
        chance = 5,
        watched = false,
        informantChance = false,
        alertJobs = {},
        items = {
            { name = "buzz_saw",      metadata = {}, min = 1, max = 1 },
            { name = "impact_driver", metadata = {}, min = 1, max = 1 },
            { name = "weapon_smg",    metadata = {}, min = 1, max = 1 },
            { name = "smg_ammo",      metadata = {}, min = 1, max = 1 },
            { name = "meth_1oz",      metadata = {}, min = 1, max = 1 },
            { name = "coke_1oz",      metadata = {}, min = 1, max = 1 },
            -- ADD AS MANY ITEMS AS YOU LIKE
        },
    },

    -- ADD AS MANY DISTRICTS AS YOU LIKE
}

-- --------------------------------------------------------------------------
--  TARGETABLE PROP MODELS
-- --------------------------------------------------------------------------

Settings.SeasideBinModels = {
    "prop_bin_beach_01a",
    "prop_bin_beach_01d",
    "prop_bin_delpiero",
    "prop_bin_delpiero_b",
}

Settings.SkipModels = {
    "prop_cs_dumpster_01a",
    "p_dumpster_t",
    "prop_dumpster_01a",
    "prop_dumpster_02a",
    "prop_dumpster_02b",
    "prop_dumpster_3a",
    "prop_dumpster_4a",
    "prop_dumpster_4b",
}

Settings.WasteBinModels = {
    "prop_bin_01a",
    "prop_bin_02a",
    "prop_bin_03a",
    "prop_bin_04a",
    "prop_bin_05a",
    "prop_bin_06a",
    "prop_bin_07a",
    "prop_bin_07b",
    "prop_bin_07c",
    "prop_bin_07d",
    "prop_bin_08a",
    "prop_bin_08open",
    "prop_bin_09a",
    "prop_bin_10a",
    "prop_bin_10b",
    "prop_bin_11a",
    "prop_bin_11b",
    "prop_bin_12a",
    "zprop_bin_01a_old",
}

Settings.EncampmentModels = {
    "prop_skid_tent_01",
    "prop_skid_tent_01b",
    "prop_skid_tent_03",
}

Settings.RefuseSackModels = {
    'prop_rub_binbag_01b',
    'prop_rub_binbag_04',
    'prop_rub_binbag_06',
    -- ADD MORE IF YOU LIKE, BUT THESE ONES BEHAVE BEST
}

-- Define your own lootable props here — any model, any loot pool, any animation set.
Settings.BespokeSearchables = {
    [1] = {
        label = 'Swipe Luggage',
        models = {
            "prop_suitcase_01",
            "prop_suitcase_01b",
            "prop_suitcase_01c",
            "prop_suitcase_01d",
            "prop_suitcase_02",
            "prop_suitcase_03b",
            "prop_ld_suitcase_01",
            "prop_ld_suitcase_02",
            "prop_luggage_01a",
            "prop_luggage_02a",
            "prop_luggage_03a",
            "prop_luggage_04a",
            "prop_luggage_05a",
            "prop_luggage_06a",
            "prop_luggage_07a",
            "prop_luggage_08a",
            "prop_luggage_09a",
            "h4_prop_h4_luggage_01a",
            "h4_prop_h4_luggage_02a",
        },
        anims = {
            { dict = 'anim@gangops@van@drive_grab@', anim = 'grab_drive' },
            { dict = 'amb@code_human_in_car_mp_actions@arse_pick@std@ps@base', anim = 'enter' },
            { dict = 'rcmepsilonism8', anim = 'bag_handler_grab_walk_left' },
            { dict = 'anim@scripted@player@freemode@gen_grab@heeled@', anim = 'low_multi' },
            { dict = 'anim@move_m@trash', anim = 'pickup' },
        },
        loot = {
            { name = "money",       metadata = {}, min = 1, max = 50, rarity = 70 },
            { name = "goldwatch",   metadata = {}, min = 1, max = 1,  rarity = 90 },
            { name = "goldbar",     metadata = {}, min = 1, max = 1,  rarity = 95 },
            { name = "cryptostick", metadata = {}, min = 1, max = 1,  rarity = 98 },
        },
        illicit = true,   -- Fires a police dispatch (wire your own call in client/customisable.lua)
        consumeProp = true, -- Prop is destroyed once looted.
    },
    [2] = {
        label = 'Raid Mailbox',
        models = { 'prop_postbox_01a', 'prop_postbox_ss_01a' },
        anims = {
            { dict = 'anim@move_m@trash', anim = 'pickup' },
            { dict = 'anim@scripted@player@freemode@gen_grab@heeled@', anim = 'low_multi' },
            { dict = 'rcmepsilonism8', anim = 'bag_handler_grab_walk_left' },
        },
        loot = {
            { name = "letter", metadata = {}, min = 1, max = 3,  rarity = 30 },
            { name = "money",  metadata = {}, min = 1, max = 20, rarity = 70 },
        },
        illicit = true,
        consumeProp = false,
    },
}

-- --------------------------------------------------------------------------
--  ANIMATION SETS
-- --------------------------------------------------------------------------

-- Mishap reactions --
Settings.VerminReactionClip = { dict = 'misscarsteal2_bin', anim = 'trev_sink_exit' }
Settings.SharpsReactionClip = { dict = 'misscarsteal2_bin', anim = 'trev_sink_exit' }
Settings.GenericMishapClip  = { dict = 'move_p_m_two_idles@generic', anim = 'fidget_sniff_fingers' }

-- Rummaging clips --
Settings.SeasideBinClips = {
    { dict = 'anim@gangops@van@drive_grab@', anim = 'grab_drive' },
    { dict = 'amb@code_human_in_car_mp_actions@arse_pick@std@ps@base', anim = 'enter' },
    { dict = 'rcmepsilonism8', anim = 'bag_handler_grab_walk_left' },
    { dict = 'anim@scripted@player@freemode@gen_grab@heeled@', anim = 'low_multi' },
    { dict = 'anim@move_m@trash', anim = 'pickup' },
    { dict = 'anim@heists@prison_heiststation@heels', anim = 'pickup_bus_schedule' },
}

Settings.SkipClips = {
    { dict = 'weapons@first_person@aim_idle@generic@melee@knife@shared@core', anim = 'fidget_low_loop' },
    { dict = 'anim@gangops@facility@servers@bodysearch@', anim = 'player_search' },
    { dict = 'anim@gangops@morgue@table@', anim = 'player_search' },
    { dict = 'missexile3', anim = 'ex03_dingy_search_case_a_michael' },
    { dict = 'anim@amb@inspect@crouch@male_a@base', anim = 'base' },
}

Settings.WasteBinClips = {
    { dict = 'switch@trevor@garbage_food', anim = 'loop_trevor' },
    { dict = 'amb@prop_human_bum_bin@base', anim = 'base' },
    { dict = 'amb@prop_human_bum_bin@idle_b', anim = 'idle_d' },
    { dict = 'anim@heists@money_grab@briefcase', anim = 'enter' },
}

Settings.RefuseSackClips = {
    { dict = 'anim@gangops@facility@servers@bodysearch@', anim = 'player_search' },
    { dict = 'missexile3', anim = 'ex03_dingy_search_case_a_michael' },
    { dict = 'amb@medic@standing@kneel@base', anim = 'base' },
    { dict = 'amb@world_human_bum_wash@male@low@base', anim = 'base' },
    { dict = 'anim@am_hold_up@male', anim = 'shoplift_low' },
}

Settings.ClimbInClips = {
    { dict = 'anim@veh@apc@ds@enter_exit_front', anim = 'climb_up' },
}

Settings.ClimbOutClips = {
    { dict = 'anim@veh@truck@squaddie@rps@enter_exit', anim = 'jump_out' },
}

Settings.ConcealmentExitKey = 73 -- Control index used to bail out of a skip. (Default: X)
