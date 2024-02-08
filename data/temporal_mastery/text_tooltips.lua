
if not(mods.temporal and mods.temporal.config) then
    error("Temporal Mastery scripts are loaded in wrong order.")
end

local tmConfig = mods.temporal.config

mods.temporal.tooltip = {}

local tooltip = mods.temporal.tooltip

local defaultText = {
    __index = function(texts)
        return texts['']
    end,
    __call = function(texts, lang, ...)
        return string.format(texts[lang], ...)
    end
}

local function text(texts)
    setmetatable(texts, defaultText)
    return texts
end

local word = {}
word.active = text{
    [''] = 'Active',
    ['zh-Hans'] = '已生效'
}
word.inactive = text{
    [''] = 'Inactive',
    ['zh-Hans'] = '未生效'
}

local title = {}
title.speedup = text{
    [''] = 'Level %d Speed Up',
    ['zh-Hans'] = '%d级时流加速'
}
title.slowdown = text{
    [''] = 'Level %d Slow Down',
    ['zh-Hans'] = '%d级时流减速'
}

local entry = {}
entry.no_effects = text{
    [''] = '- No special effects',
    ['zh-Hans'] = '- 无特殊效果'
}

entry.ion_speedup = text{
    [''] = '- (%s) Speeds up ion lock timer by %.0f%%',
    ['zh-Hans'] = '- (%s) 离子效果加速%.0f%%'
}
entry.ion_slowdown = text{
    [''] = '- (%s) Slows down ion lock timer by %.0f%%',
    ['zh-Hans'] = '- (%s) 离子效果减速%.0f%%'
}

local function getIonTooltip(sys, speed, lang)
    local isActive = sys.iLockCount > 0 and word.active[lang] or word.inactive[lang]
    if speed > 0 then
        return entry.ion_speedup(lang, isActive, tmConfig.IONLOCK_SPEEDUP_RATES[speed] * 100)
    else
        return entry.ion_slowdown(lang, isActive, -tmConfig.IONLOCK_SLOWDOWN_RATES[-speed] * 100)
    end
end

entry.shields_speedup = text{
    [''] = '- Speeds up shield recharge by %.0f%%',
    ['zh-Hans'] = '- 护盾充能速度提高%.0f%%'
}
entry.shields_speedup_energy = text{
    [''] = '- Charges energy shields when shields are fully powered and fully charged',
    ['zh-Hans'] = '- 当护盾完全供能且完全充能时，为能量护盾充能'
}
entry.shields_speedup_infshield = text{
    [''] = '- [Infinite Shield] Unlimited recharge of energy shields',
    ['zh-Hans'] = '- [无限护盾] 能量护盾可无限充能'
}
entry.shields_slowdown = text{
    [''] = '- Slows down shield recharge by %.0f%%',
    ['zh-Hans'] = '- 护盾充能速度减慢%.0f%%'
}

local function getShieldsTooltip(iShipId, sys, speed, lang)
    local str = ''
    if speed > 0 then
        if tmConfig.ships[iShipId].infinite_shield <= 0 then
            str = str .. entry.shields_speedup(lang, tmConfig.SHIELD_SPEEDUP_RATES[speed] * 100) .. '\n'
            str = str .. entry.shields_speedup_energy[lang] .. '\n'
        else
            str = str .. entry.shields_speedup_infshield[lang] .. '\n'
        end
    else
        str = str .. entry.shields_slowdown(lang, -tmConfig.SHIELD_SLOWDOWN_RATES[-speed] * 100) .. '\n'
    end
    return str .. getIonTooltip(sys, speed, lang)
end

entry.engines_speedup = text{
    [''] = '- Increases ship evasion rate by %.0f%%',
    ['zh-Hans'] = '- 舰船闪避率提高%.0f%%'
}
entry.engines_speedup_ftl = text{
    [''] = '- [Temporal FTL Booster] Increases FTL drive recharge speed by %.0f%%',
    ['zh-Hans'] = '- [超光速引擎加速器] 超光速引擎充能速度提高%.0f%%'
}
entry.engines_slowdown = text{
    [''] = '- Decreases ship evasion rate by %.0f%%',
    ['zh-Hans'] = '- 舰船闪避率降低%.0f%%'
}
entry.engines_slowdown_ftl = text{
    [''] = '- [Temporal FTL Booster] Decreases FTL drive recharge speed by %.0f%%',
    ['zh-Hans'] = '- [超光速引擎加速器] 超光速引擎充能速度降低%.0f%%'
}

local function getEnginesTooltip(iShipId, sys, speed, lang)
    local str = ''
    local power = sys:GetEffectivePower()
    local enginesDodge = {5, 10, 15, 20, 25, 28, 31, 35, [0] = 0}
    if speed > 0 then
        str = str .. entry.engines_speedup(lang, enginesDodge[power] * speed * 0.6) .. '\n'
        if tmConfig.ships[iShipId].temporal_ftl > 0 then
            str = str .. entry.engines_speedup_ftl(lang, tmConfig.FTL_SPEEDUP_RATES[speed] * 100) .. '\n'
        end
    else
        str = str .. entry.engines_slowdown(lang, -enginesDodge[power] * speed / 3) .. '\n'
        if tmConfig.ships[iShipId].temporal_ftl > 0 then
            str = str .. entry.engines_slowdown_ftl(lang, -tmConfig.FTL_SLOWDOWN_RATES[-speed] * 100) .. '\n'
        end
    end
    return str .. getIonTooltip(sys, speed, lang)
end

entry.oxygen_speedup = text{
    [''] = '- Increases oxygen refill rate by %.0f%%',
    ['zh-Hans'] = '- 氧气回复速率提高%.0f%%'
}
entry.oxygen_slowdown = text{
    [''] = '- Decreases oxygen refill rate by %.0f%%',
    ['zh-Hans'] = '- 氧气回复速率减慢%.0f%%'
}

local function getOxygenTooltip(iShipId, sys, speed, lang)
    local str = ''
    local power = sys:GetEffectivePower()
    if power > 0 then
        if speed > 0 then
            str = str .. entry.oxygen_speedup(lang, tmConfig.OXYGEN_SPEEDUP_RATES[speed] * power * 100) .. '\n'
        else
            str = str .. entry.oxygen_slowdown(lang, -tmConfig.OXYGEN_SLOWDOWN_RATES[-speed] / power * 100) .. '\n'
        end
    end
    return str .. getIonTooltip(sys, speed, lang)
end

entry.weapons_speedup = text{
    [''] = '- Speeds up weapon recharge by %.0f%%',
    ['zh-Hans'] = '- 武器充能速率提高%.0f%%'
}
entry.weapons_speedup_selective = text{
    [''] = '- [Selective Acceleration] Speeds up recharge of the weapon in the first slot by %.0f%%',
    ['zh-Hans'] = '- [选择性加速] 第一个槽位的武器充能速率提高%.0f%%'
}
entry.weapons_slowdown = text{
    [''] = '- Slows down weapon recharge by %.0f%%',
    ['zh-Hans'] = '- 武器充能速率降低%.0f%%'
}

local function getWeaponsTooltip(iShipId, sys, speed, lang)
    local str = ''
    if speed > 0 then
        if tmConfig.ships[iShipId].selective_acceleration <= 0 then
            str = str .. entry.weapons_speedup(lang, tmConfig.WEAPON_SPEEDUP_RATES[speed] * 100) .. '\n'
        else
            str = str .. entry.weapons_speedup_selective(lang, tmConfig.WEAPON_SPEEDUP_RATES[speed] * 200) .. '\n'
        end
    else
        str = str .. entry.weapons_slowdown(lang, -tmConfig.WEAPON_SLOWDOWN_RATES[-speed] * 100) .. '\n'
    end
    return str .. getIonTooltip(sys, speed, lang)
end

entry.drones_speedup = text{
    [''] = '- Speeds up crew drones at %.2fx speed',
    ['zh-Hans'] = '- 以%.2f倍的速率加速船员无人机'
}
entry.drones_speedup_space = text{
    [''] = '- Speeds up space drones at %.2fx speed',
    ['zh-Hans'] = '- 以%.2f倍的速率加速太空无人机'
}
entry.drones_speedup_amplifier = text{
    [''] = '- [Drone Amplifier] Projectiles shot by space drones are multipied by %d',
    ['zh-Hans'] = '- [无人机功放器] 太空无人机的射弹变为%d倍'
}
entry.drones_slowdown = text{
    [''] = '- Reduces maximum system power by %d bar',
    ['zh-Hans'] = '- 系统最大能级降低%d格'
}

local function getDronesTooltip(iShipId, sys, speed, lang)
    local str = ''
    if speed > 0 then
        str = str .. entry.drones_speedup(lang, tmConfig.CREWDRONE_SPEEDUP_FACTORS[speed]) .. '\n'
        if tmConfig.ships[iShipId].drone_amplifier <= 0 then
            str = str .. entry.drones_speedup_space(lang, tmConfig.SPACEDRONE_SPEEDUP_FACTORS[speed]) .. '\n'
        else
            str = str .. entry.drones_speedup_amplifier(lang, speed) .. '\n'
        end
    else
        str = str .. entry.drones_slowdown(lang, -speed) .. '\n'
    end
    return str .. getIonTooltip(sys, speed, lang)
end

entry.medbay_speedup_temporal = text{
    [''] = '- [Temporal Bot Dispersal] Speeds up all allied crew members at %.2fx speed',
    ['zh-Hans'] = '- [纳米时流机] 以%.2f倍的速率加速己方船员'
}

local function getMedbayTooltip(iShipId, sys, speed, lang)
    local str = ''
    if speed > 0 and tmConfig.ships[iShipId].temporal_bot > 0 then
        local power = sys:GetEffectivePower()
        local rate = (tmConfig.MEDBAY_SPEEDUP_FACTORS[speed] - 1) * 0.25 * power
        str = str .. entry.medbay_speedup_temporal(lang, rate + 1) .. '\n'
    end
    return str .. getIonTooltip(sys, speed, lang)
end

entry.piloting_speedup = text{
    [''] = '- Increases ship evasion rate by %.0f%%',
    ['zh-Hans'] = '- 舰船闪避率提高%.0f%%'
}
entry.piloting_speedup_manning = text{
    [''] = '- Increases manning level to level %d',
    ['zh-Hans'] = '- 将驾驶技能提升至%d级'
}
entry.piloting_slowdown = text{
    [''] = '- Decreases ship evasion rate by %.0f%%',
    ['zh-Hans'] = '- 舰船闪避率降低%.0f%%'
}

local function getPilotingTooltip(iShipId, sys, speed, lang)
    local str = ''
    local boost = sys:IsMannedBoost()
    if speed > 0 then
        local dodge = 5 * boost * speed
        str = str .. entry.piloting_speedup(lang, dodge) .. '\n'
        str = str .. entry.piloting_speedup_manning(lang, boost) .. '\n'
    else
        str = str .. entry.piloting_slowdown(lang, 3 * (boost - 4) * speed) .. '\n'
    end
    return str .. getIonTooltip(sys, speed, lang)
end

entry.sensors_speedup = text{
    [''] = '- Provides manning bonus',
    ['zh-Hans'] = '- 提供有人操纵的加成'
}
entry.sensors_slowdown = text{
    [''] = '- Reduces maximum system power by %d bar',
    ['zh-Hans'] = '- 系统最大能级降低%d格'
}

local function getSensorsTooltip(iShipId, sys, speed, lang)
    local str = ''
    if speed > 0 then
        str = str .. entry.sensors_speedup[lang] .. '\n'
    else
        str = str .. entry.sensors_slowdown(lang, math.ceil(-speed / 2)) .. '\n'
    end
    return str .. getIonTooltip(sys, speed, lang)
end

entry.doors_speedup = text{
    [''] = '- Provides manning bonus',
    ['zh-Hans'] = '- 提供有人操纵的加成'
}
entry.doors_slowdown = text{
    [''] = '- Reduces maximum system power by %d bar',
    ['zh-Hans'] = '- 系统最大能级降低%d格'
}

local function getDoorsTooltip(iShipId, sys, speed, lang)
    local str = ''
    if speed > 0 then
        str = str .. entry.doors_speedup[lang] .. '\n'
    else
        str = str .. entry.doors_slowdown(lang, math.ceil(-speed / 2)) .. '\n'
    end
    return str .. getIonTooltip(sys, speed, lang)
end

entry.teleporter_speedup_temporal = text{
    [''] = '- [Temporal Bot Teleporter] (%s) Speeds up all allied crew members on enemy ship at %.2fx speed when fully powered',
    ['zh-Hans'] = '- [纳米时流传送器] (%s) 当传送器有4格供能时以%.2f倍的速率加速敌舰上的己方船员'
}
entry.teleporter_slowdown = text{
    [''] = '- Reduces maximum system power by %d bar',
    ['zh-Hans'] = '- 系统最大能级降低%d格'
}

local function getTeleporterTooltip(iShipId, sys, speed, lang)
    local str = ''
    if speed > 0 then
        if tmConfig.ships[iShipId].temporal_teleporter > 0 then
            local power = sys:GetEffectivePower()
            local isActive = power >= 4 and word.active[lang] or word.inactive[lang]
            str = str .. entry.teleporter_speedup_temporal(lang, isActive, tmConfig.TELEPORTER_SPEEDUP_FACTORS[speed]) .. '\n'
        end
    else
        str = str .. entry.teleporter_slowdown(lang, math.ceil(-speed / 2)) .. '\n'
    end
    return str .. getIonTooltip(sys, speed, lang)
end

entry.cloaking_speedup = text{
    [''] = '- Increases ship evasion rate by %.0f%%',
    ['zh-Hans'] = '- 舰船闪避率提高%.0f%%'
}
entry.cloaking_slowdown = text{
    [''] = '- Decreases ship evasion rate by %.0f%%',
    ['zh-Hans'] = '- 舰船闪避率降低%.0f%%'
}

local function getCloakingTooltip(iShipId, sys, speed, lang)
    local str = ''
    local shipMgr = Hyperspace.ships(iShipId)
    if shipMgr and shipMgr.cloakSystem and shipMgr.cloakSystem.bTurnedOn then
        local power = sys:GetEffectivePower()
        if speed > 0 then
            str = str .. entry.cloaking_speedup(lang, 5 * power * speed) .. '\n'
        else
            str = str .. entry.cloaking_slowdown(lang, -math.max(5 * (5 - power) * speed, -60)) .. '\n'
        end
    end
    return str .. getIonTooltip(sys, speed, lang)
end

entry.artillery_speedup = text{
    [''] = '- Speeds up artillery recharge by %.0f%%',
    ['zh-Hans'] = '- 巨炮充能速率提高%.0f%%'
}
entry.artillery_slowdown = text{
    [''] = '- Slows down artillery recharge by %.0f%%',
    ['zh-Hans'] = '- 巨炮充能速率降低%.0f%%'
}

local function getArtilleryTooltip(iShipId, sys, speed, lang)
    local str = ''
    if speed > 0 then
        str = str .. entry.artillery_speedup(lang, tmConfig.ARTILLERY_SPEEDUP_RATES[speed] * 100) .. '\n'
    else
        str = str .. entry.artillery_slowdown(lang, -tmConfig.ARTILLERY_SLOWDOWN_RATES[-speed] * 100) .. '\n'
    end
    return str .. getIonTooltip(sys, speed, lang)
end

entry.battery_speedup = text{
    [''] = '- (%s) Generates additional power when turned on',
    ['zh-Hans'] = '- (%s) 电池启用时产生额外能量'
}
entry.battery_slowdown = text{
    [''] = '- Reduces maximum system power by %d bar',
    ['zh-Hans'] = '- 系统最大能级降低%d格'
}

local function getBatteryTooltip(iShipId, sys, speed, lang)
    local str = ''
    if speed > 0 then
        local shipMgr = Hyperspace.ships(iShipId)
        if shipMgr and shipMgr.batterySystem and shipMgr.batterySystem.bTurnedOn then
            local isActive = shipMgr.batterySystem.bTurnedOn and word.active[lang] or word.inactive[lang]
            str = str .. entry.battery_speedup(lang, isActive) .. '\n'
        end
    else
        str = str .. entry.battery_slowdown(lang, math.ceil(-speed / 2)) .. '\n'
    end
    return str .. getIonTooltip(sys, speed, lang)
end

entry.mind_speedup = text{
    [''] = '- Speeds up mind-controlled crew members at %.2fx speed',
    ['zh-Hans'] = '- 以%.2f倍的速率加速被心控的船员'
}
entry.mind_speedup_multi = text{
    [''] = '- [Multi-person Mind Control] %d more enemy crew members under mind control.',
    ['zh-Hans'] = '- [多人心控] 额外心控%d名船员'
}
entry.mind_slowdown = text{
    [''] = '- Reduces maximum system power by %d bar',
    ['zh-Hans'] = '- 系统最大能级降低%d格'
}

local function getMindTooltip(iShipId, sys, speed, lang)
    local str = ''
    if speed > 0 then
        if tmConfig.ships[iShipId].multi_mc <= 0 then
            str = str .. entry.mind_speedup(lang, tmConfig.MIND_SPEEDUP_FACTORS[speed]) .. '\n'
        else
            str = str .. entry.mind_speedup_multi(lang, speed) .. '\n'
        end
    else
        str = str .. entry.mind_slowdown(lang, math.ceil(-speed / 2)) .. '\n'
    end
    return str .. getIonTooltip(sys, speed, lang)
end

entry.hacking_speedup = text{
    [''] = '- Speeds up hacking process by %.0f%%',
    ['zh-Hans'] = '- 黑客速度加快%.0f%%'
}
entry.hacking_speedup_surge = text{
    [''] = '- [Hacking Surge] %d more systems are hacked',
    ['zh-Hans'] = '- [黑客能量涌动] 额外骇入%d个敌方系统'
}
entry.hacking_slowdown = text{
    [''] = '- Reduces maximum system power by %d bar',
    ['zh-Hans'] = '- 系统最大能级降低%d格'
}

local function getHackingTooltip(iShipId, sys, speed, lang)
    local str = ''
    if speed > 0 then
        if tmConfig.ships[iShipId].hacking_surge <= 0 then
            str = str .. entry.hacking_speedup(lang, tmConfig.HACKING_SPEEDUP_RATES[speed] * 100) .. '\n'
        else
            str = str .. entry.hacking_speedup_surge(lang, speed) .. '\n'
        end
    else
        str = str .. entry.hacking_slowdown(lang, math.ceil(-speed / 2)) .. '\n'
    end
    return str .. getIonTooltip(sys, speed, lang)
end

entry.temporal_slowdown = text{
    [''] = '- Reduces maximum system power by %d bar',
    ['zh-Hans'] = '- 系统最大能级降低%d格'
}

local function getTemporalTooltip(iShipId, sys, speed, lang)
    local str = ''
    if speed < 0 then
        str = str .. entry.temporal_slowdown(lang, -speed) .. '\n'
    end
    return str .. getIonTooltip(sys, speed, lang)
end

tooltip.texts = {
    word = word,
    title = title,
    entry = entry
}

local function getDefaultTooltip(iShipId, sys, speed, lang)
    return getIonTooltip(sys, speed, lang)
end

tooltip.getSystemTooltip = {
    -- shields
    [0] = getShieldsTooltip,
    -- engines
    [1] = getEnginesTooltip,
    -- oxygen
    [2] = getOxygenTooltip,
    -- weapons
    [3] = getWeaponsTooltip,
    -- drones
    [4] = getDronesTooltip,
    -- medbay
    [5] = getMedbayTooltip,
    -- piloting
    [6] = getPilotingTooltip,
    -- sensors
    [7] = getSensorsTooltip,
    -- doors
    [8] = getDoorsTooltip,
    -- teleporter
    [9] = getTeleporterTooltip,
    -- cloaking
    [10] = getCloakingTooltip,
    -- artillery
    [11] = getArtilleryTooltip,
    -- battery
    [12] = getBatteryTooltip,
    -- clonebay
    [13] = getDefaultTooltip,
    -- mind
    [14] = getMindTooltip,
    -- hacking
    [15] = getHackingTooltip,
    -- temporal
    [20] = getTemporalTooltip,
    -- unknown
    default = getDefaultTooltip
}

setmetatable(tooltip.getSystemTooltip, {
    __index = function(cases)
        return cases.default
    end,
    __call = function(cases, iShipId, sys, speed, lang)
        if speed == 0 then
            return title.speedup(lang, 0), entry.no_effects[lang]
        end
        return (speed > 0 and title.speedup(lang, speed) or title.slowdown(lang, -speed)), cases[sys.iSystemType](iShipId, sys, speed, lang)
    end
})
