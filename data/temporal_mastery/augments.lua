
local origRoomSpeed = mods.temporal.origRoomSpeed
local roomSpeed = mods.temporal.roomSpeed
local hasAug = mods.temporal.config.hasAug

local function temporalStun(shipMgr)
    if hasAug(shipMgr, '_TM_AUG_TEMPORAL_STUN') <= 0 then
        return
    end
    local iShipId = shipMgr.iShipId
    local rooms = origRoomSpeed[iShipId]
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
    local hasSdb = (hasAug(shipMgr, "_TM_AUG_SPACE_DRONE_BOOSTER") > 0)
    local hasAdb = (hasAug(shipMgr, "_TM_AUG_ANCIENT_DRONE_BOOSTER") > 0)
    if not(hasAdb or hasSdb) then
        return
    end
    local augValue = hasAdb and 1.0 or 0.5
    local extraUpdates = augValue + (shipMgr.table._tm_sdbRemnant or 0)
    extraUpdates, shipMgr.table._tm_sdbRemnant = math.modf(extraUpdates)
    local drones = shipMgr.spaceDrones
    for i = 0, drones:size() - 1 do
        local drone = drones[i]
        if drone.powered then
            if drone.currentSpeed and drone.weaponCooldown >= 0 then
                drone.weaponCooldown = drone.weaponCooldown - Hyperspace.FPS.SpeedFactor / 16 * augValue
                if drone.weaponCooldown <= 0 then
                    drone.weaponCooldown = -1
                end
            end
            for _ = 1, extraUpdates do
                drone:OnLoop()
            end
        end
    end
    if not hasAdb then
        return
    end
    local crewList = shipMgr.vCrewList
    for i = 0, crewList:size() - 1 do
        local crew = crewList[i]
        if crew:IsDrone() and not crew:GetIntruder() then
            crew:OnLoop()
        end
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, spaceDroneBooster)

local function ionSpeedUp(shipMgr)
    if hasAug(shipMgr, "_TM_AUG_ION_SPEEDUP") <= 0 then
        return
    end
    local vSystemList = shipMgr.vSystemList
    for i = 0, vSystemList:size() - 1 do
        local sys = vSystemList[i]
        local t = sys.iSystemType
        if sys.iLockCount > 0 and t ~= 9 and t ~= 10 and t ~= 12 and t ~= 14 and t~= 15 and t~= 20 then
            local timer = sys.lockTimer
            timer.currTime = timer.currTime + Hyperspace.FPS.SpeedFactor / 16
        end
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, ionSpeedUp)

local function mindSpeedUp(shipMgr)
    if hasAug(shipMgr, "_TM_AUG_MIND_SPEEDUP") <= 0 then
        return
    end
    local sys = shipMgr.mindSystem
    if not sys then
        return
    end
    local crewList = sys.controlledCrew
    for i = 0, crewList:size() - 1 do
        crewList[i]:OnLoop()
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, mindSpeedUp)

local hackingSpeedupCases = mods.temporal.hackingSpeedupCases
local function hackingSpeedUp(shipMgr)
    if hasAug(shipMgr, "_TM_AUG_HACKING_SPEEDUP") <= 0 then
        return
    end
    local sys = shipMgr.hackingSystem
    if not sys then
        return
    end
    local hackedSys = sys.currentSystem
    if not hackedSys or hackedSys.iHackEffect < 2 then
        return
    end
    local case = hackingSpeedupCases[hackedSys.iSystemType]
    if not case then
        return
    end
    local enemyShip = Hyperspace.ships(1 - shipMgr.iShipId)
    if not enemyShip then
        return
    end
    case(enemyShip, 0.5, hackedSys:GetRoomId())
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, hackingSpeedUp)

local function crewSpeedUp(shipMgr)
    if hasAug(shipMgr, "_TM_AUG_CREW_SPEEDUP") <= 0 then
        return
    end
    local crewList = shipMgr.vCrewList
    for i = 0, crewList:size() - 1 do
        crewList[i]:OnLoop()
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, crewSpeedUp)
