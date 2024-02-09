
if not mods.temporal then
    error("Temporal Mastery scripts are loaded in wrong order.")
end

local hasAug = mods.temporal.config.hasAug
local augments = mods.temporal.config.augs
local enemyConfig = mods.temporal.config.enemy
local overclockerAugs = mods.temporal.systems.overclockerAugs

-- Level 0: no difference
-- Level 1: 15% Overclocker, Temporal always Overclocker,
--          boss with temporal has _TM_AUG_TEMPORAL_STUN
-- Level 2: 30% Overclocker with 15% upgrades,
--          Temporal always Overclocker and has _TM_AUG_TEMPORAL_STUN
-- Level 3: 45% Overclocker with 30% upgrades,
--          boss and temporal always has _TM_AUG_TEMPORAL_STUN,
--          Temporal always Overclocker,
--          15% chance of external augs
-- Level 4: 60% Overclocker with 45% upgrades,
--          enemy always has _TM_AUG_TEMPORAL_STUN,
--          Temporal always Overclocker,
--          30% chance of external augs
local function enemyAdjustments(shipMgr, difficulty, isBoss)
    if difficulty <= 0 then
        return
    end
    local augs = augments[1]
    -- Developer Mode
    local hasOverclocker = false
    if difficulty >= 5 then
        augs['_TM_AUG_OVERCLOCKER_DEV'] = 1
        hasOverclocker = true
    else
        for _, aug in ipairs(overclockerAugs) do
            if hasAug(shipMgr, aug.name) > 0 then
                hasOverclocker = true
                break
            end
        end
    end
    local hasTemporal = shipMgr:HasSystem(20)
    local hasShields = shipMgr.shieldSystem
    local hasWeaponControl = shipMgr.weaponSystem
    local hasDroneControl = shipMgr.droneSystem
    local hasMedbay = shipMgr:HasSystem(5)
    local hasTeleporter = shipMgr.teleportSystem
    local hasMindControl = shipMgr.mindSystem
    local hasHacking = shipMgr.hackingSystem
    if not hasOverclocker then
        local chance = difficulty * 0.15
        if hasTemporal or math.random() < chance then
            augs['_TM_AUG_OVERCLOCKER'] = 1
            hasOverclocker = true
        end
    end
    if  (difficulty >= 4) or
        (difficulty >= 3 and (hasTemporal or isBoss)) or
        (difficulty >= 2 and hasTemporal) or
        (hasTemporal and isBoss) then
        augs['_TM_AUG_TEMPORAL_STUN'] = 1
    end
    if difficulty >= 2 and hasOverclocker then
        local chance = (difficulty - 1) * 0.15
        if hasShields and math.random() < chance then
            enemyConfig.infinite_shield = 1
            shipMgr:AddAugmentation('_TM_AUG_INFSHIELD')
        end
        if hasWeaponControl and math.random() < chance then
            enemyConfig.selective_acceleration = 1
        end
        if hasDroneControl and math.random() < chance then
            enemyConfig.drone_amplifier = 1
        end
        if hasMedbay and math.random() < chance then
            enemyConfig.temporal_bot = 1
        end
        if hasTeleporter and math.random() < chance then
            enemyConfig.temporal_teleporter = 1
        end
        if hasMindControl and math.random() < chance then
            enemyConfig.multi_mc = 1
        end
        if hasHacking and math.random() < chance then
            enemyConfig.hacking_surge = 1
        end
    end
    if difficulty >= 3 then
        local chance = (difficulty - 2) * 0.15
        if math.random() < chance then
            augs['_TM_AUG_ION_SPEEDUP'] = 1
        end
        if hasDroneControl and math.random() < chance then
            augs['_TM_AUG_SPACE_DRONE_BOOSTER'] = 1
        end
        if hasMindControl and math.random() < chance then
            augs['_TM_AUG_MIND_SPEEDUP'] = 1
        end
        if hasHacking and math.random() < chance then
            augs['_TM_AUG_HACKING_SPEEDUP'] = 1
        end
        --[[if math.random() < chance then
            augs['_TM_AUG_CREW_SPEEDUP'] = 1
        end]]
    end
    --[[print('--- augments ---')
    for k, v in pairs(enemyConfig) do
        if v > 0 then
            print(k, v)
        end
    end
    for k, v in pairs(augs) do
        print(k, v)
    end
    print('----------------')]]
end

local function enemyAdjustmentsPost(shipMgr)
    if shipMgr:HasAugmentation('_TM_AUG_INFSHIELD') > 0 then
        local sys = shipMgr.shieldSystem
        if sys and sys.shields.power.super.first >= 99 then
            sys.shields.power.super.first = sys.shields.power.super.first - 99
        else
            shipMgr:RemoveAugmentation('_TM_AUG_INFSHIELD')
        end
    end
end

local enemyConfigLoaded = 0
script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SHIP_MANAGER, function(shipMgr)
    if shipMgr.iShipId == 1 then
        for key in pairs(enemyConfig) do
            enemyConfig[key] = 0
        end
        augments[1] = {}
        enemyConfigLoaded = 2
    end
end)

local enemyPostConfigLoaded = 0
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipMgr)
    if shipMgr.iShipId ~= 1 then
        return
    end
    if enemyPostConfigLoaded > 0 and shipMgr._targetable.hostile then
        if enemyPostConfigLoaded > 1 then
            enemyPostConfigLoaded = enemyPostConfigLoaded - 1
        else
            enemyAdjustmentsPost(shipMgr)
            enemyPostConfigLoaded = 0
        end
        return
    end
    if enemyConfigLoaded <= 0 then
        return
    end
    if enemyConfigLoaded > 1 then
        enemyConfigLoaded = enemyConfigLoaded - 1
        return
    end
    local cApp = Hyperspace.Global.GetInstance():GetCApp()
    local isBoss = cApp.gui.combatControl.boss_visual
    local difficulty = Hyperspace.metaVariables['_tm_difficulty']
    enemyAdjustments(shipMgr, difficulty, isBoss)
    enemyConfigLoaded = 0
    enemyPostConfigLoaded = 2
end)
