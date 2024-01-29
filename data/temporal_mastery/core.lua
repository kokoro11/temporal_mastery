
if not(mods.temporal and mods.temporal.config) then
    error("Temporal Mastery scripts are loaded in wrong order.")
end

local tmConfig = mods.temporal.config

local roomSpeed = {
    [0] = {},
    [1] = {}
}

local function checkTemporalEffects(shipMgr)
    local iShipId = shipMgr.iShipId
    roomSpeed[iShipId] = {}
    local rooms = roomSpeed[iShipId]
    local vRoomList = shipMgr.ship.vRoomList
    local vSystemList = shipMgr.vSystemList
    for i = 0, vSystemList:size() - 1 do
        local sys = vSystemList[i]
        local roomId = sys:GetRoomId()
        local speed = vRoomList[roomId].extend.timeDilation
        if speed ~= 0 then
            speed = math.max(math.min(speed, 4), -4)
            if iShipId ~= 0 or tmConfig.player['temporal_reverser'] <= 0 then
                rooms[roomId] = speed
            else
                rooms[roomId] = -speed
            end
        end
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, checkTemporalEffects)

local function getTimeDilation(shipMgr, sys)
    local iShipId = shipMgr.iShipId
    local speed = roomSpeed[iShipId][sys:GetRoomId()]
    if not speed then
        return 0
    end
    return speed
end

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

local function getAdjacentRooms(shipMgr, startRoomId, depth)
    local depth = depth or 1
    local vDoorList = shipMgr.ship.vDoorList
    local startRooms = {[startRoomId] = true}
    local adjacentRooms = {}
    for d = 1, depth do
        local newStartRooms = {}
        for i = 0, vDoorList:size() - 1 do
            local door = vDoorList[i]
            for roomId, _ in pairs(startRooms) do
                if door.iRoom1 == roomId and not adjacentRooms[door.iRoom2] and door.iRoom2 ~= startRoomId then
                    adjacentRooms[door.iRoom2] = true
                    newStartRooms[door.iRoom2] = true
                elseif door.iRoom2 == roomId and not adjacentRooms[door.iRoom1] and door.iRoom1 ~= startRoomId then
                    adjacentRooms[door.iRoom1] = true
                    newStartRooms[door.iRoom1] = true
                end
            end
        end
        startRooms = newStartRooms
    end
    return adjacentRooms
end

local function clearBonusHacking(sys)
    if not sys.table._tm_bonusHacking then
        return
    end
    local adj = sys.table._tm_bonusHacking.adj
    local hackedShip = Hyperspace.Global.GetInstance():GetShipManager(sys.table._tm_bonusHacking.hackedShipId)
    if hackedShip then
        for id, _ in pairs(adj) do
            local enemySys = hackedShip:GetSystemInRoom(id)
            if enemySys then
                enemySys.iHackEffect = 0
                enemySys.bUnderAttack = false
            end
        end
    end
    sys.table._tm_bonusHacking = nil
end

local function hackingUpgrade(shipMgr, speed)
    local sys = shipMgr.hackingSystem
    if speed < 0 then
        clearBonusHacking(sys)
        sys.extend.additionalPowerLoss = sys.extend.additionalPowerLoss + math.ceil(-speed / 2)
        return
    end
    if sys.iLockCount ~= -1 then
        clearBonusHacking(sys)
        return
    end
    if sys.table._tm_bonusHacking then
        return
    end
    local hackedSys = sys.currentSystem
    local hackedShipId = (shipMgr.iShipId + 1) % 2
    local hackedShip = Hyperspace.Global.GetInstance():GetShipManager(hackedShipId)
    local hackedRoom = hackedSys:GetRoomId()
    local adj = getAdjacentRooms(hackedShip, hackedRoom, speed)
    sys.table._tm_bonusHacking = {}
    sys.table._tm_bonusHacking.hackedShipId = hackedShipId
    sys.table._tm_bonusHacking.adj = adj
    for id, _ in pairs(adj) do
        if shipMgr:GetDroneCount() <= 0 then
            break
        end
        local enemySys = hackedShip:GetSystemInRoom(id)
        if enemySys then
            enemySys.iHackEffect = 2
            enemySys.bUnderAttack = true
            Hyperspace.Sounds:PlaySoundMix("hackStart", -1, false)
            shipMgr:ModifyDroneCount(-1)
        end
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, genericUpgrade(15, hackingUpgrade, function(shipMgr)
    clearBonusHacking(shipMgr.hackingSystem)
end))

local function resistsMC(crew)
    local _, telepathic = crew.extend:CalculateStat(Hyperspace.CrewStat.IS_TELEPATHIC)
    if telepathic then
        return true
    end
    local _, resist = crew.extend:CalculateStat(Hyperspace.CrewStat.RESISTS_MIND_CONTROL)
    if resist then
        return true
    end
    return false
end

local function clearBonusMC(sys)
    if not sys.table._tm_bonusMC then
        return
    end
    local crewList = sys.table._tm_bonusMC.crewList
    for _, crew in ipairs(crewList) do
        if not crew.bDead and crew.bMindControlled then
            crew:SetMindControl(false)
            Hyperspace.Sounds:PlaySoundMix("mindControlEnd", -1, false)
        end
    end
    sys.table._tm_bonusMC = nil
end

local function applyBonusMC(sys, vCrewList, iShipId, limit)
    for i = 0, vCrewList:size() - 1 do
        if limit <= 0 then
            break
        end
        local crew = vCrewList[i]
        if not (crew.bDead or crew:IsDrone()) then
            if crew.bMindControlled and crew.iShipId == iShipId then
                crew:SetMindControl(false)
                Hyperspace.Sounds:PlaySoundMix("mindControlEnd", -1, false)
                limit = limit - 1
            elseif not crew.bMindControlled and not resistsMC(crew) and crew.iShipId ~= iShipId then
                crew:SetMindControl(true)
                Hyperspace.Sounds:PlaySoundMix("mindControl", -1, false)
                table.insert(sys.table._tm_bonusMC.crewList, crew)
                limit = limit - 1
            end
        end
    end
    return limit
end

local function mcUpgrade(shipMgr, speed)
    local sys = shipMgr.mindSystem
    if speed < 0 then
        clearBonusMC(sys)
        sys.extend.additionalPowerLoss = sys.extend.additionalPowerLoss + math.ceil(-speed / 2)
        return
    end
    if sys.iLockCount ~= -1 then
        clearBonusMC(sys)
        return
    end
    if sys.table._tm_bonusMC then
        return
    end
    sys.table._tm_bonusMC = {}
    sys.table._tm_bonusMC.crewList = {}
    local limit = sys:GetEffectivePower() * speed
    limit = applyBonusMC(sys, shipMgr.vCrewList, shipMgr.iShipId, limit)
    local enemyShipId = (shipMgr.iShipId + 1) % 2
    local enemyShip = Hyperspace.Global.GetInstance():GetShipManager(enemyShipId)
    if enemyShip then
        applyBonusMC(sys, enemyShip.vCrewList, shipMgr.iShipId, limit)
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, genericUpgrade(14, mcUpgrade, function(shipMgr)
    clearBonusMC(shipMgr.mindSystem)
end))

local function chargeUp(weapon, speed, speedUp, slowDown, speedUpMod)
    speedUpMod = speedUpMod or 1.0
    local safetyMargin = 0.01
    local safeMaxCooldown = weapon.cooldown.second - safetyMargin
    if weapon.powered and safeMaxCooldown > 0 and weapon.cooldown.first < safeMaxCooldown then
        local cdMod = 0.0
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
    if shipMgr.iShipId ~= 0 or tmConfig.player['selective_acceleration'] <= 0 then
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

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipMgr)
    local sys = shipMgr.shieldSystem
    if not sys then
        return
    end
    sys.shields.power.super.second = sys.shields.power.super.first
end)

local function shieldUpgrade(shipMgr, speed)
    local sys = shipMgr.shieldSystem
    if shipMgr.iShipId == 0 and tmConfig.player['infinite_shield'] > 0 and speed > 0 then
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
    local mod = 0
    if speed > 0 then
        mod = tmConfig.OXYGEN_SPEEDUP_RATES[speed] * power
    else
        mod = tmConfig.OXYGEN_SLOWDOWN_RATES[-speed] / power
    end
    delta = refill * mod
    local graph = Hyperspace.ShipGraph.GetShipInfo(shipMgr.iShipId)
    for i = 0, sys.oxygenLevels:size() - 1 do
        if sys.oxygenLevels[i] < sys.max_oxygen then
            sys.oxygenLevels[i] = math.max(sys.oxygenLevels[i] + delta, 0)
        end
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, genericUpgrade(2, oxygenUpgrade))

function setBounsPower(bonus)
    local delta = bonus - tmConfig.player['bonus_power']
    if delta == 0 then return end
    local powerMgr = Hyperspace.PowerManager.GetPowerManager(0)
    powerMgr.currentPower.second = powerMgr.currentPower.second + delta
    tmConfig.setPlayerConfig('bonus_power', bonus)
end

function clearPowerTimer(sys)
    sys.table._tm_powerTimer = 0
end

function chargeBounsPower(sys, delta, maxPoints)
    if tmConfig.player['bonus_power'] >= maxPoints then
        sys.table._tm_powerTimer = 0
        return
    end
    if not sys.table._tm_powerTimer then
        sys.table._tm_powerTimer = 0
    end
    sys.table._tm_powerTimer = sys.table._tm_powerTimer + delta * (2 ^ tmConfig.player['bpgen_speed'])
    if sys.table._tm_powerTimer >= 1 then
        sys.table._tm_powerTimer = sys.table._tm_powerTimer - 1
        setBounsPower(tmConfig.player['bonus_power'] + 1)
    end
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
        sys.extend.additionalPowerLoss = sys.extend.additionalPowerLoss - speed
        return
    end
    if speed == 0 or not sys.bTurnedOn then
        clearPowerTimer(sys)
        return
    end
    -- speed > 0 and sys.bTurnedOn
    local chargeSpeed = tmConfig.BONUSPOWER_CHARGE_RATES[speed]
    local delta = Hyperspace.FPS.SpeedFactor / 16 * chargeSpeed
    chargeBounsPower(sys, delta, power * 2)
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, batteryUpgrade)
script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function() setBounsPower(0) end)

function speedUpLock(sys, factors, speed)
    if sys.iLockCount > 0 then
        local timer = sys.lockTimer
        local delta = Hyperspace.FPS.SpeedFactor / 16 * factors[math.abs(speed)]
        timer.currTime = math.max(timer.currTime + delta, 0)
    end
end

local function lockUpgrades(shipMgr)
    local iShipId = shipMgr.iShipId
    for roomId, speed in pairs(roomSpeed[iShipId]) do
        local sys = shipMgr:GetSystemInRoom(roomId)
        if sys.iHackEffect < 2 then
            if speed < 0 then
                speedUpLock(sys, tmConfig.IONLOCK_SLOWDOWN_RATES, speed)
            elseif speed > 0 then
                speedUpLock(sys, tmConfig.IONLOCK_SPEEDUP_RATES, speed)
            end
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
    if speed < 0 then
        sys:ForceDecreasePower(-speed)
        sys.bManned = false
        sys.iActiveManned = 0
    else
        sys.bManned = true
        sys.iActiveManned = 3
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, genericUpgrade(7, sensorUpgrade))

local function doorsUpgrade(shipMgr, speed)
    local sys = shipMgr:GetSystem(8)
    if speed < 0 then
        sys:ForceDecreasePower(-speed)
        sys.bManned = false
        sys.iActiveManned = 0
    else
        sys.bManned = true
        sys.iActiveManned = 3
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, genericUpgrade(8, doorsUpgrade))

local function engineUpgrade(shipMgr, augName, augValue)
    if tmConfig.player['temporal_ftl'] <= 0 or augName ~= "FTL_BOOSTER" then
        return Defines.Chain.CONTINUE, augValue
    end
    local pilot = shipMgr:GetSystem(6)
    local engine = shipMgr:GetSystem(1)
    if not (pilot and engine and pilot.bManned and engine:Powered() and engine.iHackEffect < 2) then
        return Defines.Chain.CONTINUE, augValue
    end
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
        local factor = 0
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
    if shipId ~= 0 or tmConfig.player['drone_amplifier'] <= 0 then
        return Defines.Chain.CONTINUE
    end
    local shipMgr = Hyperspace.Global.GetInstance():GetShipManager(shipId)
    local speed = getSystemSpeed(shipMgr, 4)
    if speed <= 0 then return end
    local spaceMgr = Hyperspace.Global.GetInstance():GetCApp().world.space
    local cases = {
        ["LASER"] = function()
            -- LaserBlast* CreateLaserBlast(WeaponBlueprint *weapon, Pointf position, int space, int ownerId, Pointf target, int targetSpace, float heading);
            spaceMgr:CreateLaserBlast(
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
            -- Missile* CreateMissile(WeaponBlueprint *weapon, Pointf position, int space, int ownerId, Pointf target, int targetSpace, float heading);
            spaceMgr:CreateMissile(
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
            -- BeamWeapon* CreateBeam(WeaponBlueprint *weapon, Pointf position, int space, int ownerId, Pointf target1, Pointf target2, int targetSpace, int length, float heading);
            spaceMgr:CreateBeam(
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
            -- LaserBlast* CreateBurstProjectile(WeaponBlueprint *weapon, std::string &image, bool fake, Pointf position, int space, int ownerId, Pointf target, int targetSpace, float heading);
            local bp = drone.weaponBlueprint
            local projs = bp.miniProjectiles
            local i = math.random(0, projs:size() - 1)
            spaceMgr:CreateBurstProjectile(
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
            case()
        end
    end
    return Defines.Chain.CONTINUE
end

script.on_internal_event(Defines.InternalEvents.DRONE_FIRE, droneAmplifier)

local function dronesUpgrade(shipMgr)
    local sys = shipMgr.droneSystem
    if not sys then
        return
    end
    if sys.iHackEffect >= 2 then
        return
    end
    local speed = getTimeDilation(shipMgr, sys)
    if speed == 0 then
        return
    end
    if speed < 0 then
        sys.extend.additionalPowerLoss = sys.extend.additionalPowerLoss - speed
        return
    end

    --space drones
    if shipMgr.iShipId ~= 0 or tmConfig.player['drone_amplifier'] <= 0 then
        local extraUpdates = math.max(tmConfig.SPACEDRONE_SPEEDUP_FACTORS[speed] - 1 + (sys.table._tm_remnant or 0), 0)
        extraUpdates, sys.table._tm_remnant = math.modf(extraUpdates)
        local drones = shipMgr.spaceDrones
        for i = 0, drones:size() - 1 do
            local drone = drones[i]
            if drone.powered then
                for _ = 1, extraUpdates do
                    drone:OnLoop()
                end
            end
        end
    end

    -- crew drones
    local extraCrewUpdates = math.max(tmConfig.CREWDRONE_SPEEDUP_FACTORS[speed] - 1 + (sys.table._tm_crewRemnant or 0), 0)
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
    local otherShip = Hyperspace.Global.GetInstance():GetShipManager((shipMgr.iShipId + 1) % 2)
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
    if speed < 0 then
        if not sys.table._tm_powerLoss then
            sys.table._tm_powerLoss = math.ceil(-speed / 2)
            sys:SetPowerLoss(sys.iTempPowerLoss + sys.table._tm_powerLoss)
        end
        return
    end
    if sys.table._tm_powerLoss then
        sys:SetPowerLoss(sys.iTempPowerLoss - sys.table._tm_powerLoss)
        sys.table._tm_powerLoss = nil
    end

    if shipMgr.iShipId ~= 0 or tmConfig.player['temporal_teleporter'] <= 0 then
        return
    end

    local power = sys:GetEffectivePower()
    if speed == 0 or sys.iHackEffect >= 2 or power < 4 then
        return
    end
    local iShipId = shipMgr.iShipId
    local otherShip = Hyperspace.Global.GetInstance():GetShipManager((shipMgr.iShipId + 1) % 2)
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
    if shipMgr.iShipId ~= 0 or tmConfig.player['temporal_bot'] <= 0 then
        return
    end
    local sys = shipMgr:GetSystem(5)
    if not sys then
        return
    end
    local speed = getTimeDilation(shipMgr, sys)
    local power = sys:GetEffectivePower()
    if speed <= 0 or sys.iHackEffect >= 2 or power < 3 then
        return
    end
    local iShipId = shipMgr.iShipId
    local extraUpdates = math.max(tmConfig.MEDBAY_SPEEDUP_FACTORS[speed] - 1 + (sys.table._tm_remnant or 0), 0)
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

local function temporalStun(shipMgr)
    if tmConfig.player['temporal_stun'] <= 0 then
        return
    end
    local iShipId = shipMgr.iShipId
    local rooms = roomSpeed[iShipId]
    if not next(rooms) then
        return
    end
    local vCrewList = shipMgr.vCrewList
    for i = 0, vCrewList:size() - 1 do
        local crew = vCrewList[i]
        if not crew:IsDrone() and crew.iShipId ~= iShipId then
            for roomId, _ in pairs(rooms) do
                if crew:InsideRoom(roomId) then
                    crew.crewAnim.bStunned = true
                    crew.fStunTime = math.max(crew.fStunTime, 0.4)
                    break
                end
            end
        end
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, temporalStun)

local function spaceDroneBooster(shipMgr)
    local augName = "_TM_AUG_SPACE_DRONE_BOOSTER"
    if shipMgr:HasAugmentation(augName) <= 0 then
        return
    end
    local augValue = shipMgr:GetAugmentationValue(augName)
    if augValue <= 0 then
        return
    end
    local extraUpdates = augValue + (shipMgr.table._tm_sdbRemnant or 0)
    extraUpdates, shipMgr.table._tm_sdbRemnant = math.modf(extraUpdates)
    local drones = shipMgr.spaceDrones
    for i = 0, drones:size() - 1 do
        local drone = drones[i]
        if drone.powered then
            for _ = 1, extraUpdates do
                drone:OnLoop()
            end
        end
    end
    return
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, spaceDroneBooster)
