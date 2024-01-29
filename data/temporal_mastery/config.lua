
mods.temporal = {}

mods.temporal.config = {}

local config = mods.temporal.config

config.TEMPORAL_SPEEDUP_DURATIONS = {10, 7, 5, 2}
config.TEMPORAL_SLOWDOWN_DURATIONS = {10, 15, 20, 25}

config.WEAPON_SPEEDUP_RATES = {0.25, 0.7, 1.5, 5.0}
config.WEAPON_SLOWDOWN_RATES = {-0.5, -0.5, -0.5, -0.5}

config.ARTILLERY_SPEEDUP_RATES = {0.5, 1.4, 3.0, 10.0}
config.ARTILLERY_SLOWDOWN_RATES = {-0.75, -0.75, -0.75, -0.75}

config.SHIELD_SPEEDUP_RATES = {0.4, 1.0, 2.0, 6.5}
config.SHIELD_SLOWDOWN_RATES = {-0.5, -0.5, -0.5, -0.5}

config.SUPERSHIELD_CHARGE_RATES = {0.15, 0.35, 0.7, 2.25}

config.OXYGEN_SPEEDUP_RATES = {1.0, 3.0, 7.0, 15.0}
config.OXYGEN_SLOWDOWN_RATES = {-0.75, -0.88, -0.94, -0.97}

config.BONUSPOWER_CHARGE_RATES = {0.15, 0.35, 0.7, 2.25}

config.IONLOCK_SPEEDUP_RATES = {0.5, 1.43, 3.0, 10.0}
config.IONLOCK_SLOWDOWN_RATES = {-0.5, -0.5, -0.5, -0.5}

config.FTL_SPEEDUP_RATES = {0.28, 1.56, 4.12, 9.24}
config.FTL_SLOWDOWN_RATES = {-0.5, -0.5, -0.5, -0.5}

config.SPACEDRONE_SPEEDUP_FACTORS = {1.2, 1.7, 2.4, 6.0}
config.CREWDRONE_SPEEDUP_FACTORS = {1.75, 2.86, 4.5, 12.5}

config.MEDBAY_SPEEDUP_FACTORS = {1.75, 2.86, 4.5, 12.5}
config.TELEPORTER_SPEEDUP_FACTORS = {1.75, 2.86, 4.5, 12.5}

config.player = {
    bonus_power = 0,
    temporal_reverser = 0,
    bpgen_speed = 0,
    temporal_stun = 0,
    drone_amplifier = 0,
    temporal_bot = 0,
    temporal_teleporter = 0,
    selective_acceleration = 0,
    temporal_ftl = 0,
    infinite_shield = 0
}

local playerConfig = config.player

local configLoaded = true
script.on_init(function()
    configLoaded = false
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if configLoaded then
        return
    end
    for name, _ in pairs(playerConfig) do
        playerConfig[name] = Hyperspace.playerVariables['_tm_'..name]
    end
    configLoaded = true
end)

config.setPlayerConfig = function(name, value)
    Hyperspace.playerVariables['_tm_'..name] = value
    playerConfig[name] = value
end

script.on_game_event('_TM_INSTALL_REVERSER', false, function() config.setPlayerConfig('temporal_reverser', 1) end)
script.on_game_event('_TM_INSTALL_REACTOR', false, function() config.setPlayerConfig('bpgen_speed', playerConfig.bpgen_speed + 1) end)
script.on_game_event('_TM_INSTALL_STUNNER', false, function() config.setPlayerConfig('temporal_stun', 1) end)

script.on_game_event('_TM_INSTALL_DRONE_AMPLIFIER', false, function() config.setPlayerConfig('drone_amplifier', 1) end)
script.on_game_event('_TM_INSTALL_TEMPORAL_BOT', false, function() config.setPlayerConfig('temporal_bot', 1) end)
script.on_game_event('_TM_INSTALL_TEMPORAL_TELEPORTER', false, function() config.setPlayerConfig('temporal_teleporter', 1) end)
script.on_game_event('_TM_INSTALL_SELECTIVE_ACCELERATION', false, function() config.setPlayerConfig('selective_acceleration', 1) end)
script.on_game_event('_TM_INSTALL_TEMPORAL_FTL', false, function() config.setPlayerConfig('temporal_ftl', 1) end)
script.on_game_event('_TM_INSTALL_INFINITE_SHIELD', false, function() config.setPlayerConfig('infinite_shield', 1) end)
