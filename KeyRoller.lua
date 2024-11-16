-- KeyRoller.lua
local addonName, addon = ...
local frame = CreateFrame("Frame")
local UIParent = UIParent

local playerKeys = {}
local isRollInProgress = false
local rollResults = {}
local rollHistory = {}
local minKeyLevel = 0
local maxKeyLevel = 99

frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")

local ADDON_PREFIX = "KR"
C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)

-- Obtenir la clef mythique du joueur
local function GetPlayerMythicKey()
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            if itemInfo then
                local itemID = itemInfo.itemID
                if itemID == 180653 then -- Keystone ID
                    local keyLevel = C_MythicPlus.GetOwnedKeystoneLevel()
                    local dungeonID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
                    if keyLevel and dungeonID then
                        local dungeonName = C_ChallengeMode.GetMapUIInfo(dungeonID)
                        return dungeonName, keyLevel
                    end
                end
            end
        end
    end
    return nil, nil
end

local function ExportKeysToChat()
    if not IsInGroup() then
        print("Tu dois être dans un groupe pour exporter les clefs!")
        return
    end

    SendChatMessage("=== Clefs Mythiques du Groupe ===", "PARTY")
    for player, key in pairs(playerKeys) do
        if key.level >= minKeyLevel and key.level <= maxKeyLevel then
            local message = string.format("%s: %s +%d", player, key.dungeon, key.level)
            SendChatMessage(message, "PARTY")
        end
    end
end

-- Initialisation de l'interface principale
local function CreateMainFrame()
    local f = CreateFrame("Frame", "KRFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(320, 300)
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

    -- Bouton pour demander les clefs
    f.requestButton = CreateFrame("Button", nil, f, "GameMenuButtonTemplate")
    f.requestButton:SetPoint("TOPLEFT", 10, -40)
    f.requestButton:SetSize(120, 25)
    f.requestButton:SetText("Request Keys")
    f.requestButton:SetScript("OnClick", function()
        RequestKeys()
    end)

    -- Bouton pour exporter les clefs
    f.exportButton = CreateFrame("Button", nil, f, "GameMenuButtonTemplate")
    f.exportButton:SetPoint("TOPRIGHT", -10, -40)
    f.exportButton:SetSize(120, 25)
    f.exportButton:SetText("Export Keys")
    f.exportButton:SetScript("OnClick", function()
        ExportKeysToChat()
    end)

    -- Zone de défilement pour afficher les clefs
    f.keyList = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.keyList:SetPoint("TOPLEFT", 10, -80)
    f.keyList:SetPoint("BOTTOMRIGHT", -30, 40)

    local content = CreateFrame("Frame", nil, f.keyList)
    content:SetSize(f.keyList:GetWidth(), 200)
    f.keyList:SetScrollChild(content)
    f.keyList.content = content

    return f
end

local KRFrame = CreateMainFrame()

-- Met à jour la liste des clefs dans l'interface
local function UpdateKeyList(content)
    if not content then return end

    -- Supprime tous les anciens enfants de `content`
    for _, child in ipairs({content:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    -- Ajoute de nouveaux textes pour chaque clef
    local offset = 0
    for player, key in pairs(playerKeys) do
        if key.level >= minKeyLevel and key.level <= maxKeyLevel then
            local text = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("TOPLEFT", 10, -offset)
            text:SetText(string.format("%s: %s +%d", player, key.dungeon, key.level))
            text:Show()
            offset = offset + 20
        end
    end

    -- Ajuste la hauteur du cadre de contenu pour s'adapter
    content:SetHeight(math.max(20, offset))
end


-- Commandes slash pour l'addon
SLASH_KR1 = "/kr"
SlashCmdList["KR"] = function(msg)
    local command, arg1, arg2 = string.match(msg, "^(%w+)%s*(%w*)%s*(%w*)$")

    if command == "show" then
        KRFrame:Show()
        UpdateKeyList(KRFrame.keyList.content)
    elseif command == "hide" then
        KRFrame:Hide()
    elseif command == "roll" then
        StartRoll()
    elseif command == "request" then
        RequestKeys()
    elseif command == "export" then
        ExportKeysToChat()
    else
        print("Key Roller - Commandes disponibles:")
        print("/kr show - Affiche la fenêtre")
        print("/kr hide - Cache la fenêtre")
        print("/kr roll - Lance un roll")
        print("/kr request - Demande les clefs au groupe")
        print("/kr export - Exporte les clefs dans le chat")
    end
end

-- Fonction pour demander les clefs
function RequestKeys()
    if not IsInGroup() then
        print("Vous devez être dans un groupe pour demander les clefs!")
        return
    end

    playerKeys = {}
    local dungeonName, level = GetPlayerMythicKey()
    if dungeonName and level then
        playerKeys[UnitName("player")] = {dungeon = dungeonName, level = level}
    end

    UpdateKeyList(KRFrame.keyList.content)
end
