-- GroupFinder Addon for WoW 1.12 (Vanilla)
-- Enhanced version with instance selection, filtering, and improved compatibility

-- Local variables
local LFG_CHANNEL_NAME = "LookingForGroup"
local groupButtons = {}
local channelNumber = 4      -- Default to channel 4 (LFG)
local updateTimer = 0
local CLEANUP_INTERVAL = 300 -- 5 minutes
local isInitialized = false
-- New: State for left panel selection and right panel mode
local leftPanelSelection = "Dungeon" -- "Dungeon", "Raid", "PvP", "Other"
local rightPanelMode = "list"        -- "list" or "create"
local currentFilter = "All"
local selectedInstance = "The Deadmines"
local groupEditIndex = nil

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

    -- Other activities
    ["PvP"] = { level = "Any", type = "PvP", zone = "Various" },
    ["Questing"] = { level = "Any", type = "Questing", zone = "Various" },
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

-- Debug function to list all available UI elements
local function DebugListFrameElements()
    local prefix = "|cff00ffff[GroupFinder Debug]|r "
    
    if not GroupFinderCreateFrame then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "GroupFinderCreateFrame is nil!")
        return
    end
    
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "=== DEBUGGING FRAME ELEMENTS ===")
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "GroupFinderCreateFrame exists: " .. tostring(GroupFinderCreateFrame ~= nil))
    
    -- List all children
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "--- CHILDREN ---")
    local children = { GroupFinderCreateFrame:GetChildren() }
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Found " .. table.getn(children) .. " children:")
    for i, child in ipairs(children) do
        if child then
            local name = child:GetName() or "unnamed"
            local objType = child:GetObjectType() or "unknown"
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Child " .. i .. ": " .. name .. " (" .. objType .. ")")
        end
    end
    
    -- List all regions
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "--- REGIONS ---")
    local regions = { GroupFinderCreateFrame:GetRegions() }
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Found " .. table.getn(regions) .. " regions:")
    for i, region in ipairs(regions) do
        if region then
            local name = region:GetName() or "unnamed"
            local objType = region:GetObjectType() or "unknown"
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Region " .. i .. ": " .. name .. " (" .. objType .. ")")
            if objType == "FontString" then
                local text = region:GetText() or "no text"
                DEFAULT_CHAT_FRAME:AddMessage(prefix .. "  Text: '" .. text .. "'")
            end
        end
    end
    
    -- Test specific global names
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "--- GLOBAL NAME TESTS ---")
    local testNames = {
        "GroupFinderCreateFrameInstanceDisplay",
        "GroupFinderCreateFrame_InstanceDisplay",
        "GroupFinderCreateFrameTitle",
        "GroupFinderCreateFrameInstanceButton"
    }
    
    for _, name in ipairs(testNames) do
        local element = getglobal and getglobal(name) or nil
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. name .. ": " .. tostring(element ~= nil))
    end
    
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "=== END DEBUG ===")
end

-- Enhanced UpdateInstanceDisplay with robust element validation and retry mechanism
local function UpdateInstanceDisplay(retryCount)
    local prefix = "|cff00ffff[GroupFinder Debug]|r "
    retryCount = retryCount or 0
    local maxRetries = 3

    -- Check if the right panel create panel exists and is visible
    if not GroupFinderFrameRightPanelCreatePanel or not GroupFinderFrameRightPanelCreatePanel:IsShown() then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "UpdateInstanceDisplay() aborted: CreatePanel not visible or missing.")
        return false
    end

    -- Debug: Log the update attempt
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "UpdateInstanceDisplay() called (attempt " .. (retryCount + 1) .. ") - selectedInstance: " .. (selectedInstance or "nil"))
    
    -- Validate selectedInstance
    if not selectedInstance or selectedInstance == "" then
        selectedInstance = "The Deadmines"
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "No selectedInstance, defaulting to: " .. selectedInstance)
    end
    
    -- Try multiple methods to find the UI element (WoW 1.12 compatibility)
    local instanceDisplayElement = nil
    
    -- Method 1: Direct reference
    if GroupFinderFrameRightPanelCreatePanelInstanceDisplay then
        instanceDisplayElement = GroupFinderFrameRightPanelCreatePanelInstanceDisplay
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Found element via direct reference")
    -- Method 2: getglobal fallback
    elseif getglobal and getglobal("GroupFinderFrameRightPanelCreatePanelInstanceDisplay") then
        instanceDisplayElement = getglobal("GroupFinderFrameRightPanelCreatePanelInstanceDisplay")
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Found element via getglobal")
    -- Method 3: Manual traversal through frame hierarchy
    elseif GroupFinderFrameRightPanelCreatePanel then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Searching for element via frame traversal...")
        -- Check if we can find it as a child of GroupFinderFrameRightPanelCreatePanel
        local children = { GroupFinderFrameRightPanelCreatePanel:GetChildren() }
        for i, child in ipairs(children) do
            if child and child:GetObjectType() == "FontString" then
                local childName = child:GetName()
                if childName and string.find(childName, "InstanceDisplay") then
                    instanceDisplayElement = child
                    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Found element via traversal: " .. childName)
                    break
                end
            end
        end
        
        -- Alternative: try to find by regions
        if not instanceDisplayElement then
            local regions = { GroupFinderFrameRightPanelCreatePanel:GetRegions() }
            for i, region in ipairs(regions) do
                if region and region:GetObjectType() == "FontString" then
                    local regionName = region:GetName()
                    if regionName and string.find(regionName, "InstanceDisplay") then
                        instanceDisplayElement = region
                        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Found element via regions: " .. regionName)
                        break
                    end
                end
            end
        end
        
        -- Method 4: Find by text content (looking for default text)
        if not instanceDisplayElement then
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Searching by text content...")
            local regions = { GroupFinderFrameRightPanelCreatePanel:GetRegions() }
            for i, region in ipairs(regions) do
                if region and region:GetObjectType() == "FontString" then
                    local text = region:GetText()
                    if text and (string.find(text, "Deadmines") or string.find(text, "Dungeon") or string.find(text, "17-26")) then
                        instanceDisplayElement = region
                        local regionName = region:GetName() or "unnamed"
                        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Found element by text content: " .. regionName .. " (text: '" .. text .. "')")
                        break
                    end
                end
            end
        end
    end
    
    -- Check if we found the element
    if not instanceDisplayElement then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "ERROR: Could not find InstanceDisplay element through any method!")
        
        -- Run debug listing on first failure
        if retryCount == 0 then
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Running comprehensive debug listing...")
            DebugListFrameElements()
        end
        
        -- Method 5: Create element programmatically if it doesn't exist and we have the frame
        if GroupFinderFrameRightPanelCreatePanel and retryCount == 1 then
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Attempting to create element programmatically...")
            
            local success, newElement = pcall(function()
                local fontString = GroupFinderFrameRightPanelCreatePanel:CreateFontString("GroupFinderFrameRightPanelCreatePanelInstanceDisplay", "OVERLAY", "GameFontHighlight")
                fontString:SetPoint("TOPLEFT", GroupFinderFrameRightPanelCreatePanel, "TOPLEFT", 25, -50)
                fontString:SetText("The Deadmines (17-26 - Dungeon)")
                return fontString
            end)
            
            if success and newElement then
                instanceDisplayElement = newElement
                DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Successfully created element programmatically")
                -- Set global reference for future use
                GroupFinderFrameRightPanelCreatePanelInstanceDisplay = newElement
            else
                DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Failed to create element programmatically")
            end
        end
        
        -- If still no element, retry or give up
        if not instanceDisplayElement then
            if retryCount < maxRetries then
                DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Retrying in 0.1 seconds...")
                local retryFrame = CreateFrame("Frame")
                local retryTimer = 0
                retryFrame:SetScript("OnUpdate", function()
                    retryTimer = retryTimer + arg1
                    if retryTimer >= 0.1 then
                        retryFrame:SetScript("OnUpdate", nil)
                        UpdateInstanceDisplay(retryCount + 1)
                    end
                end)
                return false
            else
                DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Max retries reached, element not available")
                return false
            end
        end
    end
    
    -- Check if element is properly accessible and the frame is shown
    local success, error = pcall(function()
        -- Verify the parent frame is shown
        if not GroupFinderFrameRightPanelCreatePanel:IsShown() then
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Parent frame not shown!")
            return
        end
        
        -- Test element accessibility using the found element
        local testText = instanceDisplayElement:GetText()
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Current display text: " .. (testText or "nil"))
        
        -- Verify element is actually ready for updates
        local width = instanceDisplayElement:GetWidth()
        if width == 0 then
            error("Element not fully initialized (width=0)")
        end
    end)
    
    if not success then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "ERROR: Cannot access InstanceDisplay element: " .. (error or "unknown"))
        
        -- Retry mechanism for element accessibility
        if retryCount < maxRetries then
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Element exists but not accessible, retrying...")
            local retryFrame = CreateFrame("Frame")
            local retryTimer = 0
            retryFrame:SetScript("OnUpdate", function()
                retryTimer = retryTimer + arg1
                if retryTimer >= 0.1 then
                    retryFrame:SetScript("OnUpdate", nil)
                    UpdateInstanceDisplay(retryCount + 1)
                end
            end)
            return false
        else
            return false
        end
    end
    
    -- Prepare display text
    local instanceInfo = INSTANCES[selectedInstance]
    local displayText
    if instanceInfo then
        displayText = selectedInstance .. " (" .. instanceInfo.level .. " - " .. instanceInfo.type .. ")"
    else
        displayText = selectedInstance or "The Deadmines"
    end
    
    -- Attempt to update the display using the found element
    success, error = pcall(function()
        instanceDisplayElement:SetText(displayText)
        -- Force a refresh of the element
        instanceDisplayElement:Show()
    end)
    
    if success then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Successfully updated display to: " .. displayText)
        return true
    else
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "ERROR: Failed to set text: " .. (error or "unknown"))
        
        -- Final retry for text setting
        if retryCount < maxRetries then
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Retrying text update...")
            local retryFrame = CreateFrame("Frame")
            local retryTimer = 0
            retryFrame:SetScript("OnUpdate", function()
                retryTimer = retryTimer + arg1
                if retryTimer >= 0.1 then
                    retryFrame:SetScript("OnUpdate", nil)
                    UpdateInstanceDisplay(retryCount + 1)
                end
            end)
            return false
        else
            return false
        end
    end
end

-- Simple cycle function for instance selection with enhanced UI update
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
    
    -- Use enhanced UpdateInstanceDisplay with debug info
    local prefix = "|cff00ffff[GroupFinder Debug]|r "
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "CycleInstance: Selected " .. selectedInstance)
    
    local updateSuccess = UpdateInstanceDisplay()
    if not updateSuccess then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "CycleInstance: UI update failed, will retry on next frame show")
    end
    
    local instanceInfo = INSTANCES[selectedInstance]
    local userPrefix = "|cff00ff00[GroupFinder]|r "
    if instanceInfo then
        DEFAULT_CHAT_FRAME:AddMessage(userPrefix .. "Selected: " .. selectedInstance .. " (" .. instanceInfo.level .. " - " .. instanceInfo.type .. ")")
    else
        DEFAULT_CHAT_FRAME:AddMessage(userPrefix .. "Selected: " .. selectedInstance)
    end
end

function GroupFinder_ShowInstanceDropdown()
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
    
    -- Get all instances sorted by level
    local instances = GetInstanceList()
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
                local prefix = "|cff00ffff[GroupFinder Debug]|r "
                local clickedInstance = button.instanceName
                
                -- Debug logging with nil safety
                local instanceName = clickedInstance or "unknown"
                DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Instance selection clicked: " .. instanceName)
                
                if clickedInstance then
                    selectedInstance = clickedInstance
                    local updateSuccess = UpdateInstanceDisplay()
                    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Instance selection UpdateInstanceDisplay() returned: " .. tostring(updateSuccess))
                else
                    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "ERROR: Instance is nil!")
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
    -- Use leftPanelSelection for filtering
    if leftPanelSelection == "All" then
        return true
    end

    local instanceInfo = INSTANCES[group.activity]
    if instanceInfo then
        return instanceInfo.type == leftPanelSelection
    end

    return leftPanelSelection == "Other"
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

-- Filter functions
function GroupFinder_SetFilter(filterType)
    -- Deprecated: Use SetLeftPanelSelection instead
    leftPanelSelection = filterType
    rightPanelMode = "list"
    GroupFinder_RefreshGroups()
    PrintMessage("Filter set to: " .. filterType)
end

-- New: Set left panel selection and update right panel
function GroupFinder_SetLeftPanelSelection(selection)
    local debugPrefix = "|cffffff00[GF Debug]|r "
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "GroupFinder_SetLeftPanelSelection called")
    leftPanelSelection = selection or "Dungeon"
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "leftPanelSelection: " .. tostring(leftPanelSelection))
    rightPanelMode = "list"
    -- Update the right panel type display
    local typeDisplay = GroupFinderFrameRightPanelCurrentTypeDisplay
    if not typeDisplay and getglobal then
        typeDisplay = getglobal("GroupFinderFrameRightPanelCurrentTypeDisplay")
    end
    if typeDisplay and typeDisplay.SetText then
        typeDisplay:SetText("Type: " .. leftPanelSelection)
    end

    -- Update the Add Group button text robustly
    local function setAddButtonText(retryCount)
        retryCount = retryCount or 0
        local maxRetries = 3
        local addButton = GroupFinderFrameRightPanelCreateButton
        if not addButton and getglobal then
            addButton = getglobal("GroupFinderFrameRightPanelCreateButton")
        end

        -- Explicit debug logging for button state
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[GroupFinder Debug]|r Attempting to set button text. Button exists: " .. tostring(addButton ~= nil))
        if addButton then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[GroupFinder Debug]|r Button type: " .. tostring(addButton:GetObjectType()))
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[GroupFinder Debug]|r Button visible: " .. tostring(addButton:IsVisible()))
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[GroupFinder Debug]|r Button enabled: " .. tostring(addButton:IsEnabled()))
        end
        local desiredText = "Add " .. tostring(leftPanelSelection) .. " Group"
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[GroupFinder Debug]|r Desired button text: '" .. (desiredText or "nil") .. "'")

        if addButton and addButton.SetText then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[GroupFinder Debug]|r Calling SetText on button")
            addButton:SetText(desiredText)
            if addButton and addButton.GetFontString and addButton:GetFontString() then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[GroupFinder Debug]|r Button FontString text after SetText: '" .. (addButton:GetFontString():GetText() or "nil") .. "'")
            end
        elseif retryCount < maxRetries then
            local retryFrame = CreateFrame("Frame")
            local retryTimer = 0
            retryFrame:SetScript("OnUpdate", function()
                retryTimer = retryTimer + arg1
                if retryTimer >= 0.1 then
                    retryFrame:SetScript("OnUpdate", nil)
                    setAddButtonText(retryCount + 1)
                end
            end)
        else
            local prefix = "|cffff0000[GroupFinder Error]|r "
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Add Group button not found after retries")
        end
    end
    setAddButtonText()

    GroupFinder_RefreshGroups()
    if GroupFinder_UpdateRightPanel then
        GroupFinder_UpdateRightPanel()
    end
end

-- UI Management
function GroupFinder_RefreshGroups()
    if not isInitialized then
        return
    end

    -- Only show group list if rightPanelMode is "list"
    if rightPanelMode ~= "list" then
        -- Hide all group buttons if not in list mode
        for _, button in ipairs(groupButtons) do
            button:Hide()
            button:SetParent(nil)
        end
        groupButtons = {}
        if GroupFinderFrameGroupCount then
            GroupFinderFrameGroupCount:SetText("")
        end
        return
    end

    -- Clear existing buttons
    for _, button in ipairs(groupButtons) do
        button:Hide()
        button:SetParent(nil)
    end
    groupButtons = {}

    -- Get scroll frame
    local scrollFrame = GroupFinderFrameRightPanelListPanelScrollFrame
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
            -- [Unchanged: group button creation logic]
            -- ... (same as before)
            local instanceInfo = INSTANCES[group.activity]
            local timeAgo = math.floor((GetTimeStamp() - group.timestamp) / 60)
            local timeText = timeAgo < 1 and "now" or timeAgo .. "m ago"
            local levelText = instanceInfo and ("(" .. instanceInfo.level .. ")") or ""

            local button = CreateFrame("Button", "GroupFinderButton" .. i, scrollFrame)
            button:SetWidth(340)
            button:SetHeight(30)
            button:SetPoint("TOPLEFT", 5, -offset)

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

            local buttonText = string.format("%s %s\n%s - %s (%s)",
                group.activity,
                levelText,
                group.roles,
                group.leader,
                timeText
            )

            local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetPoint("LEFT", button, "LEFT", 5, 0)
            text:SetText(buttonText)
            text:SetJustifyH("LEFT")

            if group.leader == UnitName("player") then
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

                local groupLeader = group.leader
                local groupActivity = group.activity
                local groupTimestamp = group.timestamp
                local groupRoles = group.roles
                local groupDescription = group.description

                editBtn:SetScript("OnClick", function()
                    local currentIndex = nil
                    for idx, g in ipairs(GroupFinderDB.groups) do
                        if g and g.leader == groupLeader and g.activity == groupActivity and g.timestamp == groupTimestamp then
                            currentIndex = idx
                            break
                        end
                    end
                    if currentIndex then
                        GroupFinder_EditGroup(GroupFinderDB.groups[currentIndex], currentIndex)
                    else
                        local prefix = "|cffff0000[GroupFinder Error]|r "
                        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Group no longer exists")
                    end
                end)

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

                button:SetScript("OnClick", function()
                    local prefix = "|cff00ff00[GroupFinder]|r "
                    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Use Edit/Delete buttons to manage your group")
                end)
            else
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

            button:SetScript("OnEnter", function()
                button:SetBackdropColor(0.4, 0.4, 0.4, 0.9)
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

    scrollFrame:SetHeight(math.max(offset, 400))

    if GroupFinderFrameGroupCount then
        local totalGroups = table.getn(GroupFinderDB.groups)
        if leftPanelSelection == "All" then
            GroupFinderFrameGroupCount:SetText("Groups found: " .. totalGroups)
        else
            GroupFinderFrameGroupCount:SetText("Groups found: " ..
                visibleGroups .. "/" .. totalGroups .. " (filtered: " .. leftPanelSelection .. ")")
        end
    end
end

-- New: Update right panel content based on mode
function GroupFinder_UpdateRightPanel()
    -- List of group creation UI elements in GroupFinderFrameRightPanel
    local creationElements = {
        GroupFinderFrameRightPanelCreateTitle,
        GroupFinderFrameRightPanelInstanceDisplay,
        GroupFinderFrameRightPanelInstanceButton,
        GroupFinderFrameRightPanelTankCheck,
        GroupFinderFrameRightPanelHealerCheck,
        GroupFinderFrameRightPanelDPSCheck,
        GroupFinderFrameRightPanelDescription,
        GroupFinderFrameRightPanelCreateButton,
        GroupFinderFrameRightPanelCancelButton
    }

    if rightPanelMode == "create" then
        if GroupFinderFrameRightPanelListPanel then GroupFinderFrameRightPanelListPanel:Hide() end
        if GroupFinderFrameRightPanelCreatePanel then GroupFinderFrameRightPanelCreatePanel:Show() end
    else
        if GroupFinderFrameRightPanelListPanel then GroupFinderFrameRightPanelListPanel:Show() end
        if GroupFinderFrameRightPanelCreatePanel then GroupFinderFrameRightPanelCreatePanel:Hide() end
    end
end

-- New: Context-sensitive Add Group button handler
function GroupFinder_OnAddGroupButton()
    local debugPrefix = "|cffffff00[GF Debug]|r "
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "GroupFinder_OnAddGroupButton called")
    DEFAULT_CHAT_FRAME:AddMessage(debugPrefix .. "leftPanelSelection: " .. tostring(leftPanelSelection))
    -- Update the Add Group button text in case this is called directly
    -- Update the Add Group button text robustly
    local function setAddButtonText(retryCount)
        retryCount = retryCount or 0
        local maxRetries = 3
        local addButton = GroupFinderFrameRightPanelCreateButton
        if not addButton and getglobal then
            addButton = getglobal("GroupFinderFrameRightPanelCreateButton")
        end

        -- Explicit debug logging for button state
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[GroupFinder Debug]|r Attempting to set button text. Button exists: " .. tostring(addButton ~= nil))
        if addButton then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[GroupFinder Debug]|r Button type: " .. tostring(addButton:GetObjectType()))
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[GroupFinder Debug]|r Button visible: " .. tostring(addButton:IsVisible()))
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[GroupFinder Debug]|r Button enabled: " .. tostring(addButton:IsEnabled()))
        end
        local desiredText = "Add " .. tostring(leftPanelSelection) .. " Group"
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[GroupFinder Debug]|r Desired button text: '" .. (desiredText or "nil") .. "'")

        if addButton and addButton.SetText then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[GroupFinder Debug]|r Calling SetText on button")
            addButton:SetText(desiredText)
            if addButton and addButton.GetFontString and addButton:GetFontString() then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[GroupFinder Debug]|r Button FontString text after SetText: '" .. (addButton:GetFontString():GetText() or "nil") .. "'")
            end
        elseif retryCount < maxRetries then
            local retryFrame = CreateFrame("Frame")
            local retryTimer = 0
            retryFrame:SetScript("OnUpdate", function()
                retryTimer = retryTimer + arg1
                if retryTimer >= 0.1 then
                    retryFrame:SetScript("OnUpdate", nil)
                    setAddButtonText(retryCount + 1)
                end
            end)
        else
            local prefix = "|cffff0000[GroupFinder Error]|r "
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Add Group button not found after retries")
        end
    end
    setAddButtonText()

    rightPanelMode = "create"
    -- Set default instance for creation form based on leftPanelSelection
    local found = false
    for name, info in pairs(INSTANCES) do
        if info.type == leftPanelSelection then
            selectedInstance = name
            found = true
            break
        end
    end
    if not found then
        selectedInstance = "The Deadmines"
    end
    if GroupFinder_UpdateRightPanel then GroupFinder_UpdateRightPanel() end
    if UpdateInstanceDisplay then UpdateInstanceDisplay() end
end

-- New: Filtered instance list for creation form
function GroupFinder_GetFilteredInstanceList()
    local list = {}
    if leftPanelSelection == "All" then
        for name, _ in pairs(INSTANCES) do
            table.insert(list, name)
        end
    elseif leftPanelSelection == "Other" then
        for name, info in pairs(INSTANCES) do
            if info.type == "Other" then
                table.insert(list, name)
            end
        end
    else
        for name, info in pairs(INSTANCES) do
            if info.type == leftPanelSelection then
                table.insert(list, name)
            end
        end
    end
    table.sort(list, function(a, b) return a < b end)
    return list
end

-- Enhanced GroupFinder_CreateGroupWindow with proper timing and delayed UI updates
function GroupFinder_CreateGroupWindow()
    -- Context-sensitive: open creation form for current leftPanelSelection
    rightPanelMode = "create"

    local prefix = "|cff00ffff[GroupFinder Debug]|r "
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "GroupFinder_CreateGroupWindow() called (context: " .. leftPanelSelection .. ")")

    -- Set default instance for creation form based on leftPanelSelection
    local found = false
    for name, info in pairs(INSTANCES) do
        if info.type == leftPanelSelection then
            selectedInstance = name
            found = true
            break
        end
    end
    if not found then
        selectedInstance = "The Deadmines"
    end

    -- Update right panel and then update instance display
    if GroupFinder_UpdateRightPanel then GroupFinder_UpdateRightPanel() end
    if UpdateInstanceDisplay then UpdateInstanceDisplay() end
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
    rightPanelMode = "create"
    
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
    if GroupFinder_UpdateRightPanel then GroupFinder_UpdateRightPanel() end
    if UpdateInstanceDisplay then UpdateInstanceDisplay() end
    
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
    local descriptionRaw = GroupFinderCreateFrameDescription:GetText()

    -- Build roles string from checkboxes
    local rolesNeeded = {}
    if GroupFinderCreateFrameTankCheck and GroupFinderCreateFrameTankCheck:GetChecked() then
        table.insert(rolesNeeded, "Tank")
    end
    if GroupFinderCreateFrameHealerCheck and GroupFinderCreateFrameHealerCheck:GetChecked() then
        table.insert(rolesNeeded, "Healer")
    end
    if GroupFinderCreateFrameDPSCheck and GroupFinderCreateFrameDPSCheck:GetChecked() then
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
    if string.find(descriptionRaw, "e.g.,") then
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
            GroupFinderCreateFrame:Hide()

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

        GroupFinderCreateFrame:Hide()
    else
        PrintMessage("Not connected to LFG channel. Trying to reconnect...", true)
        JoinLFGChannel()
    end
end

-- After successful group creation, return to updated group list for selected type
local _original_GroupFinder_CreateGroup = GroupFinder_CreateGroup
function GroupFinder_CreateGroup()
    _original_GroupFinder_CreateGroup()
    -- After creation, switch back to list mode and refresh
    rightPanelMode = "list"
    if GroupFinder_UpdateRightPanel then GroupFinder_UpdateRightPanel() end
    GroupFinder_RefreshGroups()
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
        local message = arg1
        local sender = arg2
        local channelName = arg9

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

-- Main frame initialization
function GroupFinder_OnLoad(self)
    -- Early initialization attempt
    InitializeDB()

    -- Debug: Confirm Add Group button existence after load
    if GroupFinderFrameRightPanelCreateButton then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[GroupFinder Debug]|r OnLoad: GroupFinderFrameRightPanelCreateButton exists. Type: " .. tostring(GroupFinderFrameRightPanelCreateButton:GetObjectType()))
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[GroupFinder Debug]|r OnLoad: GroupFinderFrameRightPanelCreateButton is nil")
    end

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
        elseif mainCommand == "help" then
            PrintMessage("Commands:")
            PrintMessage("/groupfinder or /gf - Toggle main window")
            PrintMessage("/gf clear - Remove your own groups")
            PrintMessage("/gf clearall - Remove all groups")
            PrintMessage("/gf cleanup - Clean up expired groups")
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
        updateTimer = updateTimer + arg1
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
end
