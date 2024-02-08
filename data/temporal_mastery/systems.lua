
if not mods.temporal then
    error("Temporal Mastery scripts are loaded in wrong order.")
end

local systems = {}
local hasAug = mods.temporal.config.hasAug
mods.temporal.systems = systems

script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SHIP_MANAGER, function(shipMgr)
    shipMgr.table._tm_systems = {}
end)

-- JS-like class
local function Class(class)
    if class.super ~= nil then
        class.__index = class.super
        setmetatable(class, class)
    end
    function class:new(...)
        local o = { __index = self }
        setmetatable(o, o)
        if self.constructor then
            self.constructor(o, ...)
        end
        return o
    end
    return class
end

-- Multi MC

local function fullCrewList(selfCrewList, otherCrewList, i)
    if not otherCrewList or i < selfCrewList:size() then
        return selfCrewList[i]
    end
    return otherCrewList[i - selfCrewList:size()]
end

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

local MultiMC = Class{
    constructor = function(self, iShipId, size)
        self.iShipId = iShipId
        self.size = size
        self.slots = {}
        for i = 1, size do
            self.slots[i] = false
        end
    end
}

mods.temporal.MultiMC = MultiMC

function MultiMC:clearSlot(i)
    local crew = self.slots[i]
    if not crew then
        return
    end
    if crew.bDead then
        self.slots[i] = false
        return
    end
    if crew.bMindControlled then
        crew:SetMindControl(false)
        crew.bMindControlled = false
        Hyperspace.Sounds:PlaySoundMix("mindControlEnd", -1, false)
    end
    self.slots[i] = false
end

function MultiMC:resize(newSize)
    if newSize == self.size then
        return
    end
    if self.size < newSize then
        for i = self.size + 1, newSize do
            self.slots[i] = false
        end
    else
        for i = newSize + 1, self.size do
            self:clearSlot(i)
            self.slots[i] = nil
        end
    end
    self.size = newSize
end

function MultiMC:applyMC(crew, slotId)
    if not crew:IsDrone() then
        if crew.bMindControlled then
            if crew.iShipId == self.iShipId then
                crew:SetMindControl(false)
                crew.bMindControlled = false
                Hyperspace.Sounds:PlaySoundMix("mindControlEnd", -1, false)
            end
        else
            if not resistsMC(crew) and crew.iShipId ~= self.iShipId then
                crew:SetMindControl(true)
                crew.bMindControlled = true
                Hyperspace.Sounds:PlaySoundMix("mindControl", -1, false)
                self.slots[slotId] = crew
                return true
            end
        end
    end
    return false
end

function MultiMC:update(selfCrewList, otherCrewList)
    local j = 0
    local crewListSize = selfCrewList:size() + (otherCrewList and otherCrewList:size() or 0)
    for i = 1, self.size do
        if j >= crewListSize then
            break
        end
        local slot = self.slots[i]
        if not slot or slot.bDead or not slot.bMindControlled then
            while j < crewListSize do
                if self:applyMC(fullCrewList(selfCrewList, otherCrewList, j), i) then
                    break
                end
                j = j + 1
            end
        end
    end
end

function MultiMC:clear()
    self:resize(0)
end

-- Multi Hacking

local MultiHacking = Class{
    constructor = function(self, shipMgr, size)
        self.iShipId = shipMgr.iShipId
        self.hackedShipId = 1 - shipMgr.iShipId
        self.shipMgr = shipMgr
        self.size = size
        self.slots = {}
        self.droneCost = 0
        for i = 1, size do
            self.slots[i] = false
        end
    end
}

mods.temporal.MultiHacking = MultiHacking

function MultiHacking:clearSlot(i, hackedShip)
    if not hackedShip then
        self.slots[i] = false
        return
    end
    local roomId = self.slots[i]
    if not roomId then
        return
    end
    local sys = hackedShip:GetSystemInRoom(roomId)
    if not sys then
        self.slots[i] = false
        return
    end
    sys.iHackEffect = 0
    sys.bUnderAttack = false
    self.slots[i] = false
end

function MultiHacking:resize(newSize)
    if newSize == self.size then
        return
    end
    if self.size < newSize then
        for i = self.size + 1, newSize do
            self.slots[i] = false
        end
    else
        local hackedShip = Hyperspace.ships(self.hackedShipId)
        for i = newSize + 1, self.size do
            self:clearSlot(i, hackedShip)
            self.slots[i] = nil
        end
    end
    self.size = newSize
end

function MultiHacking:applyHack(sys, slotId)
    if sys.iHackEffect >= 2 then
        return false
    end
    sys.iHackEffect = 2
    sys.bUnderAttack = true
    self.slots[slotId] = sys:GetRoomId()
    Hyperspace.Sounds:PlaySoundMix("hackStart", -1, false)
    return true
end

local function shuffle(tInput)
    for i = #tInput, 1, -1 do
        local j = math.random(i)
        tInput[i], tInput[j] = tInput[j], tInput[i]
    end
end

local function randomize(vSystemList)
    local randomizedList = {}
    for i = 0, vSystemList:size() - 1 do
        local sys = vSystemList[i]
        table.insert(randomizedList, sys)
    end
    shuffle(randomizedList)
    return randomizedList
end

function MultiHacking:update()
    local hackedShip = Hyperspace.ships(self.hackedShipId)
    if not hackedShip then
        return
    end
    local j = 1
    for i = 1, self.size do
        local roomId = self.slots[i]
        local sys = roomId and hackedShip:GetSystemInRoom(roomId)
        if sys then
            sys.iHackEffect = 2
            sys.bUnderAttack = true
        elseif self.shipMgr:GetDroneCount() >= self.droneCost then
            if not hackedShip.table._tm_randomizedSystems then
                hackedShip.table._tm_randomizedSystems = randomize(hackedShip.vSystemList)
            end
            local systemList = hackedShip.table._tm_randomizedSystems
            while j <= #systemList do
                if self:applyHack(systemList[j], i) then
                    self.shipMgr:ModifyDroneCount(-self.droneCost)
                    break
                end
                j = j + 1
            end
        end
    end
end

function MultiHacking:clear()
    self:resize(0)
    local hackedShip = Hyperspace.ships(self.hackedShipId)
    if hackedShip then
        hackedShip.table._tm_randomizedSystems = nil
    end
end

-- Overclocker

local OverclockerSystem = Class{
    constructor = function(self, shipMgr, config)
        self.shipMgr = shipMgr
        self.timer = {0, 10}
        self.cooldown = {0, 40}
        -- 0 off 1 on 2 cooldown
        self.status = 0
        self.overclockedRoom = -1
        self.strength = 2
        self.powerCost = 3
        self.level = 0
        self.selectionMode = false
        if config then
            self.timer[2] = config.timer or 10
            self.cooldown[2] = config.cooldown or 40
            self.strength = config.strength or 2
            self.powerCost = config.power or 3
            self.level = config.power or 0
        end
        if shipMgr.iShipId == 1 then
            self.powerCost = 0
            -- enemy delay
            self.cooldown[1] = self.cooldown[2] - 10
            self.status = 2
        end
    end
}

function OverclockerSystem:update()
    if self.status == 0 then
        self.timer[1] = 0
        self.cooldown[1] = 0
        return
    end
    if self.status == 1 then
        if self.timer[1] < self.timer[2] then
            self.timer[1] = self.timer[1] + Hyperspace.FPS.SpeedFactor / 16
            self.cooldown[1] = 0
            self.selectionMode = false
            return
        else
            local powerMgr = Hyperspace.PowerManager.GetPowerManager(self.shipMgr.iShipId)
            powerMgr.iTempPowerLoss = powerMgr.iTempPowerLoss - self.powerCost
            Hyperspace.Sounds:PlaySoundMix("batteryStop", -1, false)
        end
    end
    self.overclockedRoom = -1
    self.selectionMode = false
    self.timer[1] = 0
    if self.cooldown[1] >= self.cooldown[2] then
        self.status = 0
        self.cooldown[1] = 0
        return
    end
    self.status = 2
    self.cooldown[1] = self.cooldown[1] + Hyperspace.FPS.SpeedFactor / 16
end

function OverclockerSystem:turnOn(overclockedRoom, strength)
    self.selectionMode = false
    self.overclockedRoom = overclockedRoom
    if strength then
        self.strength = strength
    end
    self.status = 1
    self.timer[1] = 0
    local powerMgr = Hyperspace.PowerManager.GetPowerManager(self.shipMgr.iShipId)
    powerMgr.iTempPowerLoss = powerMgr.iTempPowerLoss + self.powerCost
    Hyperspace.Sounds:PlaySoundMix("batteryStart", -1, false)
end

function OverclockerSystem:reset()
    self.timer[1] = 0
    self.cooldown[1] = 0
    self.status = 0
    self.overclockedRoom = -1
    self.selectionMode = false
end

function OverclockerSystem:enemyAI()
    if self.status == 0 then
        local vSystemList = self.shipMgr.vSystemList
        local size = vSystemList:size()
        if size <= 0 then
            return
        end
        -- for now...
        local sys = vSystemList[math.random(0, size - 1)]
        local p = sys:GetEffectivePower()
        local t = sys.iSystemType
        if p <= 0 or t == 1 or t == 6 or t == 7 or t == 12 or t == 5 or t == 13 or t == 2 or t == 10 or t == 20 then
            sys = vSystemList[math.random(0, size - 1)]
            p = sys:GetEffectivePower()
            t = sys.iSystemType
            if p <= 0 or t == 7 or t == 12 or t == 13 or t == 2 or t == 10 or t == 20 then
                sys = vSystemList[math.random(0, size - 1)]
            end
        end
        self:turnOn(sys:GetRoomId())
    end
end

-- order matters, should be ordered by level
local overclockerAugs = {
    [1] = {
        name = "_TM_AUG_OVERCLOCKER_DEV",
        timer = 2.5,
        cooldown = 17.5,
        strength = 4,
        power = 5,
        level = 4
    },
    [2] = {
        name = "_TM_AUG_OVERCLOCKER_MK3",
        timer = 5,
        cooldown = 25,
        strength = 3,
        power = 4,
        level = 3
    },
    [3] = {
        name = "_TM_AUG_OVERCLOCKER_MK2",
        timer = 15,
        cooldown = 30,
        strength = 2,
        power = 3,
        level = 2
    },
    [4] = {
        name = "_TM_AUG_OVERCLOCKER",
        timer = 10,
        cooldown = 50,
        strength = 2,
        power = 2,
        level = 1
    },
    [5] = {
        name = "_TM_AUG_OVERCLOCKER_MK0",
        timer = 10,
        cooldown = 50,
        strength = 1,
        power = 1,
        level = 0
    },
}

systems.overclockerAugs = overclockerAugs

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipMgr)
    local systemTable = shipMgr.table._tm_systems
    local overclocker = systemTable.overclocker
    local maxOverclocker = false
    for _, aug in ipairs(overclockerAugs) do
        if hasAug(shipMgr, aug.name) > 0 and not maxOverclocker then
            maxOverclocker = aug
            break
        end
    end
    if not maxOverclocker then
        systemTable.overclocker = nil
    elseif not overclocker or maxOverclocker.level > overclocker.level then
        systemTable.overclocker = OverclockerSystem:new(shipMgr, maxOverclocker)
    end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipMgr)
    local overclocker = shipMgr.table._tm_systems.overclocker
    if overclocker then
        if shipMgr.iShipId == 1 and shipMgr._targetable.hostile then
            overclocker:enemyAI()
        end
        overclocker:update()
    end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(shipMgr)
    local overclocker = shipMgr.table._tm_systems.overclocker
    if overclocker then
        overclocker:reset()
    end
end)

local function defaultPrimitive(filename)
    return Hyperspace.Resources:CreateImagePrimitiveString(filename, 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
end

local progress_bar_base = defaultPrimitive('temporal_mastery/progress_bar_base.png')
local progress_bar_timer = {}
for i = 0, 11 do
    progress_bar_timer[i] = defaultPrimitive('temporal_mastery/progress_bar_timer/'..i..'.png')
end
local progress_bar_cooldown = {}
for i = 0, 11 do
    progress_bar_cooldown[i] = defaultPrimitive('temporal_mastery/progress_bar_cooldown/'..i..'.png')
end

script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function()
    local cApp = Hyperspace.Global.GetInstance():GetCApp()
    if not cApp.world.bStartedGame or cApp.gui.menu_pause then
        return
    end
    local shipMgr = Hyperspace.ships.player
    if not shipMgr then
        return
    end
    local overclocker = shipMgr.table._tm_systems.overclocker
    if not overclocker or overclocker.status == 0 then
        return
    end
    if overclocker.status == 1 then
        local progress = math.floor((1 - overclocker.timer[1] / overclocker.timer[2]) * 11 + 0.5)
        progress = math.max(math.min(progress, 11), 0)
        --progress = (10 + 43 * progress) / 79
        Graphics.CSurface.GL_PushMatrix()
        Graphics.CSurface.GL_Translate(250 - 13, 110 - 37)
        Graphics.CSurface.GL_RenderPrimitive(progress_bar_base)
        Graphics.CSurface.GL_RenderPrimitive(progress_bar_timer[progress])
        Graphics.CSurface.GL_PopMatrix()
    else
        local progress = math.floor((overclocker.cooldown[1] / overclocker.cooldown[2]) * 11 + 0.5)
        progress = math.max(math.min(progress, 11), 0)
        --progress = (10 + 43 * progress) / 79
        Graphics.CSurface.GL_PushMatrix()
        Graphics.CSurface.GL_Translate(250 - 13, 110 - 37)
        Graphics.CSurface.GL_RenderPrimitive(progress_bar_base)
        Graphics.CSurface.GL_RenderPrimitive(progress_bar_cooldown[progress])
        Graphics.CSurface.GL_PopMatrix()
    end
end, function() end)
