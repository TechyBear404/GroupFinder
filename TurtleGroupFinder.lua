-- GroupFinder Addon for WoW 1.12 (Vanilla)
-- Enhanced version with dynamic panel UI system, instance selection, filtering, and improved compatibility

-- Local variables
local groupButtons = {}
local updateTimer = 0
local CLEANUP_INTERVAL = 300 -- 5 minutes
local isInitialized = false
local selectedInstance = "The Deadmines"
local groupEditIndex = nil

-- Channel-based communication system variables
local GROUPFINDER_CHANNEL = 'TurtleGroupFinder'
local channelIndex = 0
local channelJoinAttempts = 0
local MAX_CHANNEL_JOIN_ATTEMPTS = 5

-- Auto-broadcasting system variables
local AUTO_BROADCAST_INTERVAL = 60 -- 60 seconds
local STALE_GROUP_TIMEOUT = 300    -- Groups not broadcast in 60 seconds are considered stale
local autoBroadcastTimer = 0

-- Dynamic Panel System Variables
local currentView = "list"        -- "list" or "create"
local currentInstanceType = "All" -- Current selected instance type filter (unified with legacy currentFilter)
local selectedTypeButtons = {}    -- Track which type button is selected
local panelFrames = {}            -- Cache for panel frames

-- Filtering variables
local searchText = "" -- Current search filter text
local roleFilters = { -- Current role filter states
    tank = false,
    healer = false,
    dps = false
}

-- Frame Pooling for Memory Optimization
local framePool = {
    groupButtons = {}, -- Pool of reusable group buttons
    maxPoolSize = 20,  -- Maximum number of buttons to keep in pool
    activeButtons = {} -- Currently active buttons
}

-- Instance data for WoW Vanilla
local INSTANCES = {
    -- Dungeons by level
    ["Ragefire Chasm"] = { level = "13-18", type = "Dungeon", zone = "Orgrimmar" },
    ["The Deadmines"] = { level = "17-26", type = "Dungeon", zone = "Westfall" },
    ["Wailing Caverns"] = { level = "17-24", type = "Dungeon", zone = "The Barrens" },
    ["Shadowfang Keep"] = { level = "22-30", type = "Dungeon", zone = "Silverpine Forest" },
    ["The Stockade"] = { level = "22-30", type = "Dungeon", zone = "Stormwind City" },
    ["Gnomeregan"] = { level = "29-38", type = "Dungeon", zone = "Dun Morogh" },
    ["Razorfen Kraul"] = { level = "29-38", type = "Dungeon", zone = "The Barrens" },
    ["Scarlet Monastery"] = { level = "34-45", type = "Dungeon", zone = "Tirisfal Glades" },
    ["Razorfen Downs"] = { level = "37-46", type = "Dungeon", zone = "The Barrens" },
    ["Uldaman"] = { level = "42-52", type = "Dungeon", zone = "Badlands" },
    ["Zul'Farrak"] = { level = "44-54", type = "Dungeon", zone = "Tanaris" },
    ["Maraudon"] = { level = "46-55", type = "Dungeon", zone = "Desolace" },
    ["Temple of Atal'Hakkar"] = { level = "50-60", type = "Dungeon", zone = "Swamp of Sorrows" },
    ["Blackrock Depths"] = { level = "52-60", type = "Dungeon", zone = "Blackrock Mountain" },
    ["Lower Blackrock Spire"] = { level = "55-60", type = "Dungeon", zone = "Blackrock Mountain" },
    ["Upper Blackrock Spire"] = { level = "58-60", type = "Dungeon", zone = "Blackrock Mountain" },
    ["Dire Maul"] = { level = "55-60", type = "Dungeon", zone = "Feralas" },
    ["Stratholme"] = { level = "58-60", type = "Dungeon", zone = "Eastern Plaguelands" },
    ["Scholomance"] = { level = "58-60", type = "Dungeon", zone = "Western Plaguelands" },

    -- Raids
    ["Molten Core"] = { level = "60", type = "Raid", zone = "Blackrock Mountain" },
    ["Blackwing Lair"] = { level = "60", type = "Raid", zone = "Blackrock Mountain" },
    ["Zul'Gurub"] = { level = "60", type = "Raid", zone = "Stranglethorn Vale" },
    ["Ahn'Qiraj Temple"] = { level = "60", type = "Raid", zone = "Silithus" },
    ["Ruins of Ahn'Qiraj"] = { level = "60", type = "Raid", zone = "Silithus" },
    ["Naxxramas"] = { level = "60", type = "Raid", zone = "Eastern Plaguelands" },

    -- PvP Battlegrounds
    ["Warsong Gulch"] = { level = "10-19", type = "PvP", zone = "Ashenvale" },
    ["Warsong Gulch"] = { level = "20-29", type = "PvP", zone = "Ashenvale" },
    ["Warsong Gulch"] = { level = "30-39", type = "PvP", zone = "Ashenvale" },
    ["Warsong Gulch"] = { level = "40-49", type = "PvP", zone = "Ashenvale" },
    ["Warsong Gulch"] = { level = "50-59", type = "PvP", zone = "Ashenvale" },
    ["Warsong Gulch"] = { level = "60", type = "PvP", zone = "Ashenvale" },
    ["Arathi Basin"] = { level = "20-29", type = "PvP", zone = "Arathi Highlands" },
    ["Arathi Basin"] = { level = "30-39", type = "PvP", zone = "Arathi Highlands" },
    ["Arathi Basin"] = { level = "40-49", type = "PvP", zone = "Arathi Highlands" },
    ["Arathi Basin"] = { level = "50-59", type = "PvP", zone = "Arathi Highlands" },
    ["Arathi Basin"] = { level = "60", type = "PvP", zone = "Arathi Highlands" },
    ["Alterac Valley"] = { level = "51-60", type = "PvP", zone = "Alterac Mountains" },

    -- Other activities
    ["PvP"] = { level = "Any", type = "PvP", zone = "Various" },
    ["Other"] = { level = "Any", type = "Other", zone = "Various" }
}

-- Utility functions
local function GetTimeStamp()
    return time()
end

-- Event-based channel connection system will be registered in GroupFinder_OnLoad()
local function HandlePlayerEnteringWorld()
    local debugPrefix = "|cffff00ff[Channel Debug]|r "
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "PLAYER_ENTERING_WORLD event fired")
    
    local chanType, chanName = JoinChannelByName("TurtleGroupFinder")
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "JoinChannelByName result - Type: " .. tostring(chanType) .. ", Name: " .. tostring(chanName))
    
    ChatFrame_AddChannel(DEFAULT_CHAT_FRAME, "TurtleGroupFinder")
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "ChatFrame_AddChannel called")
    
    -- Now fetch the ID from the channel list:
    local chans = { GetChannelList() }
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "GetChannelList returned " .. table.getn(chans) .. " items")
    
    for i = 1, table.getn(chans), 3 do
        local channelId = chans[i]
        local channelName = chans[i + 1]
        local channelFlags = chans[i + 2]
        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Channel " .. i .. ": ID=" .. tostring(channelId) .. ", Name=" .. tostring(channelName) .. ", Flags=" .. tostring(channelFlags))
        
        -- Fix: Check both positions since GetChannelList() seems to swap ID and Name
        if channelName == "TurtleGroupFinder" then
            DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Found matching channel in Name position! Setting channelIndex to: " .. channelId)
            channelIndex = channelId
        elseif channelId == "TurtleGroupFinder" then
            DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Found matching channel in ID position! Setting channelIndex to: " .. channelName)
            channelIndex = channelName
        end
    end
    
    if channelIndex == 0 then
        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "WARNING: channelIndex is still 0 after processing")
    else
        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "SUCCESS: channelIndex set to " .. channelIndex)
    end
end

-- Channel Management Functions
local function JoinGroupFinderChannel()
    local debugPrefix = "|cffff00ff[Channel Debug]|r "
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "JoinGroupFinderChannel() called")
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Current channelIndex: " .. channelIndex)
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Channel join attempts: " .. channelJoinAttempts)
    
    if channelIndex > 0 then
        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Already joined - returning true")
        return true -- Already joined
    end

    if channelJoinAttempts >= MAX_CHANNEL_JOIN_ATTEMPTS then
        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Max attempts reached (" .. MAX_CHANNEL_JOIN_ATTEMPTS .. ") - returning false")
        return false -- Too many attempts
    end

    channelJoinAttempts = channelJoinAttempts + 1
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Attempt #" .. channelJoinAttempts .. " - calling JoinChannelByName('" .. GROUPFINDER_CHANNEL .. "')")

    -- Join the channel
    local chanType, chanName = JoinChannelByName(GROUPFINDER_CHANNEL)
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "JoinChannelByName result - Type: " .. tostring(chanType) .. ", Name: " .. tostring(chanName))

    -- Find channel index
    local channels = { GetChannelList() }
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "GetChannelList returned " .. table.getn(channels) .. " items")
    
    for i = 1, table.getn(channels), 3 do
        local channelId = channels[i]
        local channelName = channels[i + 1]
        local channelFlags = channels[i + 2]
        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Channel " .. i .. ": ID=" .. tostring(channelId) .. ", Name=" .. tostring(channelName) .. ", Flags=" .. tostring(channelFlags))
        
        -- Fix: Check both positions since GetChannelList() seems to swap ID and Name
        if channelName == "TurtleGroupFinder" then
            channelIndex = channelId
            DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "MATCH FOUND in Name position! Setting channelIndex to: " .. channelIndex)
            local prefix = "|cff00ff00[TurtleGroupFinder]|r "
            DEFAULT_CHAT_FRAME:AddMessage(prefix ..
            "Joined channel '" .. GROUPFINDER_CHANNEL .. "' (index: " .. channelIndex .. ")")
            return true
        elseif channelId == "TurtleGroupFinder" then
            channelIndex = channelName
            DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "MATCH FOUND in ID position! Setting channelIndex to: " .. channelIndex)
            local prefix = "|cff00ff00[TurtleGroupFinder]|r "
            DEFAULT_CHAT_FRAME:AddMessage(prefix ..
            "Joined channel '" .. GROUPFINDER_CHANNEL .. "' (index: " .. channelIndex .. ")")
            return true
        end
    end

    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "No matching channel found - returning false")
    return false
end

local function GetChannelIndex()
    local debugPrefix = "|cffff00ff[Channel Debug]|r "
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "GetChannelIndex() called")
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Current channelIndex: " .. channelIndex)
    
    if channelIndex > 0 then
        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "channelIndex > 0, returning: " .. channelIndex)
        return channelIndex
    end

    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "channelIndex is 0, trying to find channel in list")
    
    -- Try to find the channel index
    local channels = { GetChannelList() }
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "GetChannelList returned " .. table.getn(channels) .. " items")
    
    for i = 1, table.getn(channels), 3 do
        local channelId = channels[i]
        local channelName = channels[i + 1]
        local channelFlags = channels[i + 2]
        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Checking channel: ID=" .. tostring(channelId) .. ", Name=" .. tostring(channelName))
        
        -- Fix: Check both positions since GetChannelList() seems to swap ID and Name
        if channelName == "TurtleGroupFinder" then
            channelIndex = channelId
            DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "FOUND in Name position! Setting channelIndex to: " .. channelIndex)
            return channelIndex
        elseif channelId == "TurtleGroupFinder" then
            channelIndex = channelName
            DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "FOUND in ID position! Setting channelIndex to: " .. channelIndex)
            return channelIndex
        end
    end

    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Channel not found in list, attempting to join...")
    
    -- Channel not found, try to join
    if JoinGroupFinderChannel() then
        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "JoinGroupFinderChannel() succeeded, returning: " .. channelIndex)
        return channelIndex
    end

    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "JoinGroupFinderChannel() failed, returning 0")
    return 0
end

-- Get sorted list of instances
local function GetInstanceList()
    local list = {}
    for instance, _ in pairs(INSTANCES) do
        table.insert(list, instance)
    end
    table.sort(list, function(a, b) return a < b end)
    return list
end

-- Get filtered list of instances by type (maintains INSTANCES table order)
local function GetInstanceListByType(instanceType)
    local list = {}
    -- Create ordered list based on INSTANCES table definition order
    local orderedInstances = {
        -- Dungeons by level
        "Ragefire Chasm", "The Deadmines", "Wailing Caverns", "Shadowfang Keep", "The Stockade",
        "Gnomeregan", "Razorfen Kraul", "Scarlet Monastery", "Razorfen Downs", "Uldaman",
        "Zul'Farrak", "Maraudon", "Temple of Atal'Hakkar", "Blackrock Depths",
        "Lower Blackrock Spire", "Upper Blackrock Spire", "Dire Maul", "Stratholme", "Scholomance",
        -- Raids
        "Molten Core", "Blackwing Lair", "Zul'Gurub", "Ahn'Qiraj Temple", "Ruins of Ahn'Qiraj", "Naxxramas",
        -- PvP Battlegrounds
        "Warsong Gulch", "Arathi Basin", "Alterac Valley",
        -- Other activities
        "PvP", "Other"
    }

    for _, instance in ipairs(orderedInstances) do
        local data = INSTANCES[instance]
        if data and (instanceType == "All" or data.type == instanceType) then
            table.insert(list, instance)
        end
    end
    return list
end

-- Dynamic Panel Management Functions
local function InitializePanelFrames()
    if not GroupFinderFrame then
        return false
    end

    panelFrames.leftPanel = GroupFinderFrameLeftPanel
    panelFrames.rightPanel = GroupFinderFrameRightPanel
    panelFrames.listView = GroupFinderFrameRightPanelListView
    panelFrames.createView = GroupFinderFrameRightPanelCreateView

    -- Initialize type buttons
    selectedTypeButtons.all = GroupFinderFrameLeftPanelAllButton
    selectedTypeButtons.dungeon = GroupFinderFrameLeftPanelDungeonButton
    selectedTypeButtons.raid = GroupFinderFrameLeftPanelRaidButton
    selectedTypeButtons.pvp = GroupFinderFrameLeftPanelPvPButton
    selectedTypeButtons.questing = GroupFinderFrameLeftPanelQuestingButton
    selectedTypeButtons.other = GroupFinderFrameLeftPanelOtherButton

    return true
end

local function UpdateTypeButtonStates()
    if not selectedTypeButtons.all then
        return
    end

    -- Reset all button states
    for _, button in pairs(selectedTypeButtons) do
        if button and button.SetNormalTexture then
            button:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
            button:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
        end
    end

    -- Highlight selected button
    local selectedButton = nil
    if currentInstanceType == "All" then
        selectedButton = selectedTypeButtons.all
    elseif currentInstanceType == "Dungeon" then
        selectedButton = selectedTypeButtons.dungeon
    elseif currentInstanceType == "Raid" then
        selectedButton = selectedTypeButtons.raid
    elseif currentInstanceType == "PvP" then
        selectedButton = selectedTypeButtons.pvp
    elseif currentInstanceType == "Questing" then
        selectedButton = selectedTypeButtons.questing
    elseif currentInstanceType == "Other" then
        selectedButton = selectedTypeButtons.other
    end

    if selectedButton and selectedButton.SetNormalTexture then
        selectedButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Down")
    end
end

local function ShowListView()
    if not panelFrames.listView or not panelFrames.createView then
        return
    end

    currentView = "list"
    panelFrames.listView:Show()
    panelFrames.createView:Hide()

    -- Refresh the group list
    GroupFinder_RefreshGroups()
end

local function ShowCreateView()
    if not panelFrames.listView or not panelFrames.createView then
        return
    end

    currentView = "create"
    panelFrames.listView:Hide()
    panelFrames.createView:Show()

    -- Set default instance based on current filter if none selected
    if not selectedInstance or selectedInstance == "" then
        local filteredInstances = GetInstanceListByType(currentInstanceType)
        if filteredInstances and table.getn(filteredInstances) > 0 then
            selectedInstance = filteredInstances[1]
        else
            selectedInstance = "The Deadmines"
        end
    end

    -- Update instance display in create view
    GroupFinder_UpdateCreateViewInstanceDisplay()
end

-- Instance Type Selection Functions
function GroupFinder_SetInstanceType(instanceType)
    currentInstanceType = instanceType

    UpdateTypeButtonStates()

    -- Clear input focus when changing types
    GroupFinder_ClearAllInputFocus()

    -- Always update the selected instance when switching types
    if instanceType == "Questing" then
        selectedInstance = "Questing"
    elseif instanceType == "Other" then
        selectedInstance = "Other Activity"
    else
        local filteredInstances = GetInstanceListByType(instanceType)
        if filteredInstances and table.getn(filteredInstances) > 0 then
            selectedInstance = filteredInstances[1]
        end
    end

    -- If we're in list view, refresh the groups
    if currentView == "list" then
        GroupFinder_RefreshGroups()
    end

    -- Update create view if it's showing
    if currentView == "create" then
        GroupFinder_UpdateCreateViewInstanceDisplay()
    end

    local prefix = "|cff00ff00[GroupFinder]|r "
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Instance type filter set to: " .. instanceType)
end

-- View Navigation Functions
function GroupFinder_ShowListView()
    ShowListView()
end

function GroupFinder_ShowCreateView()
    ShowCreateView()
end

-- Focus management functions
function GroupFinder_ClearAllInputFocus()
    -- Clear focus from all input fields
    local inputs = {
        GroupFinderFrameRightPanelListViewSearchInput,
        GroupFinderFrameRightPanelCreateViewDescription,
        GroupFinderFrameRightPanelCreateViewMinLevelInput,
        GroupFinderFrameRightPanelCreateViewVoiceChatInput,
        GroupFinderCreateFrameDescription
    }

    for _, input in ipairs(inputs) do
        if input and input.ClearFocus then
            input:ClearFocus()
        end
    end
end

-- Main frame initialization for new panel system
function GroupFinder_OnShow()
    if not InitializePanelFrames() then
        -- Initialize without panels if not available
        GroupFinder_RefreshGroups()
        return
    end

    -- Initialize the dynamic panel system
    currentView = "list"
    currentInstanceType = "All"

    UpdateTypeButtonStates()
    ShowListView()

    -- Clear any input focus when opening the addon
    GroupFinder_ClearAllInputFocus()
end

-- Frame Pooling Functions for Memory Optimization
local function GetPooledButton(parent)
    local button = nil

    -- Try to get a button from the pool
    if table.getn(framePool.groupButtons) > 0 then
        button = table.remove(framePool.groupButtons)
        button:SetParent(parent)
        button:ClearAllPoints()
        button:Show()
    else
        -- Create new button if pool is empty
        button = CreateFrame("Button", nil, parent)
        button:SetWidth(320)
        button:SetHeight(30)

        -- Set up backdrop
        button:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 8,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
    end

    -- Reset button state
    button:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
    button:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    button:SetScript("OnClick", nil)
    button:SetScript("OnEnter", nil)
    button:SetScript("OnLeave", nil)

    table.insert(framePool.activeButtons, button)
    return button
end

local function ReturnButtonToPool(button)
    if not button then return end

    -- Clear all scripts and references
    button:SetScript("OnClick", nil)
    button:SetScript("OnEnter", nil)
    button:SetScript("OnLeave", nil)
    button:Hide()
    button:SetParent(nil)

    -- Clear any child frames (edit/delete buttons)
    local children = { button:GetChildren() }
    for _, child in ipairs(children) do
        if child then
            child:Hide()
            child:SetParent(nil)
        end
    end

    -- Clear font strings
    local regions = { button:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region:GetObjectType() == "FontString" then
            region:SetText("")
        end
    end

    -- Return to pool if not full
    if table.getn(framePool.groupButtons) < framePool.maxPoolSize then
        table.insert(framePool.groupButtons, button)
    end
end

local function ClearActiveButtons()
    -- Clear all active buttons and reset their positions
    for _, button in ipairs(framePool.activeButtons) do
        if button then
            button:ClearAllPoints()  -- Clear positioning
            button:Hide()            -- Hide the button
            ReturnButtonToPool(button)
        end
    end
    framePool.activeButtons = {}

    -- Also clear legacy groupButtons array
    for _, button in ipairs(groupButtons) do
        if button then
            button:ClearAllPoints()  -- Clear positioning
            button:Hide()            -- Hide the button
            ReturnButtonToPool(button)
        end
    end
    groupButtons = {}
end

-- Update instance display in create view
function GroupFinder_UpdateCreateViewInstanceDisplay()
    if not panelFrames.createView then
        return
    end

    local instanceLabel = GroupFinderFrameRightPanelCreateViewInstanceLabel
    local instanceDisplay = GroupFinderFrameRightPanelCreateViewInstanceDisplay
    local instanceButton = GroupFinderFrameRightPanelCreateViewInstanceButton
    local activityMessage = GroupFinderFrameRightPanelCreateViewActivityMessage

    -- Hide/show elements based on activity type
    if currentInstanceType == "Questing" or currentInstanceType == "Other" then
        -- Hide instance selection elements
        if instanceLabel then instanceLabel:Hide() end
        if instanceDisplay then instanceDisplay:Hide() end
        if instanceButton then instanceButton:Hide() end

        -- Show activity message
        if activityMessage then
            activityMessage:Show()
            if currentInstanceType == "Questing" then
                activityMessage:SetText("Describe your questing activity in the description field")
            else
                activityMessage:SetText("Describe your activity in the description field")
            end
        end
    else
        -- Show instance selection elements
        if instanceLabel then instanceLabel:Show() end
        if instanceDisplay then instanceDisplay:Show() end
        if instanceButton then instanceButton:Show() end

        -- Hide activity message
        if activityMessage then activityMessage:Hide() end

        -- Update instance display text
        if instanceDisplay then
            local instanceInfo = INSTANCES[selectedInstance]
            local displayText
            if instanceInfo then
                displayText = selectedInstance .. " (" .. instanceInfo.level .. ")"
            else
                displayText = selectedInstance or "The Deadmines"
            end
            instanceDisplay:SetText(displayText)
        end
    end
end

-- Simplified UpdateInstanceDisplay function
local function UpdateInstanceDisplay()
    -- Validate selectedInstance
    if not selectedInstance or selectedInstance == "" then
        selectedInstance = "The Deadmines"
    end

    -- Prepare display text
    local instanceInfo = INSTANCES[selectedInstance]
    local displayText
    if instanceInfo then
        displayText = selectedInstance .. " (" .. instanceInfo.level .. " - " .. instanceInfo.type .. ")"
    else
        displayText = selectedInstance or "The Deadmines"
    end

    -- Update new UI elements
    if GroupFinderFrameRightPanelCreateViewInstanceDisplay then
        GroupFinderFrameRightPanelCreateViewInstanceDisplay:SetText(displayText)
        return true
    end

    return false
end

-- Simple cycle function for instance selection
function GroupFinder_CycleInstance()
    local instances = GetInstanceList()
    if not instances or table.getn(instances) == 0 then
        return
    end

    -- Find current index
    local currentIndex = 1
    for i, instance in ipairs(instances) do
        if instance == selectedInstance then
            currentIndex = i
            break
        end
    end

    -- Go to next instance
    currentIndex = currentIndex + 1
    if currentIndex > table.getn(instances) then
        currentIndex = 1
    end

    selectedInstance = instances[currentIndex]

    -- Update display
    UpdateInstanceDisplay()

    local instanceInfo = INSTANCES[selectedInstance]
    local userPrefix = "|cff00ff00[GroupFinder]|r "
    if instanceInfo then
        DEFAULT_CHAT_FRAME:AddMessage(userPrefix .. "Selected: " .. selectedInstance .. " (" .. instanceInfo.level .. ")")
    else
        DEFAULT_CHAT_FRAME:AddMessage(userPrefix .. "Selected: " .. selectedInstance)
    end
end

function GroupFinder_ShowInstanceDropdown()
    -- Check if current instance type is "Questing" or "Other" - don't show dropdown
    if currentInstanceType == "Questing" or currentInstanceType == "Other" then
        local prefix = "|cff00ff00[GroupFinder]|r "
        if currentInstanceType == "Questing" then
            selectedInstance = "Questing Activity"
            DEFAULT_CHAT_FRAME:AddMessage(prefix ..
            "For questing activities, describe your activity in the description field.")
        else
            selectedInstance = "Other Activity"
            DEFAULT_CHAT_FRAME:AddMessage(prefix ..
            "For other activities, describe your activity in the description field.")
        end

        -- Update the display
        UpdateInstanceDisplay()
        GroupFinder_UpdateCreateViewInstanceDisplay()
        return
    end

    -- Hide any existing dropdown first
    if GroupFinderInstanceSelector then
        GroupFinderInstanceSelector:Hide()
        GroupFinderInstanceSelector = nil
    end

    -- Create dropdown frame
    local dropdown = CreateFrame("Frame", "GroupFinderInstanceSelector", UIParent)
    dropdown:SetWidth(400)
    dropdown:SetHeight(300)
    dropdown:SetPoint("CENTER", UIParent, "CENTER")
    dropdown:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    dropdown:SetFrameStrata("FULLSCREEN_DIALOG")
    dropdown:EnableMouse(true)

    -- Title
    local title = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", dropdown, "TOP", 0, -15)
    title:SetText("Select Instance")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, dropdown)
    closeBtn:SetWidth(20)
    closeBtn:SetHeight(20)
    closeBtn:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", -10, -10)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    closeBtn:SetScript("OnClick", function() dropdown:Hide() end)

    -- Get filtered instances based on current instance type
    local instances = GetInstanceListByType(currentInstanceType)
    local yOffset = 50
    local buttonHeight = 20

    for i, instance in ipairs(instances) do
        if i <= 12 then -- Show first 12 instances
            local button = CreateFrame("Button", nil, dropdown)
            button:SetWidth(350)
            button:SetHeight(buttonHeight)
            button:SetPoint("TOP", dropdown, "TOP", 0, -yOffset)

            -- Button background
            button:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 8,
                edgeSize = 8,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            button:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            button:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

            -- Instance info
            local instanceInfo = INSTANCES[instance]
            local displayText = instance
            if instanceInfo then
                displayText = instance .. " (" .. instanceInfo.level .. ")"
            end

            local buttonText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            buttonText:SetPoint("LEFT", button, "LEFT", 10, 0)
            buttonText:SetText(displayText)
            buttonText:SetTextColor(1, 1, 1, 1)

            -- Highlight current selection
            if instance == selectedInstance then
                button:SetBackdropColor(0, 0.5, 0, 0.8)
                buttonText:SetTextColor(0, 1, 0, 1)
            end

            -- Store the instance value in the button to avoid closure issues
            button.instanceName = instance

            -- Button events
            button:SetScript("OnClick", function()
                local clickedInstance = button.instanceName

                if clickedInstance then
                    selectedInstance = clickedInstance
                    UpdateInstanceDisplay()

                    local instanceInfo = INSTANCES[selectedInstance]
                    local userPrefix = "|cff00ff00[GroupFinder]|r "
                    if instanceInfo then
                        DEFAULT_CHAT_FRAME:AddMessage(userPrefix ..
                        "Selected: " ..
                        selectedInstance .. " (" .. instanceInfo.level .. " - " .. instanceInfo.type .. ")")
                    else
                        DEFAULT_CHAT_FRAME:AddMessage(userPrefix .. "Selected: " .. selectedInstance)
                    end
                end
                dropdown:Hide()
            end)

            button:SetScript("OnEnter", function()
                if instance ~= selectedInstance then
                    button:SetBackdropColor(0.3, 0.3, 0.3, 0.8)
                end
            end)

            button:SetScript("OnLeave", function()
                if instance ~= selectedInstance then
                    button:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                end
            end)

            yOffset = yOffset + buttonHeight + 2
        end
    end

    -- Show dropdown
    dropdown:Show()
end

-- Simplified initialization function - always creates new hash-based structure
local function InitializeDB()
    local prefix = "|cff00ff00[GroupFinder]|r "
    local debugPrefix = "|cff00ffff[DB Debug]|r "
    
    -- Check if we have existing data
    if GroupFinderDB and GroupFinderDB.groups then
        local oldGroupCount = 0
        for _ in pairs(GroupFinderDB.groups) do
            oldGroupCount = oldGroupCount + 1
        end
        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Found existing DB with " .. oldGroupCount .. " groups")
        
        -- Clear all groups for real-time only operation
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Clearing persistent groups - using real-time only mode")
    end
    
    -- Always create fresh database structure for real-time groups only
    GroupFinderDB = {
        groups = {}, -- Hash table: ID -> group object (e.g., ["GF_1_1234567890"] = {...})
        settings = {
            autoCleanup = true,
            cleanupTimer = 300,  -- Reduced to 5 minutes for real-time operation
            maxGroups = 50
        },
        metadata = {
            version = "3.0",
            nextGroupId = 1,
            playerGroups = {} -- Array of player's own group IDs for quick access
        }
    }

    isInitialized = true
    
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Database initialized for real-time groups only")
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Persistent storage disabled - groups will not survive logout")
end

-- Generate unique group ID
local function GenerateGroupId()
    if not GroupFinderDB or not GroupFinderDB.metadata then
        InitializeDB()
    end
    
    local timestamp = GetTimeStamp()
    local groupId = "GF_" .. GroupFinderDB.metadata.nextGroupId .. "_" .. timestamp
    GroupFinderDB.metadata.nextGroupId = GroupFinderDB.metadata.nextGroupId + 1
    return groupId
end

-- Get instance type for activity (helper function)
local function GetInstanceTypeForActivity(activity)
    if not activity then
        return "Other"
    end

    local instanceInfo = INSTANCES[activity]
    if instanceInfo and instanceInfo.type then
        return instanceInfo.type
    end

    return "Other"
end

-- Database Operation Functions

-- Add group with unique ID and proper indexing
local function AddGroupWithId(activity, leader, roles, description)
    if not isInitialized then
        return nil
    end

    local currentTime = GetTimeStamp()
    local groupId = GenerateGroupId()
    local serverKey = leader .. "_" .. currentTime

    -- Create new group object with enhanced structure
    local newGroup = {
        id = groupId,
        leader = leader,
        serverKey = serverKey,
        version = 1,
        activity = activity,
        roles = roles or "",
        description = description or "",
        timestamp = currentTime,
        lastBroadcast = (leader == UnitName("player")) and currentTime or nil,
        instanceType = GetInstanceTypeForActivity(activity)
    }

    -- Check for existing group from same leader and remove it
    local existingGroupId = nil
    for id, group in pairs(GroupFinderDB.groups) do
        if group.leader == leader then
            existingGroupId = id
            break
        end
    end

    if existingGroupId then
        -- Remove old group
        GroupFinderDB.groups[existingGroupId] = nil
        -- Remove from player groups if it was ours
        if leader == UnitName("player") then
            for i, id in ipairs(GroupFinderDB.metadata.playerGroups) do
                if id == existingGroupId then
                    table.remove(GroupFinderDB.metadata.playerGroups, i)
                    break
                end
            end
        end
    end

    -- Add new group to hash table
    GroupFinderDB.groups[groupId] = newGroup

    -- Track player's own groups
    if leader == UnitName("player") then
        table.insert(GroupFinderDB.metadata.playerGroups, groupId)
    end

    -- Limit total number of groups (remove oldest if needed)
    local totalGroups = 0
    for _ in pairs(GroupFinderDB.groups) do
        totalGroups = totalGroups + 1
    end

    if totalGroups > GroupFinderDB.settings.maxGroups then
        -- Find and remove oldest group
        local oldestId = nil
        local oldestTime = GetTimeStamp()
        for id, group in pairs(GroupFinderDB.groups) do
            if group.timestamp < oldestTime then
                oldestTime = group.timestamp
                oldestId = id
            end
        end

        if oldestId then
            GroupFinderDB.groups[oldestId] = nil
            -- Remove from player groups if it was ours
            for i, id in ipairs(GroupFinderDB.metadata.playerGroups) do
                if id == oldestId then
                    table.remove(GroupFinderDB.metadata.playerGroups, i)
                    break
                end
            end
        end
    end

    return groupId
end

-- Get group by ID (O(1) lookup)
local function GetGroupById(groupId)
    if not isInitialized or not groupId then
        return nil
    end
    return GroupFinderDB.groups[groupId]
end

-- Get groups by leader (for player's own groups)
local function GetGroupsByLeader(leader)
    if not isInitialized or not leader then
        return {}
    end

    local groups = {}
    for id, group in pairs(GroupFinderDB.groups) do
        if group.leader == leader then
            table.insert(groups, group)
        end
    end
    return groups
end

-- Update group by ID
local function UpdateGroupById(groupId, activity, roles, description)
    if not isInitialized or not groupId then
        return false
    end

    local group = GroupFinderDB.groups[groupId]
    if not group then
        return false
    end

    -- Only allow updates by the group leader
    if group.leader ~= UnitName("player") then
        return false
    end

    -- Update group data
    group.activity = activity or group.activity
    group.roles = roles or group.roles
    group.description = description or group.description
    group.timestamp = GetTimeStamp()
    group.version = group.version + 1
    group.instanceType = GetInstanceTypeForActivity(group.activity)

    return true
end

-- Delete group by ID
local function DeleteGroupById(groupId)
    if not isInitialized or not groupId then
        return false
    end

    local group = GroupFinderDB.groups[groupId]
    if not group then
        return false
    end

    -- Only allow deletion by the group leader
    if group.leader ~= UnitName("player") then
        return false
    end

    -- Remove from hash table
    GroupFinderDB.groups[groupId] = nil

    -- Remove from player groups
    for i, id in ipairs(GroupFinderDB.metadata.playerGroups) do
        if id == groupId then
            table.remove(GroupFinderDB.metadata.playerGroups, i)
            break
        end
    end

    return true
end

-- Get all groups as array (for UI compatibility)
local function GetAllGroupsArray()
    if not isInitialized then
        return {}
    end

    local groups = {}
    for id, group in pairs(GroupFinderDB.groups) do
        table.insert(groups, group)
    end

    -- Sort by timestamp (newest first)
    table.sort(groups, function(a, b)
        return (a.timestamp or 0) > (b.timestamp or 0)
    end)

    return groups
end



local function IsGroupExpired(group, maxAge)
    return (GetTimeStamp() - group.timestamp) > maxAge
end

-- String trim function for WoW 1.12
local function StringTrim(s)
    return string.gsub(s, "^%s*(.-)%s*$", "%1")
end

-- Comprehensive string sanitization for chat messages to prevent escape code errors
local function SanitizeForChat(text)
    if not text or text == "" then
        return ""
    end

    -- Convert to string if not already
    text = tostring(text)

    -- Remove or replace problematic characters that can cause escape code errors
    -- 1. Remove pipe characters (|) as they're used as delimiters in TGF format
    text = string.gsub(text, "|", "")

    -- 2. Remove backslashes (\) that can create invalid escape sequences
    text = string.gsub(text, "\\", "")

    -- 3. Remove or replace quotes that can break message parsing
    text = string.gsub(text, "\"", "'")
    text = string.gsub(text, "`", "'")

    -- 4. Remove control characters (newlines, tabs, etc.) that can cause issues
    text = string.gsub(text, "[\n\r\t\f\v]", " ")

    -- 5. Remove other potentially problematic characters
    text = string.gsub(text, "[\001-\031]", "") -- Remove ASCII control characters
    text = string.gsub(text, "[\127-\159]", "") -- Remove extended control characters

    -- 6. Replace multiple spaces with single space
    text = string.gsub(text, "%s+", " ")

    -- 7. Trim whitespace
    text = StringTrim(text)

    -- 8. Limit length to prevent overly long messages
    if string.len(text) > 200 then
        text = string.sub(text, 1, 197) .. "..."
    end

    return text
end

local function ValidateInput(text, fieldName)
    if not text or string.len(StringTrim(text)) == 0 then
        return false, fieldName .. " cannot be empty"
    end
    if string.len(text) > 100 then
        return false, fieldName .. " is too long (max 100 characters)"
    end
    return true, nil
end

local function PrintMessage(message, isError)
    local prefix = isError and "|cffff0000[GroupFinder Error]|r " or "|cff00ff00[GroupFinder]|r "
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. message)
end

-- Filter function with enhanced filtering capabilities
local function ShouldShowGroup(group)
    -- Instance type filter
    if currentInstanceType ~= "All" then
        local instanceInfo = INSTANCES[group.activity]
        if instanceInfo then
            -- Map UI filter types to instance types correctly
            local filterToInstanceType = {
                ["Dungeon"] = "Dungeon",
                ["Dungeons"] = "Dungeon", -- Support both singular and plural
                ["Raid"] = "Raid",
                ["Raids"] = "Raid",       -- Support both singular and plural
                ["PvP"] = "PvP",
                ["Questing"] = "Questing",
                ["Other"] = "Other"
            }

            local expectedInstanceType = filterToInstanceType[currentInstanceType] or currentInstanceType
            if instanceInfo.type ~= expectedInstanceType then
                return false
            end
        else
            if currentInstanceType ~= "Other" then
                return false
            end
        end
    end

    -- Search text filter (case-insensitive instance name matching)
    if searchText and searchText ~= "" then
        local activityLower = string.lower(group.activity or "")
        local searchLower = string.lower(searchText)
        if not string.find(activityLower, searchLower) then
            return false
        end
    end

    -- Role filter (if any role filters are active)
    if roleFilters.tank or roleFilters.healer or roleFilters.dps then
        local roles = string.lower(group.roles or "")
        local matchesRole = false

        if roleFilters.tank and string.find(roles, "tank") then
            matchesRole = true
        end
        if roleFilters.healer and string.find(roles, "healer") then
            matchesRole = true
        end
        if roleFilters.dps and string.find(roles, "dps") then
            matchesRole = true
        end

        if not matchesRole then
            return false
        end
    end

    return true
end

-- Filter callback functions
function GroupFinder_OnSearchTextChanged()
    local searchInput = GroupFinderFrameRightPanelListViewSearchInput
    if searchInput then
        searchText = searchInput:GetText() or ""
        GroupFinder_RefreshGroups()
    end
end

function GroupFinder_OnRoleFilterChanged()
    -- Update role filter states
    local tankFilter = GroupFinderFrameRightPanelListViewTankFilter
    local healerFilter = GroupFinderFrameRightPanelListViewHealerFilter
    local dpsFilter = GroupFinderFrameRightPanelListViewDPSFilter

    if tankFilter then
        roleFilters.tank = tankFilter:GetChecked()
    end
    if healerFilter then
        roleFilters.healer = healerFilter:GetChecked()
    end
    if dpsFilter then
        roleFilters.dps = dpsFilter:GetChecked()
    end

    GroupFinder_RefreshGroups()
end

-- Simplified channel-based communication functions
local function SendGroupMessage(messageType, activity, leader, roles, description, groupId)
    local debugPrefix = "|cffff00ff[Channel Debug]|r "
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "SendGroupMessage() called with messageType: " .. tostring(messageType))
    
    local currentChannelIndex = GetChannelIndex()
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "GetChannelIndex() returned: " .. currentChannelIndex)
    
    if currentChannelIndex == 0 then
        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Channel index is 0 - cannot send message")
        PrintMessage("Not connected to TurtleGroupFinder channel - cannot broadcast group", true)
        return false
    end

    -- Get instance type for the activity
    local instanceType = "Other"
    local instanceInfo = INSTANCES[activity]
    if instanceInfo and instanceInfo.type then
        instanceType = instanceInfo.type
    end

    -- Single format: "[GroupFinder]:TYPE:GroupID:InstanceType:InstanceName:LeaderName:Roles:Description"
    local message = "[GroupFinder]:" ..
    messageType ..
    ":" ..
    (groupId or "") ..
    ":" ..
    instanceType ..
    ":" .. (activity or "") .. ":" .. (leader or "") .. ":" .. (roles or "") .. ":" .. (description or "")

    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Attempting to send message to channel " .. currentChannelIndex)
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Message: " .. message)

    local success, errorMsg = pcall(function()
        SendChatMessage(message, "CHANNEL", nil, currentChannelIndex)
    end)

    if success then
        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "SendChatMessage() succeeded")
        PrintMessage("Group " .. string.lower(messageType) .. " sent to GroupFinder channel", false)
        return true
    else
        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "SendChatMessage() failed: " .. tostring(errorMsg))
        PrintMessage("Failed to send channel message: " .. tostring(errorMsg), true)
        return false
    end
end

-- Group management functions
local function CleanupExpiredGroups()
    if not isInitialized or not GroupFinderDB.settings.autoCleanup then
        return
    end

    local cleanupTimer = GroupFinderDB.settings.cleanupTimer
    local removed = 0

    for groupId, group in pairs(GroupFinderDB.groups) do
        if IsGroupExpired(group, cleanupTimer) then
            GroupFinderDB.groups[groupId] = nil

            -- Remove from player groups if it was ours
            if group.leader == UnitName("player") then
                for i, id in ipairs(GroupFinderDB.metadata.playerGroups) do
                    if id == groupId then
                        table.remove(GroupFinderDB.metadata.playerGroups, i)
                        break
                    end
                end
            end

            removed = removed + 1
        end
    end

    if removed > 0 then
        PrintMessage("Cleaned up " .. removed .. " expired groups")
        GroupFinder_RefreshGroups()
    end
end

local function AddGroup(activity, leader, roles, description)
    if not isInitialized then
        return
    end

    -- Use new AddGroupWithId function
    return AddGroupWithId(activity, leader, roles, description)
end

-- Enhanced auto-broadcasting system functions for Phase 3
local function BroadcastOwnGroup(group)
    if not group or group.leader ~= UnitName("player") then
        return false
    end

    local debugPrefix = "|cff00ffff[GroupFinder Auto-Broadcast]|r "

    -- Sanitize all message components to prevent escape code errors
    local cleanActivity = SanitizeForChat(group.activity or "")
    local cleanRoles = SanitizeForChat(group.roles or "")
    local cleanDescription = SanitizeForChat(group.description or "")
    local cleanLeader = SanitizeForChat(group.leader or "")
    local groupId = group.id or ""

    -- Validate that we have essential components after sanitization
    if cleanActivity == "" or cleanLeader == "" or cleanRoles == "" then
        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Cannot broadcast - essential data missing after sanitization")
        return false
    end

    -- Use channel-based communication system with group ID
    local success = SendGroupMessage("UPDATE", cleanActivity, cleanLeader, cleanRoles, cleanDescription, groupId)

    if success then
        group.lastBroadcast = GetTimeStamp()
        if groupId and groupId ~= "" then
            DEFAULT_CHAT_FRAME:AddMessage(debugPrefix ..
            "Auto-broadcast successful for: " .. group.activity .. " (ID: " .. groupId .. ")")
        else
            DEFAULT_CHAT_FRAME:AddMessage(debugPrefix ..
            "Auto-broadcast successful for: " .. group.activity .. " (legacy format)")
        end
        return true
    else
        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Auto-broadcast failed for: " .. group.activity)
        return false
    end
end

local function AutoBroadcastOwnGroups()
    if not isInitialized then
        return
    end

    local currentTime = GetTimeStamp()
    local broadcastCount = 0

    -- Use efficient playerGroups array for O(1) access to own groups
    for _, groupId in ipairs(GroupFinderDB.metadata.playerGroups) do
        local group = GroupFinderDB.groups[groupId]
        if group and group.lastBroadcast then
            local timeSinceLastBroadcast = currentTime - group.lastBroadcast

            -- Re-broadcast if it's been more than AUTO_BROADCAST_INTERVAL seconds
            if timeSinceLastBroadcast >= AUTO_BROADCAST_INTERVAL then
                if BroadcastOwnGroup(group) then
                    broadcastCount = broadcastCount + 1
                end
            end
        end
    end

    if broadcastCount > 0 then
        local debugPrefix = "|cff00ffff[GroupFinder Auto-Broadcast]|r "
        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Re-broadcast " .. broadcastCount .. " group(s)")
    end
end

local function CleanupStaleGroups()
    if not isInitialized then
        return
    end

    local currentTime = GetTimeStamp()
    local removed = 0

    for groupId, group in pairs(GroupFinderDB.groups) do
        -- For groups from other players, check if they're stale (not broadcast recently)
        if group.leader ~= UnitName("player") then
            local timeSinceLastSeen = currentTime - group.timestamp
            if timeSinceLastSeen > STALE_GROUP_TIMEOUT then
                GroupFinderDB.groups[groupId] = nil
                removed = removed + 1
            end
        end
        -- For our own groups, always keep them (they'll be auto-broadcast)
    end

    if removed > 0 then
        local debugPrefix = "|cff00ffff[GroupFinder Auto-Cleanup]|r "
        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Removed " .. removed .. " stale group(s)")
        GroupFinder_RefreshGroups()
    end
end

-- Filter functions (legacy compatibility)
function GroupFinder_SetFilter(filterType)
    currentInstanceType = filterType
    GroupFinder_RefreshGroups()
    PrintMessage("Filter set to: " .. filterType)
end

-- UI Management - Simplified without frame pooling
function GroupFinder_RefreshGroups()
    if not isInitialized then
        return
    end

    local debugPrefix = "|cff00ffff[UI Debug]|r "
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "RefreshGroups called - Starting fresh UI rebuild")
    
    -- Wrap the entire function in error handling
    local success, errorMsg = pcall(function()

    -- Determine which scroll frame to use (new or legacy)
    local scrollFrame = nil
    local groupCountDisplay = nil

    if panelFrames.listView and currentView == "list" then
        -- Use new dynamic panel system
        scrollFrame = GroupFinderFrameRightPanelListViewScrollFrameList
        groupCountDisplay = GroupFinderFrameRightPanelListViewGroupCount
    else
        -- Fallback to legacy system
        scrollFrame = GroupFinderFrameScrollFrameList
        groupCountDisplay = GroupFinderFrameGroupCount
    end

    -- Add nil checks and fallback handling
    if not scrollFrame then
        -- Try alternative scroll frame references
        if GroupFinderFrameRightPanelListViewScrollFrame then
            scrollFrame = GroupFinderFrameRightPanelListViewScrollFrame
        elseif GroupFinderFrameScrollFrame then
            scrollFrame = GroupFinderFrameScrollFrame
        elseif GroupFinderFrame then
            -- Create a temporary container if no scroll frame exists
            scrollFrame = GroupFinderFrame
        else
            PrintMessage("Error: No valid scroll frame found - UI may not be loaded", true)
            return
        end
    end

    -- COMPLETELY CLEAR ALL EXISTING BUTTONS
    local children = { scrollFrame:GetChildren() }
    for _, child in ipairs(children) do
        if child then
            child:Hide()
            child:SetParent(nil)
        end
    end
    
    -- Clear legacy arrays
    groupButtons = {}
    framePool.activeButtons = {}

    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Cleared all existing UI elements")

    -- Create buttons for each group (filtered) - FRESH START
    local offset = 0
    local buttonHeight = 35
    local visibleGroups = 0

    local allGroups = GetAllGroupsArray()
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Total groups in DB: " .. table.getn(allGroups))
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Current filter: " .. currentInstanceType)
    
    for i, group in ipairs(allGroups) do
        local shouldShow = ShouldShowGroup(group)
        if not shouldShow then
            DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "FILTERED OUT: " .. (group.activity or "unknown") .. " by " .. (group.leader or "unknown") .. " (Type: " .. (group.instanceType or "unknown") .. ", Filter: " .. currentInstanceType .. ")")
        end
        if shouldShow then
            visibleGroups = visibleGroups + 1
            
            -- Get instance info first
            local instanceInfo = INSTANCES[group.activity]
            local timeAgo = math.floor((GetTimeStamp() - group.timestamp) / 60)
            local timeText = timeAgo < 1 and "now" or timeAgo .. "m ago"
            local levelText = instanceInfo and ("(" .. instanceInfo.level .. ")") or ""

            -- CREATE FRESH BUTTON - NO POOLING
            local button = CreateFrame("Button", nil, scrollFrame)
            button:SetWidth(320)
            button:SetHeight(30)
            button:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 5, -offset)
            
            -- Set up backdrop
            button:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 8,
                edgeSize = 8,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            button:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
            button:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
            
            DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Created group " .. visibleGroups .. " at offset: " .. offset .. " (activity: " .. (group.activity or "unknown") .. ")")

            -- Increment offset for next button
            offset = offset + buttonHeight

            -- Format button text with instance info
            local buttonText = string.format("%s %s\n%s - %s (%s)",
                group.activity,
                levelText,
                group.roles,
                group.leader,
                timeText
            )

            -- Create text for the button
            local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("LEFT", button, "LEFT", 5, 0)
            text:SetText(buttonText)
            text:SetJustifyH("LEFT")

            -- Add Edit/Delete buttons for own groups
            if group.leader == UnitName("player") then
                -- Edit Button
                local editBtn = CreateFrame("Button", nil, button)
                editBtn:SetWidth(35)
                editBtn:SetHeight(15)
                editBtn:SetPoint("TOPRIGHT", -5, -5)
                editBtn:SetBackdrop({
                    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true,
                    tileSize = 8,
                    edgeSize = 8,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                })
                editBtn:SetBackdropColor(0, 0.7, 0, 0.8)
                editBtn:SetBackdropBorderColor(0, 1, 0, 1)

                local editText = editBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                editText:SetAllPoints(editBtn)
                editText:SetText("Edit")
                editText:SetTextColor(1, 1, 1, 1)

                -- Store the group data locally for the closure
                local groupLeader = group.leader
                local groupActivity = group.activity
                local groupTimestamp = group.timestamp

                editBtn:SetScript("OnClick", function()
                    -- DIAGNOSTIC: Log the search attempt
                    local debugPrefix = "|cff00ffff[Edit Debug]|r "
                    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Searching for group - Leader: " .. tostring(groupLeader) .. ", Activity: " .. tostring(groupActivity))
                    
                    -- Find the group by ID (groups is a hash table, not array)
                    local foundGroup = nil
                    local foundGroupId = nil
                    for groupId, g in pairs(GroupFinderDB.groups) do  -- Use pairs() not ipairs()
                        if g and g.leader == groupLeader and g.activity == groupActivity and g.timestamp == groupTimestamp then
                            foundGroup = g
                            foundGroupId = groupId
                            DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Found group with ID: " .. groupId)
                            break
                        end
                    end
                    
                    if foundGroup and foundGroupId then
                        GroupFinder_EditGroup(foundGroup, foundGroupId)
                    else
                        local prefix = "|cffff0000[GroupFinder Error]|r "
                        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Group no longer exists")
                        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Available groups:")
                        for groupId, g in pairs(GroupFinderDB.groups) do
                            DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "  ID: " .. groupId .. ", Leader: " .. tostring(g.leader) .. ", Activity: " .. tostring(g.activity))
                        end
                    end
                end)

                -- Delete Button
                local delBtn = CreateFrame("Button", nil, button)
                delBtn:SetWidth(35)
                delBtn:SetHeight(15)
                delBtn:SetPoint("TOPRIGHT", -45, -5)
                delBtn:SetBackdrop({
                    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true,
                    tileSize = 8,
                    edgeSize = 8,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                })
                delBtn:SetBackdropColor(0.7, 0, 0, 0.8)
                delBtn:SetBackdropBorderColor(1, 0, 0, 1)

                local delText = delBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                delText:SetAllPoints(delBtn)
                delText:SetText("Del")
                delText:SetTextColor(1, 1, 1, 1)

                delBtn:SetScript("OnClick", function()
                    -- DIAGNOSTIC: Log the search attempt
                    local debugPrefix = "|cff00ffff[Delete Debug]|r "
                    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Searching for group - Leader: " .. tostring(groupLeader) .. ", Activity: " .. tostring(groupActivity))
                    
                    -- Find the group by ID (groups is a hash table, not array)
                    local foundGroupId = nil
                    for groupId, g in pairs(GroupFinderDB.groups) do  -- Use pairs() not ipairs()
                        if g and g.leader == groupLeader and g.activity == groupActivity and g.timestamp == groupTimestamp then
                            foundGroupId = groupId
                            DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Found group with ID: " .. groupId)
                            break
                        end
                    end
                    
                    if foundGroupId then
                        GroupFinder_DeleteGroup(foundGroupId)
                    else
                        local prefix = "|cffff0000[GroupFinder Error]|r "
                        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Group no longer exists")
                        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Available groups:")
                        for groupId, g in pairs(GroupFinderDB.groups) do
                            DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "  ID: " .. groupId .. ", Leader: " .. tostring(g.leader) .. ", Activity: " .. tostring(g.activity))
                        end
                    end
                end)

                -- Set button click handler for own groups
                button:SetScript("OnClick", function()
                    local prefix = "|cff00ff00[GroupFinder]|r "
                    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Use Edit/Delete buttons to manage your group")
                end)
            else
                -- Create a local copy of the group data for the closure
                local groupData = {
                    activity = group.activity,
                    leader = group.leader
                }
                -- Set button click handler for other groups
                button:SetScript("OnClick", function()
                    if groupData and groupData.leader then
                        local message = string.format("Hi! I'd like to join your group for %s. My roles: %s",
                            groupData.activity,
                            UnitClass("player")
                        )
                        -- Use correct SendChatMessage format for whispers
                        SendChatMessage(message, "WHISPER", nil, groupData.leader)
                        local prefix = "|cff00ff00[GroupFinder]|r "
                        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Whispered " .. groupData.leader .. " about joining their group")
                    else
                        local errorPrefix = "|cffff0000[UI Error]|r "
                        DEFAULT_CHAT_FRAME:AddMessage(errorPrefix .. "Could not send whisper, group data is missing.")
                    end
                end)
            end

            -- Hover effects
            button:SetScript("OnEnter", function()
                button:SetBackdropColor(0.4, 0.4, 0.4, 0.9)

                -- Tooltip with nil checks
                if GameTooltip then
                    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                    if group and group.activity then
                        GameTooltip:SetText(group.activity, 1, 1, 0, 1)
                        GameTooltip:AddLine("Leader: " .. (group.leader or "Unknown"), 1, 1, 1, 1)
                        GameTooltip:AddLine("Roles: " .. (group.roles or "Not specified"), 0.8, 0.8, 0.8, 1)

                        local currentInstanceInfo = INSTANCES[group.activity]
                        if currentInstanceInfo then
                            GameTooltip:AddLine("Level: " .. currentInstanceInfo.level, 0.8, 0.8, 0.8, 1)
                            GameTooltip:AddLine("Type: " .. currentInstanceInfo.type, 0.8, 0.8, 0.8, 1)
                            GameTooltip:AddLine("Zone: " .. currentInstanceInfo.zone, 0.6, 0.6, 0.6, 1)
                        end

                        if group.description and group.description ~= "" then
                            GameTooltip:AddLine("Description: " .. group.description, 0.6, 0.6, 0.6, 1)
                        end

                        local currentTimeAgo = math.floor((GetTimeStamp() - (group.timestamp or 0)) / 60)
                        local currentTimeText = currentTimeAgo < 1 and "now" or currentTimeAgo .. "m ago"
                        GameTooltip:AddLine("Posted: " .. currentTimeText, 0.5, 0.5, 0.5, 1)

                        -- Different instructions based on ownership
                        if group.leader == UnitName("player") then
                            GameTooltip:AddLine("Left-click Edit, Right-click Delete", 0, 1, 0, 1)
                        else
                            GameTooltip:AddLine("Click to whisper leader", 0, 1, 0, 1)
                        end
                    end
                    GameTooltip:Show()
                end
            end)

            button:SetScript("OnLeave", function()
                button:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
                GameTooltip:Hide()
            end)

            -- Show the button and add to tracking array
            button:Show()
            table.insert(groupButtons, button)
        end
    end

    -- Update scroll frame content size
    scrollFrame:SetHeight(math.max(offset, 350))

    -- Update group count display
    if groupCountDisplay then
        local totalGroups = table.getn(allGroups) or 0
        if currentInstanceType == "All" then
            groupCountDisplay:SetText("Groups found: " .. visibleGroups)
        else
            groupCountDisplay:SetText("Groups found: " ..
                visibleGroups .. "/" .. totalGroups .. " (filtered: " .. currentInstanceType .. ")")
        end
    end
    
    local totalGroups = table.getn(allGroups) or 0
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "UI refresh completed - Visible groups: " .. visibleGroups .. ", Total groups: " .. totalGroups)
    
    end) -- Close the pcall function
    
    if not success then
        local errorPrefix = "|cffff0000[UI Error]|r "
        DEFAULT_CHAT_FRAME:AddMessage(errorPrefix .. "UI refresh failed: " .. tostring(errorMsg))
        DEFAULT_CHAT_FRAME:AddMessage(errorPrefix .. "This error is preventing UI updates")
    end
end

-- Create group window function
function GroupFinder_CreateGroupWindow()
    -- Use new UI
    if panelFrames.createView and InitializePanelFrames() then
        ShowCreateView()
        return
    end

    -- Fallback to legacy UI
    if GroupFinderCreateFrame then
        GroupFinderCreateFrame:Show()
        UpdateInstanceDisplay()
    end
end

-- Edit function for own groups (handles both UI types)
function GroupFinder_EditGroup(group, indexOrGroupId)
    if not group then
        local prefix = "|cffff0000[GroupFinder Error]|r "
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Invalid group data for editing")
        return
    end

    -- Handle both old index-based calls and new ID-based calls
    local groupId = group.id or indexOrGroupId
    local actualGroup = nil

    if type(indexOrGroupId) == "number" then
        -- Legacy index-based call - convert to ID-based
        local allGroups = GetAllGroupsArray()
        if indexOrGroupId > 0 and indexOrGroupId <= table.getn(allGroups) then
            actualGroup = allGroups[indexOrGroupId]
            groupId = actualGroup.id
        end
    else
        -- New ID-based call or group object with ID
        actualGroup = GroupFinderDB.groups[groupId]
    end

    if not actualGroup then
        local prefix = "|cffff0000[GroupFinder Error]|r "
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Group no longer exists")
        return
    end

    if actualGroup.leader ~= UnitName("player") then
        local prefix = "|cffff0000[GroupFinder Error]|r "
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "You can only edit your own groups")
        return
    end

    selectedInstance = actualGroup.activity or "The Deadmines"

    -- Parse roles and set checkboxes
    local roles = actualGroup.roles or ""
    local needTank = string.find(roles, "Tank") ~= nil
    local needHealer = string.find(roles, "Healer") ~= nil
    local needDPS = string.find(roles, "DPS") ~= nil

    -- Try new UI first, then fallback to legacy UI
    if panelFrames.createView and InitializePanelFrames() then
        -- Switch to create view in new UI
        ShowCreateView()

        -- Set checkboxes in new UI
        if GroupFinderFrameRightPanelCreateViewTankCheck then
            GroupFinderFrameRightPanelCreateViewTankCheck:SetChecked(needTank)
        end
        if GroupFinderFrameRightPanelCreateViewHealerCheck then
            GroupFinderFrameRightPanelCreateViewHealerCheck:SetChecked(needHealer)
        end
        if GroupFinderFrameRightPanelCreateViewDPSCheck then
            GroupFinderFrameRightPanelCreateViewDPSCheck:SetChecked(needDPS)
        end

        if GroupFinderFrameRightPanelCreateViewDescription then
            GroupFinderFrameRightPanelCreateViewDescription:SetText(actualGroup.description or "")
        end

        GroupFinder_UpdateCreateViewInstanceDisplay()
    else
        -- Fallback to legacy UI
        if GroupFinderCreateFrameTankCheck then
            GroupFinderCreateFrameTankCheck:SetChecked(needTank)
        end
        if GroupFinderCreateFrameHealerCheck then
            GroupFinderCreateFrameHealerCheck:SetChecked(needHealer)
        end
        if GroupFinderCreateFrameDPSCheck then
            GroupFinderCreateFrameDPSCheck:SetChecked(needDPS)
        end

        if GroupFinderCreateFrameDescription then
            GroupFinderCreateFrameDescription:SetText(actualGroup.description or "")
        end

        GroupFinderCreateFrame:Show()
        UpdateInstanceDisplay()
    end

    groupEditIndex = groupId -- Store group ID instead of index

    local prefix = "|cff00ff00[GroupFinder]|r "
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Editing your group. Modify and click Create Group to update.")
end

function GroupFinder_DeleteGroup(indexOrGroupId)
    -- Handle both old index-based calls and new ID-based calls
    local group = nil
    local groupId = nil

    if type(indexOrGroupId) == "number" then
        -- Legacy index-based call - convert to ID-based
        local allGroups = GetAllGroupsArray()
        if indexOrGroupId > 0 and indexOrGroupId <= table.getn(allGroups) then
            group = allGroups[indexOrGroupId]
            groupId = group.id
        end
    elseif type(indexOrGroupId) == "string" then
        -- New ID-based call
        groupId = indexOrGroupId
        group = GroupFinderDB.groups[groupId]
    end

    if not group or not groupId then
        local prefix = "|cffff0000[GroupFinder Error]|r "
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Group not found")
        return
    end

    if group.leader == UnitName("player") then
        -- Database-first approach: Remove from database first
        if DeleteGroupById(groupId) then
            -- Send DELETE message to other players with group ID
            local cleanActivity = SanitizeForChat(group.activity or "")
            local cleanLeader = SanitizeForChat(group.leader or "")
            local cleanRoles = SanitizeForChat(group.roles or "")
            local cleanDescription = SanitizeForChat(group.description or "")

            -- Validate that we have essential components after sanitization
            if cleanActivity ~= "" and cleanLeader ~= "" and cleanRoles ~= "" then
                local success = SendGroupMessage("DELETE", cleanActivity, cleanLeader, cleanRoles, cleanDescription,
                    groupId)
                if success then
                    local debugPrefix = "|cff00ffff[GroupFinder Debug]|r "
                    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix ..
                    "DELETE message sent for: " .. group.activity .. " (ID: " .. groupId .. ")")
                end
            end

            -- Fetch updated data from database and refresh UI
            local allGroups = GetAllGroupsArray()
            GroupFinder_RefreshGroups()

            local prefix = "|cff00ff00[GroupFinder]|r "
            DEFAULT_CHAT_FRAME:AddMessage(prefix ..
            "Your group has been deleted (ID: " .. groupId .. ") and DELETE message sent to other players.")
        else
            local prefix = "|cffff0000[GroupFinder Error]|r "
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Failed to delete group from database")
        end
    else
        local prefix = "|cffff0000[GroupFinder Error]|r "
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "You can only delete your own groups")
    end
end

function GroupFinder_CreateGroup()
    if not isInitialized then
        local prefix = "|cffff0000[GroupFinder Error]|r "
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "GroupFinder not initialized")
        return
    end

    -- Make sure we have a valid activity
    local activity = selectedInstance or "The Deadmines"
    local descriptionRaw = ""

    -- Determine which UI we're using and get the description
    if currentView == "create" and GroupFinderFrameRightPanelCreateViewDescription then
        -- New UI
        descriptionRaw = GroupFinderFrameRightPanelCreateViewDescription:GetText()
    elseif GroupFinderCreateFrameDescription then
        -- Legacy UI
        descriptionRaw = GroupFinderCreateFrameDescription:GetText()
    end

    -- Build roles string from checkboxes (try new UI first, then legacy)
    local rolesNeeded = {}
    local tankCheck, healerCheck, dpsCheck

    if currentView == "create" then
        -- New UI checkboxes
        tankCheck = GroupFinderFrameRightPanelCreateViewTankCheck
        healerCheck = GroupFinderFrameRightPanelCreateViewHealerCheck
        dpsCheck = GroupFinderFrameRightPanelCreateViewDPSCheck
    else
        -- Legacy UI checkboxes
        tankCheck = GroupFinderCreateFrameTankCheck
        healerCheck = GroupFinderCreateFrameHealerCheck
        dpsCheck = GroupFinderCreateFrameDPSCheck
    end

    if tankCheck and tankCheck:GetChecked() then
        table.insert(rolesNeeded, "Tank")
    end
    if healerCheck and healerCheck:GetChecked() then
        table.insert(rolesNeeded, "Healer")
    end
    if dpsCheck and dpsCheck:GetChecked() then
        table.insert(rolesNeeded, "DPS")
    end

    local roles = ""
    if table.getn(rolesNeeded) > 0 then
        roles = "Need: " .. table.concat(rolesNeeded, ", ")
    else
        roles = "All welcome"
    end

    -- Clean description (remove placeholder text)
    local description = descriptionRaw
    if string.find(descriptionRaw, "e.g.,") or string.find(descriptionRaw, "Description:") then
        description = ""
    end

    -- Check if we're editing an existing group
    if groupEditIndex then
        -- groupEditIndex now contains group ID instead of array index
        local group = GroupFinderDB.groups[groupEditIndex]
        if group and group.leader == UnitName("player") then
            -- Database-first approach: Update in database first
            if UpdateGroupById(groupEditIndex, activity, roles, description) then
                -- Get updated group data from database
                local updatedGroup = GetGroupById(groupEditIndex)

                -- Send immediate UPDATE message with group ID
                local cleanActivity = SanitizeForChat(activity or "")
                local cleanRoles = SanitizeForChat(roles or "")
                local cleanDescription = SanitizeForChat(description or "")
                local cleanLeader = SanitizeForChat(group.leader or "")

                -- Validate that we have essential components after sanitization
                if cleanActivity ~= "" and cleanLeader ~= "" and cleanRoles ~= "" then
                    local success = SendGroupMessage("UPDATE", cleanActivity, cleanLeader, cleanRoles, cleanDescription,
                        groupEditIndex)
                    if success then
                        updatedGroup.lastBroadcast = GetTimeStamp()
                    end
                end

                groupEditIndex = nil -- Reset

                -- Hide the appropriate frame (this will trigger the refresh)
                if currentView == "create" then
                    ShowListView()                -- Return to list view in new UI
                else
                    GroupFinderCreateFrame:Hide() -- Hide legacy frame
                end

                local prefix = "|cff00ff00[GroupFinder]|r "
                DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Group updated successfully (ID: " .. tostring(groupEditIndex or "unknown") .. ")")
                return
            end
        end
        groupEditIndex = nil -- Reset if something went wrong
    end

    -- Validate inputs
    local isValid, errorMsg = ValidateInput(activity, "Activity")
    if not isValid then
        PrintMessage(errorMsg, true)
        return
    end

    isValid, errorMsg = ValidateInput(roles, "Roles")
    if not isValid then
        PrintMessage(errorMsg, true)
        return
    end

    -- Description is optional but validate if provided
    if description and string.len(description) > 200 then
        PrintMessage("Description is too long (max 200 characters)", true)
        return
    end

    local leader = UnitName("player")

    -- Sanitize all message components to prevent escape code errors
    local cleanActivity = SanitizeForChat(activity or "")
    local cleanRoles = SanitizeForChat(roles or "")
    local cleanDescription = SanitizeForChat(description or "")
    local cleanLeader = SanitizeForChat(leader or "")

    -- Validate that we have essential components after sanitization
    if cleanActivity == "" or cleanLeader == "" or cleanRoles == "" then
        PrintMessage("Cannot create group - essential data missing after sanitization", true)
        return
    end

    -- Database-first approach: Add to database first, then broadcast
    local newGroupId = AddGroupWithId(activity, leader, roles, description or "")

    if newGroupId then
        -- Send CREATE message with group ID
        local success = SendGroupMessage("CREATE", cleanActivity, cleanLeader, cleanRoles, cleanDescription, newGroupId)

        if success then
            -- Update last broadcast time
            local newGroup = GetGroupById(newGroupId)
            if newGroup then
                newGroup.lastBroadcast = GetTimeStamp()
            end

            PrintMessage("Group created and posted (ID: " .. newGroupId .. ")")
        else
            PrintMessage("Group created locally but failed to broadcast", true)
        end

        -- Hide the appropriate frame and return to list view (this will trigger the refresh)
        if currentView == "create" then
            ShowListView()                -- Return to list view in new UI
        else
            GroupFinderCreateFrame:Hide() -- Hide legacy frame
        end
    else
        PrintMessage("Failed to create group in database", true)
    end
end

function GroupFinder_ClearOwnGroups()
    if not isInitialized then
        PrintMessage("GroupFinder not initialized", true)
        return
    end

    local leader = UnitName("player")
    local removed = 0

    -- Use efficient playerGroups array to remove own groups
    for _, groupId in ipairs(GroupFinderDB.metadata.playerGroups) do
        if GroupFinderDB.groups[groupId] then
            GroupFinderDB.groups[groupId] = nil
            removed = removed + 1
        end
    end

    -- Clear the playerGroups array
    GroupFinderDB.metadata.playerGroups = {}

    if removed > 0 then
        PrintMessage("Removed " .. removed .. " of your own groups")
        GroupFinder_RefreshGroups()
    else
        PrintMessage("No groups found for " .. leader)
    end
end

function GroupFinder_ClearAllGroups()
    if not isInitialized then
        PrintMessage("GroupFinder not initialized", true)
        return
    end
    GroupFinderDB.groups = {}
    GroupFinderDB.metadata.playerGroups = {}
    PrintMessage("All groups cleared")
    GroupFinder_RefreshGroups()
end

-- Manual string splitting for WoW 1.12
local function SplitString(str, delimiter)
    local parts = {}
    local start = 1
    local pos = 1
    while pos <= string.len(str) do
        local found = string.find(str, delimiter, pos)
        if found then
            table.insert(parts, string.sub(str, start, found - 1))
            start = found + 1
            pos = found + 1
        else
            table.insert(parts, string.sub(str, start))
            break
        end
    end
    return parts
end

-- Event handling
function GroupFinderFrame_OnEvent()
    if event == "PLAYER_ENTERING_WORLD" then
        local debugPrefix = "|cffff00ff[Channel Debug]|r "
        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "GroupFinderFrame_OnEvent: PLAYER_ENTERING_WORLD received")
        HandlePlayerEnteringWorld()
    elseif event == "CHAT_MSG_CHANNEL" then
        local message, sender, language, channelString, target, flags, unknown, channelNumber = arg1, arg2, arg3, arg4,
            arg5, arg6, arg7, arg8

        if channelNumber == channelIndex and message and string.find(message, "^%[GroupFinder%]:") then
            local cleanMessage = string.gsub(message, "^%[GroupFinder%]:", "")
            local parts = SplitString(cleanMessage, ":")

            local debugPrefix = "|cff00ffff[GroupFinder Debug]|r "
            DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Received channel message from " .. (sender or "unknown"))
            DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Raw message: " .. (message or "nil"))
            DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Clean message: " .. (cleanMessage or "nil"))
            DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Parts count: " .. table.getn(parts))
            
            -- Log all parts for debugging
            for i, part in ipairs(parts) do
                DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Part " .. i .. ": '" .. (part or "nil") .. "'")
            end

            if table.getn(parts) >= 7 then
                local messageType = parts[1]
                local groupId = parts[2]
                local instanceType = parts[3]
                local activity = parts[4]
                local leader = parts[5]
                local roles = parts[6]
                local description = parts[7] or ""

                DEFAULT_CHAT_FRAME:AddMessage(debugPrefix ..
                "Parsed - Type: " ..
                (messageType or "nil") ..
                ", GroupID: " ..
                (groupId or "nil") ..
                ", InstanceType: " .. (instanceType or "nil") .. ", Activity: " .. (activity or "nil"))

                groupId = groupId and SanitizeForChat(groupId) or nil
                instanceType = SanitizeForChat(instanceType or "Other")
                activity = SanitizeForChat(activity or "")
                leader = SanitizeForChat(leader or "")
                roles = SanitizeForChat(roles or "")
                description = SanitizeForChat(description or "")

                if activity and leader and roles and string.len(activity) > 0 and string.len(leader) > 0 and string.len(roles) > 0 then
                    if leader ~= UnitName("player") then
                        if messageType == "CREATE" then
                            DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Processing CREATE message from " .. leader)
                            local newGroupId = AddGroupWithId(activity, leader, roles, description)
                            if newGroupId then
                                local allGroups = GetAllGroupsArray()
                                DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Group added to database, total groups: " .. table.getn(allGroups))
                                DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Calling GroupFinder_RefreshGroups() to update UI...")
                                GroupFinder_RefreshGroups()
                                DEFAULT_CHAT_FRAME:AddMessage(debugPrefix ..
                                "Created group: " ..
                                activity .. " (" .. instanceType .. ") by " .. leader .. " (ID: " .. newGroupId .. ")")
                                DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "UI refresh completed")
                            else
                                DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "FAILED to add group to database")
                            end
                        elseif messageType == "UPDATE" then
                            if groupId then
                                local success = UpdateGroupById(groupId, activity, roles, description)
                                if success then
                                    local allGroups = GetAllGroupsArray()
                                    GroupFinder_RefreshGroups()
                                    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix ..
                                    "Updated group: " .. activity .. " (ID: " .. groupId .. ") by " .. leader)
                                else
                                    local newGroupId = AddGroupWithId(activity, leader, roles, description)
                                    if newGroupId then
                                        local allGroups = GetAllGroupsArray()
                                        GroupFinder_RefreshGroups()
                                        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix ..
                                        "Created new group (update failed): " ..
                                        activity .. " by " .. leader .. " (ID: " .. newGroupId .. ")")
                                    end
                                end
                            end
                        elseif messageType == "DELETE" then
                            if groupId then
                                local group = GetGroupById(groupId)
                                if group and group.leader == leader then
                                    GroupFinderDB.groups[groupId] = nil
                                    local allGroups = GetAllGroupsArray()
                                    GroupFinder_RefreshGroups()
                                    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix ..
                                    "Deleted group: " .. activity .. " (ID: " .. groupId .. ") by " .. leader)
                                end
                            end
                        end -- close messageType checks

                        -- Instance info debug
                        local instanceInfo = INSTANCES[activity]
                        if instanceInfo then
                            DEFAULT_CHAT_FRAME:AddMessage(debugPrefix ..
                            "Instance info found - Type: " .. instanceInfo.type .. ", Level: " .. instanceInfo.level)
                        else
                            DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "No instance info found for: " .. activity)
                        end
                    else
                        DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Ignored own group message")
                    end
                else
                    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix ..
                    "Invalid group data received after sanitization - skipping")
                end
            else
                DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "Malformed channel message - not enough parts")
            end
        end
    elseif event == "ADDON_LOADED" then
        local addonName = arg1
        if addonName == "GroupFinder" then
            InitializeDB()
            PrintMessage("Addon loaded successfully")
        end
    end
end

-- WoW 1.12 Compatibility Validation
local function ValidateWoW112Compatibility()
    local issues = {}

    -- Check for required API functions
    if not CreateFrame then
        table.insert(issues, "CreateFrame function not available")
    end

    if not UnitName then
        table.insert(issues, "UnitName function not available")
    end

    if not SendChatMessage then
        table.insert(issues, "SendChatMessage function not available")
    end

    -- Check for UI elements
    if not UIParent then
        table.insert(issues, "UIParent not available")
    end

    -- Check for required templates
    local testFrame = CreateFrame("Frame", "GroupFinderCompatTest", UIParent)
    if testFrame then
        local success, error = pcall(function()
            local testButton = CreateFrame("Button", nil, testFrame, "UIPanelButtonTemplate")
            if testButton then
                testButton:Hide()
                testButton:SetParent(nil)
            end
        end)
        if not success then
            table.insert(issues, "UIPanelButtonTemplate not available: " .. (error or "unknown"))
        end

        testFrame:Hide()
        testFrame:SetParent(nil)
    end

    if table.getn(issues) > 0 then
        local prefix = "|cffff0000[GroupFinder Compatibility Error]|r "
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "WoW 1.12 compatibility issues detected:")
        for _, issue in ipairs(issues) do
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "- " .. issue)
        end
        return false
    end

    return true
end

-- ============================================================================
-- COMPREHENSIVE TESTING INTEGRATION
-- ============================================================================

-- Load the comprehensive test suite
local function LoadTestSuite()
    -- Check if test functions are available
    if GroupFinderTests_RunCompleteTestSuite then
        return true
    end

    -- Try to load the test file
    local success, error = pcall(function()
        -- In WoW 1.12, we need to manually include the test functions
        -- This would normally be done via a separate .lua file inclusion
        PrintMessage("Test suite functions not found. Please ensure GroupFinderTests.lua is loaded.", true)
    end)

    return false
end

-- Main frame initialization
function GroupFinder_OnLoad(self)
    -- Validate WoW 1.12 compatibility
    if not ValidateWoW112Compatibility() then
        local prefix = "|cffff0000[GroupFinder Error]|r "
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Addon disabled due to compatibility issues")
        return
    end

    -- Early initialization attempt
    InitializeDB()

    -- Register events
    self:RegisterEvent("CHAT_MSG_CHANNEL")
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:SetScript("OnEvent", GroupFinderFrame_OnEvent)

    local debugPrefix = "|cffff00ff[Channel Debug]|r "
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "GroupFinder_OnLoad: Events registered including PLAYER_ENTERING_WORLD")

    -- Setup slash commands
    SLASH_GROUPFINDER1 = "/groupfinder"
    SLASH_GROUPFINDER2 = "/gf"
    SlashCmdList["GROUPFINDER"] = function(msg)
        local command = string.lower(msg or "")
        local parts = SplitString(command, " ")
        local mainCommand = parts[1] or ""

        if mainCommand == "clear" then
            GroupFinder_ClearOwnGroups()
        elseif mainCommand == "clearall" then
            GroupFinder_ClearAllGroups()
        elseif mainCommand == "cleanup" then
            CleanupExpiredGroups()
        elseif mainCommand == "test" then
            -- Run complete test suite
            if LoadTestSuite() and GroupFinderTests_RunCompleteTestSuite then
                GroupFinderTests_RunCompleteTestSuite()
            else
                PrintMessage("Complete test suite not available. Running basic tests...", true)
                -- Run basic built-in tests as fallback
                local prefix = "|cff00ffff[Basic Tests]|r "
                DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Running basic functionality tests...")

                -- Test database structure
                local dbValid = GroupFinderDB and GroupFinderDB.groups and GroupFinderDB.metadata
                if dbValid then
                    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "✓ Database structure valid")
                else
                    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "✗ Database structure invalid")
                end

                -- Test group creation
                local testId = AddGroupWithId("Basic Test", UnitName("player"), "Need: All", "Basic test")
                if testId then
                    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "✓ Group creation works")
                    DeleteGroupById(testId)
                else
                    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "✗ Group creation failed")
                end

                DEFAULT_CHAT_FRAME:AddMessage(prefix ..
                "Basic tests completed. For comprehensive testing, ensure GroupFinderTests.lua is loaded.")
            end
        elseif mainCommand == "testdb" then
            -- Run database tests
            if LoadTestSuite() and GroupFinderTests_RunDatabaseTests then
                GroupFinderTests_RunDatabaseTests()
            else
                PrintMessage("Database test suite not available", true)
            end
        elseif mainCommand == "testmsg" then
            -- Run message compatibility tests
            if LoadTestSuite() and GroupFinderTests_RunMessageTests then
                GroupFinderTests_RunMessageTests()
            else
                PrintMessage("Message test suite not available", true)
            end
        elseif mainCommand == "testui" then
            -- Run UI functionality tests
            if LoadTestSuite() and GroupFinderTests_RunUITests then
                GroupFinderTests_RunUITests()
            else
                PrintMessage("UI test suite not available", true)
            end
        elseif mainCommand == "benchmark" then
            -- Run performance benchmarks
            if LoadTestSuite() and GroupFinderTests_RunBenchmarks then
                GroupFinderTests_RunBenchmarks()
            else
                PrintMessage("Benchmark suite not available", true)
            end
        elseif mainCommand == "validate" then
            -- Generate validation report
            if LoadTestSuite() and GroupFinderTests_GenerateValidationReport then
                GroupFinderTests_GenerateValidationReport()
            else
                PrintMessage("Validation report not available", true)
            end
        elseif mainCommand == "debug" then
            -- Debug command for testing new UI and channel system
            local prefix = "|cff00ffff[GroupFinder Debug]|r "
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Current view: " .. currentView)
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Current instance type: " .. currentInstanceType)
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Panel frames initialized: " .. tostring(panelFrames.listView ~= nil))
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Active buttons: " .. table.getn(framePool.activeButtons))
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Pooled buttons: " .. table.getn(framePool.groupButtons))
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Communication: Channel-based system")
            DEFAULT_CHAT_FRAME:AddMessage(prefix ..
            "Channel: " .. GROUPFINDER_CHANNEL .. " (index: " .. channelIndex .. ")")
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Channel join attempts: " .. channelJoinAttempts)
            DEFAULT_CHAT_FRAME:AddMessage(prefix ..
            "Auto-broadcast timer: " ..
            string.format("%.1f", autoBroadcastTimer) .. "/" .. AUTO_BROADCAST_INTERVAL .. "s")

            -- Show own groups and their broadcast status
            local ownGroups = 0
            local currentTime = GetTimeStamp()
            for _, groupId in ipairs(GroupFinderDB.metadata.playerGroups) do
                local group = GroupFinderDB.groups[groupId]
                if group then
                    ownGroups = ownGroups + 1
                    local timeSinceLastBroadcast = group.lastBroadcast and (currentTime - group.lastBroadcast) or "never"
                    DEFAULT_CHAT_FRAME:AddMessage(prefix ..
                        "Own group: " .. group.activity .. " (ID: " .. groupId .. ", last broadcast: " ..
                        (type(timeSinceLastBroadcast) == "number" and (timeSinceLastBroadcast .. "s ago") or timeSinceLastBroadcast) ..
                        ")")
                end
            end
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Own groups: " .. ownGroups)
        elseif mainCommand == "broadcast" then
            -- Manual trigger for auto-broadcasting (for testing)
            AutoBroadcastOwnGroups()
            PrintMessage("Manual auto-broadcast triggered")
        elseif mainCommand == "cleanstale" then
            -- Manual trigger for stale group cleanup (for testing)
            CleanupStaleGroups()
            PrintMessage("Manual stale group cleanup triggered")
        elseif mainCommand == "test" then
            -- Test function to verify the fixes
            local prefix = "|cff00ffff[GroupFinder Test]|r "
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Testing message parsing and filtering fixes...")

            -- Test the example message format
            local testMessage = "[GroupFinder]:CREATE:Dungeon:Gnomergan:Marcel:Need: Tank:"
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Simulating message: " .. testMessage)

            -- Simulate the parsing logic
            local cleanMessage = string.gsub(testMessage, "^%[GroupFinder%]:", "")
            local parts = SplitString(cleanMessage, ":")

            if table.getn(parts) >= 5 then
                local messageType = parts[1]
                local instanceType = parts[2]
                local activity = parts[3]
                local leader = parts[4]
                local roles = parts[5]
                local description = parts[6] or ""

                DEFAULT_CHAT_FRAME:AddMessage(prefix ..
                "Parsed - Type: " .. messageType .. ", InstanceType: " .. instanceType .. ", Activity: " .. activity)

                -- Test the filtering logic
                local instanceInfo = INSTANCES[activity]
                if instanceInfo then
                    DEFAULT_CHAT_FRAME:AddMessage(prefix ..
                    "Instance info found - Type: " .. instanceInfo.type .. ", Level: " .. instanceInfo.level)

                    -- Test the filter mapping
                    local filterToInstanceType = {
                        ["Dungeon"] = "Dungeon",
                        ["Dungeons"] = "Dungeon",
                        ["Raid"] = "Raid",
                        ["Raids"] = "Raid",
                        ["PvP"] = "PvP",
                        ["Questing"] = "Questing",
                        ["Other"] = "Other"
                    }

                    local expectedInstanceType = filterToInstanceType["Dungeon"] or "Dungeon"
                    local wouldShow = (instanceInfo.type == expectedInstanceType)

                    DEFAULT_CHAT_FRAME:AddMessage(prefix ..
                    "Filter test - Expected: " ..
                    expectedInstanceType ..
                    ", Actual: " .. instanceInfo.type .. ", Would show in Dungeon filter: " .. tostring(wouldShow))
                else
                    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "No instance info found for: " .. activity)
                end

                -- Add the test group temporarily
                AddGroup(activity, leader, roles, description)
                DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Test group added temporarily")

                -- Test focus clearing
                DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Testing focus clearing...")
                GroupFinder_ClearAllInputFocus()
                DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Focus cleared on all inputs")
            else
                DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Failed to parse test message")
            end
        elseif mainCommand == "help" then
            PrintMessage("Commands:")
            PrintMessage("/groupfinder or /gf - Toggle main window")
            PrintMessage("/gf clear - Remove your own groups")
            PrintMessage("/gf clearall - Remove all groups")
            PrintMessage("/gf cleanup - Clean up expired groups")
            PrintMessage("")
            PrintMessage("Testing Commands:")
            PrintMessage("/gf test - Run complete comprehensive test suite")
            PrintMessage("/gf testdb - Test database operations and migration")
            PrintMessage("/gf testmsg - Test message compatibility (new/old/legacy formats)")
            PrintMessage("/gf testui - Test UI functionality and frame pooling")
            PrintMessage("/gf benchmark - Run performance benchmarks")
            PrintMessage("/gf validate - Generate comprehensive validation report")
            PrintMessage("")
            PrintMessage("Debug Commands:")
            PrintMessage("/gf debug - Show debug information and auto-broadcast status")
            PrintMessage("/gf broadcast - Manually trigger auto-broadcast (testing)")
            PrintMessage("/gf cleanstale - Manually trigger stale group cleanup (testing)")
            PrintMessage("/gf help - Show this help")
            PrintMessage("")
            PrintMessage("System Info:")
            PrintMessage("Communication: Uses custom GroupFinder channel (server-wide)")
            PrintMessage("Auto-broadcast: Groups re-broadcast every " .. AUTO_BROADCAST_INTERVAL .. " seconds")
            PrintMessage("Stale cleanup: Groups not seen for " .. STALE_GROUP_TIMEOUT .. " seconds are removed")
            PrintMessage("Database: Hash-based with unique group IDs and O(1) lookups")
            PrintMessage("UI: Dynamic panel system with frame pooling for memory optimization")
        else
            if GroupFinderFrame:IsShown() then
                GroupFinderFrame:Hide()
            else
                GroupFinderFrame:Show()
            end
        end
    end

    -- Setup update timer for cleanup and auto-broadcasting
    local frame = CreateFrame("Frame")
    frame:SetScript("OnUpdate", function()
        local elapsed = arg1 or 0
        updateTimer = updateTimer + elapsed
        autoBroadcastTimer = autoBroadcastTimer + elapsed

        -- Auto-broadcast and cleanup stale groups every 60 seconds
        if autoBroadcastTimer >= AUTO_BROADCAST_INTERVAL then
            autoBroadcastTimer = 0
            AutoBroadcastOwnGroups()
            CleanupStaleGroups()
        end

        -- Regular cleanup every 5 minutes
        if updateTimer >= CLEANUP_INTERVAL then
            updateTimer = 0
            CleanupExpiredGroups()

            -- Check and rejoin channel if needed
            if channelIndex == 0 then
                JoinGroupFinderChannel()
            end
        end
    end)

    PrintMessage("Loaded! Use /groupfinder or /gf to open. Type /gf help for commands.")
    PrintMessage("Using channel-based system for group communication (server-wide via GroupFinder channel).")
    PrintMessage("New dynamic panel UI system enabled with memory optimization.")
    PrintMessage("Auto-broadcasting: Your groups will be re-broadcast every " ..
    AUTO_BROADCAST_INTERVAL .. " seconds automatically.")
end
