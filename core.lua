-- AugSonar Core - Augmentation Evoker Buff Tracker with Combat Support
local VERSION = "0.15"
local EM_SPELL_ID = 395296
local PRESC_SPELL_ID = 409311

local ADDON_NAME = ...
local InCombat = false

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

local PALETTES = {
    default = { name = "Default (Gold)", emColor = { 0.8, 0.6, 0 }, prescColor = { 0.4, 0.8, 0.9 }, bg = { 0.05, 0.05, 0.05, 0.85 }, panel = { 0.08, 0.08, 0.08, 0.9 }, border = { 1, 0.82, 0, 1 }, accent = { 1, 0.82, 0, 1 }, text = { 1, 1, 1, 1 } },
    dark = { name = "Dark", emColor = { 1, 0.7, 0.1 }, prescColor = { 0.2, 0.8, 1 }, bg = { 0.02, 0.02, 0.02, 0.94 }, panel = { 0.05, 0.05, 0.05, 0.94 }, border = { 0.45, 0.45, 0.45, 1 }, accent = { 0.5, 0.5, 0.5, 1 }, text = { 1, 1, 1, 1 } },
    light = { name = "Light", emColor = { 1, 0.8, 0.2 }, prescColor = { 0.2, 0.7, 1 }, bg = { 0.88, 0.88, 0.88, 0.82 }, panel = { 0.94, 0.94, 0.94, 0.88 }, border = { 0.2, 0.2, 0.2, 1 }, accent = { 1, 0.82, 0, 1 }, text = { 0.1, 0.1, 0.1, 1 } },
    purple = { name = "Purple Mage", emColor = { 0.9, 0.4, 1 }, prescColor = { 0.6, 0.2, 0.9 }, bg = { 0.08, 0.03, 0.12, 0.9 }, panel = { 0.1, 0.04, 0.15, 0.95 }, border = { 0.8, 0.4, 1, 1 }, accent = { 1, 0.6, 1, 1 }, text = { 1, 1, 1, 1 } },
    elvui = { name = "ElvUI (Crimson)", emColor = { 0.9, 0.1, 0.1 }, prescColor = { 0.3, 0.7, 0.9 }, bg = { 0.025, 0.025, 0.025, 0.98 }, panel = { 0.045, 0.045, 0.045, 0.98 }, border = { 0.42, 0.42, 0.42, 1 }, accent = { 0.25, 0.75, 0.70, 1 }, text = { 0.9, 0.9, 0.9, 1 } },
    ellsemereui = { name = "EllesemereUI (Teal)", emColor = { 0.2, 0.8, 0.8 }, prescColor = { 0.3, 0.9, 0.7 }, bg = { 0.02, 0.025, 0.035, 0.98 }, panel = { 0.035, 0.045, 0.06, 0.98 }, border = { 0.12, 0.2, 0.25, 1 }, accent = { 0.32, 0.82, 0.72, 1 }, text = { 0.9, 0.94, 0.96, 1 } },
    gw2ui = { name = "GW2 UI (Gold/Brown)", emColor = { 1, 0.82, 0.2 }, prescColor = { 0.5, 0.8, 0.3 }, bg = { 0.07, 0.05, 0.03, 0.98 }, panel = { 0.11, 0.08, 0.05, 0.98 }, border = { 0.45, 0.35, 0.22, 1 }, accent = { 1, 0.93, 0.73, 1 }, text = { 0.95, 0.92, 0.85, 1 } },
    realui = { name = "RealUI (Blue/Cyan)", emColor = { 0.3, 0.8, 1 }, prescColor = { 0.2, 0.9, 0.8 }, bg = { 0.04, 0.04, 0.05, 0.98 }, panel = { 0.07, 0.07, 0.08, 0.98 }, border = { 0.40, 0.40, 0.42, 1 }, accent = { 0.24, 0.57, 1, 1 }, text = { 0.9, 0.9, 0.92, 1 } },
}

local frame = CreateFrame("Frame", "AugSonarMainFrame", UIParent)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")

local function DebugPrint(message)
    if AugSonarDB.debugMode then
        print("|cFF33FF99AugSonar [DEBUG]:|r " .. message)
    end
end

local function SetFrameBackdrop(frame)
    if not frame then return end
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        return
    end
    if not frame.bg then
        frame.bg = frame:CreateTexture(nil, "BACKGROUND")
        frame.bg:SetAllPoints()
    end
    if not frame.border then
        frame.border = frame:CreateTexture(nil, "BORDER")
        frame.border:SetAllPoints()
        frame.border:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
end

local function ApplyBorder(frame, color)
    if not frame then return end
    if frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(unpack(color))
    elseif frame.border then
        frame.border:SetColorTexture(unpack(color))
    end
end

local function SetBackdropColors(frame, bgColor, borderColor)
    if not frame then return end
    if frame.SetBackdropColor then
        frame:SetBackdropColor(unpack(bgColor))
        ApplyBorder(frame, borderColor)
    else
        if frame.bg then frame.bg:SetColorTexture(unpack(bgColor)) end
        ApplyBorder(frame, borderColor)
    end
end

local function SkinButton(button, palette)
    if not button then return end
    if not button._bg then
        button._bg = button:CreateTexture(nil, "BACKGROUND")
        button._bg:SetAllPoints()
    end
    if not button._border then
        button._border = button:CreateTexture(nil, "BORDER")
        button._border:SetAllPoints()
        button._border:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    button._bg:SetColorTexture(unpack(palette.panel))
    button._border:SetColorTexture(unpack(palette.border))
end

local function ToggleDebugAddonMode()
    AugSonarDB.debugMode = not AugSonarDB.debugMode
    if AugSonarDB.debugMode then
        AugSonarDB.disabledAddons = {}
        local numAddOns = (C_AddOns and C_AddOns.GetNumAddOns) and C_AddOns.GetNumAddOns() or 0
        for i = 1, numAddOns do
            local name = C_AddOns.GetAddOnInfo(i)
            if name and name ~= ADDON_NAME and C_AddOns.IsAddOnLoaded(name) then
                table.insert(AugSonarDB.disabledAddons, name)
                C_AddOns.DisableAddOn(name)
            end
        end
        print("|cFF33FF99AugSonar|r Debug mode ON - disabled " .. #AugSonarDB.disabledAddons .. " other addon(s).")
    else
        if type(AugSonarDB.disabledAddons) == "table" and C_AddOns and C_AddOns.EnableAddOn then
            for _, name in ipairs(AugSonarDB.disabledAddons) do
                C_AddOns.EnableAddOn(name)
            end
        end
        print("|cFF33FF99AugSonar|r Debug mode OFF - restored disabled addon(s).")
        AugSonarDB.disabledAddons = nil
    end
end

local function PlaySonarSound()
    if not AugSonarDB.soundEnabled then
        return
    end
    local soundPath1 = "Interface/AddOns/AugSonar/sonar.ogg"
    local soundPath2 = "Interface\\AddOns\\AugSonar\\sonar.ogg"
    if PlaySoundFile then
        if not PlaySoundFile(soundPath1, "Master") then
            PlaySoundFile(soundPath2, "Master")
        end
    else
        PlaySound(8596)
    end
end

local testPreviewActive = false

local uiContainer = CreateFrame("Frame", "AugSonarUIContainer", UIParent)
uiContainer:SetSize(250, 100)
uiContainer:SetPoint("CENTER", 0, -150)
uiContainer:SetMovable(true)
uiContainer:EnableMouse(true)
uiContainer:RegisterForDrag("LeftButton")
uiContainer:SetScript("OnDragStart", function(self) if not AugSonarDB.locked then self:StartMoving() end end)
uiContainer:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

local emBar = CreateFrame("StatusBar", nil, uiContainer)
emBar:SetSize(240, 22)
emBar:SetPoint("TOP", uiContainer, "TOP", 0, 0)
emBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
emBar:Hide()
local emBg = emBar:CreateTexture(nil, "BACKGROUND"); emBg:SetAllPoints()
local emBorder = emBar:CreateTexture(nil, "BORDER"); emBorder:SetAllPoints(); emBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
local emText = emBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); emText:SetPoint("CENTER"); emText:SetText("Ebon Might")
uiContainer.emBar, uiContainer.emBg, uiContainer.emBorder, uiContainer.emText = emBar, emBg, emBorder, emText

local prescBar = CreateFrame("StatusBar", nil, uiContainer)
prescBar:SetSize(240, 22)
prescBar:SetPoint("TOP", uiContainer, "TOP", 0, -28)
prescBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
prescBar:Hide()
local prescBg = prescBar:CreateTexture(nil, "BACKGROUND"); prescBg:SetAllPoints()
local prescBorder = prescBar:CreateTexture(nil, "BORDER"); prescBorder:SetAllPoints(); prescBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
local prescText = prescBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); prescText:SetPoint("CENTER"); prescText:SetText("Prescience")
uiContainer.prescBar, uiContainer.prescBg, uiContainer.prescBorder, uiContainer.prescText = prescBar, prescBg, prescBorder, prescText

local prescienceWindow = CreateFrame("Frame", "AugSonarPrescienceWindow", UIParent, "BackdropTemplate")
prescienceWindow:SetSize(360, 360)
prescienceWindow:SetPoint("CENTER", 400, 0)
prescienceWindow:SetMovable(true)
prescienceWindow:EnableMouse(true)
prescienceWindow:RegisterForDrag("LeftButton")
prescienceWindow:SetScript("OnDragStart", function(self) if not AugSonarDB.locked then self:StartMoving() end end)
prescienceWindow:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
prescienceWindow:Hide()
SetFrameBackdrop(prescienceWindow)
local pwTitle = prescienceWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
pwTitle:SetPoint("TOPLEFT", prescienceWindow, "TOPLEFT", 8, -8)
pwTitle:SetText("AugSonar Team Tracker")
prescienceWindow.maxRows = 6
prescienceWindow.members = {}

local settingsFrame = CreateFrame("Frame", "AugSonarSettingsFrame", UIParent, "BackdropTemplate")
settingsFrame:SetSize(380, 520)
settingsFrame:SetPoint("CENTER")
settingsFrame:SetMovable(true)
settingsFrame:EnableMouse(true)
settingsFrame:RegisterForDrag("LeftButton")
settingsFrame:SetScript("OnDragStart", settingsFrame.StartMoving)
settingsFrame:SetScript("OnDragStop", settingsFrame.StopMovingOrSizing)
settingsFrame:Hide()
SetFrameBackdrop(settingsFrame)
settingsFrame.title = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
settingsFrame.title:SetPoint("TOP", settingsFrame, "TOP", 0, -12)
settingsFrame.title:SetText("AugSonar Settings")
local versionText = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
versionText:SetPoint("BOTTOMRIGHT", settingsFrame, "BOTTOMRIGHT", -10, 8)
versionText:SetText("v" .. VERSION)
local settingsClose = CreateFrame("Button", nil, settingsFrame, "UIPanelCloseButton")
settingsClose:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", 4, 4)

local function CurrentPalette()
    return PALETTES[AugSonarDB.theme] or PALETTES.default
end

local function ApplyTheme()
    local palette = CurrentPalette()
    if uiContainer.emBar then
        uiContainer.emBar:SetStatusBarColor(unpack(palette.emColor))
        uiContainer.emBg:SetColorTexture(unpack(palette.bg))
        uiContainer.emBorder:SetColorTexture(unpack(palette.border))
    end
    if uiContainer.prescBar then
        uiContainer.prescBar:SetStatusBarColor(unpack(palette.prescColor))
        uiContainer.prescBg:SetColorTexture(unpack(palette.bg))
        uiContainer.prescBorder:SetColorTexture(unpack(palette.border))
    end
    if prescienceWindow then
        SetBackdropColors(prescienceWindow, palette.panel, palette.border)
    end
    if settingsFrame then
        SetBackdropColors(settingsFrame, palette.panel, palette.border)
        if settingsFrame.title then settingsFrame.title:SetTextColor(unpack(palette.accent)) end
        if versionText then versionText:SetTextColor(unpack(palette.accent)) end
        SkinButton(testButton, palette)
        SkinButton(closeButton, palette)
        SkinButton(debugButton, palette)
    end
end

local yOffset = -42
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

local themeLabel = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
themeLabel:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, yOffset)
themeLabel:SetText("Theme:")
yOffset = yOffset - 25
local themeDropdown = CreateFrame("Frame", "AugSonarThemeDropdown", settingsFrame, "UIDropDownMenuTemplate")
themeDropdown:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 10, yOffset)
UIDropDownMenu_SetWidth(themeDropdown, 150)
local function InitializeThemeDropdown(self, level)
    for themeKey, themeData in pairs(PALETTES) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = themeData.name
        info.arg1 = themeKey
        info.checked = (AugSonarDB.theme == themeKey)
        info.func = function(_, arg1)
            AugSonarDB.theme = arg1
            ApplyTheme()
            UIDropDownMenu_SetSelectedValue(themeDropdown, arg1)
            UIDropDownMenu_SetText(themeDropdown, (PALETTES[arg1] or PALETTES.default).name)
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info, level)
    end
end
UIDropDownMenu_Initialize(themeDropdown, InitializeThemeDropdown)
UIDropDownMenu_SetSelectedValue(themeDropdown, AugSonarDB.theme or "default")
UIDropDownMenu_SetText(themeDropdown, (PALETTES[AugSonarDB.theme] or PALETTES.default).name)
yOffset = yOffset - 35

local prescCheckbox = CreateFrame("CheckButton", nil, settingsFrame, "UICheckButtonTemplate")
prescCheckbox:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, yOffset)
prescCheckbox:SetChecked(AugSonarDB.showPrescience)
prescCheckbox.text = prescCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
prescCheckbox.text:SetPoint("LEFT", prescCheckbox, "RIGHT", 5, 0)
prescCheckbox.text:SetText("Track Your Prescience")
prescCheckbox:SetScript("OnClick", function(self) AugSonarDB.showPrescience = self:GetChecked() end)
yOffset = yOffset - 30

local groupPrescCheckbox = CreateFrame("CheckButton", nil, settingsFrame, "UICheckButtonTemplate")
groupPrescCheckbox:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, yOffset)
groupPrescCheckbox:SetChecked(AugSonarDB.showGroupPrescience)
groupPrescCheckbox.text = groupPrescCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
groupPrescCheckbox.text:SetPoint("LEFT", groupPrescCheckbox, "RIGHT", 5, 0)
groupPrescCheckbox.text:SetText("Show Team Tracker Window")
groupPrescCheckbox:SetScript("OnClick", function(self) AugSonarDB.showGroupPrescience = self:GetChecked() end)
yOffset = yOffset - 30

local soundCheckbox = CreateFrame("CheckButton", nil, settingsFrame, "UICheckButtonTemplate")
soundCheckbox:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, yOffset)
soundCheckbox:SetChecked(AugSonarDB.soundEnabled)
soundCheckbox.text = soundCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
soundCheckbox.text:SetPoint("LEFT", soundCheckbox, "RIGHT", 5, 0)
soundCheckbox.text:SetText("Enable Sounds")
soundCheckbox:SetScript("OnClick", function(self) AugSonarDB.soundEnabled = self:GetChecked() end)
yOffset = yOffset - 30

local lockCheckbox = CreateFrame("CheckButton", nil, settingsFrame, "UICheckButtonTemplate")
lockCheckbox:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, yOffset)
lockCheckbox:SetChecked(AugSonarDB.locked)
lockCheckbox.text = lockCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lockCheckbox.text:SetPoint("LEFT", lockCheckbox, "RIGHT", 5, 0)
lockCheckbox.text:SetText("Lock UI Position")
lockCheckbox:SetScript("OnClick", function(self) AugSonarDB.locked = self:GetChecked() end)
yOffset = yOffset - 30

yOffset = yOffset - 5
local debugButton = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
debugButton:SetSize(180, 28)
debugButton:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, yOffset)
debugButton:SetText("Debug Mode: Off")
debugButton:SetScript("OnClick", function(self)
    ToggleDebugAddonMode()
    self:SetText(AugSonarDB.debugMode and "Debug Mode: On" or "Debug Mode: Off")
end)
yOffset = yOffset - 45

local testButton = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
testButton:SetSize(140, 28)
testButton:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 20, yOffset)
testButton:SetText("Test Alert & UI")
testButton:SetScript("OnClick", function()
    local palette = CurrentPalette()
    ApplyTheme()
    testPreviewActive = not testPreviewActive
    if testPreviewActive then
        emBar:Show()
        prescBar:Show()
        emBar:SetMinMaxValues(0, 10)
        emBar:SetValue(3)
        prescBar:SetMinMaxValues(0, 15)
        prescBar:SetValue(4)
        emText:SetText("Ebon Might: 3.0s")
        prescText:SetText("Prescience: 4.0s")
        emBar:SetStatusBarColor(unpack(palette.emColor))
        prescBar:SetStatusBarColor(unpack(palette.prescColor))
        testButton:SetText("Hide Test UI")
        PlaySonarSound()
    else
        emBar:Hide()
        prescBar:Hide()
        testButton:SetText("Test Alert & UI")
    end
end)

local closeButton = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
closeButton:SetSize(140, 28)
closeButton:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 220, yOffset)
closeButton:SetText("Close")
closeButton:SetScript("OnClick", function() settingsFrame:Hide() end)

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
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
end
minimapBtn:SetScript("OnDragStart", function(self) self:LockHighlight(); self:SetScript("OnUpdate", function() local mx, my = Minimap:GetCenter(); local px, py = GetCursorPosition(); local scale = Minimap:GetEffectiveScale(); px, py = px / scale, py / scale; AugSonarDB.minimapAngle = math.deg(math.atan(py - my, px - mx)); UpdateMinimapPos() end) end)
minimapBtn:SetScript("OnDragStop", function(self) self:UnlockHighlight(); self:SetScript("OnUpdate", nil) end)
minimapBtn:SetScript("OnClick", function()
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        ApplyTheme()
        settingsFrame:Show()
    end
end)
minimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("AugSonar " .. VERSION)
    GameTooltip:AddLine("Click for settings")
    GameTooltip:Show()
end)
minimapBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

local lastEMAlert = 0
local lastPrescAlert = 0
local emAlertToken = nil
local prescAlertToken = nil

local function GetBuffFromNameplate(spellID)
    local frames = { WorldFrame:GetChildren() }
    for _, child in ipairs(frames) do
        local name = child.GetName and child:GetName()
        if name and name:find("NamePlate") then
            local unitFrame = child.UnitFrame or child.UnitFrame and child.UnitFrame
            local buffFrame = unitFrame and unitFrame.BuffFrame
            if buffFrame and buffFrame.auraFrames then
                for _, aura in pairs(buffFrame.auraFrames) do
                    local auraInstanceID = aura.auraInstanceID
                    if auraInstanceID and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
                        local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID("player", auraInstanceID)
                        if auraData and auraData.spellId == spellID then
                            return auraData
                        end
                    end
                end
            end
        end
    end
end

local function GetPlayerBuff(spellID)
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        if aura then return aura end
    end
    if AuraUtil and AuraUtil.FindAuraBySpellID then
        local aura = AuraUtil.FindAuraBySpellID(spellID, "player", "HELPFUL")
        if aura then return aura end
    end
    if InCombat then
        return GetBuffFromNameplate(spellID)
    end
end

local function GetUnitAuraBySpellID(unit, spellID)
    if unit == "player" then
        return GetPlayerBuff(spellID)
    end
    if AuraUtil and AuraUtil.FindAuraBySpellID then
        local aura = AuraUtil.FindAuraBySpellID(spellID, unit, "HELPFUL")
        if aura then return aura end
    end
    if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellID then
        local aura = C_UnitAuras.GetAuraDataBySpellID(unit, spellID)
        if aura then return aura end
    end
end

local function GetSpellIconTexture(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        local tex = C_Spell.GetSpellTexture(spellID)
        if tex then return tex end
    end
    if GetSpellTexture then
        local tex = GetSpellTexture(spellID)
        if tex then return tex end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- WoW does not expose exact distance-in-yards for arbitrary group members
-- (that API was removed for anti-cheat reasons). UnitInRange is the
-- combat-safe, Blizzard-sanctioned equivalent real raid frames use, so we
-- surface an in-range/out-of-range indicator instead of a fabricated number.
local function IsUnitInRange(unit)
    if unit == "player" then return true end
    local inRange, checked = UnitInRange(unit)
    if checked then return inRange end
    return true
end

local function GetUnitClassColor(unit)
    local _, class = UnitClass(unit)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end

local function UpdateGroupPrescienceWindow()
    if not AugSonarDB.showGroupPrescience then
        prescienceWindow:Hide()
        return
    end
    local inInstance = IsInGroup() or IsInRaid() or (select(2, IsInInstance()) == true)
    if not inInstance then
        prescienceWindow:Hide()
        return
    end
    local groupData = {}
    local currentTime = GetTime()
    local isRaid = IsInRaid()
    local groupSize = GetNumGroupMembers()
    if groupSize == 0 then groupSize = 1 end
    for i = 1, groupSize do
        local unit = isRaid and ("raid" .. i) or (i == 1 and "player" or ("party" .. (i - 1)))
        if UnitExists(unit) then
            local emAura = GetUnitAuraBySpellID(unit, EM_SPELL_ID)
            local prescAura = AugSonarDB.showPrescience and GetUnitAuraBySpellID(unit, PRESC_SPELL_ID) or nil
            local emRemaining = emAura and emAura.expirationTime and math.max(0, emAura.expirationTime - currentTime) or nil
            local prescRemaining = prescAura and prescAura.expirationTime and math.max(0, prescAura.expirationTime - currentTime) or nil
            local hpMax = UnitHealthMax(unit)
            local hpPct = hpMax and hpMax > 0 and (UnitHealth(unit) / hpMax * 100) or 100
            table.insert(groupData, {
                unit = unit,
                name = UnitName(unit) or unit,
                emRemaining = emRemaining,
                emDuration = emAura and emAura.duration and emAura.duration > 0 and emAura.duration or 10,
                prescRemaining = prescRemaining,
                prescDuration = prescAura and prescAura.duration and prescAura.duration > 0 and prescAura.duration or 15,
                hpPct = hpPct,
                inRange = IsUnitInRange(unit),
                score = math.min(emRemaining or -1, prescRemaining or -1),
            })
        end
    end
    table.sort(groupData, function(a, b) return a.score < b.score end)
    if #groupData == 0 then
        prescienceWindow:Hide()
        return
    end
    prescienceWindow:Show()
    local palette = CurrentPalette()
    for i = 1, math.min(#groupData, prescienceWindow.maxRows) do
        local data = groupData[i]
        local row = prescienceWindow.members[i]
        if not row then
            row = CreateFrame("Frame", nil, prescienceWindow)
            row:SetSize(336, 50)
            row:SetPoint("TOPLEFT", prescienceWindow, "TOPLEFT", 8, -30 - ((i - 1) * 54))
            SetFrameBackdrop(row)
            row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints()
            row.border = row:CreateTexture(nil, "BORDER"); row.border:SetAllPoints(); row.border:SetTexture("Interface\\Buttons\\WHITE8X8")

            row.emIcon = row:CreateTexture(nil, "ARTWORK")
            row.emIcon:SetSize(16, 16)
            row.emIcon:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -4)
            row.emIcon:SetTexture(GetSpellIconTexture(EM_SPELL_ID))

            row.prescIcon = row:CreateTexture(nil, "ARTWORK")
            row.prescIcon:SetSize(16, 16)
            row.prescIcon:SetPoint("LEFT", row.emIcon, "RIGHT", 2, 0)
            row.prescIcon:SetTexture(GetSpellIconTexture(PRESC_SPELL_ID))

            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameText:SetPoint("LEFT", row.prescIcon, "RIGHT", 6, 0)
            row.nameText:SetWidth(140)
            row.nameText:SetJustifyH("LEFT")

            row.hpText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.hpText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -60, -4)
            row.hpText:SetWidth(50)
            row.hpText:SetJustifyH("RIGHT")

            row.rangeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.rangeText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -4)
            row.rangeText:SetWidth(56)
            row.rangeText:SetJustifyH("RIGHT")

            row.emBar = CreateFrame("StatusBar", nil, row)
            row.emBar:SetSize(328, 12)
            row.emBar:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -22)
            row.emBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            row.emBarText = row.emBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.emBarText:SetPoint("CENTER")

            row.prescBar = CreateFrame("StatusBar", nil, row)
            row.prescBar:SetSize(328, 12)
            row.prescBar:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -36)
            row.prescBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            row.prescBarText = row.prescBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.prescBarText:SetPoint("CENTER")

            prescienceWindow.members[i] = row
        end
        row:Show()
        row.nameText:SetText(data.name)
        row.nameText:SetTextColor(GetUnitClassColor(data.unit))
        row.hpText:SetText(string.format("%.0f%%", data.hpPct))
        if data.hpPct <= 35 then
            row.hpText:SetTextColor(1, 0.2, 0.2)
        else
            row.hpText:SetTextColor(1, 1, 1)
        end
        if data.inRange then
            row.rangeText:SetText("In Range")
            row.rangeText:SetTextColor(0.3, 1, 0.3)
        else
            row.rangeText:SetText("Out of Range")
            row.rangeText:SetTextColor(1, 0.3, 0.3)
        end

        row.emBar:SetMinMaxValues(0, data.emDuration)
        if data.emRemaining then
            row.emBar:SetValue(data.emRemaining)
            row.emBar:SetStatusBarColor(unpack(palette.emColor))
            row.emBarText:SetText(string.format("Ebon Might: %.1fs", data.emRemaining))
        else
            row.emBar:SetValue(0)
            row.emBar:SetStatusBarColor(0.6, 0.1, 0.1)
            row.emBarText:SetText("Ebon Might: Missing")
        end

        row.prescBar:SetShown(AugSonarDB.showPrescience)
        if AugSonarDB.showPrescience then
            row.prescBar:SetMinMaxValues(0, data.prescDuration)
            if data.prescRemaining then
                row.prescBar:SetValue(data.prescRemaining)
                row.prescBar:SetStatusBarColor(unpack(palette.prescColor))
                row.prescBarText:SetText(string.format("Prescience: %.1fs", data.prescRemaining))
            else
                row.prescBar:SetValue(0)
                row.prescBar:SetStatusBarColor(0.6, 0.1, 0.1)
                row.prescBarText:SetText("Prescience: Missing")
            end
        end

        row.bg:SetColorTexture(unpack(palette.bg))
        row.border:SetColorTexture(unpack(palette.border))
    end
    for i = #groupData + 1, #prescienceWindow.members do
        if prescienceWindow.members[i] then prescienceWindow.members[i]:Hide() end
    end
end

local function UpdateBuffBars()
    if testPreviewActive then return end
    local currentTime = GetTime()
    local emAura = GetPlayerBuff(EM_SPELL_ID)
    if emAura then
        emBar:Show()
        local remaining = math.max(0, emAura.expirationTime - currentTime)
        local duration = emAura.duration and emAura.duration > 0 and emAura.duration or 10
        local token = tostring(emAura.auraInstanceID or emAura.spellId or EM_SPELL_ID) .. ":" .. math.floor(emAura.expirationTime or 0)
        emBar:SetMinMaxValues(0, duration)
        emBar:SetValue(remaining)
        emText:SetText(string.format("Ebon Might: %.1fs", remaining))
        if token ~= emAlertToken then
            emAlertToken = token
            lastEMAlert = 0
        end
        if remaining > 0 and remaining <= AugSonarDB.alertThreshold and lastEMAlert ~= token then
            PlaySonarSound()
            lastEMAlert = token
        end
    else
        emBar:Hide()
        emAlertToken = nil
        lastEMAlert = 0
    end
    if AugSonarDB.showPrescience then
        local prescAura = GetPlayerBuff(PRESC_SPELL_ID)
        if prescAura then
            prescBar:Show()
            local remaining = math.max(0, prescAura.expirationTime - currentTime)
            local duration = prescAura.duration and prescAura.duration > 0 and prescAura.duration or 15
            local token = tostring(prescAura.auraInstanceID or prescAura.spellId or PRESC_SPELL_ID) .. ":" .. math.floor(prescAura.expirationTime or 0)
            prescBar:SetMinMaxValues(0, duration)
            prescBar:SetValue(remaining)
            prescText:SetText(string.format("Prescience: %.1fs", remaining))
            if token ~= prescAlertToken then
                prescAlertToken = token
                lastPrescAlert = 0
            end
            if remaining > 0 and remaining <= AugSonarDB.alertThreshold and lastPrescAlert ~= token then
                PlaySonarSound()
                lastPrescAlert = token
            end
        else
            prescBar:Hide()
            prescAlertToken = nil
            lastPrescAlert = 0
        end
    else
        prescBar:Hide()
        prescAlertToken = nil
        lastPrescAlert = 0
    end
    UpdateGroupPrescienceWindow()
end

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        threshSlider:SetValue(AugSonarDB.alertThreshold)
        threshText:SetText(string.format("%.1f", AugSonarDB.alertThreshold))
        UpdateMinimapPos()
        ApplyTheme()
        print("|cFF33FF99AugSonar " .. VERSION .. ":|r Loaded. Click minimap icon for settings.")
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not self.ticker then
            self.ticker = C_Timer.NewTicker(0.1, UpdateBuffBars)
        end
        emBar:Hide()
        prescBar:Hide()
        prescienceWindow:Hide()
        UpdateBuffBars()
    elseif event == "PLAYER_REGEN_DISABLED" then
        InCombat = true
        UpdateBuffBars()
    elseif event == "PLAYER_REGEN_ENABLED" then
        InCombat = false
        UpdateBuffBars()
    elseif event == "UNIT_AURA" or event == "GROUP_ROSTER_UPDATE" then
        UpdateBuffBars()
    end
end)
