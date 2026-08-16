--[[ ==========================================================================
     BlackLight Dumpsters — Progression, Economy & Minigame Settings
========================================================================== ]]

Settings.UseTargetSystem = true -- false = use blacklight-interact's 0.00ms "PRESS E" model detection instead.

Settings.PlayExitClipOnLeave = true -- Play a climb-out animation when abandoning a skip.

Settings.VagrantJobName = "hobo" -- Framework job name granted to committed street dwellers. (Framework contract — keep it aligned with your jobs list.)

Settings.CurrencyItem = "bottle_cap" -- The scavenger currency item.

Settings.DismountCartKey = "X" -- Default keybind to bail out of a cart while riding (rebindable in-game).

Settings.SimpleModeOnly = false -- true = strips the entire reputation ladder, leaving only classic container searching.

Settings.Reputation = {
    -- Cumulative XP needed to reach each rank.
    RankThresholds = {
        [1] = 0, -- Starting rank
        [2] = 100,
        [3] = 250,
        [4] = 1000, -- Street-dweller job unlock
        [5] = 2000,
        [6] = 3500,
        [7] = 5000,
        [8] = 7500,
        [9] = 15000,
        [10] = 50000,
    },

    XPPerCurrencyTithed = 2, -- XP awarded for each currency item tithed to the Overseer.

    -- XP granted per unit of contraband handed over.
    ContrabandXP = {
        ['weed']    = { label = 'Weed',    xp = 5 },  -- key = inventory item name
        ['meth']    = { label = 'Meth',    xp = 10 },
        ['cocaine'] = { label = 'Cocaine', xp = 15 },
        ['heroin']  = { label = 'Heroin',  xp = 20 },
        ['crack']   = { label = 'Crack',   xp = 30 },
        -- Add more if you want
    },

    -- XP paid out for finishing each storyline chapter.
    ChapterXP = {
        [1] = 50,  -- Breaking Ground
        [2] = 75,  -- Vermin Purge
        [3] = 125, -- Silver Tongue
        [4] = 100, -- Downhill Rush
        [5] = 125, -- Salvage Run
        [6] = 150, -- Mercy Delivery
        [7] = 175, -- Settling Scores
        [8] = 200, -- Bandit Bond
        [9] = 200, -- Trolley Cab
    },
}

-- Overseer (formerly the crowned figurehead) settings
Settings.Overseer = {
    Anchor = vector4(123.7565, -1187.1653, 29.5033, 256.7901), -- Where the Overseer NPC stands (x, y, z, heading)
    Model = "a_m_m_tramp_01",
    DormancyDays = 7,      -- Days of absence before an Overseer loses the seat.
    BuyoutPrice = 250000,  -- Currency cost to walk away from the life (available at rank 10).
}

-- Rank-gated stock for the Overseer's market.
Settings.MarketStock = {
    [1] = {
        {
            name = "cardboard_bed",
            label = "Cardboard Bed",
            description = "A rudimentary sleeping surface pieced together from salvaged cardboard",
            price = 50,
        },
    },
    [2] = {
        {
            name = "rat_treats",
            label = "Rat Treats",
            description = "Morsels that keep rodents away from your belongings",
            price = 150,
        },
        {
            name = "WEAPON_HOBO_PIPE",
            label = "Rusty Pipe",
            description = "A no-frills defence against rodents and other nuisances",
            price = 2000,
        },
    },
    [3] = {
        {
            name = "begging_sign",
            label = "Begging Sign",
            description = "Placard that noticeably improves your panhandling take",
            price = 350,
        },
    },
    [4] = {
        {
            name = "WEAPON_HOBO_STICK",
            label = "Hobo Stick",
            description = "A dependable stave for defence and rodent culling",
            price = 3000,
        },
        {
            name = "sleeping_bag",
            label = "Sleeping Bag",
            description = "Insulated bedroll that grants a far better night's rest",
            price = 500,
        },
    },
    [5] = {
        {
            name = "hobo_gloves",
            label = "Hobo Gloves",
            description = "Thick gloves for handling refuse and hazardous finds",
            price = 1000,
        },
        {
            name = "rat_bait",
            label = "Rat Bait",
            description = "Pungent bait that draws rodents out of hiding",
            price = 1000,
        },
    },
    [6] = {
        {
            name = "hobo_tent",
            label = "Hobo Tent",
            description = "Packable shelter that keeps the weather off your back",
            price = 2500,
        },
        {
            name = "hobo_bottle",
            label = "Hobo Bottle",
            description = "A refillable flask for staying hydrated",
            price = 1000,
        },
    },
    [7] = {
        {
            name = "WEAPON_HOBO_DUSTER",
            label = "Nuts N Bolts",
            description = "Scratch-built knuckle dusters forged from hardware!",
            price = 5000,
        },
    },
    [8] = {
        {
            name = "racoon_treats",
            label = "Raccoon Treats",
            description = "Morsels that win over and pacify wild bandits",
            price = 1000,
        },
    },
    [9] = {
        {
            name = "ration_pack",
            label = "Ration Pack",
            description = "Sealed bundle holding food, water and medical supplies",
            price = 1500,
        },
    },
    [10] = {
        {
            name = "WEAPON_HOBO_TOILET",
            label = "Hobo Toilet",
            description = "A foul porcelain seat, ideal for clobbering!",
            price = 10000,
        },
        {
            name = "WEAPON_HOBO_DIRTYNEEDLE",
            label = "Dirty Needle",
            description = "A vicious implement that leaves foes poisoned",
            price = 50000,
        },
        {
            name = "WEAPON_HOBO_OLDMACHETE",
            label = "Old Machete",
            description = "A corroded blade that still bites deep!",
            price = 20000,
        },
        {
            name = "WEAPON_HOBO_PLANK",
            label = "Broken Plank",
            description = "Timber studded with rusted nails!",
            price = 10000,
        },
        {
            name = "WEAPON_HOBO_REBAR",
            label = "Rebar",
            description = "The original scratch-built street sledgehammer!",
            price = 30000,
        },
    },
}

-- --------------------------------------------------------------------------
--  STORYLINE CHAPTERS
-- --------------------------------------------------------------------------

Settings.Chapters = {
    [1] = {
        name = "Breaking Ground",
        Districts = { -- 5 marked districts to explore
            vector3(363.2059, 258.2572, 102.9974),
            vector3(-348.2647, -103.7508, 45.6639),
            vector3(-1822.6433, -1211.3577, 13.0173),
            vector3(349.5642, -2038.6068, 21.9663),
            vector3(967.3438, -1869.2826, 31.2881),
        },
        DistrictRadius = 50.0,
        description = "Time to get those hands filthy! Roam out and rifle skips across 5 marked districts!",
        descriptionCompleted = "You've earned your stripes out there. Not everybody has the nerve to work those districts.",
    },

    [2] = {
        name = "Vermin Purge",
        repeatable = true,
        InfestedSites = { -- 3 random sites will be picked
            vector3(465.4482, -844.8887, 26.8470),
            vector3(344.3250, -1193.0433, 29.2919),
            vector3(5.7729, -1230.5500, 29.5238),
            vector3(-553.0201, -1713.3948, 18.8629),
            vector3(103.1906, -1811.4915, 26.4984),
            vector3(153.2500, -1187.619, 30.8865),
            vector3(423.5489, -1521.3486, 29.2813),
            vector3(-1179.7357, -904.7003, 13.5206),
            vector3(-361.8564, -961.6348, 31.0806),
            vector3(452.5122, -700.0877, 27.5441),
            vector3(242.8166, -824.6507, 29.9793),
            vector3(337.0464, -1088.4724, 29.4064),
        },
        SiteRadius = 25.0,
        description = "We've got a rodent situation. Head out and thin the population across these 3 sites!",
        descriptionCompleted = "Those rodents won't trouble anyone again. Solid work stamping out the nests. Say the word when you're ready for more.",
    },

    [3] = {
        name = "Silver Tongue",
        repeatable = true,
        TargetEarnings = 1000, -- $1000 to gather
        description = "Time to prove what you're worth. Get out there and talk the city out of as much cash as you can!",
        descriptionCompleted = "Look at you, conjuring money from thin air! That's genuine talent.",
    },

    [4] = {
        name = "Downhill Rush",
        repeatable = true,
        TargetMetres = 1000, -- 1000 metres travelled overall
        description = "Track down a trolley and ride it for 1000 metres overall. Feel the rush of tearing down hillsides street-style! \n\nDedicated derby venues are pinned on your map!",
        descriptionCompleted = "Now THAT was a ride! You've mastered trolley surfing. Very few can say the same.",
    },

    [5] = {
        name = "Salvage Run",
        repeatable = true,
        TargetSalvage = 100, -- 100 salvage pieces
        description = "We're running dry on materials around here. Bring me 100 pieces of salvage and I'll open up the reclaimer for you.",
        descriptionCompleted = "One man's refuse is our fortune. You've a sharp eye for worthwhile salvage. Use the reclaimer whenever you please.",
    },

    [6] = {
        name = "Mercy Delivery",
        TargetContainers = 100,
        ParcelChance = 5, -- Percent chance of turning up the parcel once the quota is met
        description = "My child, the street sickness has me. I need a 'Medical Care Package' or I'm finished. Rifle skips until you turn one up and bring it back to me.. Hurry, my time is short..",
        descriptionCompleted = "This parcel will surely save me. Precious few care about our little kingdom, but you came through, kid.",
    },

    [7] = {
        name = "Settling Scores",
        RivalAnchor = vector4(1422.4708, 6349.4858, 23.9850, 274.0450),
        description = "Listen close. This one matters. There was a drifter called 'Samuel' around here. Word is he's been lifting from us! Go set that punk straight!",
        descriptionCompleted = "You defended our name and came out on top. That kind of loyalty is rare.",
    },

    [8] = {
        name = "Bandit Bond",
        description = "Word is the masked bandits have moved in thick around here. They're dragging off our refuse and raiding our food. Take these treats, track one down and see if it'll warm to you.",
        descriptionCompleted = "You won over one of those wild things? Well... colour me impressed!",
        DenSites = {
            vector3(-90.0, -100.0, 30.0),
            vector3(-120.0, -90.0, 30.0),
            vector3(-140.0, -110.0, 30.0),
        },
    },

    [9] = {
        name = "Trolley Cab",
        description = "Those trolleys we shove around? They'll move people across town far quicker. I've got folks queued up for a lift. Get them where they need to be!",
        descriptionCompleted = "That's how you shuttle folk from A to B! Come see me any time you want another run.",
        repeatable = true,
        CollectionPoints = {
            vector4(-55.0349, -1213.8828, 28.7008, 80.5107),
            vector4(-85.8015, -1456.9954, 33.0552, 348.2387),
            vector4(71.0508, -1566.6477, 29.5978, 56.4699),
            vector4(474.6123, -1454.2571, 29.2921, 346.6114),
            vector4(113.1992, -1526.4160, 30.0273, 269.0996),
            vector4(528.0711, -1248.9755, 18.6323, 174.9017),
            vector4(712.4208, -1256.7214, 26.3524, 162.4095),
            vector4(689.0983, -1016.3560, 22.6134, 275.1468),
            vector4(734.5854, -861.9752, 24.7771, 185.4494),
            vector4(455.7884, -869.9780, 27.2786, 12.8067),
            vector4(252.0802, -1073.1123, 29.3775, 21.8393),
            vector4(257.1402, -1108.6440, 29.7341, 186.2960),
            vector4(119.4286, -1578.1511, 29.6025, 335.2963),
            vector4(291.1413, -1234.0590, 29.4379, 79.7148),
            vector4(33.0000, -1433.9170, 30.4820, 238.2740),
            vector4(-21.3212, -1534.7759, 30.1945, 325.4472),
            vector4(-250.3188, -954.5213, 31.2200, 265.7514),
            vector4(-348.8181, -815.8940, 31.5544, 184.2784),
            vector4(696.7436, -1016.4307, 22.7127, 86.6200),
        },
        DeliveryPoints = {
            vector4(-55.0349, -1213.8828, 28.7008, 80.5107),
            vector4(-85.8015, -1456.9954, 33.0552, 348.2387),
            vector4(71.0508, -1566.6477, 29.5978, 56.4699),
            vector4(474.6123, -1454.2571, 29.2921, 346.6114),
            vector4(113.1992, -1526.4160, 30.0273, 269.0996),
            vector4(528.0711, -1248.9755, 18.6323, 174.9017),
            vector4(712.4208, -1256.7214, 26.3524, 162.4095),
            vector4(689.0983, -1016.3560, 22.6134, 275.1468),
            vector4(734.5854, -861.9752, 24.7771, 185.4494),
            vector4(455.7884, -869.9780, 27.2786, 12.8067),
            vector4(252.0802, -1073.1123, 29.3775, 21.8393),
            vector4(257.1402, -1108.6440, 29.7341, 186.2960),
            vector4(119.4286, -1578.1511, 29.6025, 335.2963),
            vector4(291.1413, -1234.0590, 29.4379, 79.7148),
            vector4(33.0000, -1433.9170, 30.4820, 238.2740),
            vector4(-21.3212, -1534.7759, 30.1945, 325.4472),
            vector4(-250.3188, -954.5213, 31.2200, 265.7514),
            vector4(-348.8181, -815.8940, 31.5544, 184.2784),
            vector4(696.7436, -1016.4307, 22.7127, 86.6200),
        },
        Payout = {
            XP = 50,
            Currency = 25,
        },
        MinutesAllowed = 10, -- Minutes permitted per delivery
    },

    [10] = { -- Chapter 10 hosts the Corner Grinder contracts, unlocked at assorted ranks
        name = "Corner Grinder",
        unlockRank = 6,
        description = 'Time to grind out that street credit! Take a look at the fresh contracts I have going.',
        Contracts = {
            {
                name = "Panhandling Trial",
                rank = 6,
                type = "panhandle_trial",
                description = "Gather $5000 through panhandling.",
                target = 5000,
                currencyReward = 100,
            },
            {
                name = "Gather 250 bottle caps",
                rank = 7,
                type = "currency_haul",
                description = "Comb the city and pull 250 bottle caps out of skips.",
                target = 250,
                currencyReward = 100,
            },
            {
                name = "Trolley Derby Cup",
                rank = 8,
                type = "derby_cup",
                description = "Run a Trolley Derby cup with at least 5 riders!",
                target = 5, -- Minimum entrants
                currencyReward = 200,
            },
            {
                name = "Alley Bowling",
                rank = 9,
                type = "alley_bowling",
                description = "Run an Alley Bowling match with at least 5 players!",
                target = 5, -- Minimum entrants
                currencyReward = 150,
            },
            {
                name = "Trolley Cab",
                rank = 10,
                type = "trolley_cab",
                description = "Run cab contracts and collect your fare!",
            },
        },
    },

    [11] = {
        name = "The Final Gauntlet",
        XPtoUnlock = 500000,
        repeatable = true,
        ArenaAnchor = vector4(134.7184, -1184.7572, 29.5015, 156.0000),
    },
}

-- --------------------------------------------------------------------------
--  SURVIVAL GEAR BEHAVIOUR
-- --------------------------------------------------------------------------

Settings.GearBehaviour = {
    -- Rank 1
    cardboard_bed = {
        model = "prop_rub_cardpile_05",
        recovery = 1, -- HP restored per tick
    },

    -- Rank 2
    rat_treats = {
        charges = 1, -- Number of rodent attacks it wards off
    },

    -- Rank 4
    sleeping_bag = {
        model = "prop_skid_sleepbag_1",
        recovery = 2, -- HP restored per tick
    },

    -- Rank 6
    hobo_tent = {
        model = "prop_tent_01",
        recovery = 3, -- HP restored per tick
    },

    -- Rank 7
    hobo_bottle = {
        charges = 3,  -- Number of sips
        hydration = 25, -- Thirst restored per sip
    },

    -- Rank 8
    racoon_treats = {
        minutes = 30, -- Minutes a bandit companion sticks around
    },

    -- Rank 9
    ration_pack = {
        yields = {
            { item = "burger",  max = 3 },
            { item = "water",   max = 2 },
            { item = "bandage", max = 1 },
        },
    },
}

-- --------------------------------------------------------------------------
--  PANHANDLING & WINDSCREEN WASHING
-- --------------------------------------------------------------------------

Settings.Panhandling = {
    Command = "beg",
    BrushOffChance = 65,      -- Percent chance of being flat-out ignored
    MaxBasePayout = 25,       -- Highest payout before multipliers
    MaxFinalPayout = 100,     -- Hard ceiling once multipliers are applied
    SignBonus = 1.5,          -- 1.5x payout while holding a placard
    CommittedBonus = 2,       -- 2x payout for committed street dwellers (holding the job)
    HostileChance = 10,       -- Percent chance a pedestrian turns nasty
    CooldownSeconds = 10,
    ShowProgressBar = false,  -- Display a progress bar while panhandling

    -- Windscreen washing --
    WashingEnabled = true,      -- Allow players to wash vehicle windscreens
    MinWashPayout = 1,
    MaxWashPayout = 50,
    MinWashSeconds = 7,
    MaxWashSeconds = 15,
    HostileWashChance = 50,     -- Percent chance the driver turns nasty mid-wash
}

-- --------------------------------------------------------------------------
--  RODENT BAIT
-- --------------------------------------------------------------------------

Settings.BaitLifetimeSeconds = 60

-- --------------------------------------------------------------------------
--  SALVAGE & RECLAIMER
-- --------------------------------------------------------------------------

-- Extra salvage pieces surfaced while rifling containers — feedstock for the reclaimer.
Settings.SalvageTiers = {
    Tiers = {
        -- Common tier
        common = {
            chance = 50,
            items = {
                { name = Settings.CurrencyItem, amount = { 1, 1 }, chance = 20 }, -- required for progression
                { name = "wooden_junk",         amount = { 1, 3 }, chance = 60 },
                { name = "copper_junk",         amount = { 1, 2 }, chance = 60 },
            },
        },
        -- Uncommon tier
        uncommon = {
            chance = 35,
            items = {
                { name = Settings.CurrencyItem, amount = { 1, 2 }, chance = 20 },
                { name = "scrap_junk",          amount = { 1, 3 }, chance = 40 },
                { name = "cloth_junk",          amount = { 1, 3 }, chance = 40 },
                { name = "plastic_junk",        amount = { 1, 3 }, chance = 40 },
                { name = "electronic_junk",     amount = { 1, 3 }, chance = 10 },
            },
        },
        -- Rare tier
        rare = {
            chance = 25,
            items = {
                { name = Settings.CurrencyItem, amount = { 2, 3 }, chance = 50 }, -- required for progression
                { name = "electronic_junk",     amount = { 1, 2 }, chance = 30 },
                { name = "broken_phone",        amount = { 1, 1 }, chance = 20 },
            },
        },
        -- Exceptional tier
        very_rare = {
            chance = 15,
            items = {
                { name = Settings.CurrencyItem, amount = { 3, 4 }, chance = 40 }, -- required for progression
                { name = "food_waste",          amount = { 1, 1 }, chance = 10 },
                { name = "medical_waste",       amount = { 1, 1 }, chance = 5 },
            },
        },
    },
}

Settings.ReclaimerSites = {
    [1] = {
        coords = vector3(175.5112, -1200.5493, 29.2951),
        heading = 181.5229,
    },
}

Settings.ReclaimerBehaviour = {
    cycleSeconds = 5,        -- Seconds a reclaim cycle takes
    chapterGated = false,    -- false = the reclaimer is open to everyone from the start
}

-- PLEASE NOTE: change each `output` to an item that genuinely exists on your server.
Settings.ReclaimRecipes = {
    [Settings.CurrencyItem] = { output = "metalscrap",       min = 1, max = 3 },
    ["scrap_junk"]          = { output = "metalscrap",       min = 1, max = 2 },
    ["cloth_junk"]          = { output = "cloth",            min = 1, max = 2 },
    ["plastic_junk"]        = { output = "plastic",          min = 1, max = 2 },
    ["electronic_junk"]     = { output = "electronic_scrap", min = 1, max = 2 },
    ["broken_phone"]        = { output = "electronic_scrap", min = 1, max = 2 },
    ["food_waste"]          = { output = "compost",          min = 1, max = 2 },
    ["medical_waste"]       = { output = "bandage",          min = 1, max = 2 },
    ["paper_junk"]          = { output = "paper",            min = 1, max = 2 },
    ["glass_junk"]          = { output = "glass",            min = 1, max = 2 },
    ["wooden_junk"]         = { output = "wood",             min = 1, max = 2 },
}

-- --------------------------------------------------------------------------
--  TROLLEY DERBY
-- --------------------------------------------------------------------------

Settings.TrolleyDerby = {
    AlwaysShowBlips = true, -- false = venue blips only appear during the Downhill Rush chapter
    BlipSize = 0.8,
    Venues = {
        [1] = {
            name = "Downhill Trail",
            npc = vector4(1424.4292, -858.0736, 111.7589, 79.1301),
            trolleySpot = vector4(1422.9073, -858.9063, 111.6167, 283.2439),
            launchPoint = vector4(1420.2488, -858.6202, 110.3647, 100.0),
            launchRadius = 10.0,
            revealLaunchZone = true,
        },
        [2] = {
            name = "Rockford Hills",
            npc = vector4(-580.7780, 914.7377, 229.1532, 132.8778),
            trolleySpot = vector4(-582.0977, 915.7252, 229.1067, 87.6015),
            launchPoint = vector4(-583.7144, 912.3519, 226.6051, 148.9423),
            launchRadius = 25.0,
            revealLaunchZone = true,
        },
        [3] = {
            name = "Observatory",
            npc = vector4(-436.8737, 1058.2284, 319.9926, 189.9796),
            trolleySpot = vector4(-438.5188, 1057.2852, 320.2427, 113.5812),
            launchPoint = vector4(-436.8737, 1058.2284, 318.9926, 189.9796),
            launchRadius = 25.0,
            revealLaunchZone = true,
        },
        [4] = {
            name = "Mount Chiliad",
            npc = vector4(498.5247, 5605.1328, 797.9094, 186.4537),
            trolleySpot = vector4(500.1170, 5605.1621, 797.9094, 270.1760),
            launchPoint = vector4(498.5247, 5605.1328, 796.9094, 186.4537),
            launchRadius = 40.0,
            revealLaunchZone = true,
        },
        [5] = {
            name = "Chiliad Trail",
            npc = vector4(-89.5027, 4950.2090, 385.4798, 239.1310),
            trolleySpot = vector4(-88.6888, 4950.9355, 385.9283, 221.7422),
            launchPoint = vector4(-89.5027, 4950.2090, 385.4798, 239.1310),
            launchRadius = 25.0,
            revealLaunchZone = true,
        },
        [6] = {
            name = "Thrill Valley",
            npc = vector4(1783.2324, -250.6645, 292.1313, 123.0405),
            trolleySpot = vector4(1782.6484, -248.8291, 292.0567, 91.9719),
            launchPoint = vector4(1783.2324, -250.6645, 292.1313, 123.0405),
            launchRadius = 25.0,
            revealLaunchZone = true,
        },
        -- Add more venues if you like
    },
}

-- --------------------------------------------------------------------------
--  TAINTED ARMAMENTS
-- --------------------------------------------------------------------------

Settings.TaintedArms = {
    [1] = {
        weapon = -1638292314, -- RAT STICK
        tickDamage = 1,
        durationSeconds = 60,
        cureItem = "rabies_shot",
    },
    [2] = {
        weapon = `WEAPON_HOBO_DIRTYNEEDLE`,
        tickDamage = 2,
        durationSeconds = 600,
        cureItem = "tetanus_shot",
    },
}

-- --------------------------------------------------------------------------
--  ALLEY BOWLING
-- --------------------------------------------------------------------------

Settings.AlleyBowling = {
    Enabled = true,
    MaxEntrants = 10,
    MinEntrants = 1,
    ScorePerPin = 1,
    PerfectBonus = 3,
    VictorXP = 10,            -- XP multiplied by the number of entrants
    ThrowLineRadius = 15.0,   -- Max distance from the throwing mark before a foul is called
    PinGap = 0.8,

    Venues = {
        {
            name = "Downtown Lanes",
            laneBearing = -230.0,                                          -- Rotation of the bowling lane
            revealFoulZone = true,
            npc = vector4(222.3060, -1772.6326, 29.1146, 332.5828),        -- Compere NPC
            lane = vector4(229.5850, -1775.9917, 28.8357, 229.7295),       -- Centre of the lane
            pinCluster = vector4(237.4855, -1782.4124, 28.8041, 43.8897),  -- Centre of the pin formation
            throwMark = vector4(218.3922, -1766.5566, 29.0030, 228.8056),  -- Where players must throw from
            foulLine = vector4(230.6213, -1774.8726, 28.7465, 320.2130),   -- Line players must not cross
            trolleySpawn = vector4(219.4123, -1767.5861, 29.0150, 224.3853), -- Where the trolley appears
        },
        -- Add more if you like
    },

    CompereModel = "a_m_m_skidrow_01",
    HeadPinModel = "a_m_m_trampbeac_01", -- Model used for the NPC at the head of the formation
    PinModels = {
        'a_m_m_trampbeac_01',
        'a_f_m_skidrow_01',
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
    },
}

-- --------------------------------------------------------------------------
--  ARMAMENTS HANDED TO HOSTILE VAGRANTS
-- --------------------------------------------------------------------------

Settings.VagrantArmaments = {
    Thresholds = {
        Rare = 80,
        Uncommon = 65,
        Common = 20,
    },

    Loadouts = {
        Rare     = { name = "WEAPON_PISTOL", ammo = 12 }, -- Rounds issued with the weapon
        Uncommon = { name = "WEAPON_KNIFE",  ammo = 0 },  -- Melee needs no ammunition
        Common   = { name = "WEAPON_BOTTLE", ammo = 0 },  -- Melee needs no ammunition
    },

    StreetArms = {
        enabled = true,
        chance = 20, -- Percent chance a street-made weapon is issued instead of the standard loadouts
        weapons = {
            "WEAPON_HOBO_PIPE",
            "WEAPON_HOBO_PLANK",
            "WEAPON_HOBO_OLDMACHETE",
            "WEAPON_HOBO_STICK",
            "WEAPON_HOBO_REBAR",
        },
    },
}
