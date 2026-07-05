---@diagnostic disable: undefined-global

local ADDON_NAME = "AutoExpansionFilter"
local FRAME_WIDTH = 300
local FRAME_HEIGHT = 120
local COLOR_PREFIX = "|cFF00FF00AutoExpansionFilter:|r "

local AEF = {}
local configCreated = false

-- Retry across a spread of delays in case the filter button isn't fully
-- initialized yet right as the search bar shows.
local RETRY_DELAYS = { 0, 0.2, 0.5, 1.0 }

-- Both the Auction House's FilterButton and the Crafting Orders "Browse
-- Orders" page's FilterDropdown share the same Enum.AuctionHouseFilter.
-- CurrentExpansionOnly key, but they're wired differently under the hood:
--   - AH's FilterButton exposes GetFilters/ToggleFilter; the visible
--     checkbox is driven by that selection state, not a raw table.
--   - Crafting Orders' FilterDropdown has no such methods -- Blizzard's own
--     checkbox handler there just flips filterDropdown.filters[key]
--     directly (confirmed against Blizzard_ProfessionsCustomerOrdersBrowse-
--     Orders.lua), and the menu re-reads that table fresh each time it's
--     opened. Its .filters table also doesn't exist until that page's own
--     Init() has run, so this may need to wait for a retry to catch it.
local function ToggleCurrentExpansionFilter(filterDropdown)
    if not filterDropdown then return end

    local filterKey = Enum.AuctionHouseFilter.CurrentExpansionOnly

    if filterDropdown.GetFilters and filterDropdown.ToggleFilter then
        local current = filterDropdown:GetFilters()
        local isCurrentlyOn = current and current[filterKey] == true
        if isCurrentlyOn ~= AEF.db.enabled then
            filterDropdown:ToggleFilter(filterKey)
        end
    elseif type(filterDropdown.filters) == "table" then
        filterDropdown.filters[filterKey] = AEF.db.enabled
        if filterDropdown.ValidateResetState then
            filterDropdown:ValidateResetState()
        end
    end
end

local function ApplyFilterToUI()
    local sb = AuctionHouseFrame and AuctionHouseFrame.SearchBar
    local fb = sb and sb.FilterButton
    if not fb then return end

    ToggleCurrentExpansionFilter(fb)

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

    ToggleCurrentExpansionFilter(fb)

    if sb.UpdateClearFiltersButton then
        sb:UpdateClearFiltersButton()
    end
    if fb.UpdateVisualState then
        fb:UpdateVisualState()
    end
end

---@param enabled boolean
---@param showMessage boolean
local function SetFilterEnabled(enabled, showMessage)
    AEF.db.enabled = enabled

    if AutoExpansionFilterFrame and AutoExpansionFilterFrame.EnableCheckbox then
        AutoExpansionFilterFrame.EnableCheckbox:SetChecked(enabled)
    end

    for _, delay in ipairs(RETRY_DELAYS) do
        C_Timer.After(delay, function()
            local success, err = pcall(ApplyFilterToUI)
            if not success and err then
                print(COLOR_PREFIX .. "Error applying AH filter: " .. tostring(err))
            end

            local ordersSuccess, ordersErr = pcall(ApplyOrdersFilterToUI)
            if not ordersSuccess and ordersErr then
                print(COLOR_PREFIX .. "Error applying Crafting Orders filter: " .. tostring(ordersErr))
            end
        end)
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

local function DumpDropdownDebug(label, dropdown)
    if not dropdown then
        print(COLOR_PREFIX .. label .. ": nil")
        return
    end
    print(COLOR_PREFIX .. label .. ": " .. tostring(dropdown))
    print("  GetFilters=" .. tostring(dropdown.GetFilters) .. "  ToggleFilter=" .. tostring(dropdown.ToggleFilter))

    local methods = {}
    for k, v in pairs(dropdown) do
        if type(v) == "function" then
            table.insert(methods, k)
        end
    end
    table.sort(methods)
    print("  methods: " .. table.concat(methods, ", "))

    print("  raw fields:")
    for k, v in pairs(dropdown) do
        if type(v) ~= "function" then
            print(string.format("    %s (%s) = %s", tostring(k), type(v), tostring(v)))
        end
    end

    if type(dropdown.filters) == "table" then
        print("  .filters contents:")
        for k, v in pairs(dropdown.filters) do
            print(string.format("    [%s] = %s", tostring(k), tostring(v)))
        end
    end
end

local function RunOrdersDebug()
    print(COLOR_PREFIX .. "Crafting Orders debug:")

    local f = ProfessionsCustomerOrdersFrame
    print("  ProfessionsCustomerOrdersFrame: " .. tostring(f))
    if not f then return end

    local p = f.BrowseOrders
    print("  .BrowseOrders: " .. tostring(p))
    if not p then return end

    local sb = p.SearchBar
    print("  .SearchBar: " .. tostring(sb) .. "  hooked=" .. tostring(sb and sb._aefHooked))
    if not sb then return end

    DumpDropdownDebug("  .FilterDropdown", sb.FilterDropdown)
end

local function RunAHDebug()
    print(COLOR_PREFIX .. "Auction House debug:")

    local ah = AuctionHouseFrame
    print("  AuctionHouseFrame: " .. tostring(ah))
    if not ah then return end

    local sb = ah.SearchBar
    print("  .SearchBar: " .. tostring(sb) .. "  hooked=" .. tostring(sb and sb._aefHooked))
    if not sb then return end

    DumpDropdownDebug("  .FilterButton", sb.FilterButton)
end

local function HookOrders()
    local ordersFrame = ProfessionsCustomerOrdersFrame
    if not ordersFrame then return end

    local browsePage = ordersFrame.BrowseOrders
    local searchBar = browsePage and browsePage.SearchBar
    if not searchBar or searchBar._aefHooked then return end

    searchBar._aefHooked = true

    searchBar:HookScript("OnShow", function()
        SetFilterEnabled(AEF.db.enabled, false)
    end)

    if browsePage:IsShown() then
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

    elseif event == "ADDON_LOADED" and addonName == "Blizzard_ProfessionsCustomerOrders" then
        HookOrders()

    elseif event == "PLAYER_LOGIN" then
        CreateConfig()
        HookAH()
        HookOrders()
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
    elseif msg == "debug" or msg == "debugorders" then
        RunOrdersDebug()
    elseif msg == "debugah" then
        RunAHDebug()
    elseif msg == "help" then
        print(COLOR_PREFIX .. "Commands:")
        print("  /aef - Open config")
        print("  /aef on/enable - Enable filter")
        print("  /aef off/disable - Disable filter")
        print("  /aef debug - Dump Crafting Orders filter dropdown state")
        print("  /aef debugah - Dump Auction House filter dropdown state")
    else
        print(COLOR_PREFIX .. "Unknown command. Type /aef help for commands")
    end
end

