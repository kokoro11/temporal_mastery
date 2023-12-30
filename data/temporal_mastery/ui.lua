
if not mods.tmConfig then
    error("Temporal Mastery scripts are loaded in wrong order.")
end

local tmConfig = mods.tmConfig

local blackColor = Graphics.GL_Color(0 / 255, 0 / 255, 0 / 255, 1.0)
local whiteColor = Graphics.GL_Color(255 / 255, 255 / 255, 255 / 255, 1.0)
local greenColor = Graphics.GL_Color(100 / 255, 255 / 255, 100 / 255, 1.0)
local goldColor = Graphics.GL_Color(250 / 255, 250 / 255, 90 / 255, 1.0)
local redColor = Graphics.GL_Color(230 / 255, 110 / 255, 30 / 255, 1.0)

local function renderEnergyShieldCharger(playerShip)
    local shieldSystem = playerShip.shieldSystem
    if not shieldSystem then
        return
    end
    local superTimer = shieldSystem.table.__TM__superTimer
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

    local powerTimer = batterySystem.table.__TM__powerTimer
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
