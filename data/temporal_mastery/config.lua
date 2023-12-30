
mods.tmConfig = {}

local tmConfig = mods.tmConfig

tmConfig.TEMPORAL_SPEEDUP_DURATIONS = {10, 7, 5, 2}
tmConfig.TEMPORAL_SLOWDOWN_DURATIONS = {10, 15, 20, 25}

tmConfig.WEAPON_SPEEDUP_FACTORS = {0.25, 0.7, 1.5, 5.0}
tmConfig.WEAPON_SLOWDOWN_FACTORS = {-0.5, -0.5, -0.5, -0.5}

tmConfig.ARTILLERY_SPEEDUP_FACTORS = {0.5, 1.4, 3.0, 10.0}
tmConfig.ARTILLERY_SLOWDOWN_FACTORS = {-0.75, -0.75, -0.75, -0.75}

tmConfig.SHIELD_SPEEDUP_FACTORS = {0.4, 1.0, 2.0, 6.5}
tmConfig.SHIELD_SLOWDOWN_FACTORS = {-0.5, -0.5, -0.5, -0.5}

tmConfig.SUPERSHIELD_CHARGE_RATES = {0.15, 0.35, 0.7, 2.25}

tmConfig.OXYGEN_SPEEDUP_FACTORS = {1.0, 3.0, 7.0, 15.0}
tmConfig.OXYGEN_SLOWDOWN_FACTORS = {-0.75, -0.88, -0.94, -0.97}

tmConfig.BONUSPOWER_CHARGE_RATES = {0.15, 0.35, 0.7, 2.25}

tmConfig.IONLOCK_SPEEDUP_FACTORS = {0.5, 1.43, 3.0, 10.0}
tmConfig.IONLOCK_SLOWDOWN_FACTORS = {-0.5, -0.5, -0.5, -0.5}

tmConfig.FTL_SPEEDUP_FACTORS = {0.28, 1.56, 4.12, 9.24}
tmConfig.FTL_SLOWDOWN_FACTORS = {-0.5, -0.5, -0.5, -0.5}

tmConfig.CREWDRONE_SPEEDUP_FACTORS = {2.0, 2.86, 4.0, 10.0}
tmConfig.CREWDRONE_SLOWDOWN_FACTORS = {0.5, 0.5, 0.5, 0.5}

tmConfig.TELEPORT_SPEEDUP_FACTORS = {2.0, 4.0, 8.0, 16.0}

local playerConfigList = {
    bonus_power = 0,
    temporal_reverser = 0,
    bpgen_speed = 0,
    temporal_stun = 0
}

script.on_init(function()
    for name, _ in pairs(playerConfigList) do
        playerConfigList[name] = Hyperspace.playerVariables['__TM__'..name]
    end
end)

tmConfig.setPlayerConfig = function(name, value)
    Hyperspace.playerVariables['__TM__'..name] = value
    playerConfigList[name] = value
end

tmConfig.player = playerConfigList

script.on_game_event('_TM_INSTALL_REVERSER', false, function() tmConfig.setPlayerConfig('temporal_reverser', 1) end)
script.on_game_event('_TM_INSTALL_REACTOR', false, function() tmConfig.setPlayerConfig('bpgen_speed', 1) end)
script.on_game_event('_TM_INSTALL_STUNNER', false, function() tmConfig.setPlayerConfig('temporal_stun', 1) end)
