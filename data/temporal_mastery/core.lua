
if not(mods.temporal and mods.temporal.config) then
    error("Temporal Mastery scripts are loaded in wrong order.")
end

local tmConfig = mods.temporal.config
local shipsConfig = tmConfig.ships

local origRoomSpeed = {
    [0] = {},
    [1] = {}
}
mods.temporal.origRoomSpeed = origRoomSpeed

local roomSpeed = {
    [0] = {},
    [1] = {}
}
mods.temporal.roomSpeed = roomSpeed

local function checkTemporalEffects(shipMgr)
    local iShipId = shipMgr.iShipId
    origRoomSpeed[iShipId] = {}
    roomSpeed[iShipId] = {}
    local origRooms = origRoomSpeed[iShipId]
    local rooms = roomSpeed[iShipId]
    local vRoomList = shipMgr.ship.vRoomList
    local vSystemList = shipMgr.vSystemList
    for i = 0, vSystemList:size() - 1 do
        local sys = vSystemList[i]
        local roomId = sys:GetRoomId()
        local speed = vRoomList[roomId].extend.timeDilation
        if speed ~= 0 then
            origRooms[roomId] = speed
            speed = math.max(math.min(speed, 4), -4)
            if shipsConfig[iShipId].temporal_reverser <= 0 then
                rooms[roomId] = speed
            else
                rooms[roomId] = -speed
            end
        end
    end
    local overclocker = shipMgr.table._tm_systems.overclocker
    if overclocker and overclocker.status == 1 then
        local overclockedRoom = overclocker.overclockedRoom
        local speed = rooms[overclockedRoom]
        if speed then
            rooms[overclockedRoom] = math.max(overclocker.strength, speed)
        else
            rooms[overclockedRoom] = overclocker.strength
        end
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, checkTemporalEffects)

local function getTimeDilation(shipMgr, sys)
    local iShipId = shipMgr.iShipId
    local speed = roomSpeed[iShipId][sys:GetRoomId()]
    return speed or 0
end

mods.temporal.getTimeDilation = getTimeDilation

-- Should not be used for artillery
local function getSystemSpeed(shipMgr, sysId)
    local sys = shipMgr:GetSystem(sysId)
    if not sys or sys.iHackEffect >= 2 then
        return 0
    end
    return getTimeDilation(shipMgr, sys)
end

local function genericUpgrade(sysId, upgradeFunc, normalFunc)
    normalFunc = normalFunc or (function() end)
    return function(shipMgr)
        local sys = shipMgr:GetSystem(sysId)
        if not sys then
            return
        end
        if sys.iHackEffect >= 2 then
            normalFunc(shipMgr)
            return
        end
        local speed = getTimeDilation(shipMgr, sys)
        if speed == 0 then
            normalFunc(shipMgr)
        else
            upgradeFunc(shipMgr, speed)
        end
    end
end

local powerDrainSystems = {
    [4] = 1,
    [7] = 2,
    [8] = 2,
    [9] = 2,
    [12] = 2,
    [14] = 2,
    [15] = 2,
    [20] = 1,
}
local function powerDrains(shipMgr)
    for sysId, strength in pairs(powerDrainSystems) do
        local sys = shipMgr:GetSystem(sysId)
        if sys then
            local speed = getTimeDilation(shipMgr, sys)
            if speed < 0 then
                local currDrain = sys.table._tm_powerLoss or 0
                local delta = math.ceil(-speed / strength) - currDrain
                if delta ~= 0 then
                    local realPowerLoss = sys.iTempPowerLoss
                    local newPowerLoss = math.max(math.min(realPowerLoss + delta, sys:GetPowerCap()), 0)
                    local realDelta = newPowerLoss - realPowerLoss
                    sys:SetPowerLoss(newPowerLoss)
                    sys.table._tm_powerLoss = currDrain + realDelta
                end
            else
                local currDrain = sys.table._tm_powerLoss
                if currDrain and currDrain > 0 then
                    sys:SetPowerLoss(sys.iTempPowerLoss - currDrain)
                    sys.table._tm_powerLoss = nil
                end
            end
        end
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, powerDrains)

local hackingSpeedupCases = {
    -- shields
    [0] = function(enemyShip, rate)
        local shields = enemyShip.shieldSystem.shields
        if shields.power.first > 0 then
            local frameTime = Hyperspace.FPS.SpeedFactor / 16
            if shields.charger > frameTime then
                local delta = frameTime * rate
                shields.charger = math.max(shields.charger - delta, frameTime)
            end
        end
    end,
    -- oxygen
    [2] = function(enemyShip, rate)
        local sys = enemyShip.oxygenSystem
        local refill = sys:GetRefillSpeed()
        local delta = math.abs(refill * rate)
        local oxygenLevels = sys.oxygenLevels
        for i = 0, oxygenLevels:size() - 1 do
            oxygenLevels[i] = math.max(oxygenLevels[i] - delta, 0)
        end
    end,
    -- weapons
    [3] = function(enemyShip, rate)
        local sys = enemyShip.weaponSystem
        local weapons = sys.weapons
        for i = 0, weapons:size() - 1 do
            local weapon = weapons[i]
            local cooldown = weapon.cooldown
            if weapon.powered and cooldown.second > 0 and cooldown.first > 0 then
                local delta = Hyperspace.FPS.SpeedFactor / 16 * rate
                cooldown.first = math.max(cooldown.first - delta, 0)
            end
        end
    end,
    -- medbay
    [5] = function(enemyShip, rate, roomId)
        local iShipId = enemyShip.iShipId
        local vCrewList = enemyShip.vCrewList
        for i = 0, vCrewList:size() - 1 do
            local crew = vCrewList[i]
            if not crew:IsDrone() and crew:InsideRoom(roomId) and crew.iShipId == iShipId then
                crew.fMedbay = crew.fMedbay * (1 + rate)
            end
        end
    end,
    -- artilleries
    [11] = function(enemyShip, rate, roomId)
        local artillerySystems = enemyShip.artillerySystems
        local artillery = false
        for i = 0, artillerySystems:size() - 1 do
            local sys = artillerySystems[i]
            if sys:GetRoomId() == roomId then
                artillery = sys
                break
            end
        end
        if not artillery then
            return
        end
        local weapon = artillery.projectileFactory
        local cooldown = weapon.cooldown
        if weapon.powered and cooldown.second > 0 and cooldown.first > 0 then
            local delta = Hyperspace.FPS.SpeedFactor / 16 * rate
            cooldown.first = math.max(cooldown.first - delta, 0)
        end
    end,
    -- clonebay
    [13] = function(enemyShip, rate)
        local sys = enemyShip.cloneSystem
        if sys.fDeathTime >= 0 then
            local delta = Hyperspace.FPS.SpeedFactor / 16 * rate
            sys.fDeathTime = sys.fDeathTime + delta
        end
    end
}
mods.temporal.hackingSpeedupCases = hackingSpeedupCases

local function hackingUpgrade(shipMgr, speed)
    local sys = shipMgr.hackingSystem
    local hackedSys = sys.currentSystem
    if speed < 0 or sys.effectTimer.first >= sys.effectTimer.second or not hackedSys then
        if sys.table._tm_multiHacking then
            sys.table._tm_multiHacking:clear()
            sys.table._tm_multiHacking = nil
        end
        return
    end
    if shipsConfig[shipMgr.iShipId].hacking_surge <= 0 then
        local enemyShip = Hyperspace.ships(1 - shipMgr.iShipId)
        if enemyShip and hackedSys then
            local case = hackingSpeedupCases[hackedSys.iSystemType]
            if case then
                case(enemyShip, tmConfig.HACKING_SPEEDUP_RATES[speed], hackedSys:GetRoomId())
            end
        end
        return
    end
    local multiHacking = sys.table._tm_multiHacking
    if not multiHacking then
        multiHacking = mods.temporal.MultiHacking:new(shipMgr, speed)
        sys.table._tm_multiHacking = multiHacking
    end
    multiHacking:resize(speed)
    multiHacking:update()
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, genericUpgrade(15, hackingUpgrade, function(shipMgr)
    local sys = shipMgr.hackingSystem
    if sys.table._tm_multiHacking then
        sys.table._tm_multiHacking:clear()
        sys.table._tm_multiHacking = nil
    end
end))

local function mcUpgrade(shipMgr, speed)
    local sys = shipMgr.mindSystem
    if speed < 0 or sys.controlledCrew:size() <= 0 then
        if sys.table._tm_multiMC then
            sys.table._tm_multiMC:clear()
            sys.table._tm_multiMC = nil
        end
        return
    end
    local iShipId = shipMgr.iShipId
    if shipsConfig[iShipId].multi_mc <= 0 then
        local extraUpdates = math.max(tmConfig.MIND_SPEEDUP_FACTORS[speed] - 1 + (sys.table._tm_remnant or 0), 0)
        extraUpdates, sys.table._tm_remnant = math.modf(extraUpdates)
        local crewList = sys.controlledCrew
        for i = 0, crewList:size() - 1 do
            local crew = crewList[i]
            for _ = 1, extraUpdates do
                crew:OnLoop()
            end
        end
        return
    end
    local multiMC = sys.table._tm_multiMC
    if not multiMC then
        multiMC = mods.temporal.MultiMC:new(iShipId, speed)
        sys.table._tm_multiMC = multiMC
    end
    multiMC:resize(speed)
    local enemyShip = Hyperspace.ships(1 - iShipId)
    multiMC:update(shipMgr.vCrewList, enemyShip and enemyShip.vCrewList)
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, genericUpgrade(14, mcUpgrade, function(shipMgr)
    local sys = shipMgr.mindSystem
    if sys.table._tm_multiMC then
        sys.table._tm_multiMC:clear()
        sys.table._tm_multiMC = nil
    end
end))

local function chargeUp(weapon, speed, speedUp, slowDown, speedUpMod)
    speedUpMod = speedUpMod or 1.0
    local safetyMargin = 0.01
    local safeMaxCooldown = weapon.cooldown.second - safetyMargin
    if weapon.powered and safeMaxCooldown > 0 and weapon.cooldown.first < safeMaxCooldown then
        local cdMod
        if speed < 0 then
            cdMod = slowDown[-speed]
        else
            cdMod = speedUp[speed] * speedUpMod
        end
        local delta = Hyperspace.FPS.SpeedFactor / 16 * cdMod
        weapon.cooldown.first = math.max(math.min(weapon.cooldown.first + delta, safeMaxCooldown), 0)
    end
end

local function weaponUpgrade(shipMgr, speed)
    local weapons = shipMgr:GetWeaponList()
    if shipsConfig[shipMgr.iShipId].selective_acceleration <= 0 then
        for i = 0, weapons:size() - 1 do
            chargeUp(weapons[i], speed, tmConfig.WEAPON_SPEEDUP_RATES, tmConfig.WEAPON_SLOWDOWN_RATES)
        end
    else
        for i = 0, math.min(weapons:size(), 1) - 1 do
            chargeUp(weapons[i], speed, tmConfig.WEAPON_SPEEDUP_RATES, tmConfig.WEAPON_SLOWDOWN_RATES, 2.0)
        end
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, genericUpgrade(3, weaponUpgrade))

local function artilleryUpgrade(shipMgr)
    local systems = shipMgr.artillerySystems
    for i = 0, systems:size() - 1 do
        local sys = systems[i]
        local power = sys:GetEffectivePower()
        local speed = getTimeDilation(shipMgr, sys)
        if power > 0 and speed ~= 0 and sys.iHackEffect < 2 then
            chargeUp(sys.projectileFactory, speed, tmConfig.ARTILLERY_SPEEDUP_RATES, tmConfig.ARTILLERY_SLOWDOWN_RATES)
        end
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, artilleryUpgrade)

local function clearSuperTimer(shieldSystem)
    shieldSystem.table._tm_superTimer = 0
end

local function chargeSuperShield(shieldSystem, delta, maxPoints)
    if shieldSystem.shields.power.super.first >= maxPoints then
        shieldSystem.table._tm_superTimer = 0
        return
    end
    if not shieldSystem.table._tm_superTimer then
        shieldSystem.table._tm_superTimer = 0
    end
    shieldSystem.table._tm_superTimer = shieldSystem.table._tm_superTimer + delta
    if shieldSystem.table._tm_superTimer >= 1 then
        shieldSystem.table._tm_superTimer = shieldSystem.table._tm_superTimer - 1
        if shieldSystem.shields.power.super.first >= shieldSystem.shields.power.super.second then
            shieldSystem.shields.power.super.second = shieldSystem.shields.power.super.first + 1
        end
        shieldSystem.shields.power.super.first = shieldSystem.shields.power.super.first + 1
        --shieldSystem:AddSuperShield(Hyperspace.Point(math.random(0, 1000), math.random(0, 1000)))
    end
end

-- reset super shield hp for player
script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SHIP_MANAGER, function(shipMgr)
    if shipMgr.iShipId == 1 then
        local sys = Hyperspace.ships.player.shieldSystem
        if sys and shipMgr:HasAugmentation('_TM_AUG_INFSHIELD') > 0 then
            sys.shields.power.super.first = math.max(sys.shields.power.super.first - 99, 0)
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipMgr)
    if shipMgr:HasAugmentation('_TM_AUG_INFSHIELD') <= 0 then
        return
    end
    local sys = shipMgr.shieldSystem
    if sys then
        sys.shields.power.super.second = math.max(sys.shields.power.super.first, 5)
    end
end)

local function shieldUpgrade(shipMgr, speed)
    local sys = shipMgr.shieldSystem
    if shipsConfig[shipMgr.iShipId].infinite_shield > 0 and speed > 0 then
        local chargeSpeed = tmConfig.SUPERSHIELD_CHARGE_RATES[speed]
        local delta = Hyperspace.FPS.SpeedFactor / 16 * chargeSpeed * 2.0
        chargeSuperShield(sys, delta, 999)
        return
    end
    if not sys:Powered() then
        clearSuperTimer(sys)
        return
    end
    local fullyCharged = (sys.shields.power.first >= sys.shields.power.second)
    local power = sys:GetEffectivePower()
    if speed < 0 or power < sys.healthState.second or not fullyCharged then
        clearSuperTimer(sys)
        if fullyCharged then
            return
        end
        local cdMod
        if speed < 0 then
            cdMod = tmConfig.SHIELD_SLOWDOWN_RATES[-speed]
        else
            cdMod = tmConfig.SHIELD_SPEEDUP_RATES[speed]
        end
        local delta = Hyperspace.FPS.SpeedFactor / 16 * cdMod
        sys.shields.charger = math.max(sys.shields.charger + delta, 0)
        return
    end
    local chargeSpeed = tmConfig.SUPERSHIELD_CHARGE_RATES[speed]
    local delta = Hyperspace.FPS.SpeedFactor / 16 * chargeSpeed
    chargeSuperShield(sys, delta, 5)
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, genericUpgrade(0, shieldUpgrade, function(shipMgr)
    clearSuperTimer(shipMgr.shieldSystem)
end))

local function oxygenUpgrade(shipMgr, speed)
    local sys = shipMgr.oxygenSystem
    local power = sys:GetEffectivePower()
    if power <= 0 then return end
    local refill = sys:GetRefillSpeed()
    local mod
    if speed > 0 then
        mod = tmConfig.OXYGEN_SPEEDUP_RATES[speed] * power
    else
        mod = tmConfig.OXYGEN_SLOWDOWN_RATES[-speed] / power
    end
    local delta = refill * mod
    --local graph = Hyperspace.ShipGraph.GetShipInfo(shipMgr.iShipId)
    for i = 0, sys.oxygenLevels:size() - 1 do
        if sys.oxygenLevels[i] < sys.max_oxygen then
            sys.oxygenLevels[i] = math.max(sys.oxygenLevels[i] + delta, 0)
        end
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, genericUpgrade(2, oxygenUpgrade))

local function setBounsPower(bonus)
    local delta = bonus - tmConfig.player.bonus_power
    if delta == 0 then return end
    local powerMgr = Hyperspace.PowerManager.GetPowerManager(0)
    powerMgr.currentPower.second = powerMgr.currentPower.second + delta
    tmConfig.setPlayerConfig('bonus_power', bonus)
end

local function chargeBounsPower(sys, delta, maxPoints)
    if tmConfig.player.bonus_power >= maxPoints then
        sys.table._tm_powerTimer = 0
        return
    end
    if not sys.table._tm_powerTimer then
        sys.table._tm_powerTimer = 0
    end
    sys.table._tm_powerTimer = sys.table._tm_powerTimer + delta * (2 ^ tmConfig.player.bpgen_speed)
    if sys.table._tm_powerTimer >= 1 then
        sys.table._tm_powerTimer = sys.table._tm_powerTimer - 1
        setBounsPower(tmConfig.player.bonus_power + 1)
    end
end

local function clearPowerTimer(sys)
    sys.table._tm_powerTimer = 0
end

local function batteryUpgrade(shipMgr)
    if shipMgr.iShipId ~= 0 then
        return
    end
    local sys = shipMgr.batterySystem
    if not sys then
        return
    end
    if sys.iHackEffect >= 2 then
        clearPowerTimer(sys)
        setBounsPower(0)
        return
    end
    local power = sys:GetEffectivePower()
    if power <= 0 then
        clearPowerTimer(sys)
        return
    end

    local speed = getTimeDilation(shipMgr, sys)
    if speed < 0 then
        clearPowerTimer(sys)
        setBounsPower(0)
        return
    end
    if speed == 0 or not sys.bTurnedOn then
        clearPowerTimer(sys)
        return
    end
    -- when speed > 0 and sys.bTurnedOn
    local chargeSpeed = tmConfig.BONUSPOWER_CHARGE_RATES[speed]
    local delta = Hyperspace.FPS.SpeedFactor / 16 * chargeSpeed
    chargeBounsPower(sys, delta, power * 2)
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, batteryUpgrade)
script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function() setBounsPower(0) end)

local function speedUpLock(sys, factors, speed)
    if sys.iLockCount > 0 then
        local timer = sys.lockTimer
        local delta = Hyperspace.FPS.SpeedFactor / 16 * factors[math.abs(speed)]
        timer.currTime = math.max(timer.currTime + delta, 0)
    end
end
mods.temporal.speedUpLock = speedUpLock

local function lockUpgrades(shipMgr)
    local iShipId = shipMgr.iShipId
    for roomId, speed in pairs(roomSpeed[iShipId]) do
        local sys = shipMgr:GetSystemInRoom(roomId)
        if speed < 0 then
                speedUpLock(sys, tmConfig.IONLOCK_SLOWDOWN_RATES, speed)
        elseif speed > 0 then
                speedUpLock(sys, tmConfig.IONLOCK_SPEEDUP_RATES, speed)
        end
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, lockUpgrades)

local function pilotingUpgrade(shipMgr, speed)
    if speed < 0 then return end
    local sys = shipMgr:GetSystem(6)
    local power = sys:GetEffectivePower()
    if power <= 0 then return end
    local boost = sys.iActiveManned
    if boost < 1 then
        if sys.bManned then
            boost = 0.9
        else
            boost = ({0, 0.5, 0.8})[power]
        end
    end
    sys.iActiveManned = math.min(math.floor(boost * speed), 3)
    sys.bManned = sys.bManned or (sys.iActiveManned > 0)
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, genericUpgrade(6, pilotingUpgrade))

local function sensorUpgrade(shipMgr, speed)
    local sys = shipMgr:GetSystem(7)
    if speed > 0 then
        sys.bManned = true
        sys.iActiveManned = 3
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, genericUpgrade(7, sensorUpgrade))

local function doorsUpgrade(shipMgr, speed)
    local sys = shipMgr:GetSystem(8)
    if speed > 0 then
        sys.bManned = true
        sys.iActiveManned = 3
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, genericUpgrade(8, doorsUpgrade))

local function engineUpgrade(shipMgr, augName, augValue)
    if not shipMgr or shipsConfig[shipMgr.iShipId].temporal_ftl <= 0 or augName ~= "FTL_BOOSTER" then
        return Defines.Chain.CONTINUE, augValue
    end
    local engine = shipMgr:GetSystem(1)
    local speed = getTimeDilation(shipMgr, engine)
    if speed == 0 then
        return Defines.Chain.CONTINUE, augValue
    end
    if speed < 0 then
        return Defines.Chain.CONTINUE, augValue + tmConfig.FTL_SLOWDOWN_RATES[-speed]
    end
    return Defines.Chain.CONTINUE, augValue + tmConfig.FTL_SPEEDUP_RATES[speed]
end

script.on_internal_event(Defines.InternalEvents.GET_AUGMENTATION_VALUE, engineUpgrade)

local function dodgeUpgrade(shipMgr, dodge)
    local engineSpeed = getSystemSpeed(shipMgr, 1)
    if engineSpeed ~= 0 then
        local enginePower = shipMgr:GetSystem(1):GetEffectivePower()
        local factor
        if engineSpeed > 0 then
            factor = 0.6
        else
            factor = 1 / 3
        end
        dodge = dodge + ({5, 10, 15, 20, 25, 28, 31, 35, [0] = 0})[enginePower] * engineSpeed * factor
    end

    local pilotingSpeed = getSystemSpeed(shipMgr, 6)
    if pilotingSpeed ~= 0 then
        local pilotingBoost = shipMgr:GetSystem(6):IsMannedBoost()
        if pilotingSpeed > 0 then
            dodge = dodge + 5 * pilotingBoost * pilotingSpeed
        else
            dodge = dodge + 3 * (4 - pilotingBoost) * pilotingSpeed
        end
    end

    dodge = math.max(dodge, 0)

    local cloakSpeed = getSystemSpeed(shipMgr, 10)
    local cloakSystem = shipMgr.cloakSystem
    if cloakSpeed ~= 0 and cloakSystem.bTurnedOn then
        local cloakPower = cloakSystem:GetEffectivePower()
        if cloakSpeed > 0 then
            dodge = dodge + 5 * cloakPower * cloakSpeed
        else
            dodge = dodge + math.max(5 * (5 - cloakPower) * cloakSpeed, -60)
        end
    end
    return Defines.Chain.CONTINUE, dodge
end

script.on_internal_event(Defines.InternalEvents.GET_DODGE_FACTOR, dodgeUpgrade)

local function random_point_radius(origin, radius)
    local r = radius * math.sqrt(math.random())
    local theta = 2 * math.pi * math.random()
    return Hyperspace.Pointf(origin.x + r * math.cos(theta), origin.y + r * math.sin(theta))
end

local function droneAmplifier(proj, drone)
    local shipId = drone:GetOwnerId()
    if shipsConfig[shipId].drone_amplifier <= 0 then
        return Defines.Chain.CONTINUE
    end
    local shipMgr = Hyperspace.ships(shipId)
    local speed = getSystemSpeed(shipMgr, 4)
    if speed <= 0 then return end
    local spaceMgr = Hyperspace.Global.GetInstance():GetCApp().world.space
    local cases = {
        ["LASER"] = function()
            --[[ LaserBlast* CreateLaserBlast(
                WeaponBlueprint *weapon,
                Pointf position,
                int space,
                int ownerId,
                Pointf target,
                int targetSpace,
                float heading
            );]]
            return spaceMgr:CreateLaserBlast(
                drone.weaponBlueprint,
                drone.currentLocation,
                proj.currentSpace,
                proj.ownerId,
                random_point_radius(proj.target, 60),
                proj.destinationSpace,
                proj.heading
            )
        end,
        ["MISSILES"] = function()
            --[[ Missile* CreateMissile(
                WeaponBlueprint *weapon,
                Pointf position, int space,
                int ownerId,
                Pointf target,
                int targetSpace,
                float heading
            );]]
            return spaceMgr:CreateMissile(
                drone.weaponBlueprint,
                drone.currentLocation,
                proj.currentSpace,
                proj.ownerId,
                random_point_radius(proj.target, 60),
                proj.destinationSpace,
                proj.heading
            )
        end,
        ["BEAM"] = function()
            --[[ BeamWeapon* CreateBeam(
                WeaponBlueprint *weapon,
                Pointf position,
                int space,
                int ownerId,
                Pointf target1,
                Pointf target2,
                int targetSpace,
                int length,
                float heading
            );]]
            return spaceMgr:CreateBeam(
                drone.weaponBlueprint,
                drone.currentLocation,
                proj.currentSpace,
                proj.ownerId,
                random_point_radius(proj.target1, 60),
                random_point_radius(proj.target2, 60),
                proj.destinationSpace,
                proj.length,
                proj.heading
            )
        end,
        ["BURST"] = function()
            --[[ LaserBlast* CreateBurstProjectile(
                WeaponBlueprint *weapon,
                std::string &image,
                bool fake,
                Pointf position,
                int space,
                int ownerId,
                Pointf target,
                int targetSpace,
                float heading
            );]]
            local bp = drone.weaponBlueprint
            local projs = bp.miniProjectiles
            local i = math.random(0, projs:size() - 1)
            return spaceMgr:CreateBurstProjectile(
                bp,
                projs[i].image,
                projs[i].fake,
                drone.currentLocation,
                proj.currentSpace,
                proj.ownerId,
                random_point_radius(proj.target, 60 + bp.radius),
                proj.destinationSpace,
                proj.heading
            )
        end
    }
    local case = cases[drone.weaponBlueprint.typeName]
    if case then
        for _ = 2, speed do
            case():ComputeHeading()
        end
    end
    return Defines.Chain.CONTINUE
end

script.on_internal_event(Defines.InternalEvents.DRONE_FIRE, droneAmplifier)

local function dronesUpgrade(shipMgr)
    local sys = shipMgr.droneSystem
    if not sys or sys.iHackEffect >= 2 then
        return
    end
    local speed = getTimeDilation(shipMgr, sys)
    if speed <= 0 then
        return
    end

    --space drones
    if shipsConfig[shipMgr.iShipId].drone_amplifier <= 0 then
        local rate = tmConfig.SPACEDRONE_SPEEDUP_FACTORS[speed] - 1
        local extraUpdates = math.max(rate + (sys.table._tm_remnant or 0), 0)
        extraUpdates, sys.table._tm_remnant = math.modf(extraUpdates)
        local drones = shipMgr.spaceDrones
        for i = 0, drones:size() - 1 do
            local drone = drones[i]
            if drone.powered then
                if drone.currentSpeed and drone.weaponCooldown >= 0 then
                    drone.weaponCooldown = drone.weaponCooldown - Hyperspace.FPS.SpeedFactor / 16 * rate
                    if drone.weaponCooldown <= 0 then
                        drone.weaponCooldown = -1
                    end
                end
                for _ = 1, extraUpdates do
                    drone:OnLoop()
                end
            end
        end
    end

    -- crew drones
    local extraCrewUpdates = math.max(
        tmConfig.CREWDRONE_SPEEDUP_FACTORS[speed] - 1 + (sys.table._tm_crewRemnant or 0), 0)
    extraCrewUpdates, sys.table._tm_crewRemnant = math.modf(extraCrewUpdates)
    local crewList = shipMgr.vCrewList
    for i = 0, crewList:size() - 1 do
        local crew = crewList[i]
        if crew:IsDrone() and not crew:GetIntruder() then
            for _ = 1, extraCrewUpdates do
                crew:OnLoop()
            end
        end
    end
    local otherShip = Hyperspace.ships(1 - shipMgr.iShipId)
    if not otherShip then
        return
    end
    crewList = otherShip.vCrewList
    for i = 0, crewList:size() - 1 do
        local crew = crewList[i]
        if crew:IsDrone() and crew:GetIntruder() then
            for _ = 1, extraCrewUpdates do
                crew:OnLoop()
            end
        end
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, dronesUpgrade)

local function teleporterUpgrade(shipMgr)
    local sys = shipMgr.teleportSystem
    if not sys then
        return
    end
    local speed = getTimeDilation(shipMgr, sys)
    if speed < 0 or shipsConfig[shipMgr.iShipId].temporal_teleporter <= 0 then
        return
    end

    local power = sys:GetEffectivePower()
    if speed == 0 or sys.iHackEffect >= 2 or power < 4 then
        return
    end
    local iShipId = shipMgr.iShipId
    local otherShip = Hyperspace.ships(1 - shipMgr.iShipId)
    if not otherShip then
        return
    end

    local extraUpdates = math.max(tmConfig.TELEPORTER_SPEEDUP_FACTORS[speed] - 1 + (sys.table._tm_remnant or 0), 0)
    extraUpdates, sys.table._tm_remnant = math.modf(extraUpdates)
    local crewList = otherShip.vCrewList
    for i = 0, crewList:size() - 1 do
        local crew = crewList[i]
        if not crew:IsDrone() and crew.iShipId == iShipId then
            for _ = 1, extraUpdates do
                crew:OnLoop()
            end
        end
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, teleporterUpgrade)

local function medbayUpgrade(shipMgr)
    if shipsConfig[shipMgr.iShipId].temporal_bot <= 0 then
        return
    end
    local sys = shipMgr:GetSystem(5)
    if not sys then
        return
    end
    local speed = getTimeDilation(shipMgr, sys)
    local power = sys:GetEffectivePower()
    if speed <= 0 or sys.iHackEffect >= 2 or power <= 0 then
        return
    end
    local iShipId = shipMgr.iShipId
    local rate = (tmConfig.MEDBAY_SPEEDUP_FACTORS[speed] - 1) * 0.25 * power
    local extraUpdates = math.max(rate + (sys.table._tm_remnant or 0), 0)
    extraUpdates, sys.table._tm_remnant = math.modf(extraUpdates)
    local crewList = shipMgr.vCrewList
    for i = 0, crewList:size() - 1 do
        local crew = crewList[i]
        if not crew:IsDrone() and crew.iShipId == iShipId then
            for _ = 1, extraUpdates do
                crew:OnLoop()
            end
        end
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, medbayUpgrade)
