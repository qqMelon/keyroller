-- KeyRoller.lua
local addonName, addonTable = ...
local frame = CreateFrame("Frame")
local mainframe = nil
local dataFrame = nil
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
local refreshLock = false
local refreshLockRoll = false
local isResizeNeeded = false
local dungNameMaxSize = 0
local isGuildDatasReq = false
local isScrollBar = false
local scrollFrameTemp = nil
local scrollChild = nil

frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("PARTY_LEADER_CHANGED")

local ADDON_PREFIX = "KR"
C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)

local function ExtractResilientValue(itemLink)
	local itemString = select(3, strfind(itemLink, "|H(.+)|h"))
	local resilient = (string.match(itemString, "(.-)%[")):sub(-4)
	resilient = string.sub(resilient, 1,2)
		if resilient == ":0" then
			resilient = "0"
		end
	return resilient
end

local function GetPlayerMythicKey()
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            if itemInfo then
                local itemID = itemInfo.itemID
                if itemID == 180653 then -- Keystone ID
                    local itemLink = itemInfo.hyperlink
					local resilient = ExtractResilientValue(itemLink)
                    if itemLink then
                        local keyLevel = C_MythicPlus.GetOwnedKeystoneLevel()
                        local dungeonID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
                        if keyLevel and dungeonID then
                            local dungeonName = C_ChallengeMode.GetMapUIInfo(dungeonID)
                            if dungeonName and keyLevel > 0 then
                                return dungeonName, keyLevel, resilient
                            end
                        end
                    end
                end
            end
        end
    end
    return nil, nil, nil
end

local function GetGroupType()
    return IsInRaid() and "RAID" or "PARTY"
end

local function ClearingDatas ()
		if isGuildDatasReq then
			C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "GUILD_DATAS", "GUILD")
		else	
			if IsInGroup() then 
				C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "CLEARING_DATAS", GetGroupType())
			else
				C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "CLEARING_DATAS", "WHISPER", UnitName("player"))
			end
		end
	return
end

local function DispatchDatas(message, sender)
	C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "KEY:" .. message, "WHISPER", sender)
end

local function BroacastKeyGuild(sender)
	local dungeonName, level, resilient = GetPlayerMythicKey()
    if dungeonName and level then
		local ratingSummary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(UnitFullName("player"))	
		local score = ratingSummary.currentSeasonScore
        local message = string.format("%s:%d:%d:%d:%s:%s", dungeonName, level, score, resilient, UnitNameUnmodified("player"), GetRealmName())
		C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "KEY_GUILD:" .. message, "WHISPER", sender)
	end

end

local function BroadcastKey(sender)
    local dungeonName, level, resilient = GetPlayerMythicKey()
    if dungeonName and level then
		local ratingSummary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(UnitFullName("player"))	
		local score = ratingSummary.currentSeasonScore
        local message = string.format("%s:%d:%d:%d", dungeonName, level, score, resilient)
		
		DispatchDatas(message, sender)
    end
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

local function GetColorForScore(score)
	if score >= 3500 then
		return "|cffff8000" -- orange
    elseif score >= 3000 and score < 3500 then
        return "|cffff00ff" -- pink
    elseif score >= 2500 and score < 3000 then
        return "|cffa335ee" -- purple
    elseif score >= 2000 and score < 2500 then
        return "|cff0070dd" -- blue
    elseif score >= 1000 and score < 2000 then
        return "|cff1eff00" -- green
    else
		return "|cffffffff" -- white
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
				refreshLockRoll = false
			end,
			OnCancel = function()
				refreshLockRoll = false
			end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
			}
			
			refreshLockRoll = true
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
				refreshLockRoll = false
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
			OnCancel = function()
				refreshLockRoll = false
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

local function CreateVersionFrame ()
	--creation of the version frame
    local f = CreateFrame("Frame", "VersFrame", UIParent, "BackdropTemplate")
	    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 1, top = 3, bottom = 3 }
    })
    f:SetSize(180, 72)
	f:SetPoint("BOTTOMRIGHT", "KRFrame", 178,0)
	    f:SetBackdropColor(0, 0, 0, 0.8)
    f:SetMovable(false)
    f:EnableMouse(false)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()
	f:SetScript("OnHide", function()
		versFont:SetText("")
		refreshLock = false
	end
	)

	tinsert(UISpecialFrames, "VersFrame")
	return f
end

local function DisplayVersionFrame()
    if not isVersFont then
        versFont = VersFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        versFont:SetPoint("TOPLEFT", 5, -5)
        versFont:SetJustifyH("LEFT")
        versFont:SetJustifyV("TOP")

        isVersFont = true
    end
	
	local text = ""
    for p, v in pairs(versionList) do
        text = text .. "v. " .. v .. "   " .. p .. "\n"
    end
    versTxt = text

    versFont:SetText(versTxt)
    VersFrame:Show()

end

local function DisplayPopUpRefreshData()
    StaticPopupDialogs["GATHERING_DATAS"] = {
    text = "DISPLAYING PLAYERS ADDON-VERSION",
	OnCancel = function ()
		DisplayVersionFrame()
	end,
	sound = levelup2,
    timeout = 2,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    }
			
    StaticPopup_Show ("GATHERING_DATAS")
end

local function DisplayPopUpRefreshDataKey(checkBox, refreshBtn, versBtn, rollButton)
    StaticPopupDialogs["GATHERING_DATAS_KEY"] = {
    text = "GATHERING DATAS ...",
	OnCancel = function ()
		checkBox:Enable()
		refreshBtn:Enable()
		versBtn:Enable()
		if UnitIsGroupLeader(UnitName("player")) then
			rollButton:Enable()
		end
	end,
	sound = levelup2,
    timeout = 1,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    }
			
    StaticPopup_Show ("GATHERING_DATAS_KEY")
end

--- Manage locale for i18n (frFR and enUS(default) supported) ---
local function ManageDungNameByLocale(dungName)
	local playerLocale = GetLocale()
	local dungListKey = nil
	local returnValue = nil
	
	for k,v in pairs (addonTable.dungListFR) do
		if dungName == addonTable.dungListFR[k] then
			dungListKey = k
			break
		-- bypass fix for Tazavesh dung not matching references (frFR locale)
		elseif dungName:find("^Tazavesh") and dungName:find("merveilles$") then
			returnValue = "Tazavesh : les rues des merveilles"
			return returnValue	
		elseif dungName:find("^Tazavesh") and dungName:find("So’leah$") then
			returnValue = "Tazavesh : le stratagème de So’leah"
			return returnValue	
		end
	end

	for k,v in pairs (addonTable.dungListEN) do
		if dungName == addonTable.dungListEN[k] then
			dungListKey = k
			break
		end
	end
	
	
	if playerLocale == addonTable.constFRLocale then
		returnValue = addonTable.dungListFR[dungListKey]
	else 
		returnValue = addonTable.dungListEN[dungListKey]
	end
	
	return returnValue
end

local function CreateScrollBar (state)
	if state == "create" then
		scrollFrameTemp = CreateFrame("ScrollFrame", nil, dataFrame, "UIPanelScrollFrameTemplate")
		scrollFrameTemp:SetPoint("TOPLEFT", 10, -70)
		scrollFrameTemp:SetPoint("BOTTOMRIGHT", -30, 35)

		scrollChild = CreateFrame("ScrollFrame", "ScrollArea", scrollFrameTemp )
		scrollFrameTemp:SetScrollChild(scrollChild)
		scrollChild:EnableMouse(false)
		scrollChild:SetWidth(500)
		scrollChild:SetHeight(500) 
		
		-- scrollChild.bg = scrollChild:CreateTexture(nil, "BACKGROUND")
        --scrollChild.bg:SetAllPoints()
		scrollFrameTemp:Hide()
		
		return scrollFrameTemp
	elseif state == "hide" then
		scrollFrameTemp:Hide()
	elseif state == "show" then
		scrollFrameTemp:Show()
	end
end

local function CreateInviteBtn(player, realm, frame)
	invBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	invBtn:RegisterEvent ("PARTY_LEADER_CHANGED")
	invBtn:RegisterEvent ("GROUP_ROSTER_UPDATE")
    invBtn:SetPoint("LEFT", 2, 0)
    invBtn:SetSize(120, 21)
	local text = invBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetText(string.gsub(player, "-.*", ""))
	text:SetPoint("LEFT",5,0)

    invBtn:SetScript(
        "OnClick",
        function(self, event)
			if string.gsub(UnitName("player"), "-.*", "") ~= string.gsub(player, "-.*", "") then
                C_PartyInfo.InviteUnit(player..'-'..realm)
			end
        end
    )
	
	invBtn:Hide()
	if not IsInGroup(UnitName("player")) or UnitIsGroupLeader(UnitName("player")) then
		invBtn:Show()
	end

	return invBtn
end

local function UpdateKeyList(content)
    if not content then return end
	
	local guildDataLoaded = false
    -- Clean children
    for _, child in ipairs({content:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
	
	 for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
	
    local totalWidth = content:GetWidth()
	--resetting size if previous resizing
	if isResizeNeeded then
		isResizeNeeded = false
		mainFrame:SetWidth(mainFrame:GetWidth() - (dungNameMaxSize - 20))
		dataFrame:SetWidth(dataFrame:GetWidth() - (dungNameMaxSize - 20))
		dungNameMaxSize = 0
	end
	
	if isScrollBar then
	mainFrame:SetWidth(mainFrame:GetWidth() - 20)
	dataFrame:SetWidth(dataFrame:GetWidth() - 20)
	isScrollBar = false
	CreateScrollBar("hide")
	end

	--checking if resizing is needed
	for player, key in pairs(playerKeys) do
		local dungName = ManageDungNameByLocale(key.dungeon)
		local lenValue = string.len(dungName)
		if lenValue >= 20 and lenValue > dungNameMaxSize then
			dungNameMaxSize = lenValue
			isResizeNeeded = true
		end
	end
	
	
	
	--resizing
	if dungNameMaxSize > 0 and isResizeNeeded then
		totalWidth = content:GetWidth() + (dungNameMaxSize - 20)
		mainFrame:SetWidth(mainFrame:GetWidth() + (dungNameMaxSize - 20))
		dataFrame:SetWidth(dataFrame:GetWidth() + (dungNameMaxSize - 20))
	end
	
	if isGuildDatasReq then
		isScrollBar = true
		mainFrame:SetWidth(mainFrame:GetWidth() +20)
		dataFrame:SetWidth(dataFrame:GetWidth() +20)
		CreateScrollBar("show")
	end

    local rowHeight = 26
    local spacing = 5
    local rowIndex = 0

    -- Headers
    local header = CreateFrame("Frame", nil, content)
    header:SetPoint("TOPLEFT", 0, 0)
    --header:SetPoint("TOPRIGHT", 0, 0)
	header:SetSize(totalWidth, rowHeight)

    local h1 = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h1:SetPoint("LEFT", 5, 0)
    h1:SetText("Player")
	
	local h4 = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h4:SetPoint("LEFT", 115, 0)
    h4:SetText("RIO Score")

    local h2 = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h2:SetPoint("CENTER", header, "CENTER", -38, 0)
    h2:SetText("Level")
	
	local h5 = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h5:SetPoint("CENTER", header, "CENTER", 10, 0)
    h5:SetText("Resilient")

    local h3 = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h3:SetPoint("RIGHT", -5, 0)
    h3:SetText("Dungeon")

    for player, key in pairs(playerKeys) do
        if key.level >= minKeyLevel and key.level <= maxKeyLevel then
            rowIndex = rowIndex + 1
			local row
			local btn
			if isGuildDatasReq then
				row = CreateFrame("Frame", nil, scrollChild)
				btn = CreateInviteBtn(player, key.realm, row)
			else
				row = CreateFrame("Frame", nil, content)
			end
            row:SetSize(totalWidth, rowHeight)
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
            --nameText:SetWidth(nameWidth)
            nameText:SetJustifyH("LEFT")
            nameText:SetText(string.gsub(player, "-.*", ""))
			
			local scoreText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			local colorScore = GetColorForScore(key.score)
            scoreText:SetPoint("LEFT", 130, 0)
            --scoreText:SetWidth(scoreWidth)
            scoreText:SetJustifyH("LEFT")
            scoreText:SetText(colorScore .. key.score .. "|r")

            local levelText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            local color = GetColorForLevel(key.level)
            levelText:SetPoint("CENTER", row, "CENTER", -40, 0)
            levelText:SetText(color .. "+" .. key.level .. "|r")
            levelText:SetJustifyH("CENTER")
			
			local resiText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            local color = GetColorForLevel(key.resilient)
            resiText:SetPoint("CENTER", row, "CENTER", 10, 0)
			if key.resilient ~= 0 then
				resiText:SetText(color .. key.resilient .. "|r")
			end
            resiText:SetJustifyH("CENTER")

            local dungeonText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            dungeonText:SetPoint("RIGHT", -5, 0)
			local dungName = ManageDungNameByLocale(key.dungeon)
            dungeonText:SetText(dungName)
            dungeonText:SetJustifyH("RIGHT")
				
        end
    end

    content:SetHeight((rowHeight + spacing) * (rowIndex + 2))
end

local function CreateMainFrame()

    local p = CreateFrame("Frame", "KRFrame", UIParent, "BackdropTemplate")
    p:SetSize(490, 350) -- width - height
    p:SetPoint("CENTER")
    p:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 1, top = 3, bottom = 3 }
    })
    p:SetBackdropColor(0, 0, 0, 0.8)
    p:SetMovable(true)
    p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving)
    p:SetScript("OnDragStop", p.StopMovingOrSizing)
    p:Hide()

    p.title = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p.title:SetPoint("TOP", 0, -15)
    p.title:SetFont("Fonts\\FRIZQT__.TTF", 21, "OUTLINE")
    p.title:SetTextColor(0.8, 0.8, 1)
    p.title:SetText("KEY ROLLER")
	
	p.closeButton = CreateFrame("Button", nil, p, "UIPanelCloseButton")
    p.closeButton:SetPoint("TOPRIGHT", -5, -5)
    p.closeButton:SetSize(24, 24)
	p.closeButton:SetScript(
        "OnClick",
        function()
			KRFrame:Hide()
            VersFrame:Hide()
			TPPanel:Hide()
			PanelTemplates_SetTab(mainFrame, 1)
        end
    )
	
	local f = CreateFrame("Frame", "DataFrame", KRFrame)
    --f:SetSize(490, 350) -- width - height
    f:SetAllPoints(KRFrame)
    
    --f:SetMovable(true)
    --f:EnableMouse(true)
    --f:RegisterForDrag("LeftButton")
    --f:SetScript("OnDragStart", f.StartMoving)
    --f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
	
	

    f.rollButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.rollButton:RegisterEvent ("PARTY_LEADER_CHANGED")
    f.rollButton:SetPoint("BOTTOM", 5, 5)
    f.rollButton:SetSize(120, 25)
    f.rollButton:SetText("Roll the Keys !")
    f.rollButton:SetScript(
        "OnClick",
        function()
			if not refreshLockRoll then
				refreshLockRoll = true
				StartRoll()
			end
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
    f.versButton:SetPoint("BOTTOMRIGHT", -5, 5)
    f.versButton:SetSize(65, 25)
    f.versButton:SetText("v. "..C_AddOns.GetAddOnMetadata("keyroller", "Version"))
	f.versButton:SetScript(
        "OnClick",
        function()
			if not refreshLock then
				refreshLock = true
				versionList = {}
				--getting player's version data (storing in versList global variable)
				GetPlayerAddonVersion ()
				DisplayPopUpRefreshData()
			end
			
			if VersFrame then
				if VersFrame:IsShown() then
					VersFrame:Hide()
				end
			end
		end )
		
	f.refreshBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.refreshBtn:RegisterEvent ("PARTY_LEADER_CHANGED")
	f.refreshBtn:RegisterEvent("GROUP_ROSTER_UPDATE")
    f.refreshBtn:SetPoint("BOTTOMLEFT", 5, 5)
    f.refreshBtn:SetSize(65, 25)
    f.refreshBtn:SetText("Refresh")
	f.refreshBtn:SetScript(
        "OnClick",
        function()
			playerKeys = {}
			f.checkBox:Disable()
			f.refreshBtn:Disable()
			f.versButton:Disable()
			f.rollButton:Disable()
			ClearingDatas()
			DisplayPopUpRefreshDataKey(f.checkBox, f.refreshBtn, f.versButton, f.rollButton)
		end )
	
	f.checkBox = CreateFrame("CheckButton", "nil", f, "ChatConfigCheckButtonTemplate")
	f.checkBox:RegisterEvent ("PARTY_LEADER_CHANGED")
	f.checkBox:RegisterEvent ("GROUP_ROSTER_UPDATE")
	f.checkBox:SetPoint("BOTTOMLEFT", 70, -1)
	f.checkBox:SetSize(35, 35)
	f.checkBox.tooltip = "Switch to guild datas with invite button ? (online members only)"
	f.checkBox:SetScript("OnClick", 
		function()
			if f.checkBox:GetChecked() then
				isGuildDatasReq = true
			else 
				isGuildDatasReq = false
			end
		end
	)
	tinsert(UISpecialFrames, "Frame")
	
    return f, p
end

-- Event manager
frame:SetScript(
    "OnEvent",
    function(self, event, ...)
        if event == "CHAT_MSG_ADDON" then
            local prefix, message, channel, sender = ...
            if prefix == ADDON_PREFIX then
                if string.find(message, "^KEY:") then
                    local _, _, dungeonName, level, score, resilient = string.find(message, "KEY:(.+):(%d+):(%d+):(%d+)")	
                    if dungeonName and level then
                        playerKeys[sender] = {dungeon = dungeonName, level = tonumber(level), score = tonumber(score), resilient = tonumber(resilient)}
                        UpdateKeyList(DataFrame.keyList.content)
                    end
				elseif string.find(message, "^KEY_GUILD:") then
					local _,_, dungeonName, level, score, resilient, playerName, realm = string.find(message, "KEY_GUILD:(.+):(%d+):(%d+):(%d+):(.+):(.+)")
                    if dungeonName and level then
                        playerKeys[playerName] = {dungeon = dungeonName, level = tonumber(level), score = tonumber(score), resilient = tonumber(resilient), realm = realm}
                        UpdateKeyList(DataFrame.keyList.content)
                    end
                elseif string.find(message, "VERSION_PAYLOAD:") then
					local _,_, player, version = string.find(message, "VERSION_PAYLOAD:(.+):(%A+)")
					versionList[player] = version
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
				elseif message == "CLEARING_DATAS" then
					BroadcastKey(sender)
				elseif message == "GUILD_DATAS" then
					BroacastKeyGuild(sender)
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
                    local name = string.gsub(GetRaidRosterInfo(i), "-.*", "")
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
						refreshLockRoll = false
                    end
                end
            end
		end
    end
)

-- Commands
-- luacheck: globals SLASH_KR1
SLASH_KR1 = "/kr"
SlashCmdList["KR"] = function()
    if KRFrame:IsShown() then
        KRFrame:Hide()
		DataFrame:Hide()
		VersFrame:Hide()
		TPPanel:Hide()
		PanelTemplates_SetTab(mainFrame, 1)
    else
        KRFrame:Show()
		DataFrame:Show()
    end
end

-- Initialisation
dataFrame, mainFrame = CreateMainFrame()
local tabs = CreateTabs(mainFrame, dataFrame)
CreateVersionFrame()
CreateScrollBar("create")