-- GroupFinder Addon for WoW 1.12 (Vanilla)
-- Enhanced version with dynamic panel UI system, instance selection, filtering, and improved compatibility

-- Local variables
local LFG_CHANNEL_NAME = "LookingForGroup"
local groupButtons = {}
local channelNumber = 4      -- Default to channel 4 (LFG)
local updateTimer = 0
local CLEANUP_INTERVAL = 300 -- 5 minutes
local isInitialized = false
local selectedInstance = "The Deadmines"
local groupEditIndex = nil

-- Dynamic Panel System Variables
local currentView = "list"  -- "list" or "create"
local currentInstanceType = "All"  -- Current selected instance type filter (unified with legacy currentFilter)
local selectedTypeButtons = {}  -- Track which type button is selected
local panelFrames = {}  -- Cache for panel frames

-- Frame Pooling for Memory Optimization
local framePool = {
    groupButtons = {},  -- Pool of reusable group buttons
    maxPoolSize = 20,   -- Maximum number of buttons to keep in pool
    activeButtons = {}  -- Currently active buttons
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
    ["Warsong Gulch"]= { level = "60", type = "PvP", zone = "Ashenvale" },
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

-- Get sorted list of instances
local function GetInstanceList()
    local list = {}
    for instance, _ in pairs(INSTANCES) do
        table.insert(list, instance)
    end
    table.sort(list, function(a, b) return a < b end)
    return list
end

-- Get filtered list of instances by type
local function GetInstanceListByType(instanceType)
    local list = {}
    for instance, data in pairs(INSTANCES) do
        if instanceType == "All" or data.type == instanceType then
            table.insert(list, instance)
        end
    end
    table.sort(list, function(a, b) return a < b end)
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
    
    -- If we're in list view, refresh the groups
    if currentView == "list" then
        GroupFinder_RefreshGroups()
    end
    
    -- Update create view if it's showing
    if currentView == "create" then
        -- Set default instance based on current filter
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

-- Main frame initialization for new panel system
function GroupFinder_OnShow()
    if not InitializePanelFrames() then
        -- Fallback to old system if new panels not available
        GroupFinder_RefreshGroups()
        return
    end
    
    -- Initialize the dynamic panel system
    currentView = "list"
    currentInstanceType = "All"
    
    UpdateTypeButtonStates()
    ShowListView()
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
    for _, button in ipairs(framePool.activeButtons) do
        ReturnButtonToPool(button)
    end
    framePool.activeButtons = {}
    
    -- Also clear legacy groupButtons array
    for _, button in ipairs(groupButtons) do
        ReturnButtonToPool(button)
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
                displayText = selectedInstance .. " (" .. instanceInfo.level .. " - " .. instanceInfo.type .. ")"
            else
                displayText = selectedInstance or "The Deadmines"
            end
            instanceDisplay:SetText(displayText)
        end
    end
end

-- Instance cycling
local instanceList = nil
local currentInstanceIndex = 1

local function InitializeInstanceList()
    if not instanceList then
        instanceList = GetInstanceList()
        -- Find current instance index
        for i, instance in ipairs(instanceList) do
            if instance == selectedInstance then
                currentInstanceIndex = i
                break
            end
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
    
    -- Try to update new UI first
    if GroupFinderFrameRightPanelCreateViewInstanceDisplay then
        GroupFinderFrameRightPanelCreateViewInstanceDisplay:SetText(displayText)
        return true
    end
    
    -- Fallback to legacy UI
    if GroupFinderCreateFrameInstanceDisplay then
        GroupFinderCreateFrameInstanceDisplay:SetText(displayText)
        return true
    end
    
    -- If neither element exists, create the legacy one programmatically
    if GroupFinderCreateFrame then
        local success, newElement = pcall(function()
            local fontString = GroupFinderCreateFrame:CreateFontString("GroupFinderCreateFrameInstanceDisplay", "OVERLAY", "GameFontHighlight")
            fontString:SetPoint("TOPLEFT", GroupFinderCreateFrame, "TOPLEFT", 25, -50)
            fontString:SetText(displayText)
            return fontString
        end)
        
        if success and newElement then
            GroupFinderCreateFrameInstanceDisplay = newElement
            return true
        end
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
        DEFAULT_CHAT_FRAME:AddMessage(userPrefix .. "Selected: " .. selectedInstance .. " (" .. instanceInfo.level .. " - " .. instanceInfo.type .. ")")
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
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "For questing activities, describe your activity in the description field.")
        else
            selectedInstance = "Other Activity"
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "For other activities, describe your activity in the description field.")
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
        tile = true, tileSize = 32, edgeSize = 16,
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
                tile = true, tileSize = 8, edgeSize = 8,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            button:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            button:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            
            -- Instance info
            local instanceInfo = INSTANCES[instance]
            local displayText = instance
            if instanceInfo then
                displayText = instance .. " (" .. instanceInfo.level .. " - " .. instanceInfo.type .. ")"
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
                        DEFAULT_CHAT_FRAME:AddMessage(userPrefix .. "Selected: " .. selectedInstance .. " (" .. instanceInfo.level .. " - " .. instanceInfo.type .. ")")
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


-- Safe initialization function
local function InitializeDB()
    if not GroupFinderDB then
        GroupFinderDB = {}
    end
    if not GroupFinderDB.groups then
        GroupFinderDB.groups = {}
    end
    if not GroupFinderDB.settings then
        GroupFinderDB.settings = {
            autoCleanup = true,
            cleanupTimer = 3600,
            maxGroups = 50
        }
    end
    isInitialized = true
end

-- Utility functions
local function GetTimeStamp()
    return time()
end

local function IsGroupExpired(group, maxAge)
    return (GetTimeStamp() - group.timestamp) > maxAge
end

-- String trim function for WoW 1.12
local function StringTrim(s)
    return string.gsub(s, "^%s*(.-)%s*$", "%1")
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

-- Filter function
local function ShouldShowGroup(group)
    if currentInstanceType == "All" then
        return true
    end

    local instanceInfo = INSTANCES[group.activity]
    if instanceInfo then
        return instanceInfo.type == currentInstanceType
    end

    return currentInstanceType == "Other"
end

-- Channel management
local function FindLFGChannel()
    local channels = { GetChannelList() }
    for i = 1, table.getn(channels), 3 do
        local channelName = channels[i + 1]
        if channelName == LFG_CHANNEL_NAME or channelName == "LFG" then
            channelNumber = channels[i]
            return channelNumber
        end
    end
    return nil
end

local function JoinLFGChannel()
    -- Try to find existing LFG channel
    local foundChannel = FindLFGChannel()
    if foundChannel then
        channelNumber = foundChannel
        PrintMessage("Found LFG channel (ID: " .. foundChannel .. ")")
        return true
    end

    -- Try to join by name
    local channel = JoinChannelByName(LFG_CHANNEL_NAME)
    if not channel or channel == 0 then
        channel = JoinChannelByName("LFG")
    end

    if channel and channel > 0 then
        channelNumber = channel
        PrintMessage("Joined LFG channel (ID: " .. channel .. ")")
        return true
    else
        -- Fallback to channel 4
        channelNumber = 4
        PrintMessage("Using channel 4 for LFG")
        return true
    end
end

-- Group management functions
local function CleanupExpiredGroups()
    if not isInitialized or not GroupFinderDB.settings.autoCleanup then
        return
    end

    local cleanupTimer = GroupFinderDB.settings.cleanupTimer
    local removed = 0
    local newGroups = {}

    for _, group in ipairs(GroupFinderDB.groups) do
        if not IsGroupExpired(group, cleanupTimer) then
            table.insert(newGroups, group)
        else
            removed = removed + 1
        end
    end

    GroupFinderDB.groups = newGroups

    if removed > 0 then
        PrintMessage("Cleaned up " .. removed .. " expired groups")
        GroupFinder_RefreshGroups()
    end
end

local function AddGroup(activity, leader, roles, description)
    if not isInitialized then
        return
    end

    -- Check if group already exists from same leader
    for i, group in ipairs(GroupFinderDB.groups) do
        if group.leader == leader then
            -- Update existing group
            group.activity = activity
            group.roles = roles
            group.description = description
            group.timestamp = GetTimeStamp()
            return
        end
    end

    -- Add new group
    local newGroup = {
        activity = activity,
        leader = leader,
        roles = roles,
        description = description,
        timestamp = GetTimeStamp()
    }

    table.insert(GroupFinderDB.groups, newGroup)

    -- Limit number of groups
    while table.getn(GroupFinderDB.groups) > GroupFinderDB.settings.maxGroups do
        table.remove(GroupFinderDB.groups, 1)
    end
end

-- Filter functions (legacy compatibility)
function GroupFinder_SetFilter(filterType)
    currentInstanceType = filterType
    GroupFinder_RefreshGroups()
    PrintMessage("Filter set to: " .. filterType)
end

-- UI Management - Updated for Dynamic Panel System with Frame Pooling
function GroupFinder_RefreshGroups()
    if not isInitialized then
        return
    end

    -- Clear existing buttons using frame pooling
    ClearActiveButtons()

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
    
    if not scrollFrame then
        PrintMessage("Error: ScrollFrame not found", true)
        return
    end

    -- Create buttons for each group (filtered)
    local offset = 0
    local buttonHeight = 35
    local visibleGroups = 0

    for i, group in ipairs(GroupFinderDB.groups) do
        if ShouldShowGroup(group) then
            -- Get instance info first
            local instanceInfo = INSTANCES[group.activity]
            local timeAgo = math.floor((GetTimeStamp() - group.timestamp) / 60)
            local timeText = timeAgo < 1 and "now" or timeAgo .. "m ago"
            local levelText = instanceInfo and ("(" .. instanceInfo.level .. ")") or ""

            -- Get button from pool
            local button = GetPooledButton(scrollFrame)
            button:SetPoint("TOPLEFT", 5, -offset)

            -- Format button text with instance info
            local buttonText = string.format("%s %s\n%s - %s (%s)",
                group.activity,
                levelText,
                group.roles,
                group.leader,
                timeText
            )

            -- Create text manually instead of SetText
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
                    -- Find the group by matching stored data
                    local currentIndex = nil
                    for idx, g in ipairs(GroupFinderDB.groups) do
                        if g and g.leader == groupLeader and g.activity == groupActivity and g.timestamp == groupTimestamp then
                            currentIndex = idx
                            break
                        end
                    end
                    if currentIndex then
                        GroupFinder_EditGroupInNewUI(GroupFinderDB.groups[currentIndex], currentIndex)
                    else
                        local prefix = "|cffff0000[GroupFinder Error]|r "
                        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Group no longer exists")
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
                    -- Find the group by matching stored data
                    local currentIndex = nil
                    for idx, g in ipairs(GroupFinderDB.groups) do
                        if g and g.leader == groupLeader and g.activity == groupActivity and g.timestamp == groupTimestamp then
                            currentIndex = idx
                            break
                        end
                    end
                    if currentIndex then
                        GroupFinder_DeleteGroup(currentIndex)
                    else
                        local prefix = "|cffff0000[GroupFinder Error]|r "
                        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Group no longer exists")
                    end
                end)

                -- Set button click handler for own groups
                button:SetScript("OnClick", function()
                    local prefix = "|cff00ff00[GroupFinder]|r "
                    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Use Edit/Delete buttons to manage your group")
                end)
            else
                -- Set button click handler for other groups
                button:SetScript("OnClick", function()
                    local message = string.format("Hi! I'd like to join your group for %s. My roles: %s",
                        group.activity,
                        UnitClass("player")
                    )
                    SendChatMessage(message, "WHISPER", nil, group.leader)
                    local prefix = "|cff00ff00[GroupFinder]|r "
                    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Whispered " .. group.leader .. " about joining their group")
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

            table.insert(groupButtons, button)
            offset = offset + buttonHeight
            visibleGroups = visibleGroups + 1
        end
    end

    -- Update scroll frame content size
    scrollFrame:SetHeight(math.max(offset, 350))

    -- Update group count display
    if groupCountDisplay then
        local totalGroups = table.getn(GroupFinderDB.groups)
        if currentInstanceType == "All" then
            groupCountDisplay:SetText("Groups found: " .. totalGroups)
        else
            groupCountDisplay:SetText("Groups found: " ..
                visibleGroups .. "/" .. totalGroups .. " (filtered: " .. currentInstanceType .. ")")
        end
    end
end

-- Enhanced GroupFinder_CreateGroupWindow with new UI integration
function GroupFinder_CreateGroupWindow()
    -- Try to use new UI first
    if panelFrames.createView and InitializePanelFrames() then
        ShowCreateView()
        return
    end
    
    -- Fallback to legacy UI
    if not GroupFinderCreateFrame then
        return
    end
    
    GroupFinderCreateFrame:Show()
    UpdateInstanceDisplay()
end

-- Edit and Delete functions for own groups
function GroupFinder_EditGroup(group, index)
    if not group or not index then
        local prefix = "|cffff0000[GroupFinder Error]|r "
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Invalid group data for editing")
        return
    end

    if not GroupFinderDB.groups[index] then
        local prefix = "|cffff0000[GroupFinder Error]|r "
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Group no longer exists")
        return
    end

    local actualGroup = GroupFinderDB.groups[index]
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

    groupEditIndex = index
    GroupFinderCreateFrame:Show()
    -- Update display after frame is shown
    UpdateInstanceDisplay()
    
    local prefix = "|cff00ff00[GroupFinder]|r "
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Editing your group. Modify and click Create Group to update.")
end

-- New UI Edit function
function GroupFinder_EditGroupInNewUI(group, index)
    if not group or not index then
        local prefix = "|cffff0000[GroupFinder Error]|r "
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Invalid group data for editing")
        return
    end

    if not GroupFinderDB.groups[index] then
        local prefix = "|cffff0000[GroupFinder Error]|r "
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Group no longer exists")
        return
    end

    local actualGroup = GroupFinderDB.groups[index]
    if actualGroup.leader ~= UnitName("player") then
        local prefix = "|cffff0000[GroupFinder Error]|r "
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "You can only edit your own groups")
        return
    end

    -- Set the selected instance
    selectedInstance = actualGroup.activity or "The Deadmines"
    
    -- Switch to create view
    ShowCreateView()
    
    -- Parse roles and set checkboxes in new UI
    local roles = actualGroup.roles or ""
    local needTank = string.find(roles, "Tank") ~= nil
    local needHealer = string.find(roles, "Healer") ~= nil
    local needDPS = string.find(roles, "DPS") ~= nil
    
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

    groupEditIndex = index
    GroupFinder_UpdateCreateViewInstanceDisplay()
    
    local prefix = "|cff00ff00[GroupFinder]|r "
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Editing your group. Modify and click Create Group to update.")
end

function GroupFinder_DeleteGroup(index)
    if not index or not GroupFinderDB.groups[index] then
        local prefix = "|cffff0000[GroupFinder Error]|r "
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Group not found")
        return
    end

    local group = GroupFinderDB.groups[index]
    if group.leader == UnitName("player") then
        table.remove(GroupFinderDB.groups, index)
        GroupFinder_RefreshGroups()
        local prefix = "|cff00ff00[GroupFinder]|r "
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Your group has been deleted.")
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
        local group = GroupFinderDB.groups[groupEditIndex]
        if group and group.leader == UnitName("player") then
            group.activity = activity
            group.roles = roles
            group.description = description or ""
            group.timestamp = GetTimeStamp()

            groupEditIndex = nil -- Reset
            GroupFinder_RefreshGroups()
            
            -- Hide the appropriate frame
            if currentView == "create" then
                ShowListView()  -- Return to list view in new UI
            else
                GroupFinderCreateFrame:Hide()  -- Hide legacy frame
            end

            local prefix = "|cff00ff00[GroupFinder]|r "
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Group updated successfully")
            return
        else
            groupEditIndex = nil -- Reset if something went wrong
        end
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
    
    -- Clean the message to avoid invalid escape codes
    local cleanActivity = string.gsub(activity or "", "[\\\"]", "")
    local cleanRoles = string.gsub(roles or "", "[\\\"]", "")
    local cleanDescription = string.gsub(description or "", "[\\\"]", "")
    
    local message = "LFG|" .. cleanActivity .. "|" .. leader .. "|" .. cleanRoles .. "|" .. cleanDescription

    -- Send to channel
    if channelNumber then
        SendChatMessage(message, "CHANNEL", nil, channelNumber)
        PrintMessage("Group posted to LFG channel")

        -- Add to our own list immediately
        AddGroup(activity, leader, roles, description or "")
        GroupFinder_RefreshGroups()

        -- Hide the appropriate frame and return to list view
        if currentView == "create" then
            ShowListView()  -- Return to list view in new UI
        else
            GroupFinderCreateFrame:Hide()  -- Hide legacy frame
        end
    else
        PrintMessage("Not connected to LFG channel. Trying to reconnect...", true)
        JoinLFGChannel()
    end
end

function GroupFinder_ClearOwnGroups()
    if not isInitialized then
        PrintMessage("GroupFinder not initialized", true)
        return
    end

    local leader = UnitName("player")
    local removed = 0
    local newGroups = {}

    for _, group in ipairs(GroupFinderDB.groups) do
        if group.leader ~= leader then
            table.insert(newGroups, group)
        else
            removed = removed + 1
        end
    end

    GroupFinderDB.groups = newGroups

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
    if event == "CHAT_MSG_CHANNEL" then
        local message, sender, _, _, _, _, _, _, channelName = arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9

        -- Check for LFG messages from any LFG-related channel
        if (channelName == LFG_CHANNEL_NAME or channelName == "LFG" or channelName == "4") and string.sub(message, 1, 4) == "LFG|" then
            local parts = SplitString(message, "|")

            if table.getn(parts) >= 4 then
                local activity = parts[2]
                local leader = parts[3]
                local roles = parts[4]
                local description = parts[5] or ""

                -- Don't add our own groups twice
                if leader ~= UnitName("player") then
                    AddGroup(activity, leader, roles, description)
                    GroupFinder_RefreshGroups()
                end
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
    self:SetScript("OnEvent", GroupFinderFrame_OnEvent)

    -- Try to join LFG channel
    JoinLFGChannel()

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
        elseif mainCommand == "debug" then
            -- Debug command for testing new UI
            local prefix = "|cff00ffff[GroupFinder Debug]|r "
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Current view: " .. currentView)
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Current instance type: " .. currentInstanceType)
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Panel frames initialized: " .. tostring(panelFrames.listView ~= nil))
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Active buttons: " .. table.getn(framePool.activeButtons))
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Pooled buttons: " .. table.getn(framePool.groupButtons))
        elseif mainCommand == "help" then
            PrintMessage("Commands:")
            PrintMessage("/groupfinder or /gf - Toggle main window")
            PrintMessage("/gf clear - Remove your own groups")
            PrintMessage("/gf clearall - Remove all groups")
            PrintMessage("/gf cleanup - Clean up expired groups")
            PrintMessage("/gf debug - Show debug information")
            PrintMessage("/gf help - Show this help")
        else
            if GroupFinderFrame:IsShown() then
                GroupFinderFrame:Hide()
            else
                GroupFinderFrame:Show()
            end
        end
    end

    -- Setup update timer for cleanup
    local frame = CreateFrame("Frame")
    frame:SetScript("OnUpdate", function()
        local elapsed = arg1 or 0
        updateTimer = updateTimer + elapsed
        if updateTimer >= CLEANUP_INTERVAL then
            updateTimer = 0
            CleanupExpiredGroups()

            -- Try to reconnect to channel if disconnected
            if not channelNumber or not FindLFGChannel() then
                JoinLFGChannel()
            end
        end
    end)

    PrintMessage("Loaded! Use /groupfinder or /gf to open. Type /gf help for commands.")
    PrintMessage("New dynamic panel UI system enabled with memory optimization.")
end
