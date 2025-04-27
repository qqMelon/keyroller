-- KeyRoller.lua
local addonName, addon = ...
local frame = CreateFrame("Frame")

local playerKeys = {}
local isRollInProgress = false
local rollResults = {}
local rollHistory = {}
local minKeyLevel = 0
local maxKeyLevel = 99
local text = nil
local versionList = {}
local versTxt = ""
local isVersFont = false
local versFont = nil

frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("PARTY_LEADER_CHANGED")

local ADDON_PREFIX = "KR"
C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)

local function GetPlayerMythicKey()
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            if itemInfo then
                local itemID = itemInfo.itemID
                if itemID == 180653 then -- Keystone ID
                    local itemLink = itemInfo.hyperlink
                    if itemLink then
                        local keyLevel = C_MythicPlus.GetOwnedKeystoneLevel()
                        local dungeonID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
                        if keyLevel and dungeonID then
                            local dungeonName = C_ChallengeMode.GetMapUIInfo(dungeonID)
                            if dungeonName and keyLevel > 0 then
                                return dungeonName, keyLevel
                            end
                        end
                    end
                end
            end
        end
    end
    return nil, nil
end

local function GetGroupType()
    return IsInRaid() and "RAID" or "PARTY"
end

local function BroadcastKey()
    local dungeonName, level = GetPlayerMythicKey()
    if dungeonName and level then
        local message = string.format("%s:%d", dungeonName, level)
        if IsInGroup() then
            C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "KEY:" .. message, GetGroupType())
        end
    end
end

local function RequestKeys()
    if not IsInGroup() then
        print("You have to be in a group to ask for the keys")
        return
    end

    playerKeys = {}
    BroadcastKey() -- Send key
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "REQUEST_KEY", GetGroupType()) -- Call Keys
end

local function GetColorForLevel(level)
    if level >= 16 then
        return "|cffff8000" -- orange
    elseif level >= 11 then
        return "|cffa335ee" -- purple
    elseif level >= 4 then
        return "|cff0070dd" -- blue
    else
        return "|cff1eff00" -- green
    end
end

local function StartRoll()
    if not IsInGroup() then
        print("You have to be in a band to launch a roll")
        return
    end

    isRollInProgress = true
    rollResults = {}
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "ROLL", GetGroupType())
    local timestamp = date("%H:%M:%S")
    table.insert(rollHistory, {time = timestamp, results = {}})
end


local function FirePromotionEvent(winner)
	C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "PROMOTE_LEADER", GetGroupType())
	SendChatMessage(string.format("=== THE NEW LEADER OF THE GROUP IS %s ===", winner), GetGroupType())
	return
end

local function GetPlayerAddonVersion ()

	if IsInGroup() then
		C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "ADDON_VERSION", GetGroupType())
	else 
		C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "ADDON_VERSION", "WHISPER", UnitName("player"))
	end
		
	return
end

local function CreateMythicGroup()
    if GetNumGroupMembers() < 5 then
        if UnitIsGroupLeader(UnitName("player")) then
            PVEFrame_ShowFrame("GroupFinderFrame")
            GroupFinderFrameGroupButton3:Click()
            LFGListCategorySelection_SelectCategory(LFGListFrame.CategorySelection,2,0)
            LFGListCategorySelectionStartGroupButton_OnClick(LFGListFrame.CategorySelection.StartGroupButton)
			SendChatMessage(string.format("=== THE KEY IS GOING TO BE LISTED ==="),GetGroupType())

        end
    end
    return
end

local function DisplayPopupCreation(winner)
	
    if GetNumGroupMembers() < 5 then
        if UnitIsGroupLeader(UnitName("player")) then
			StaticPopupDialogs["CREATION_CONFIRMATION"] = {
			text = "Do you want to list your key ?",
			button1 = "Yes",
			button2 = "No",
			OnAccept = function()
				CreateMythicGroup()
			end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
			}
    
			StaticPopup_Show ("CREATION_CONFIRMATION")
        end
    end
    return
end

local function DisplayPopUpLeadTransfer(winner)
    if GetNumGroupMembers() < 5 then
        if UnitIsGroupLeader(UnitName("player")) then
            StaticPopupDialogs["LEADPROMOTE_TRANSFER"] = {
            text = "TRANSFERING GROUP LEADERSHIP",
            OnCancel = function()
				FirePromotionEvent(winner)
            end,
			sound = levelup2,
            timeout = 2,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
            }
			
            StaticPopup_Show ("LEADPROMOTE_TRANSFER")
        end
    end
    return
end

local function DisplayPopUpLeadPromote(winner)
    if GetNumGroupMembers() < 5 then
        if UnitIsGroupLeader(UnitName("player")) then
            StaticPopupDialogs["LEADPROMOTE_CONFIRMATION"] = {
            text = "Do you want to promote the winner of the roll and list the group ?",
            button1 = "Yes",
            button2 = "No",
            OnAccept = function()
				PromoteToLeader(winner)
				DisplayPopUpLeadTransfer(winner)
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
            }
    
            StaticPopup_Show ("LEADPROMOTE_CONFIRMATION")
        end
    end
    return
end

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnShow", function()
    if IsInGroup() then
        SendOwnKey()
    end
end)

f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
    if event == "CHAT_MSG_ADDON" and prefix == "KR" then
        -- Decode and save received key
        local name, level, dungeon = strsplit(":", message)
        name, level, dungeon = name or "?", tonumber(level), dungeon or "?"
        if name and level and dungeon then
            keyList[name] = { level = level, dungeon = dungeon }
            if mainFrame and mainFrame.keyList then
                UpdateKeyList(mainFrame.keyList.content)
            end
        end
    end
end)

f:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
    if event == "CHAT_MSG_ADDON" and prefix == "KR" and string.find(message, "VERSION_PAYLOAD:") then
		--if UnitIsGroupLeader(UnitName("player")) then
			local _,_, player, version = string.find(message, "VERSION_PAYLOAD:(%a+):(%A+)")
			--table.insert.insert(versionList,{player, version})
			versionList[player] = version
		--end
		
    end
end)

local function CreateVersionFrame ()
	--retrieveing data
	GetPlayerAddonVersion ()
	--creation of the version frame
    local f = CreateFrame("Frame", "VersFrame", UIParent, "BackdropTemplate")
	    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 1, top = 3, bottom = 3 }
    })
    f:SetSize(180, 80)
	f:SetPoint("BOTTOMRIGHT", "KRFrame", 178,0)
	    f:SetBackdropColor(0, 0, 0, 0.8)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()

	return f
end

local function DisplayVersionFrame()
    if not isVersFont then
        versFont = VersFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        versFont:SetPoint("TOPLEFT", 5, -5)
        versFont:SetJustifyH("LEFT")
        versFont:SetJustifyV("TOP")

        local text = ""
        for p, v in pairs(versionList) do
            text = text .. "v. " .. v .. "   " .. p .. "\n"
        end
        versTxt = text

        isVersFont = true
    end

    if VersFrame then
        if VersFrame:IsShown() then
            VersFrame:Hide()
            versFont:SetText("")
        else
            versFont:SetText(versTxt)
            VersFrame:Show()
        end
    end
end

local function findGroupLeader()
	for i = 1, GetNumGroupMembers() do
		local name = GetRaidRosterInfo(i)
		if UnitIsGroupLeader(UnitName(name)) then
			return name
		end
	end
end

local function UpdateKeyList(content)
    if not content then return end

    -- Clean children
    for _, child in ipairs({content:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local totalWidth = content:GetWidth()
    local nameWidth = totalWidth * 0.33
    local levelWidth = totalWidth * 0.17
    local dungeonWidth = totalWidth * 0.5

    local rowHeight = 24
    local spacing = 5
    local rowIndex = 0

    -- Headers
    local header = CreateFrame("Frame", nil, content)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(rowHeight)

    local h1 = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h1:SetPoint("LEFT", 5, 0)
    h1:SetText("Player")

    local h2 = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h2:SetPoint("CENTER", header, "CENTER", 0, 0)
    h2:SetText("Level")

    local h3 = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h3:SetPoint("RIGHT", -5, 0)
    h3:SetText("Dongeon")

    for player, key in pairs(playerKeys) do
        if key.level >= minKeyLevel and key.level <= maxKeyLevel then
            rowIndex = rowIndex + 1
            local row = CreateFrame("Frame", nil, content)
            row:SetSize(content:GetWidth(), rowHeight)
            row:SetHeight(rowHeight)
            row:SetPoint("TOPLEFT", 0, -(rowHeight + spacing) * rowIndex)


            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.6)

            row:SetScript("OnEnter", function()
                row.bg:SetColorTexture(0.2, 0.2, 0.2, 0.9)
            end)
            row:SetScript("OnLeave", function()
                row.bg:SetColorTexture(0.1, 0.1, 0.1, 0.6)
            end)

            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nameText:SetPoint("LEFT", 5, 0)
            nameText:SetWidth(nameWidth)
            nameText:SetJustifyH("LEFT")
            nameText:SetText(string.gsub(player, "-.*", ""))

            local levelText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            local color = GetColorForLevel(key.level)
            levelText:SetPoint("CENTER", row, "CENTER", 0, 0)
            levelText:SetText(color .. "+" .. key.level .. "|r")
            levelText:SetJustifyH("CENTER")

            local dungeonText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            dungeonText:SetPoint("RIGHT", -5, 0)
            dungeonText:SetText(key.dungeon or "?")
            dungeonText:SetJustifyH("RIGHT")
        end
    end

    content:SetHeight((rowHeight + spacing) * (rowIndex + 2))
end

local function CreateMainFrame()
    local f = CreateFrame("Frame", "KRFrame", UIParent, "BackdropTemplate")
    f:SetSize(490, 350) -- width - height
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 1, top = 3, bottom = 3 }
    })
    f:SetBackdropColor(0, 0, 0, 0.8)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", 0, -15)
    f.title:SetFont("Fonts\\FRIZQT__.TTF", 21, "OUTLINE")
    f.title:SetTextColor(0.8, 0.8, 1)
    f.title:SetText("KEY ROLLER")

    f.rollButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.rollButton:RegisterEvent ("PARTY_LEADER_CHANGED")
    f.rollButton:SetPoint("BOTTOM", 5, 5)
    f.rollButton:SetSize(120, 25)
    f.rollButton:SetText("Roll the Keys !")
    f.rollButton:SetScript(
        "OnClick",
        function()
            StartRoll()
        end
    )
	f.rollButton:SetScript(
		"OnEvent",
		function()
			if UnitIsGroupLeader(UnitName("player")) then
				f.rollButton:Enable()
			else
				f.rollButton:Disable()
			end
		end
	)
	
	if UnitIsGroupLeader(UnitName("player")) then
		f.rollButton:Enable()
	else
		f.rollButton:Disable()
	end

    f.closeButton = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeButton:SetPoint("TOPRIGHT", -5, -5)
    f.closeButton:SetSize(24, 24)
	f.closeButton:SetScript(
        "OnClick",
        function()
			KRFrame:Hide()
            VersFrame:Hide()
        end
    )

    table.insert(UISpecialFrames, "KRFrame")

    -- ScrollFrame
    f.keyList = CreateFrame("ScrollFrame", nil, f)
    f.keyList:SetPoint("TOPLEFT", 12, -45)
    f.keyList:SetPoint("BOTTOMRIGHT", -12, 45)

    local content = CreateFrame("Frame", nil, f.keyList)
    content:SetPoint("TOPLEFT")
    content:SetPoint("TOPRIGHT")
    content:SetWidth(f.keyList:GetWidth())
    f.keyList:SetScrollChild(content)
    f.keyList.content = content


	f.versButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.versButton:RegisterEvent ("PARTY_LEADER_CHANGED")
    f.versButton:SetPoint("BOTTOMRIGHT", -5, 5)
    f.versButton:SetSize(65, 25)
    f.versButton:SetText("v. "..C_AddOns.GetAddOnMetadata("keyroller", "Version"))
	f.versButton:SetScript(
        "OnClick",
        function()
			--getting player's version data (storing in versList global variable)
			DisplayVersionFrame()
        end
    )
	
    return f
end

-- Event manager
frame:SetScript(
    "OnEvent",
    function(self, event, ...)
        if event == "CHAT_MSG_ADDON" then
            local prefix, message, channel, sender = ...
            if prefix == ADDON_PREFIX then
                if string.find(message, "^KEY:") then
                    local _, _, dungeonName, level = string.find(message, "KEY:(.+):(%d+)")
                    if dungeonName and level then
                        playerKeys[sender] = {dungeon = dungeonName, level = tonumber(level)}
                        UpdateKeyList(KRFrame.keyList.content)
                    end
                elseif message == "REQUEST_KEY" then
                    BroadcastKey()
                elseif message == "ROLL" and sender ~= UnitName("player") then
                    RandomRoll(1, 100)
                elseif message == "PROMOTE_LEADER" then
					DisplayPopupCreation(winner)
				elseif message == "ADDON_VERSION" then
					local player = UnitName("player")
					local version = C_AddOns.GetAddOnMetadata("keyroller", "Version")
					local message = string.format("%s:%s", player, version)
					if IsInGroup() then
						C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "VERSION_PAYLOAD:" .. message, "PARTY")
					else 
						C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "VERSION_PAYLOAD:" .. message, "WHISPER", UnitName("player"))
					end
				end
            end
        elseif event == "CHAT_MSG_SYSTEM" then
            local message = ...
			local player, roll, min, max = string.match(message, "^(.-)%s.-(%d+)%s%((%d+)%-(%d+)%)")
            if player and isRollInProgress then
                rollResults[player] = tonumber(roll)

                local currentRoll = rollHistory[#rollHistory]
                if currentRoll then
                    table.insert(currentRoll.results, {player = player, roll = roll})
                end

                local allRolled = true
                for i = 1, GetNumGroupMembers() do
                    local name = GetRaidRosterInfo(i)
                    if not rollResults[name] then
                        allRolled = false
                        break
                    end
                end

                if allRolled then
                    isRollInProgress = false
                    local highestRoll = 0
                    local winner = nil
                    for matchedPlayer, matchedRoll in pairs(rollResults) do
                        if matchedRoll > highestRoll then
                            highestRoll = matchedRoll
                            winner = matchedPlayer
                        end
                    end

                    if winner then
                        SendChatMessage(
                            string.format("The winner is %s with: %d", winner, highestRoll),
                            GetGroupType()
                        )
						DisplayPopUpLeadPromote(winner)
                    end
                end
            end
        elseif event == "BAG_UPDATE" then
            BroadcastKey()
        elseif event == "GROUP_ROSTER_UPDATE" then
            BroadcastKey()
		end
    end
)

-- Commands
-- luacheck: globals SLASH_KR1
SLASH_KR1 = "/kr"
SlashCmdList["KR"] = function()
    if KRFrame:IsShown() then
        KRFrame:Hide()
		VersFrame:Hide()
    else
        KRFrame:Show()
    end
end

-- Initialisation
local mainFrame = CreateMainFrame()
local versFrame = CreateVersionFrame()