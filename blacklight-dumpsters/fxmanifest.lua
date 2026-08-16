--[[
    ██████╗ ██╗      █████╗  ██████╗██╗  ██╗██╗     ██╗ ██████╗ ██╗  ██╗████████╗
    ██╔══██╗██║     ██╔══██╗██╔════╝██║ ██╔╝██║     ██║██╔════╝ ██║  ██║╚══██╔══╝
    ██████╔╝██║     ███████║██║     █████╔╝ ██║     ██║██║  ███╗███████║   ██║
    ██╔══██╗██║     ██╔══██║██║     ██╔═██╗ ██║     ██║██║   ██║██╔══██║   ██║
    ██████╔╝███████╗██║  ██║╚██████╗██║  ██╗███████╗██║╚██████╔╝██║  ██║   ██║
    ╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝

    BlackLight Dumpsters — Street Survival & Scavenging Framework
]]

fx_version 'cerulean'
game 'gta5'

author 'BlackLight Development'
description 'BlackLight Dumpsters — a complete street-survival, scavenging and vagrant progression framework featuring container looting, cart racing, alley bowling, cart transport contracts, tainted armaments and a full reputation ladder.'
repository 'https://github.com/BlackLight-Development/blacklight-dumpsters'
version '3.0.0'

lua54 'yes'
use_experimental_fxv2_oal 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    '@blacklight-bridge/bridge.lua',
    'shared/settings.lua',
    'shared/settings_progression.lua',
    'shared/locale.lua',
}

client_scripts {
    'client/*.lua',
}

server_scripts {
    'server/*.lua',
}

escrow_ignore {
    'shared/*.lua',
    'client/customisable.lua',
}

dependencies {
    'ox_lib',
    'blacklight-bridge',
    'blacklight-interact',
}

bridge 'blacklight-bridge'

-- bridge_disable { 'target' } -- UNCOMMENT THIS IF YOU HAVE NO TARGET RESOURCE INSTALLED AND WOULD RATHER USE BLACKLIGHT-INTERACT'S 0.00MS "PRESS E" DETECTION - ALSO SET Settings.UseTargetSystem TO FALSE IN shared/settings_progression.lua

dependency '/assetpacks'
