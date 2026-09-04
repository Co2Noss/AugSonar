-- AugSonar Core - Augmentation Evoker Buff Tracker with Combat Support
local VERSION = "0.02"
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
    showGroupPrescience = true,
    locked = false,
    debugMode = false,
}

-- Theme definitions
local THEMES = {
    default = {
        name = "Default (Gold)",
        emColor = { 0.8, 0.6, 0 },
        prescColor = { 0.4, 0.8, 0.9 },
        bgColor = { 0, 0, 0, 0.6 },
        borderColor = { 1, 1, 1, 0.3 },
        windowBgColor = { 0.05, 0.05, 0.05, 0.8 },
    },
    dark = {
        name = "Dark",
        emColor = { 1, 0.7, 0.1 },
        prescColor = { 0.2, 0.8, 1 },
        bgColor = { 0.05, 0.05, 0.05, 0.9 },
        borderColor = { 0.5, 0.5, 0.5, 0.7 },
        windowBgColor = { 0.02, 0.02, 0.02, 0.9 },
    },
    light = {
        name = "Light",
        emColor = { 1, 0.8, 0.2 },
        prescColor = { 0.2, 0.7, 1 },
        bgColor = { 0.9, 0.9, 0.9, 0.5 },
        borderColor = { 0.2, 0.2, 0.2, 0.7 },
        windowBgColor = { 0.85, 0.85, 0.85, 0.7 },
    },
    purple = {
        name = "Purple Mage",
        emColor = { 0.9, 0.4, 1 },
        prescColor = { 0.6, 0.2, 0.9 },
        bgColor = { 0.1, 0.05, 0.15, 0.8 },
        borderColor = { 0.8, 0.4, 1, 0.8 },
        windowBgColor = { 0.08, 0.03, 0.12, 0.85 },
    },
    elvui = {
        name = "ElvUI (Crimson)",
        emColor = { 0.9, 0.1, 0.1 },
        prescColor = { 0.3, 0.7, 0.9 },
        bgColor = { 0.12, 0.05, 0.05, 0.85 },
        borderColor = { 0.6, 0.1, 0.1, 0.8 },
        windowBgColor = { 0.1, 0.04, 0.04, 0.9 },
    },
    ellsemereui = {
        name = "EllesemereUI (Teal)",
        emColor = { 0.2, 0.8, 0.8 },
        prescColor = { 0.3, 0.9, 0.7 },
        bgColor = { 0.05, 0.15, 0.15, 0.85 },
        borderColor = { 0.2, 0.7, 0.7, 0.8 },
        windowBgColor = { 0.04, 0.12, 0.12, 0.9 },
    },
    gw2ui = {
        name = "GW2 UI (Gold/Brown)",
        emColor = { 1, 0.82, 0.2 },
        prescColor = { 0.5, 0.8, 0.3 },
        bgColor = { 0.15, 0.1, 0.05, 0.85 },
        borderColor = { 0.8, 0.6, 0.2, 0.8 },
        windowBgColor = { 0.12, 0.08, 0.04, 0.9 },
    },
    realui = {
        name = "RealUI (Blue/Cyan)",
        emColor = { 0.3, 0.8, 1 },
        prescColor = { 0.2, 0.9, 0.8 },
        bgColor = { 0.05, 0.12, 0.18, 0.85 },
        borderColor = { 0.2, 0.6, 0.9, 0.8 },
        windowBgColor = { 0.04, 0.08, 0.14, 0.9 },
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
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")

-- ==========================================
-- [2] Sound Function
-- ==========================================
-- [2] Sound & Debug Functions
-- ==========================================
local function DebugPrint(message)
    if AugSonarDB.debugMode then
        print("|cFF33FF99AugSonar [DEBUG]:|r " .. message)
    end
end

local function PlaySonarSound()
    if not AugSonarDB.soundEnabled then 
        DebugPrint("Sound is disabled, skipping alert")
        return 
    end
    
    DebugPrint("Playing sonar sound...")
    
    -- Try with forward slashes (WoW standard)
    local soundPath1 = "Interface/AddOns/AugSonar/sonar.ogg"
    local soundPath2 = "Interface\\AddOns\\AugSonar\\sonar.ogg"
    
    if PlaySoundFile then
        local success = PlaySoundFile(soundPath1, "Master")
        if not success then
            PlaySoundFile(soundPath2, "Master")
        end
    else
        -- Fallback: Use a built-in game sound
        PlaySound(8596)
    end
end

-- ==========================================
-- [3] UI Container with Theme Support
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
uiContainer.emBg = emBg
uiContainer.emBorder = emBorder
uiContainer.emText = emText

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
uiContainer.prescBg = prescBg
uiContainer.prescBorder = prescBorder
uiContainer.prescText = prescText

-- Apply theme to UI
local function ApplyTheme(immediately)
    local theme = THEMES[AugSonarDB.theme] or THEMES.default
    
    -- Player buffs
    if uiContainer.emBar then
        uiContainer.emBar:SetStatusBarColor(unpack(theme.emColor))
        uiContainer.emBg:SetColorTexture(unpack(theme.bgColor))
        uiContainer.emBorder:SetColorTexture(unpack(theme.borderColor))
    end
    
    if uiContainer.prescBar then
        uiContainer.prescBar:SetStatusBarColor(unpack(theme.prescColor))
        uiContainer.prescBg:SetColorTexture(unpack(theme.bgColor))
        uiContainer.prescBorder:SetColorTexture(unpack(theme.borderColor))
    end
    
    -- Group Prescience window
    if prescienceWindow then
        if prescienceWindow.bg then
            prescienceWindow.bg:SetColorTexture(unpack(theme.bgColor))
        end
        if prescienceWindow.border then
            prescienceWindow.border:SetColorTexture(unpack(theme.borderColor))
        end
        -- Update all group member rows
        for i = 1, prescienceWindow.maxRows or 5 do
            local row = prescienceWindow["row" .. i]
            if row and row.bar then
                row.bar:SetStatusBarColor(unpack(theme.prescColor))
                if row.bg then
                    row.bg:SetColorTexture(unpack(theme.bgColor))
                end
            end
        end
    end
end

-- ==========================================
-- [4] Group Prescience Tracking Window
-- ==========================================
local prescienceWindow = CreateFrame("Frame", "AugSonarPrescienceWindow", UIParent)
prescienceWindow:SetSize(300, 200)
prescienceWindow:SetPoint("CENTER", 400, 0)
prescienceWindow:SetMovable(true)
prescienceWindow:EnableMouse(true)
prescienceWindow:RegisterForDrag("LeftButton")
prescienceWindow:SetScript("OnDragStart", function(self)
    if not AugSonarDB.locked then
        self:StartMoving()
    end
end)
prescienceWindow:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)
prescienceWindow:Hide()

-- Window background
local pwBg = prescienceWindow:CreateTexture(nil, "BACKGROUND")
pwBg:SetAllPoints()
pwBg:SetColorTexture(0, 0, 0, 0.6)
prescienceWindow.bg = pwBg

-- Window border
local pwBorder = prescienceWindow:CreateTexture(nil, "BORDER")
pwBorder:SetAllPoints()
pwBorder:SetTexture("Interface\\Common\\Common-Input-Border")
pwBorder:SetColorTexture(1, 1, 1, 0.3)
prescienceWindow.border = pwBorder

-- Title
local pwTitle = prescienceWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
pwTitle:SetPoint("TOPLEFT", prescienceWindow, "TOPLEFT", 8, -8)
pwTitle:SetText("Prescience Targets")

prescienceWindow.maxRows = 8
local groupPrescienceData = {}

local function UpdateGroupPrescienceWindow()
    if not AugSonarDB.showGroupPrescience or not AugSonarDB.showPrescience then
        prescienceWindow:Hide()
        return
    end
    
    local inInstance = IsInInstance()
    if not inInstance then
        prescienceWindow:Hide()
        return
    end
    
    groupPrescienceData = {}
    local numGroupMembers = GetNumGroupMembers()
    
    if numGroupMembers == 0 then
        prescienceWindow:Hide()
        return
    end
    
    local currentTime = GetTime()
    local isRaid = IsInRaid()
    
    for i = 1, numGroupMembers do
        local unit = isRaid and ("raid" .. i) or ("party" .. i)
        if UnitExists(unit) then
            local auras = C_UnitAuras.GetAuraSlots(unit, 1)
            if auras then
                for _, auraInfo in ipairs(auras) do
                    if auraInfo.spellId == PRESC_SPELL_ID then
                        local remaining = math.max(0, auraInfo.expirationTime - currentTime)
                        table.insert(groupPrescienceData, {
                            name = UnitName(unit),
                            remaining = remaining,
                            expirationTime = auraInfo.expirationTime,
                        })
                        break
                    end
                end
            end
        end
    end
    
    -- Sort by remaining time
    table.sort(groupPrescienceData, function(a, b)
        return a.remaining > b.remaining
    end)
    
    if #groupPrescienceData == 0 then
        prescienceWindow:Hide()
        return
    end
    
    prescienceWindow:Show()
    
    -- Update rows
    local yOffset = -30
    for i = 1, #groupPrescienceData do
        if i > prescienceWindow.maxRows then break end
        
        local data = groupPrescienceData[i]
        local rowName = "row" .. i
        local row = prescienceWindow[rowName]
        
        if not row then
            row = CreateFrame("Frame", nil, prescienceWindow)
            row:SetSize(280, 20)
            row:SetPoint("TOPLEFT", prescienceWindow, "TOPLEFT", 8, yOffset)
            
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            row.bg = bg
            
            local bar = CreateFrame("StatusBar", nil, row)
            bar:SetSize(140, 18)
            bar:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            bar:SetMinMaxValues(0, 15)
            row.bar = bar
            
            local barBg = bar:CreateTexture(nil, "BACKGROUND")
            barBg:SetAllPoints()
            barBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
            
            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameText:SetPoint("LEFT", row, "LEFT", 0, 0)
            nameText:SetWidth(130)
            row.nameText = nameText
            
            prescienceWindow[rowName] = row
        end
        
        row:Show()
        row.nameText:SetText(data.name)
        row.bar:SetValue(data.remaining)
        
        local theme = THEMES[AugSonarDB.theme] or THEMES.default
        row.bar:SetStatusBarColor(unpack(theme.prescColor))
        row.bg:SetColorTexture(unpack(theme.bgColor))
        
        yOffset = yOffset - 22
    end
    
    -- Hide unused rows
    for i = #groupPrescienceData + 1, prescienceWindow.maxRows do
        local row = prescienceWindow["row" .. i]
        if row then row:Hide() end
    end
    
    local windowHeight = math.max(100, 40 + (#groupPrescienceData * 22))
    prescienceWindow:SetHeight(windowHeight)
end

-- ==========================================
-- [5] Buff Tracking with Combat Fallback
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
-- [6] Update Logic
-- ==========================================
local isTesting = false

local function UpdateBuffBars()
    if isTesting then return end
    
    local inInstance = IsInInstance()
    if not inInstance then
        emBar:Hide()
        prescBar:Hide()
        prescienceWindow:Hide()
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
            PlaySonarSound()
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
                PlaySonarSound()
                lastPrescAlert = GetTime()
            end
        else
            prescBar:Hide()
        end
    else
        prescBar:Hide()
    end
    
    -- Update group Prescience window
    UpdateGroupPrescienceWindow()
end

-- ==========================================
-- [7] Settings UI
-- ==========================================
local settingsFrame = CreateFrame("Frame", "AugSonarSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
settingsFrame:SetSize(380, 520)
settingsFrame:SetPoint("CENTER")
settingsFrame:SetMovable(true)
settingsFrame:EnableMouse(true)
settingsFrame:RegisterForDrag("LeftButton")
settingsFrame:SetScript("OnDragStart", settingsFrame.StartMoving)
settingsFrame:SetScript("OnDragStop", settingsFrame.StopMovingOrSizing)
settingsFrame:Hide()

-- Settings frame background - use BORDER layer so it shows above template background
local settingsFrameBg = settingsFrame:CreateTexture(nil, "BORDER")
settingsFrameBg:SetAllPoints()
settingsFrame.bg = settingsFrameBg

settingsFrame.title = settingsFrame:CreateFontString(nil, "OVERLAY")
settingsFrame.title:SetFontObject("GameFontHighlight")
settingsFrame.title:SetPoint("CENTER", settingsFrame.TitleBg, "CENTER", 0, 0)
settingsFrame.title:SetText("AugSonar Settings")

-- Version Display (at bottom to avoid X overlap)
local versionText = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
versionText:SetPoint("BOTTOMRIGHT", settingsFrame, "BOTTOMRIGHT", -10, 8)
versionText:SetTextColor(1, 0.84, 0)
versionText:SetText("v" .. VERSION)

-- Apply theme to settings window
local function ApplySettingsWindowTheme()
    local theme = THEMES[AugSonarDB.theme] or THEMES.default
    if settingsFrame.TitleBg then
        settingsFrame.TitleBg:SetColorTexture(unpack(theme.bgColor))
    end
    if settingsFrame.bg then
        settingsFrame.bg:SetColorTexture(unpack(theme.windowBgColor))
    end
    -- Apply border colors to all inset borders
    if settingsFrame.InsetBorderTop then
        settingsFrame.InsetBorderTop:SetColorTexture(unpack(theme.borderColor))
    end
    if settingsFrame.InsetBorderBottom then
        settingsFrame.InsetBorderBottom:SetColorTexture(unpack(theme.borderColor))
    end
    if settingsFrame.InsetBorderLeft then
        settingsFrame.InsetBorderLeft:SetColorTexture(unpack(theme.borderColor))
    end
    if settingsFrame.InsetBorderRight then
        settingsFrame.InsetBorderRight:SetColorTexture(unpack(theme.borderColor))
    end
end

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
UIDropDownMenu_SetWidth(themeDropdown, 150)

local function InitializeThemeDropdown(self, level)
    for themeKey, themeData in pairs(THEMES) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = themeData.name
        info.arg1 = themeKey
        info.checked = (AugSonarDB.theme == themeKey)
        info.func = function(self, arg1)
            AugSonarDB.theme = arg1
            DebugPrint("Theme changed to " .. themeData.name)
            ApplyTheme(true)
            ApplySettingsWindowTheme()
            -- Force dropdown to update display
            UIDropDownMenu_SetSelectedValue(themeDropdown, arg1)
            UIDropDownMenu_SetText(themeDropdown, themeData.name)
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

UIDropDownMenu_Initialize(themeDropdown, InitializeThemeDropdown)
UIDropDownMenu_SetSelectedValue(themeDropdown, AugSonarDB.theme or "default")
-- Set the initial display text to the current theme name
local currentTheme = THEMES[AugSonarDB.theme] or THEMES.default
UIDropDownMenu_SetText(themeDropdown, currentTheme.name)

yOffset = yOffset - 35

-- Prescience Toggle
local prescCheckbox = CreateFrame("CheckButton", nil, settingsFrame, "UICheckButtonTemplate")
prescCheckbox:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, yOffset)
prescCheckbox:SetChecked(AugSonarDB.showPrescience)
prescCheckbox.text = prescCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
prescCheckbox.text:SetPoint("LEFT", prescCheckbox, "RIGHT", 5, 0)
prescCheckbox.text:SetText("Track Your Prescience")
prescCheckbox:SetScript("OnClick", function(self)
    AugSonarDB.showPrescience = self:GetChecked()
    if not AugSonarDB.showPrescience then prescBar:Hide() end
end)

yOffset = yOffset - 30

-- Group Prescience Toggle
local groupPrescCheckbox = CreateFrame("CheckButton", nil, settingsFrame, "UICheckButtonTemplate")
groupPrescCheckbox:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, yOffset)
groupPrescCheckbox:SetChecked(AugSonarDB.showGroupPrescience)
groupPrescCheckbox.text = groupPrescCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
groupPrescCheckbox.text:SetPoint("LEFT", groupPrescCheckbox, "RIGHT", 5, 0)
groupPrescCheckbox.text:SetText("Show Group Prescience Window")
groupPrescCheckbox:SetScript("OnClick", function(self)
    AugSonarDB.showGroupPrescience = self:GetChecked()
    if not AugSonarDB.showGroupPrescience then prescienceWindow:Hide() end
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

yOffset = yOffset - 30

-- Debug Mode Toggle
local debugCheckbox = CreateFrame("CheckButton", nil, settingsFrame, "UICheckButtonTemplate")
debugCheckbox:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, yOffset)
debugCheckbox:SetChecked(AugSonarDB.debugMode)
debugCheckbox.text = debugCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
debugCheckbox.text:SetPoint("LEFT", debugCheckbox, "RIGHT", 5, 0)
debugCheckbox.text:SetText("Debug Mode (Chat Output)")
debugCheckbox:SetScript("OnClick", function(self)
    AugSonarDB.debugMode = self:GetChecked()
    if AugSonarDB.debugMode then
        print("|cFF33FF99AugSonar:|r Debug mode enabled")
    end
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
        
        PlaySonarSound()
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
-- [8] Minimap Button
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
        ApplySettingsWindowTheme()
        settingsFrame:Show()
    end
end)

minimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("AugSonar 2.0")
    GameTooltip:AddLine("Click for settings")
    GameTooltip:Show()
end)

minimapBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- ==========================================
-- [9] Event Handling
-- ==========================================
local ticker

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        threshSlider:SetValue(AugSonarDB.alertThreshold)
        threshText:SetText(string.format("%.1f", AugSonarDB.alertThreshold))
        UpdateMinimapPos()
        ApplyTheme(true)
        ApplySettingsWindowTheme()
        print("|cFF33FF99AugSonar " .. VERSION .. ":|r Loaded. Click minimap icon for settings.")
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not ticker then
            ticker = C_Timer.NewTicker(0.1, UpdateBuffBars)
        end
        emBar:Hide()
        prescBar:Hide()
        prescienceWindow:Hide()
        
    elseif event == "PLAYER_REGEN_DISABLED" then
        InCombat = true
        
    elseif event == "PLAYER_REGEN_ENABLED" then
        InCombat = false
        
    elseif event == "UNIT_AURA" or event == "GROUP_ROSTER_UPDATE" then
        UpdateGroupPrescienceWindow()
    end
end)
