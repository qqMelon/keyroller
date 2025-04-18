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

frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("CHAT_MSG_SYSTEM")

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
        print("Tu dois être dans un groupe pour demander les clefs!")
        return
    end

    playerKeys = {} -- Réinitialise la liste des clefs
    BroadcastKey() -- Envoie votre clef
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "REQUEST_KEY", GetGroupType()) -- Demande les clefs
    print("Demande de clefs envoyée au groupe.")
end

local function GetColorForLevel(level)
    if level >= 16 then
        return "|cffff8000" -- orange
    elseif level >= 11 then
        return "|cffa335ee" -- violet
    elseif level >= 4 then
        return "|cff0070dd" -- bleu
    else
        return "|cff1eff00" -- vert
    end
end

local function ExportKeysToChat()
    if not IsInGroup() then
        print("Tu dois être dans un groupe pour exporter les clefs!")
        return
    end

    SendChatMessage("=== Clefs Mythiques du Groupe ===", GetGroupType())
    for player, key in pairs(playerKeys) do
        if key.level >= minKeyLevel and key.level <= maxKeyLevel then
            local message = string.format("%s: %s +%d", player, key.dungeon, key.level)
            SendChatMessage(message, GetGroupType())
        end
    end
end

local function StartRoll()
    if not IsInGroup() then
        print("Tu dois être dans un groupe pour lancer un roll!")
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
				--PromoteToLeader(winner)
				FirePromotionEvent(winner)
            end,
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
				--FirePromotionEvent(winner)
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
    if event == "CHAT_MSG_ADDON" and prefix == "KR_ADDON" then
        -- Décode et stocke la clé reçue
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
--     header:SetSize(content:GetWidth(), rowHeight)
--     header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(rowHeight)

    local h1 = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h1:SetPoint("LEFT", 5, 0)
    h1:SetText("Nom du joueur")

    local h2 = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h2:SetPoint("CENTER", header, "CENTER", 0, 0)
    h2:SetText("Niveau")

    local h3 = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h3:SetPoint("RIGHT", -5, 0)
    h3:SetText("Donjon")

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
    f:SetSize(490, 350) -- Largeur - Hauteur
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
    f.rollButton:SetPoint("BOTTOM", 5, 5)
    f.rollButton:SetSize(120, 25)
    f.rollButton:SetText("Roll the Keys !")
    f.rollButton:SetScript(
        "OnClick",
        function()
            StartRoll()
        end
    )
    
        f.TButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.TButton:SetPoint("BOTTOMLEFT", 0, 0)
    f.TButton:SetSize(120, 25)
    f.TButton:SetText("TEST")
    f.TButton:SetScript(
        "OnClick",
        function()
            DisplayPopUpLeadPromote()
        end
    )

    f.closeButton = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeButton:SetPoint("TOPRIGHT", -5, -5)
    f.closeButton:SetSize(24, 24)

    table.insert(UISpecialFrames, "KRFrame")

    -- ScrollFrame
    f.keyList = CreateFrame("ScrollFrame", nil, f)
    f.keyList:SetPoint("TOPLEFT", 12, -45)
    f.keyList:SetPoint("BOTTOMRIGHT", -30, 45)

    local content = CreateFrame("Frame", nil, f.keyList)
    content:SetPoint("TOPLEFT")
    content:SetPoint("TOPRIGHT")
    content:SetWidth(f.keyList:GetWidth())
	-- content:SetSize(f.keyList:GetWidth(), 450)
    f.keyList:SetScrollChild(content)
    f.keyList.content = content


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
				end
            end
        elseif event == "CHAT_MSG_SYSTEM" then
            local message = ...
            local player, roll, min, max = string.match(message, "(.+) rolls (%d+) %((%d+)%-(%d+)%)")
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
                            string.format("Le gagnant est %s avec un roll de %d!", winner, highestRoll),
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

-- Commandes
-- luacheck: globals SLASH_KR1
SLASH_KR1 = "/kr"
SlashCmdList["KR"] = function()
    if KRFrame:IsShown() then
        KRFrame:Hide()
    else
        KRFrame:Show()
    end
end

-- Initialisation
local mainFrame = CreateMainFrame()