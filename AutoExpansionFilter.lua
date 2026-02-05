---@diagnostic disable: undefined-global

local ADDON_NAME = "AutoExpansionFilter"
local FRAME_WIDTH = 300
local FRAME_HEIGHT = 120
local COLOR_PREFIX = "|cFF00FF00AutoExpansionFilter:|r "

local AEF = {}
local configCreated = false

---@param enabled boolean
---@param showMessage boolean
local function SetFilterEnabled(enabled, showMessage)
    AEF.db.enabled = enabled

    if AutoExpansionFilterFrame and AutoExpansionFilterFrame.EnableCheckbox then
        AutoExpansionFilterFrame.EnableCheckbox:SetChecked(enabled)
    end

    local success, err = pcall(function()
        local ahFrame = AuctionHouseFrame
        if not ahFrame or not ahFrame.SearchBar then return end

        local searchBar = ahFrame.SearchBar
        if not searchBar.FilterButton then return end

        C_Timer.After(0, function()
            local sb = AuctionHouseFrame and AuctionHouseFrame.SearchBar
            if not sb or not sb.FilterButton then return end

            sb.FilterButton.filters = sb.FilterButton.filters or {}
            sb.FilterButton.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = AEF.db.enabled

            sb:UpdateClearFiltersButton()
            if sb.FilterButton.UpdateVisualState then
                sb.FilterButton:UpdateVisualState()
            end
        end)
    end)

    if not success and err then
        print(COLOR_PREFIX .. "Error applying filter: " .. tostring(err))
    end


    if showMessage then
        print(COLOR_PREFIX .. (enabled and "Enabled" or "Disabled"))
    end
end

local function HookAH()
    local ahFrame = AuctionHouseFrame
    if not ahFrame then return end

    local searchBar = ahFrame.SearchBar
    if not searchBar or searchBar._aefHooked then return end

    searchBar._aefHooked = true

    searchBar:HookScript("OnShow", function()
        SetFilterEnabled(AEF.db.enabled, false)
    end)

    if ahFrame:IsShown() then
        SetFilterEnabled(AEF.db.enabled, false)
    end
end

local function CreateConfig()
    if configCreated then return end
    configCreated = true

    local f = CreateFrame("Frame", "AutoExpansionFilterFrame", UIParent)
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    tinsert(UISpecialFrames, "AutoExpansionFilterFrame")

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.8)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("Auction House Filter")

    local cb = CreateFrame("CheckButton", "AutoExpansionFilterFrameEnableCheckbox", f, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 20, -50)
    cb:SetSize(26, 26)
    cb.Text:SetText("Auto-set 'Current Expansion Only' filter")
    cb:SetChecked(AEF.db.enabled)
    cb:SetScript("OnClick", function(self)
        SetFilterEnabled(self:GetChecked(), true)
    end)
    cb:SetFrameLevel(f:GetFrameLevel() + 1)
    f.EnableCheckbox = cb

    f:SetScript("OnShow", function()
        f.EnableCheckbox:SetChecked(AEF.db.enabled)
    end)

    local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btn:SetSize(100, 32)
    btn:SetPoint("BOTTOM", 0, 15)
    btn:SetText("Close")
    btn:SetScript("OnClick", function() f:Hide() end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")

eventFrame:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName == ADDON_NAME then
        AEF.db = AutoExpansionFilterDB or {}

        if AEF.db.enabled == nil then
            AEF.db.enabled = true
        end

        AutoExpansionFilterDB = AEF.db

        eventFrame:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        CreateConfig()
        HookAH()
        eventFrame:UnregisterEvent("PLAYER_LOGIN")

    elseif event == "AUCTION_HOUSE_SHOW" then
        HookAH()
        SetFilterEnabled(AEF.db.enabled, false)
    end
end)

SLASH_AUTOEXPANSIONFILTER1 = "/aef"
SLASH_AUTOEXPANSIONFILTER2 = "/autofilter"
SLASH_AUTOEXPANSIONFILTER3 = "/expfilter"

---@param msg string
SlashCmdList["AUTOEXPANSIONFILTER"] = function(msg)
    msg = strtrim(msg or ""):lower()

    if msg == "config" or msg == "" then
        if AutoExpansionFilterFrame then
            AutoExpansionFilterFrame:Show()
        else
            print(COLOR_PREFIX .. "Config not loaded yet")
        end
    elseif msg == "on" or msg == "enable" then
        SetFilterEnabled(true, true)
    elseif msg == "off" or msg == "disable" then
        SetFilterEnabled(false, true)
    elseif msg == "help" then
        print(COLOR_PREFIX .. "Commands:")
        print("  /aef - Open config")
        print("  /aef on/enable - Enable filter")
        print("  /aef off/disable - Disable filter")
    else
        print(COLOR_PREFIX .. "Unknown command. Type /aef help for commands")
    end
end

