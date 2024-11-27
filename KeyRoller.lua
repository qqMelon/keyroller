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

local function UpdateKeyList(content)
    if not content then
        return
    end

    if text == nil then
        text = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end

    for _, child in ipairs({content:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local formattedDisplay = ""
    local returnStr = "\n"
    for player, key in pairs(playerKeys) do
        if key.level >= minKeyLevel and key.level <= maxKeyLevel then
            formattedDisplay =
                formattedDisplay .. string.format("%s: %s +%d %s %s", player, key.dungeon, key.level, returnStr, returnStr)
        end
    end
    text:SetJustifyH("LEFT");
    text:SetPoint("TOPLEFT", 0, 0)
    text:SetText(formattedDisplay)
    content:SetHeight(math.max(20, 0))
end

local function CreateMainFrame()
    local f = CreateFrame("Frame", "KRFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(400, 350) -- Largeur - Hauteur
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", 0, -5)
    f.title:SetText("Key Roller")

    f.requestButton = CreateFrame("Button", nil, f, "GameMenuButtonTemplate")
    f.requestButton:SetPoint("TOPLEFT", 10, -40)
    f.requestButton:SetSize(120, 25)
    f.requestButton:SetText("Request Keys")
    f.requestButton:SetScript(
        "OnClick",
        function()
            RequestKeys()
        end
    )

    f.exportButton = CreateFrame("Button", nil, f, "GameMenuButtonTemplate")
    f.exportButton:SetPoint("TOPRIGHT", -10, -40)
    f.exportButton:SetSize(120, 25)
    f.exportButton:SetText("Export Keys")
    f.exportButton:SetScript(
        "OnClick",
        function()
            ExportKeysToChat()
        end
    )

    f.rollButton = CreateFrame("Button", nil, f, "GameMenuButtonTemplate")
    f.rollButton:SetPoint("BOTTOM", 10, 10)
    f.rollButton:SetSize(120, 25)
    f.rollButton:SetText("Roll the Keys !")
    f.rollButton:SetScript(
        "OnClick",
        function()
            StartRoll()
        end
    )

    -- Zone de défilement pour afficher les clefs
    f.keyList = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.keyList:SetPoint("TOPLEFT", 10, -80)
    f.keyList:SetPoint("BOTTOMRIGHT", -30, 40)

    local content = CreateFrame("Frame", nil, f.keyList)
    content:SetSize(f.keyList:GetWidth(), 400)
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
SLASH_KR1 = "/kr" -- SlashCommand to start
SlashCmdList["KR"] = function(msg)
    local command, arg1, arg2 = string.match(msg, "^(%w+)%s*(%w*)%s*(%w*)$")

    if command == "show" then
        KRFrame:Show()
    elseif command == "hide" then
        KRFrame:Hide()
    elseif command == "roll" then
        StartRoll()
    elseif command == "filter" then
        minKeyLevel = tonumber(arg1) or 0
        maxKeyLevel = tonumber(arg2) or 99
        UpdateKeyList(KRFrame.keyList.content)
    elseif command == "export" then
        ExportKeysToChat()
    elseif command == "request" then
        RequestKeys()
    else
        print("Key Roller - Commandes disponibles:")
        print("/kr show - Affiche la fenêtre")
        print("/kr hide - Cache la fenêtre")
        print("/kr roll - Lance un roll")
        print("/kr filter min max - Définit les filtres de niveau")
        print("/kr export - Exporte les clefs dans le chat")
        print("/kr request - Demande les clefs au groupe")
    end
end

-- Initialisation
local mainFrame = CreateMainFrame()
