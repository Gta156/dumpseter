fx_version 'cerulean'
game 'gta5'

author 'BlackLight Development'
description 'BlackLight Scavenging — street-level survival, salvage economy, trolley derby, alley bowling and street warden progression.'
version '3.0.0'

lua54 'yes'
use_experimental_fxv2_oal 'yes'

-- NOTE: load order is explicit and MUST stay this way.
-- config_core.lua declares `Config = {}` and therefore has to be parsed before
-- any other shared file that writes into that table. The original resource relied
-- on alphabetical glob ordering for this, which silently breaks the moment a file
-- is renamed. Listing the files by hand removes that trap.
shared_scripts {
    '@ox_lib/init.lua',
    '@envi-bridge/bridge.lua',
    'shared/config_core.lua',
    'shared/config_advanced.lua',
    'shared/lang.lua',
}

client_scripts {
    'client/rummage.lua',
    'client/integrations.lua',
    'client/critters.lua',
    'client/gear.lua',
    'client/toxins.lua',
    'client/panhandle.lua',
    'client/hustles.lua',
    'client/reclaim_units.lua',
    'client/trolley_derby.lua',
    'client/alley_bowling.lua',
    'client/fare_runs.lua',
    'client/warden_hub.lua',
    'client/warden_gauntlet.lua',
}

server_scripts {
    -- security.lua defines the global `Security` helper used by every other server file
    -- to validate client input, so it must be loaded first.
    'server/security.lua',
    'server/progression.lua',
    'server/rummage.lua',
    'server/gear.lua',
    'server/market.lua',
    'server/toxins.lua',
    'server/hustles.lua',
    'server/contracts.lua',
    'server/progress_loot.lua',
    'server/reclaim_units.lua',
    'server/trolley_derby.lua',
    'server/alley_bowling.lua',
}

escrow_ignore {
    'shared/*.lua',
    'client/integrations.lua',
}

dependencies {
    'ox_lib',
    'envi-bridge',
    'envi-interact',
}

bridge 'envi-bridge'

-- bridge_disable { 'target' } -- UNCOMMENT IF YOU DO NOT HAVE A TARGET RESOURCE INSTALLED AND WANT TO USE
-- ENVI-INTERACT'S 0.00MS PRESS E SYSTEM INSTEAD - ALSO SET Config.Target = false IN shared/config_advanced.lua

dependency '/assetpacks'
