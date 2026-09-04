local EM_SPELL_ID = 395296

-- Initialize Database
AugSonarDB = AugSonarDB or {
    alertThreshold = 3.0,
    minimapAngle = 45,
}

local ADDON_NAME = ...
local frame = CreateFrame("Frame", "AugSonarMainFrame", UIParent)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- ==========================================
-- [1] UI Elements: Duration Bar
-- ==========================================
local emBar = CreateFrame("StatusBar", nil, UIParent)
emBar:SetSize(200, 20)
emBar:SetPoint("CENTER", 0, -150)
emBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
emBar:SetStatusBarColor(0.8, 0.6, 0)
emBar:Hide()

local emBarBg = emBar:CreateTexture(nil, "BACKGROUND")
emBarBg:SetAllPoints()
emBarBg:SetColorTexture(0, 0, 0, 0.5)

local emText = emBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
emText:SetPoint("CENTER")
emText:SetText("Ebon Might")

-- ==========================================
-- [2] Settings UI & Test Mode Logic
-- ==========================================
local isTesting = false

local settingsFrame = CreateFrame("Frame", "AugSonarSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
settingsFrame:SetSize(300, 200)
settingsFrame:SetPoint("CENTER")
settingsFrame:SetMovable(true)
settingsFrame:EnableMouse(true)
settingsFrame:RegisterForDrag("LeftButton")
settingsFrame:SetScript("OnDragStart", settingsFrame.StartMoving)
settingsFrame:SetScript("OnDragStop", settingsFrame.StopMovingOrSizing)
settingsFrame:Hide()

settingsFrame.title = settingsFrame:CreateFontString(nil, "OVERLAY")
settingsFrame.title:SetFontObject("GameFontHighlight")
settingsFrame.title:SetPoint("CENTER", settingsFrame.TitleBg, "CENTER", 0, 0)
settingsFrame.title:SetText("AugSonar Settings")

local slider = CreateFrame("Slider", "AugSonarThresholdSlider", settingsFrame, "OptionsSliderTemplate")
slider:SetPoint("TOP", settingsFrame, "TOP", 0, -60)
slider:SetMinMaxValues(1, 10)
slider:SetValueStep(0.5)
slider:SetObeyStepOnDrag(true)

local sliderText = _G[slider:GetName() .. "Text"]
local sliderLow = _G[slider:GetName() .. "Low"]
local sliderHigh = _G[slider:GetName() .. "High"]

sliderLow:SetText("1s")
sliderHigh:SetText("10s")

slider:SetScript("OnValueChanged", function(self, value)
    AugSonarDB.alertThreshold = value
    sliderText:SetText("Alert Threshold: " .. string.format("%.1f", value) .. "s")
end)

local testButton = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
testButton:SetSize(120, 25)
testButton:SetPoint("BOTTOM", settingsFrame, "BOTTOM", 0, 20)
testButton:SetText("Test Alert & UI")

local function PlaySonarSound()
    PlaySoundFile("Interface\\AddOns\\AugSonar\\sonar.ogg", "Master")
end

testButton:SetScript("OnClick", function()
    isTesting = not isTesting

    if isTesting then
        testButton:SetText("Stop Testing")
        emBar:Show()
        emBar:SetMinMaxValues(0, 15)
        emBar:SetValue(7.5)
        emText:SetText("Ebon Might: 7.5s (TEST)")
        PlaySonarSound()
    else
        testButton:SetText("Test Alert & UI")
        emBar:Hide()
    end
end)

-- ==========================================
-- [3] Minimap Button
-- ==========================================
local minimapBtn = CreateFrame("Button", "AugSonarMinimapBtn", Minimap)
minimapBtn:SetSize(32, 32)
minimapBtn:SetFrameStrata("MEDIUM")
minimapBtn:SetFrameLevel(8)
minimapBtn:RegisterForClicks("AnyUp")
minimapBtn:RegisterForDrag("LeftButton")
minimapBtn:SetMovable(true)

local minimapIcon = minimapBtn:CreateTexture(nil, "BACKGROUND")
minimapIcon:SetTexture("Interface\\AddOns\\AugSonar\\icon.tga")
minimapIcon:SetSize(20, 20)
minimapIcon:SetPoint("CENTER")

local minimapBorder = minimapBtn:CreateTexture(nil, "OVERLAY")
minimapBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
minimapBorder:SetSize(54, 54)
minimapBorder:SetPoint("TOPLEFT")

local function UpdateMinimapPos()
    local angle = math.rad(AugSonarDB.minimapAngle or 45)
    local x, y = math.cos(angle) * 80, math.sin(angle) * 80
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

minimapBtn:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale

        local angle = math.deg(math.atan(py - my, px - mx))
        AugSonarDB.minimapAngle = angle
        UpdateMinimapPos()
    end)
end)

minimapBtn:SetScript("OnDragStop", function(self)
    self:UnlockHighlight()
    self:SetScript("OnUpdate", nil)
end)

minimapBtn:SetScript("OnClick", function()
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        settingsFrame:Show()
    end
end)

local alertedEM = false
local lastExpirationTime = 0
local ticker

local function UpdateLogic()
    if isTesting then return end

    local inInstance = IsInInstance()
    if not inInstance then
        emBar:Hide()
        alertedEM = false
        lastExpirationTime = 0
        return
    end

    local currentTime = GetTime()
    local emAura = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID and C_UnitAuras.GetPlayerAuraBySpellID(EM_SPELL_ID)

    if emAura then
        emBar:Show()

        local remaining = math.max(0, emAura.expirationTime - currentTime)
        local duration = (emAura.duration and emAura.duration > 0) and emAura.duration or 15

        emBar:SetMinMaxValues(0, duration)
        emBar:SetValue(remaining)
        emText:SetText(string.format("Ebon Might: %.1fs", remaining))

        if emAura.expirationTime ~= lastExpirationTime then
            alertedEM = false
            lastExpirationTime = emAura.expirationTime
        end

        if remaining > 0 and remaining <= AugSonarDB.alertThreshold and not alertedEM then
            PlaySonarSound()
            alertedEM = true
        elseif remaining > AugSonarDB.alertThreshold then
            alertedEM = false
        end
    else
        emBar:Hide()
        alertedEM = false
        lastExpirationTime = 0
    end
end

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        slider:SetValue(AugSonarDB.alertThreshold)
        sliderText:SetText("Alert Threshold: " .. string.format("%.1f", AugSonarDB.alertThreshold) .. "s")
        UpdateMinimapPos()
        print("|cFF33FF99AugSonar:|r Loaded successfully. Click the minimap icon for settings.")
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not ticker then
            ticker = C_Timer.NewTicker(0.1, UpdateLogic)
        end
    end
end)
