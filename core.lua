-- AugSonar Core - Augmentation Evoker Buff Tracker with Combat Support
local EM_SPELL_ID = 395296    -- Ebon Might
local PRESC_SPELL_ID = 409311 -- Prescience

local ADDON_NAME = ...
local InCombat = false

-- ==========================================
-- [0] Database & Defaults
-- ==========================================
AugSonarDB = AugSonarDB or {
    alertThreshold = 3.0,
    minimapAngle = 45,
    theme = "default",
    showPrescience = true,
    soundEnabled = true,
    uiScale = 1.0,
    locked = false,
}

-- Theme definitions
local THEMES = {
    default = {
        name = "Default (Gold)",
        emColor = { 0.8, 0.6, 0 },
        prescColor = { 0.4, 0.8, 0.9 },
        bgColor = { 0, 0, 0, 0.6 },
        borderColor = { 1, 1, 1, 0.3 },
    },
    dark = {
        name = "Dark",
        emColor = { 1, 0.7, 0.1 },
        prescColor = { 0.2, 0.8, 1 },
        bgColor = { 0.05, 0.05, 0.05, 0.8 },
        borderColor = { 0.5, 0.5, 0.5, 0.5 },
    },
    light = {
        name = "Light",
        emColor = { 1, 0.8, 0.2 },
        prescColor = { 0.2, 0.7, 1 },
        bgColor = { 0.9, 0.9, 0.9, 0.3 },
        borderColor = { 0.2, 0.2, 0.2, 0.5 },
    },
    purple = {
        name = "Purple Mage",
        emColor = { 0.9, 0.4, 1 },
        prescColor = { 0.6, 0.2, 0.9 },
        bgColor = { 0.1, 0.05, 0.15, 0.7 },
        borderColor = { 0.8, 0.4, 1, 0.6 },
    },
}

-- ==========================================
-- [1] Main Frame & Events
-- ==========================================
local frame = CreateFrame("Frame", "AugSonarMainFrame", UIParent)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

-- ==========================================
-- [2] UI Container with Theme Support
-- ==========================================
local uiContainer = CreateFrame("Frame", "AugSonarUIContainer", UIParent)
uiContainer:SetSize(250, 100)
uiContainer:SetPoint("CENTER", 0, -150)
uiContainer:SetMovable(true)
uiContainer:EnableMouse(true)
uiContainer:RegisterForDrag("LeftButton")
uiContainer:SetScript("OnDragStart", function(self)
    if not AugSonarDB.locked then
        self:StartMoving()
    end
end)
uiContainer:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

local function ApplyTheme(container)
    local theme = THEMES[AugSonarDB.theme] or THEMES.default
    if container.emBar then
        container.emBar:SetStatusBarColor(unpack(theme.emColor))
    end
    if container.prescBar then
        container.prescBar:SetStatusBarColor(unpack(theme.prescColor))
    end
    if container.bg then
        container.bg:SetColorTexture(unpack(theme.bgColor))
    end
    if container.border then
        container.border:SetColorTexture(unpack(theme.borderColor))
    end
end

-- Ebon Might Bar
local emBar = CreateFrame("StatusBar", nil, uiContainer)
emBar:SetSize(240, 22)
emBar:SetPoint("TOP", uiContainer, "TOP", 0, 0)
emBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
emBar:Hide()

local emBg = emBar:CreateTexture(nil, "BACKGROUND")
emBg:SetAllPoints()

local emBorder = emBar:CreateTexture(nil, "BORDER")
emBorder:SetAllPoints()
emBorder:SetTexture("Interface\\Common\\Common-Input-Border")

local emText = emBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
emText:SetPoint("CENTER")
emText:SetText("Ebon Might")

uiContainer.emBar = emBar
uiContainer.bg = emBg
uiContainer.border = emBorder

-- Prescience Bar
local prescBar = CreateFrame("StatusBar", nil, uiContainer)
prescBar:SetSize(240, 22)
prescBar:SetPoint("TOP", uiContainer, "TOP", 0, -28)
prescBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
prescBar:Hide()

local prescBg = prescBar:CreateTexture(nil, "BACKGROUND")
prescBg:SetAllPoints()

local prescBorder = prescBar:CreateTexture(nil, "BORDER")
prescBorder:SetAllPoints()
prescBorder:SetTexture("Interface\\Common\\Common-Input-Border")

local prescText = prescBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
prescText:SetPoint("CENTER")
prescText:SetText("Prescience")

uiContainer.prescBar = prescBar

-- ==========================================
-- [3] Buff Tracking with Combat Fallback
-- ==========================================
local lastEMAlert = 0
local lastPrescAlert = 0

local function GetBuffFromNameplate(spellID)
    if not spellID or not UnitExists("player") then return nil end
    
    local nameplate = C_NamePlate and C_NamePlate.GetNamePlateForUnit("player")
    if not nameplate or not nameplate.UnitFrame or not nameplate.UnitFrame.BuffFrame then
        return nil
    end
    
    local buffFrame = nameplate.UnitFrame.BuffFrame
    for i = 1, buffFrame.numBuffs or 0 do
        local buff = buffFrame.auras[i]
        if buff and buff.spellID == spellID then
            return {
                spellID = buff.spellID,
                expirationTime = buff.expirationTime or (GetTime() + 15),
                duration = 15,
            }
        end
    end
    return nil
end

local function GetPlayerBuff(spellID)
    if not spellID then return nil end
    
    -- Try primary API first (works outside combat)
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        if aura then return aura end
    end
    
    -- Fallback for combat or if API unavailable
    return GetBuffFromNameplate(spellID)
end

-- ==========================================
-- [4] Update Logic
-- ==========================================
local isTesting = false

local function UpdateBuffBars()
    if isTesting then return end
    
    local inInstance = IsInInstance()
    if not inInstance then
        emBar:Hide()
        prescBar:Hide()
        return
    end
    
    local currentTime = GetTime()
    
    -- Update Ebon Might
    local emAura = GetPlayerBuff(EM_SPELL_ID)
    if emAura then
        emBar:Show()
        local remaining = math.max(0, emAura.expirationTime - currentTime)
        local duration = (emAura.duration and emAura.duration > 0) and emAura.duration or 15
        
        emBar:SetMinMaxValues(0, duration)
        emBar:SetValue(remaining)
        emText:SetText(string.format("Ebon Might: %.1fs", remaining))
        
        if remaining > 0 and remaining <= AugSonarDB.alertThreshold and (GetTime() - lastEMAlert) > 0.5 then
            if AugSonarDB.soundEnabled then
                PlaySoundFile("Interface\\AddOns\\AugSonar\\sonar.ogg", "Master")
            end
            lastEMAlert = GetTime()
        end
    else
        emBar:Hide()
    end
    
    -- Update Prescience (if enabled)
    if AugSonarDB.showPrescience then
        local prescAura = GetPlayerBuff(PRESC_SPELL_ID)
        if prescAura then
            prescBar:Show()
            local remaining = math.max(0, prescAura.expirationTime - currentTime)
            local duration = (prescAura.duration and prescAura.duration > 0) and prescAura.duration or 15
            
            prescBar:SetMinMaxValues(0, duration)
            prescBar:SetValue(remaining)
            prescText:SetText(string.format("Prescience: %.1fs", remaining))
            
            if remaining > 0 and remaining <= AugSonarDB.alertThreshold and (GetTime() - lastPrescAlert) > 0.5 then
                if AugSonarDB.soundEnabled then
                    PlaySoundFile("Interface\\AddOns\\AugSonar\\sonar.ogg", "Master")
                end
                lastPrescAlert = GetTime()
            end
        else
            prescBar:Hide()
        end
    else
        prescBar:Hide()
    end
end

-- ==========================================
-- [5] Settings UI
-- ==========================================
local settingsFrame = CreateFrame("Frame", "AugSonarSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
settingsFrame:SetSize(380, 450)
settingsFrame:SetPoint("CENTER")
settingsFrame:SetMovable(true)
settingsFrame:EnableMouse(true)
settingsFrame:RegisterForDrag("LeftButton")
settingsFrame:SetScript("OnDragStart", settingsFrame.StartMoving)
settingsFrame:SetScript("OnDragStop", settingsFrame.StopMovingOrSizing)
settingsFrame:Hide()

settingsFrame.title = settingsFrame:CreateFontString(nil, "OVERLAY")
settingsFrame.title:SetFontObject("GameFontBold")
settingsFrame.title:SetPoint("CENTER", settingsFrame.TitleBg, "CENTER", 0, 0)
settingsFrame.title:SetText("AugSonar Settings")

local yOffset = -40

-- Alert Threshold
local threshLabel = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
threshLabel:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, yOffset)
threshLabel:SetText("Alert Threshold:")
yOffset = yOffset - 25

local threshSlider = CreateFrame("Slider", "AugSonarThresholdSlider", settingsFrame, "OptionsSliderTemplate")
threshSlider:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 10, yOffset)
threshSlider:SetWidth(200)
threshSlider:SetMinMaxValues(0.5, 10)
threshSlider:SetValueStep(0.5)
threshSlider:SetObeyStepOnDrag(true)

local threshText = _G[threshSlider:GetName() .. "Text"]
local threshLow = _G[threshSlider:GetName() .. "Low"]
local threshHigh = _G[threshSlider:GetName() .. "High"]

threshLow:SetText("0.5s")
threshHigh:SetText("10s")

threshSlider:SetScript("OnValueChanged", function(self, value)
    AugSonarDB.alertThreshold = value
    threshText:SetText(string.format("%.1f", value))
end)

yOffset = yOffset - 40

-- Theme Selection
local themeLabel = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
themeLabel:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, yOffset)
themeLabel:SetText("Theme:")
yOffset = yOffset - 25

local themeDropdown = CreateFrame("Frame", "AugSonarThemeDropdown", settingsFrame, "UIDropDownMenuTemplate")
themeDropdown:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 10, yOffset)

UIDropDownMenu_Initialize(themeDropdown, function(self, level)
    for themeKey, themeData in pairs(THEMES) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = themeData.name
        info.arg1 = themeKey
        info.func = function(self, arg1)
            AugSonarDB.theme = arg1
            ApplyTheme(uiContainer)
            UIDropDownMenu_SetSelectedValue(themeDropdown, arg1)
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

UIDropDownMenu_SetSelectedValue(themeDropdown, AugSonarDB.theme)
UIDropDownMenu_SetWidth(themeDropdown, 150)

yOffset = yOffset - 35

-- Prescience Toggle
local prescCheckbox = CreateFrame("CheckButton", nil, settingsFrame, "UICheckButtonTemplate")
prescCheckbox:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, yOffset)
prescCheckbox:SetChecked(AugSonarDB.showPrescience)
prescCheckbox.text = prescCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
prescCheckbox.text:SetPoint("LEFT", prescCheckbox, "RIGHT", 5, 0)
prescCheckbox.text:SetText("Track Prescience")
prescCheckbox:SetScript("OnClick", function(self)
    AugSonarDB.showPrescience = self:GetChecked()
    if not AugSonarDB.showPrescience then prescBar:Hide() end
end)

yOffset = yOffset - 30

-- Sound Toggle
local soundCheckbox = CreateFrame("CheckButton", nil, settingsFrame, "UICheckButtonTemplate")
soundCheckbox:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, yOffset)
soundCheckbox:SetChecked(AugSonarDB.soundEnabled)
soundCheckbox.text = soundCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
soundCheckbox.text:SetPoint("LEFT", soundCheckbox, "RIGHT", 5, 0)
soundCheckbox.text:SetText("Enable Sounds")
soundCheckbox:SetScript("OnClick", function(self)
    AugSonarDB.soundEnabled = self:GetChecked()
end)

yOffset = yOffset - 30

-- Lock UI Toggle
local lockCheckbox = CreateFrame("CheckButton", nil, settingsFrame, "UICheckButtonTemplate")
lockCheckbox:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, yOffset)
lockCheckbox:SetChecked(AugSonarDB.locked)
lockCheckbox.text = lockCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lockCheckbox.text:SetPoint("LEFT", lockCheckbox, "RIGHT", 5, 0)
lockCheckbox.text:SetText("Lock UI Position")
lockCheckbox:SetScript("OnClick", function(self)
    AugSonarDB.locked = self:GetChecked()
end)

yOffset = yOffset - 40

-- Test Button
local testButton = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
testButton:SetSize(140, 28)
testButton:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, yOffset)
testButton:SetText("Test Alert & UI")
testButton:SetScript("OnClick", function()
    isTesting = not isTesting
    if isTesting then
        testButton:SetText("Stop Testing")
        emBar:Show()
        emBar:SetMinMaxValues(0, 15)
        emBar:SetValue(7.5)
        emText:SetText("Ebon Might: 7.5s (TEST)")
        
        if AugSonarDB.showPrescience then
            prescBar:Show()
            prescBar:SetMinMaxValues(0, 15)
            prescBar:SetValue(9.2)
            prescText:SetText("Prescience: 9.2s (TEST)")
        end
        
        if AugSonarDB.soundEnabled then
            PlaySoundFile("Interface\\AddOns\\AugSonar\\sonar.ogg", "Master")
        end
    else
        testButton:SetText("Test Alert & UI")
        emBar:Hide()
        prescBar:Hide()
    end
end)

yOffset = yOffset - 40

-- Close Button
local closeButton = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
closeButton:SetSize(140, 28)
closeButton:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 220, yOffset + 40)
closeButton:SetText("Close")
closeButton:SetScript("OnClick", function()
    settingsFrame:Hide()
end)

-- ==========================================
-- [6] Minimap Button
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

minimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("AugSonar")
    GameTooltip:AddLine("Click for settings")
    GameTooltip:Show()
end)

minimapBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- ==========================================
-- [7] Event Handling
-- ==========================================
local ticker

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        threshSlider:SetValue(AugSonarDB.alertThreshold)
        threshText:SetText(string.format("%.1f", AugSonarDB.alertThreshold))
        UpdateMinimapPos()
        ApplyTheme(uiContainer)
        print("|cFF33FF99AugSonar 2.0:|r Loaded. Click minimap icon for settings. In-combat mode active.")
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not ticker then
            ticker = C_Timer.NewTicker(0.1, UpdateBuffBars)
        end
        emBar:Hide()
        prescBar:Hide()
        
    elseif event == "PLAYER_REGEN_DISABLED" then
        InCombat = true
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        InCombat = false
    end
end)
