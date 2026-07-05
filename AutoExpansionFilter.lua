local ADDON_NAME = "AutoExpansionFilter"
local FRAME_WIDTH = 320
local FRAME_HEIGHT = 190
local COLOR_PREFIX = "|cFF00FF00AutoExpansionFilter:|r "
local AEF = {}
local configCreated = false
local function GetAddonVersion()
    local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata
    if type(getMeta) == "function" then
        return getMeta(ADDON_NAME, "Version")
    end
    if type(GetAddOnMetadata) == "function" then
        return GetAddOnMetadata(ADDON_NAME, "Version")
    end
    return nil
end
local RETRY_DELAYS = { 0, 0.2, 0.5, 1.0 }
local function ToggleCurrentExpansionFilter(filterDropdown, desiredEnabled)
    if not filterDropdown then return end
    local filterKey = Enum.AuctionHouseFilter.CurrentExpansionOnly
    if filterDropdown.GetFilters and filterDropdown.ToggleFilter then
        local current = filterDropdown:GetFilters()
        local isCurrentlyOn = current and current[filterKey] == true
        if isCurrentlyOn ~= desiredEnabled then
            filterDropdown:ToggleFilter(filterKey)
        end
    elseif type(filterDropdown.filters) == "table" then
        filterDropdown.filters[filterKey] = desiredEnabled
        if filterDropdown.ValidateResetState then
            filterDropdown:ValidateResetState()
        end
    end
end
local function ApplyFilterToUI()
    local sb = AuctionHouseFrame and AuctionHouseFrame.SearchBar
    local fb = sb and sb.FilterButton
    if not fb then return end
    ToggleCurrentExpansionFilter(fb, AEF.db.ahEnabled)
    if sb.UpdateClearFiltersButton then
        sb:UpdateClearFiltersButton()
    end
    if fb.UpdateVisualState then
        fb:UpdateVisualState()
    end
end
local function ApplyOrdersFilterToUI()
    local page = ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame.BrowseOrders
    local sb = page and page.SearchBar
    local fb = sb and sb.FilterDropdown
    if not fb then return end
    ToggleCurrentExpansionFilter(fb, AEF.db.ordersEnabled)
    if sb.UpdateClearFiltersButton then
        sb:UpdateClearFiltersButton()
    end
    if fb.UpdateVisualState then
        fb:UpdateVisualState()
    end
end
local function SetAHFilterEnabled(enabled, showMessage)
    AEF.db.ahEnabled = enabled
    if AutoExpansionFilterFrame and AutoExpansionFilterFrame.AHCheckbox then
        AutoExpansionFilterFrame.AHCheckbox:SetChecked(enabled)
    end
    for _, delay in ipairs(RETRY_DELAYS) do
        C_Timer.After(delay, function()
            local success, err = pcall(ApplyFilterToUI)
            if not success and err then
                print(COLOR_PREFIX .. "Error applying AH filter: " .. tostring(err))
            end
        end)
    end
    if showMessage then
        print(COLOR_PREFIX .. "Auction House auto-filter " .. (enabled and "enabled" or "disabled"))
    end
end
local function SetOrdersFilterEnabled(enabled, showMessage)
    AEF.db.ordersEnabled = enabled
    if AutoExpansionFilterFrame and AutoExpansionFilterFrame.OrdersCheckbox then
        AutoExpansionFilterFrame.OrdersCheckbox:SetChecked(enabled)
    end
    for _, delay in ipairs(RETRY_DELAYS) do
        C_Timer.After(delay, function()
            local success, err = pcall(ApplyOrdersFilterToUI)
            if not success and err then
                print(COLOR_PREFIX .. "Error applying Crafting Orders filter: " .. tostring(err))
            end
        end)
    end
    if showMessage then
        print(COLOR_PREFIX .. "Crafting Orders auto-filter " .. (enabled and "enabled" or "disabled"))
    end
end
local function HookAH()
    local ahFrame = AuctionHouseFrame
    if not ahFrame then return end
    local searchBar = ahFrame.SearchBar
    if not searchBar or searchBar._aefHooked then return end
    searchBar._aefHooked = true
    searchBar:HookScript("OnShow", function()
        SetAHFilterEnabled(AEF.db.ahEnabled, false)
    end)
    if ahFrame:IsShown() then
        SetAHFilterEnabled(AEF.db.ahEnabled, false)
    end
end
local function HookOrders()
    local ordersFrame = ProfessionsCustomerOrdersFrame
    if not ordersFrame then return end
    local browsePage = ordersFrame.BrowseOrders
    local searchBar = browsePage and browsePage.SearchBar
    if not searchBar or searchBar._aefHooked then return end
    searchBar._aefHooked = true
    searchBar:HookScript("OnShow", function()
        SetOrdersFilterEnabled(AEF.db.ordersEnabled, false)
    end)
    if browsePage:IsShown() then
        SetOrdersFilterEnabled(AEF.db.ordersEnabled, false)
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
    title:SetText("Auto Expansion Filter")
    local version = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    version:SetPoint("TOP", title, "BOTTOM", 0, -4)
    version:SetText("v" .. (GetAddonVersion() or "?"))
    local ahCb = CreateFrame("CheckButton", "AutoExpansionFilterFrameAHCheckbox", f, "UICheckButtonTemplate")
    ahCb:SetPoint("TOPLEFT", 20, -60)
    ahCb:SetSize(26, 26)
    ahCb.Text:SetText("Auto-filter: Auction House")
    ahCb:SetChecked(AEF.db.ahEnabled)
    ahCb:SetScript("OnClick", function(self)
        SetAHFilterEnabled(self:GetChecked(), true)
    end)
    ahCb:SetFrameLevel(f:GetFrameLevel() + 1)
    f.AHCheckbox = ahCb
    local ordersCb = CreateFrame("CheckButton", "AutoExpansionFilterFrameOrdersCheckbox", f, "UICheckButtonTemplate")
    ordersCb:SetPoint("TOPLEFT", 20, -95)
    ordersCb:SetSize(26, 26)
    ordersCb.Text:SetText("Auto-filter: Crafting Orders")
    ordersCb:SetChecked(AEF.db.ordersEnabled)
    ordersCb:SetScript("OnClick", function(self)
        SetOrdersFilterEnabled(self:GetChecked(), true)
    end)
    ordersCb:SetFrameLevel(f:GetFrameLevel() + 1)
    f.OrdersCheckbox = ordersCb
    f:SetScript("OnShow", function()
        f.AHCheckbox:SetChecked(AEF.db.ahEnabled)
        f.OrdersCheckbox:SetChecked(AEF.db.ordersEnabled)
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
        if AEF.db.ahEnabled == nil then
            AEF.db.ahEnabled = (AEF.db.enabled ~= nil) and AEF.db.enabled or true
        end
        if AEF.db.ordersEnabled == nil then
            AEF.db.ordersEnabled = (AEF.db.enabled ~= nil) and AEF.db.enabled or true
        end
        AutoExpansionFilterDB = AEF.db
    elseif event == "ADDON_LOADED" and addonName == "Blizzard_ProfessionsCustomerOrders" then
        HookOrders()
    elseif event == "PLAYER_LOGIN" then
        CreateConfig()
        HookAH()
        HookOrders()
        eventFrame:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "AUCTION_HOUSE_SHOW" then
        HookAH()
        SetAHFilterEnabled(AEF.db.ahEnabled, false)
    end
end)
SLASH_AUTOEXPANSIONFILTER1 = "/aef"
SLASH_AUTOEXPANSIONFILTER2 = "/autofilter"
SLASH_AUTOEXPANSIONFILTER3 = "/expfilter"
SlashCmdList["AUTOEXPANSIONFILTER"] = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "config" or msg == "" then
        if AutoExpansionFilterFrame then
            AutoExpansionFilterFrame:Show()
        else
            print(COLOR_PREFIX .. "Config not loaded yet")
        end
    elseif msg == "on" or msg == "enable" then
        SetAHFilterEnabled(true, false)
        SetOrdersFilterEnabled(true, true)
    elseif msg == "off" or msg == "disable" then
        SetAHFilterEnabled(false, false)
        SetOrdersFilterEnabled(false, true)
    elseif msg == "help" then
        print(COLOR_PREFIX .. "Commands:")
        print("  /aef - Open config")
        print("  /aef on/enable - Enable both filters")
        print("  /aef off/disable - Disable both filters")
    else
        print(COLOR_PREFIX .. "Unknown command. Type /aef help for commands")
    end
end
