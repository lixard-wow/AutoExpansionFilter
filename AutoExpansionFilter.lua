AutoExpansionFilterDB = AutoExpansionFilterDB

local ADDON_NAME = "AutoExpansionFilter"
local COLOR_PREFIX = "|cFF00FF00AutoExpansionFilter:|r "

local AEF = {}

local function SetFilterEnabled(enabled, showMessage)
    AEF.db.enabled = enabled

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

local function CreateSettings()
    local category = Settings.RegisterVerticalLayoutCategory("Auto Expansion Filter")

    local function GetValue()
        return AEF.db.enabled
    end

    local function SetValue(value)
        SetFilterEnabled(value, true)
    end

    local setting = Settings.RegisterAddOnSetting(category, "AutoExpansionFilterEnabled", "enabled", AutoExpansionFilterDB, Settings.VarType.Boolean, "Auto-set 'Current Expansion Only' filter", true)
    setting:SetValueChangedCallback(SetValue)

    Settings.CreateCheckbox(category, setting, "Automatically set 'Current Expansion Only' filter when opening the Auction House")

    Settings.RegisterAddOnCategory(category)
    AEF.settingsCategory = category
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
        CreateSettings()
        HookAH()
        eventFrame:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "AUCTION_HOUSE_SHOW" then
        HookAH()
        SetFilterEnabled(AEF.db.enabled, false)
    end
end)

SLASH_AUTOEXPANSIONFILTER1 = "/aef"

SlashCmdList["AUTOEXPANSIONFILTER"] = function(msg)
    msg = (msg or ""):lower():trim()

    if msg == "config" or msg == "" then
        Settings.OpenToCategory(AEF.settingsCategory:GetID())
    elseif msg == "on" or msg == "enable" then
        SetFilterEnabled(true, true)
    elseif msg == "off" or msg == "disable" then
        SetFilterEnabled(false, true)
    elseif msg == "help" then
        print(COLOR_PREFIX .. "Commands:")
        print("  /aef - Open settings")
        print("  /aef on - Enable filter")
        print("  /aef off - Disable filter")
    else
        print(COLOR_PREFIX .. "Unknown command. Type /aef help for commands")
    end
end