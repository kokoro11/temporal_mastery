
if not mods.temporal then
    error("Temporal Mastery scripts are loaded in wrong order.")
end

local tmConfig = mods.temporal.config
local getTimeDilation = mods.temporal.getTimeDilation
local getSystemTooltip = mods.temporal.tooltip.getSystemTooltip

local blackColor = Graphics.GL_Color(0 / 255, 0 / 255, 0 / 255, 1.0)
local whiteColor = Graphics.GL_Color(255 / 255, 255 / 255, 255 / 255, 1.0)
local greenColor = Graphics.GL_Color(100 / 255, 255 / 255, 100 / 255, 1.0)
local goldColor = Graphics.GL_Color(250 / 255, 250 / 255, 90 / 255, 1.0)
local redColor = Graphics.GL_Color(241 / 255, 59 / 255, 59 / 255, 1.0)

local function renderEnergyShieldCharger(playerShip)
    local shieldSystem = playerShip.shieldSystem
    if not shieldSystem then
        return
    end
    local superTimer = shieldSystem.table._tm_superTimer
    if not superTimer or superTimer <= 0 then
        return
    end
    Graphics.CSurface.GL_DrawRectOutline(30, 87, 98, 7, whiteColor, 1)
    Graphics.CSurface.GL_DrawRect(33, 89, 92 * superTimer, 3, greenColor)
end

local function renderBonusEnergyCharger(playerShip)
    local batterySystem = playerShip.batterySystem
    if not batterySystem then
        return
    end

    local powerTimer = batterySystem.table._tm_powerTimer
    if powerTimer and powerTimer > 0 then
        Graphics.CSurface.GL_DrawRectOutline(12, 694, 28, 7, greenColor, 1)
        Graphics.CSurface.GL_DrawRect(14, 696, 24 * powerTimer, 3, goldColor)
    end

    local bonusPower = tmConfig.player['bonus_power']
    if bonusPower <= 0 then
        return
    end

    local maxBonusPower = 2 * batterySystem:GetEffectivePower()
    for i = 0, maxBonusPower - 1 do
        Graphics.CSurface.GL_DrawRectOutline(3, 686 - i * 9, 7, 7, greenColor, 1)
    end
    for i = 0, bonusPower - 1 do
        if i + 1 > maxBonusPower then
            Graphics.CSurface.GL_DrawRectOutline(3, 686 - i * 9, 7, 7, redColor, 1)
        end
        Graphics.CSurface.GL_DrawRect(5, 688 - i * 9, 3, 3, goldColor)
    end
end

local function playerShipRender()
    local playerShip = Hyperspace.ships.player
    if not playerShip then
        return
    end
    renderEnergyShieldCharger(playerShip)
    renderBonusEnergyCharger(playerShip)
end

script.on_render_event(Defines.RenderEvents.LAYER_PLAYER, playerShipRender, function() end)

local systemX = {
    [0] = 0,
    [1] = 0,
    [2] = 0,
    [3] = 0,
    [4] = 0,
    [5] = 0,
    [6] = 0,
    [7] = 0,
    [8] = 0,
    [9] = 0,
    [10] = 0,
    [11] = 0,
    [12] = 0,
    [13] = 0,
    [14] = 0,
    [15] = 0,
    [20] = 0
}

-- roomId as key
local enemySystemX = {}

local function checkEnemySystemPositions(shipMgr, isBoss)
    enemySystemX = {}
    local vSystemList = shipMgr.vSystemList
    local xOffset = isBoss and 851 or 931
    for i = 0, vSystemList:size() - 1 do
        local sys = vSystemList[i]
        enemySystemX[sys:GetRoomId()] = xOffset
        xOffset = xOffset + 30
    end
end

local function checkSystemPositions(shipMgr)
    if shipMgr.iShipId ~= 0 then
        local cApp = Hyperspace.Global.GetInstance():GetCApp()
        local isBoss = cApp.gui.combatControl.boss_visual
        checkEnemySystemPositions(shipMgr, isBoss)
        return
    end
    -- player systems positions
    local simpleSystemWidth = 36
    local specialSystemWidth = 54

    -- subsystems
    -- piloting
    if shipMgr:HasSystem(6) then
        systemX[6] = 1034
    else
        systemX[6] = 0
    end
    -- sensors
    if shipMgr:HasSystem(7) then
        systemX[7] = 1070
    else
        systemX[7] = 0
    end
    -- doors
    if shipMgr:HasSystem(8) then
        systemX[8] = 1106
    else
        systemX[8] = 0
    end
    -- battery
    if shipMgr:HasSystem(12) then
        systemX[12] = 1157
    else
        systemX[12] = 0
    end

    -- main systems
    local xOffset = 77
    -- shields
    if shipMgr:HasSystem(0) then
        systemX[0] = xOffset
        xOffset = xOffset + simpleSystemWidth
    else
        systemX[0] = 0
    end
    -- engines
    if shipMgr:HasSystem(1) then
        systemX[1] = xOffset
        xOffset = xOffset + simpleSystemWidth
    else
        systemX[1] = 0
    end
    -- medbay
    if shipMgr:HasSystem(5) then
        systemX[5] = xOffset
        xOffset = xOffset + simpleSystemWidth
    else
        systemX[5] = 0
    end
    -- clonebay
    if shipMgr:HasSystem(13) then
        systemX[13] = xOffset
        xOffset = xOffset + simpleSystemWidth
    else
        systemX[13] = 0
    end
    -- oxygen
    if shipMgr:HasSystem(2) then
        systemX[2] = xOffset
        xOffset = xOffset + simpleSystemWidth
    else
        systemX[2] = 0
    end
    -- teleporter
    if shipMgr:HasSystem(9) then
        systemX[9] = xOffset
        xOffset = xOffset + specialSystemWidth
    else
        systemX[9] = 0
    end
    -- cloaking
    if shipMgr:HasSystem(10) then
        systemX[10] = xOffset
        xOffset = xOffset + specialSystemWidth
    else
        systemX[10] = 0
    end
    -- artilleries
    if shipMgr:HasSystem(11) then
        systemX[11] = xOffset
        xOffset = xOffset + shipMgr.artillerySystems:size() * simpleSystemWidth
    else
        systemX[11] = 0
    end
    -- mind
    if shipMgr:HasSystem(14) then
        systemX[14] = xOffset
        xOffset = xOffset + specialSystemWidth
    else
        systemX[14] = 0
    end
    -- hacking
    if shipMgr:HasSystem(15) then
        systemX[15] = xOffset
        xOffset = xOffset + specialSystemWidth
    else
        systemX[15] = 0
    end
    -- temporal
    if shipMgr:HasSystem(20) then
        systemX[20] = xOffset
        xOffset = xOffset + specialSystemWidth
    else
        systemX[20] = 0
    end
    -- weapons
    if shipMgr:HasSystem(3) then
        systemX[3] = xOffset
        xOffset = xOffset + 48 + 97 * shipMgr.weaponSystem.slot_count
    else
        systemX[3] = 0
    end
    -- drones
    if shipMgr:HasSystem(4) then
        systemX[4] = xOffset
    else
        systemX[4] = 0
    end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, checkSystemPositions)

local function powerBarHeight(bars, iSystemType)
    -- assume bars > 0
    if iSystemType == 0 then
        return 8 * bars - 6 + (bars + 1) // 2 * 4
    end
    return 8 * bars - 2
end

local function drawPowerOutline(sys, x, color)
    local iSystemType = sys.iSystemType
    local height = powerBarHeight(sys:GetPowerCap(), iSystemType) + 6
    local width = 22
    local baseY
    if iSystemType == 6 or iSystemType == 7 or iSystemType == 8 or iSystemType == 12 then
        baseY = 650
    else
        baseY = 668
    end
    local y = baseY - height
    Graphics.CSurface.GL_DrawRectOutline(x, y, width, height, color, 2)
    x = x + 3
    baseY = baseY - 3
    local power = sys:GetEffectivePower()
    if sys.bManned and (iSystemType == 7 or iSystemType == 8) then
        power = power - 1
    end
    for i = 1, power do
        height = powerBarHeight(i, iSystemType)
        y = baseY - height
        Graphics.CSurface.GL_DrawRect(x, y, 16, 6, color)
    end
end

local function drawEnemyPowerOutline(sys, x, color, isBoss)
    local iSystemType = sys.iSystemType
    local height = powerBarHeight(sys:GetPowerCap(), iSystemType) + 6
    local width = 22
    -- local y = (isBoss and 590 - 31 or 563 - 31) - height
    local baseY = isBoss and 559 or 532
    local y = baseY - height
    Graphics.CSurface.GL_DrawRectOutline(x, y, width, height, color, 2)
    x = x + 3
    baseY = baseY - 3
    local power = sys:GetEffectivePower()
    if sys.bManned and (iSystemType == 7 or iSystemType == 8) then
        power = power - 1
    end
    for i = 1, power do
        height = powerBarHeight(i, iSystemType)
        y = baseY - height
        Graphics.CSurface.GL_DrawRect(x, y, 16, 6, color)
    end
end

local speedup_indicators = {}
local slowdown_indicators = {}
for speed = 1, 4 do
    local tex = Hyperspace.Resources:GetImageId("temporal_mastery/speedup_"..speed..".png")
    speedup_indicators[speed] = Graphics.CSurface.GL_CreateImagePrimitive(tex, 0, 0, 26, 11, 0, whiteColor)
    tex = Hyperspace.Resources:GetImageId("temporal_mastery/slowdown_"..speed..".png")
    slowdown_indicators[speed] = Graphics.CSurface.GL_CreateImagePrimitive(tex, 0, 0, 26, 11, 0, whiteColor)
end

local function renderEnemyIndicators(shipMgr, isBoss, playerShip)
    local y = isBoss and 590 or 563
    local rooms = mods.temporal.roomSpeed[1]
    for roomId, speed in pairs(rooms) do
        local sys = shipMgr:GetSystemInRoom(roomId)
        local xOffset = enemySystemX[roomId] or 0
        if speed > 0 then
            Graphics.CSurface.GL_PushMatrix()
            Graphics.CSurface.GL_Translate(xOffset, y)
            Graphics.CSurface.GL_RenderPrimitive(speedup_indicators[speed])
            Graphics.CSurface.GL_PopMatrix()
            if playerShip:DoSensorsProvide(3) then
                drawEnemyPowerOutline(sys, xOffset + 2, greenColor, isBoss)
            end
        else
            Graphics.CSurface.GL_PushMatrix()
            Graphics.CSurface.GL_Translate(xOffset, y)
            Graphics.CSurface.GL_RenderPrimitive(slowdown_indicators[-speed])
            Graphics.CSurface.GL_PopMatrix()
            if playerShip:DoSensorsProvide(3) then
                drawEnemyPowerOutline(sys, xOffset + 2, redColor, isBoss)
            end
        end
    end
end

local function renderPlayerIndicators(playerShip)
    local y = 699
    --local iconWidth = 26
    --local iconHeight = 11
    local artillerySystems = playerShip.artillerySystems
    for i = 0, artillerySystems:size() - 1 do
        local sys = artillerySystems[i]
        local speed = getTimeDilation(playerShip, sys)
        if speed ~= 0 then
            local x = systemX[11] + i * 36
            if speed > 0 then
                Graphics.CSurface.GL_PushMatrix()
                Graphics.CSurface.GL_Translate(x, y)
                Graphics.CSurface.GL_RenderPrimitive(speedup_indicators[speed])
                Graphics.CSurface.GL_PopMatrix()
                drawPowerOutline(sys, x + 2, greenColor)
            elseif speed < 0 then
                Graphics.CSurface.GL_PushMatrix()
                Graphics.CSurface.GL_Translate(x, y)
                Graphics.CSurface.GL_RenderPrimitive(slowdown_indicators[-speed])
                Graphics.CSurface.GL_PopMatrix()
                drawPowerOutline(sys, x + 2, redColor)
            end
        end
    end
    local rooms = mods.temporal.roomSpeed[0]
    for roomId, speed in pairs(rooms) do
        local sys = playerShip:GetSystemInRoom(roomId)
        local iSystemType = sys.iSystemType
        if iSystemType ~= 11 then
            local x = systemX[iSystemType]
            if speed > 0 then
                Graphics.CSurface.GL_PushMatrix()
                Graphics.CSurface.GL_Translate(x, y)
                Graphics.CSurface.GL_RenderPrimitive(speedup_indicators[speed])
                Graphics.CSurface.GL_PopMatrix()
                drawPowerOutline(sys, x + 2, greenColor)
            else
                Graphics.CSurface.GL_PushMatrix()
                Graphics.CSurface.GL_Translate(x, y)
                Graphics.CSurface.GL_RenderPrimitive(slowdown_indicators[-speed])
                Graphics.CSurface.GL_PopMatrix()
                drawPowerOutline(sys, x + 2, redColor)
            end
        end
    end
end

local oc_buttons = {
    'temporal_mastery/overclocker_select_off.png',
    'temporal_mastery/overclocker_select_on.png',
    'temporal_mastery/overclocker_select_select2.png',
}
for i, v in ipairs(oc_buttons) do
    local tex = Hyperspace.Resources:GetImageId(v)
    oc_buttons[i] = Graphics.CSurface.GL_CreateImagePrimitive(tex, 0, 0, 32, 17, 0, whiteColor)
end
local function renderOverclockerButtons(playerShip, mouse)
    mouse = mouse.position
    local y = 696
    local iconWidth = 32
    local iconHeight = 17
    local artillerySystems = playerShip.artillerySystems
    local noHover = true
    for i = 0, artillerySystems:size() - 1 do
        local x = systemX[11] + i * 36 - 3
        local state = 2
        if noHover and x <= mouse.x and mouse.x < x + iconWidth and
            y <= mouse.y and mouse.y < y + iconHeight then
            state = 3
            noHover = false
        end
        Graphics.CSurface.GL_PushMatrix()
        Graphics.CSurface.GL_Translate(x, y)
        Graphics.CSurface.GL_RenderPrimitive(oc_buttons[state])
        Graphics.CSurface.GL_PopMatrix()
    end
    local vSystemList = playerShip.vSystemList
    for i = 0, vSystemList:size() - 1 do
        local sys = vSystemList[i]
        local iSystemType = sys.iSystemType
        if iSystemType ~= 11 then
            local x = systemX[iSystemType] - 3
            local state = 2
            if noHover and x <= mouse.x and mouse.x < x + iconWidth and
                y <= mouse.y and mouse.y < y + iconHeight then
                state = 3
                noHover = false
            end
            Graphics.CSurface.GL_PushMatrix()
            Graphics.CSurface.GL_Translate(x, y)
            Graphics.CSurface.GL_RenderPrimitive(oc_buttons[state])
            Graphics.CSurface.GL_PopMatrix()
        end
    end
end

local function renderTemporalIndicators()
    local cApp = Hyperspace.Global.GetInstance():GetCApp()
    if not cApp.world.bStartedGame or cApp.gui.menu_pause then
        return
    end
    local playerShip = Hyperspace.ships.player
    if not playerShip then
        return
    end
    renderPlayerIndicators(playerShip)
    local overclocker = playerShip.table._tm_systems.overclocker
    if overclocker and overclocker.selectionMode == true then
        renderOverclockerButtons(playerShip, Hyperspace.Mouse)
    end
    local enemyShip = Hyperspace.ships.enemy
    if enemyShip and not playerShip.bJumping and enemyShip._targetable.hostile then
        renderEnemyIndicators(enemyShip, cApp.gui.combatControl.boss_visual, playerShip)
    end
end

script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, renderTemporalIndicators, function() end)

local function renderPlayerTooltips(shipMgr, mouse)
    local position = mouse.position
    local y = 699
    local iconWidth = 26
    local iconHeight = 11
    if not(y <= position.y and position.y < y + iconHeight) then
        return false
    end

    local artillerySystems = shipMgr.artillerySystems
    for i = 0, artillerySystems:size() - 1 do
        local sys = artillerySystems[i]
        local speed = getTimeDilation(shipMgr, sys)
        if speed ~= 0 then
            local x = systemX[11] + i * 36
            if x <= position.x and position.x < x + iconWidth then
                local title, content = getSystemTooltip(0, sys, speed, Hyperspace.Settings.language)
                mouse:SetTooltipTitle(title)
                mouse:SetTooltip(content)
                return true
            end
        end
    end

    local rooms = mods.temporal.roomSpeed[0]
    for roomId, speed in pairs(rooms) do
        local sys = shipMgr:GetSystemInRoom(roomId)
        local iSystemType = sys.iSystemType
        if iSystemType ~= 11 then
            local x = systemX[iSystemType]
            if x <= position.x and position.x < x + iconWidth then
                local title, content = getSystemTooltip(0, sys, speed, Hyperspace.Settings.language)
                mouse:SetTooltipTitle(title)
                mouse:SetTooltip(content)
                return true
            end
        end
    end
    return false
end

local function renderOverclockerTooltips(shipMgr, mouse, speed)
    -- assume speed ~= 0
    local position = mouse.position
    local y = 699
    local iconWidth = 26
    local iconHeight = 11
    if not(y <= position.y and position.y < y + iconHeight) then
        return false
    end

    local artillerySystems = shipMgr.artillerySystems
    for i = 0, artillerySystems:size() - 1 do
        local sys = artillerySystems[i]
        local x = systemX[11] + i * 36
        if x <= position.x and position.x < x + iconWidth then
            local title, content = getSystemTooltip(0, sys, speed, Hyperspace.Settings.language)
            mouse:SetTooltipTitle(title)
            mouse:SetTooltip(content)
            return true
        end
    end
    local vSystemList = shipMgr.vSystemList
    for i = 0, vSystemList:size() - 1 do
        local sys = vSystemList[i]
        local iSystemType = sys.iSystemType
            if iSystemType ~= 11 then
            local x = systemX[iSystemType]
            if x <= position.x and position.x < x + iconWidth then
                local title, content = getSystemTooltip(0, sys, speed, Hyperspace.Settings.language)
                mouse:SetTooltipTitle(title)
                mouse:SetTooltip(content)
                return true
            end
        end
    end
    return false
end

local function renderEnemyTooltips(shipMgr, isBoss, mouse)
    --local mouse = Hyperspace.Mouse
    local position = mouse.position
    local y = isBoss and 590 or 563
    local iconWidth = 26
    local iconHeight = 11
    if not(y <= position.y and position.y < y + iconHeight) then
        return false
    end
    local rooms = mods.temporal.roomSpeed[1]
    for roomId, speed in pairs(rooms) do
        local sys = shipMgr:GetSystemInRoom(roomId)
        local xOffset = enemySystemX[roomId] or 0
        if xOffset <= position.x and position.x < xOffset + iconWidth then
            local title, content = getSystemTooltip(1, sys, speed, Hyperspace.Settings.language)
            mouse:SetTooltipTitle(title)
            mouse:SetTooltip(content)
            return true
        end
    end
    return false
end

local function renderTooltips()
    local cApp = Hyperspace.Global.GetInstance():GetCApp()
    if not cApp.world.bStartedGame or cApp.gui.menu_pause then
        return
    end
    local playerShip = Hyperspace.ships.player
    if not playerShip then
        return
    end
    local mouse = Hyperspace.Mouse
    local enemyShip = Hyperspace.ships.enemy
    if enemyShip and not playerShip.bJumping and enemyShip._targetable.hostile then
        if renderEnemyTooltips(enemyShip, cApp.gui.combatControl.boss_visual, mouse) then
            return
        end
    end
    local overclocker = playerShip.table._tm_systems.overclocker
    if not overclocker or overclocker.selectionMode ~= true then
        renderPlayerTooltips(playerShip, mouse)
    else
        renderOverclockerTooltips(playerShip, mouse, overclocker.strength)
    end
end

script.on_internal_event(Defines.InternalEvents.ON_TICK, renderTooltips)

local function overclockerSelectionMode(mouseX, mouseY)
    local cApp = Hyperspace.Global.GetInstance():GetCApp()
    if not cApp.world.bStartedGame or cApp.gui.menu_pause then
        return
    end
    local shipMgr = Hyperspace.ships.player
    if not shipMgr then
        return
    end

    local overclocker = shipMgr.table._tm_systems.overclocker
    if not overclocker or overclocker.selectionMode ~= true then
        return
    end

    local y = 699
    local iconWidth = 26
    local iconHeight = 11
    if not(y <= mouseY and mouseY < y + iconHeight) then
        return
    end

    local artillerySystems = shipMgr.artillerySystems
    for i = 0, artillerySystems:size() - 1 do
        local sys = artillerySystems[i]
        local x = systemX[11] + i * 36
        if x <= mouseX and mouseX < x + iconWidth then
            overclocker:turnOn(sys:GetRoomId())
            return
        end
    end

    local vSystemList = shipMgr.vSystemList
    for i = 0, vSystemList:size() - 1 do
        local sys = vSystemList[i]
        local iSystemType = sys.iSystemType
        if iSystemType ~= 11 then
            local x = systemX[iSystemType]
            if x <= mouseX and mouseX < x + iconWidth then
                overclocker:turnOn(sys:GetRoomId())
                return
            end
        end
    end
end

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, overclockerSelectionMode)

local ocButton = Hyperspace.Button()
ocButton:OnInit("statusUI/tm_overclocker", Hyperspace.Point(200 + 8, 110 + 19))

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
    if not overclocker then
        ocButton:SetActive(false)
        return
    end
    if overclocker.selectionMode or overclocker.status ~= 0 then
        ocButton:SetActive(false)
    else
        ocButton:SetActive(true)
    end
    local mouse = Hyperspace.Mouse.position
    local hitbox = ocButton.hitbox
    if hitbox.x <= mouse.x and mouse.x < hitbox.x + hitbox.w and
        hitbox.y <= mouse.y and mouse.y < hitbox.y + hitbox.h then
        ocButton.bHover = true
    else
        ocButton.bHover = false
    end
    ocButton:OnRender()
end, function() end)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function()
    local cApp = Hyperspace.Global.GetInstance():GetCApp()
    if not cApp.world.bStartedGame or cApp.gui.menu_pause then
        return
    end
    local shipMgr = Hyperspace.ships.player
    if not shipMgr then
        return
    end
    local overclocker = shipMgr.table._tm_systems.overclocker
    if not overclocker or overclocker.status ~= 0 or overclocker.selectionMode then
        return
    end
    local mouse = Hyperspace.Mouse.position
    local hitbox = ocButton.hitbox
    if hitbox.x <= mouse.x and mouse.x < hitbox.x + hitbox.w and
        hitbox.y <= mouse.y and mouse.y < hitbox.y + hitbox.h then
        overclocker.selectionMode = true
    end
end)

local systemIds = {
    [0] = "shields",
    "engines",
    "oxygen",
    "weapons",
    "drones",
    "medbay",
    "pilot",
    "sensors",
    "doors",
    "teleporter",
    "cloaking",
    "artillery",
    "battery",
    "clonebay",
    "mind",
    "hacking",
    [20] = "temporal"
}
local systemIcons = {}
do
    local function systemIcon(name)
        local tex = Hyperspace.Resources:GetImageId("icons/s_"..name.."_overlay.png")
        return Graphics.CSurface.GL_CreateImagePrimitive(tex, 0, 0, 32, 32, 0, whiteColor)
    end
    for id, sys in pairs(systemIds) do
        systemIcons[id] = systemIcon(sys)
    end
end

local overclockerBox = Hyperspace.Resources:CreateImagePrimitiveString('temporal_mastery/enemy_overclocker.png', 0, 0, 0, whiteColor, 1.0, false)
local function renderEnemyOverclocker()
    local cApp = Hyperspace.Global.GetInstance():GetCApp()
    if not cApp.world.bStartedGame or cApp.gui.menu_pause then
        return
    end
    local playerShip = Hyperspace.ships.player
    local enemyShip = Hyperspace.ships.enemy
    if not (playerShip and not playerShip.bJumping and enemyShip and enemyShip._targetable.hostile) then
        return
    end
    local overclocker = enemyShip.table._tm_systems.overclocker
    if not overclocker or overclocker.status ~= 1 then
        return
    end
    local sys = enemyShip:GetSystemInRoom(overclocker.overclockedRoom)
    if not sys then
        return
    end
    local systemIcon = systemIcons[sys.iSystemType]
    if not systemIcon then
        return
    end
    local currentX = 884
	local currentY = 202
	if cApp.gui.combatControl.boss_visual then
		currentX = 759
		currentY = 159
	end
    local mouse = Hyperspace.Mouse.position
    local iconWidth = 73
    local iconHeight = 40
    local alpha = 1.0
    if currentX <= mouse.x and mouse.x < currentX + iconWidth and
        currentY <= mouse.y and mouse.y < currentY + iconHeight then
        alpha = 0.5
    end
    Graphics.CSurface.GL_PushMatrix()
    Graphics.CSurface.GL_Translate(currentX, currentY)
    Graphics.CSurface.GL_RenderPrimitiveWithAlpha(overclockerBox, alpha)
    Graphics.CSurface.GL_Translate(32, 4)
    Graphics.CSurface.GL_RenderPrimitiveWithAlpha(systemIcon, alpha)
    Graphics.CSurface.GL_PopMatrix()
end

script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, renderEnemyOverclocker, function() end)
