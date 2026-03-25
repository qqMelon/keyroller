local addonName, addonTable = ...
C_ChatInfo.RegisterAddonMessagePrefix("KR")
local isTpUp = false

local function CreateTTFrameTP()
    --creation of the ToolTip frame for buttons
    local f = CreateFrame("Frame", "TTFrame", UIParent, "BackdropTemplate")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 1, top = 3, bottom = 3 }
    })
    f:SetSize(0, 40)
    f:SetBackdropColor(0, 0, 0, 0.8)

    f:Hide()
    f:SetFrameStrata("HIGH")

    f:SetScript("OnUpdate", function()
        local x, y = GetCursorPosition()
        local effScale = UIParent:GetEffectiveScale()
        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", UIParent, (x / effScale) + 20, (y / effScale) - 20)
    end)

    tinsert(UISpecialFrames, "TTFrame")
    return f
end

function CreateTPBtn(TPPanel)
    local x = 9
    local i = 0
    for id, spell in pairs(dungTPSpells) do
        local btn = CreateFrame("Button", "DungTP" .. i, TPPanel, "InsecureActionButtonTemplate")
        btn:RegisterEvent("CHAT_MSG_ADDON")
        btn:SetSize(69, 59) -- width - height

        btn:SetMovable(false)
        btn:EnableMouse(true)
        btn:SetPoint("TOPLEFT", x, 0)
        btn.spellID = spell
        btn:SetAttribute("type", "spell")
        btn:SetAttribute("spell", spell)
        btn:RegisterForClicks("AnyDown", "AnyUp")

        local icon = btn:CreateTexture()
        icon:SetSize(48, 48)
        icon:SetAllPoints(btn)
        icon:SetTexture(dungBckPath[tonumber(id)])
        icon:SetTexCoord(0, 1, 0, 1)
        btn.icon = icon
        if not IsSpellKnown(btn.spellID) then
            btn:Disable()
            btn.icon:SetDesaturated(true)
        else
            btn:Enable()
            btn.icon:SetDesaturated(false)
        end
        local f = CreateTTFrameTP()
        local TTFont = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        TTFont:SetPoint("TOPLEFT", 5, -5)
        TTFont:SetJustifyH("LEFT")
        TTFont:SetJustifyV("TOP")
        --TAZA exception
        local dungeonName = nil
        if id == 391 then
            dungeonName = "Tazavesh"
        else
            dungeonName = C_ChallengeMode.GetMapUIInfo(id)
        end

        TTFont:SetText("Teleport to \n" .. dungeonName)
        f:SetWidth(TTFont:GetStringWidth() + 10)
        btn:SetScript("OnEnter", function(self)
            f:Show()
        end)
        btn:SetScript("OnLeave", function(self)
            f:Hide()
        end)


        i = i + 1
        x = x + 73.5
    end

    return
end

function CheckTPSpellCD()
    local spellCdText
    for id, spell in pairs(dungTPSpells) do
        if IsSpellKnown(spell) then
            local t = C_Spell.GetSpellCooldown(spell)
            if t.duration == 0 then
                isTpUp = true
                spellCdText = "|cff1eff00 Known teleport spells are available |r"
                break
            else
                isTpUp = false
                spellCdText = "|cffff8000 Known teleport spells are NOT available (cooldown: " ..
                math.ceil((((t.startTime + t.duration) - GetTime()) / 3600)) .. "h)|r"
                break
            end
        end
    end

    return spellCdText
end

function CreateTPPanel(mainFrame)
    local tpPanel = CreateFrame("Frame", "TPPanel", mainFrame);
    tinsert(UISpecialFrames, "TPPanel")
    tpPanel:SetSize(600, 80)
    tpPanel:SetPoint("TOPLEFT", 0, -310);
    tpPanel.Text = tpPanel:CreateFontString()
    tpPanel.Text:SetFontObject(GameFontNormal)
    tpPanel.Text:SetText(CheckTPSpellCD())
    tpPanel.Text:SetPoint("BOTTOM", 0, 45)

    CreateTPBtn(TPPanel)

    return tpPanel
end

function CheckAndShowTPPanel(tpPanel)
    -- checking tp spells cd's
    tpPanel.Text:SetFont("Fonts\\FRIZQT__.TTF", 13)
    tpPanel.Text:SetText(CheckTPSpellCD())
    tpPanel.Text:SetPoint("BOTTOM", 0, 5)

    --updating tp buttons
    local children = { tpPanel:GetChildren() }

    for i, child in ipairs(children) do
        if isTpUp then
            child:Enable()
            child.icon:SetDesaturated(false)
        else
            child:Disable()
            child.icon:SetDesaturated(true)
        end
    end

    --displaying buttons in panel
    tpPanel:Show()
end
