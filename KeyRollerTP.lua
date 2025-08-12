local addonName, addonTable = ...
C_ChatInfo.RegisterAddonMessagePrefix("KR")
local tpFrame = nil
-- THX BigWigs team :)
local dungTPSpells = {
	[2830] = 1237215, -- aldani
	[2287] = 354465, -- hoa
	[2660] = 445417, -- arakara
	[2441] = 367416, -- tazavesh
	[2662] = 445414, -- dawnbreaker
	[2649] = 445444, -- priory
	[2773] = 1216786, -- floodgate
}

function CreateTPBtn(TPPanel)
	local x = 30
	local y = -80
	local i = 0
	for id, spell in pairs(dungTPSpells) do
		local btn = CreateFrame("Button", "DungTP", TPPanel, "InsecureActionButtonTemplate")
		btn:RegisterEvent("CHAT_MSG_ADDON")
		btn:SetSize(90, 70) -- width - height

		btn:SetMovable(false)
		btn:EnableMouse(true)
		btn:SetPoint("TOPLEFT", x, y)
		btn.spellID = spell
		btn:SetAttribute("type", "spell")
		btn:SetAttribute("spell", spell)
		btn:RegisterForClicks("AnyDown", "AnyUp")
		btn:SetScript("OnEvent", function(self, event, ...)
			if event == "CHAT_MSG_ADDON" then
				local prefix, message, channel, sender = ...
				if prefix == "KR" and message == "CHECK_TP" then
					local t = C_Spell.GetSpellCooldown(spell)
					if not IsSpellKnown(btn.spellID) or t.duration ~= 0 then
						btn:Disable()
						btn.icon:SetDesaturated(true)
					else
						btn:Enable()
						btn.icon:SetDesaturated(false)
					end
				end
			end
		end)
		
		local icon = btn:CreateTexture()
		icon:SetSize(48, 48)
		icon:SetAllPoints(btn)
		local texture = C_Spell.GetSpellTexture(spell)
		icon:SetTexture(texture)
		btn.icon = icon
		local name, _ = C_ChallengeMode.GetMapUIInfo(id)
		btn:SetText(C_ChallengeMode.GetMapUIInfo(id))

		i=i+1
		x = x+110
		if i == 4 then
			x = 85
			y = -180
		end
		
		if not IsSpellKnown(spell) then
			btn:Disable()
			icon:SetDesaturated(true)
		end
		
		
	end
	
	return 

end

function CheckTPSpellCD ()
local spellCdText
	for id, spell in pairs(dungTPSpells) do
		if IsSpellKnown(spell) then
			local t = C_Spell.GetSpellCooldown(spell)
			print(((t.startTime + t.duration) - GetTime())/3600)
			if t.duration == 0 then
				spellCdText= "|cff1eff00 Known teleport spells are available |r"
				break
			else 
				spellCdText= "|cffff8000 Known teleport spells are NOT available (cooldown: "..math.ceil((((t.startTime + t.duration) - GetTime())/3600)).."h)|r"
				break
			end
		end
	end
	
	return spellCdText
end

function CreateTPPanel(mainFrame)
	local tpPanel=CreateFrame("Frame", "TPPanel", mainFrame);
	tpPanel:RegisterEvent("CHAT_MSG_ADDON")
    tinsert(UISpecialFrames, "TPPanel")
    tpPanel:Hide()
    tpPanel:SetAllPoints(mainFrame);
    tpPanel.Text = tpPanel:CreateFontString()
    tpPanel.Text:SetFontObject(GameFontNormal)
    tpPanel.Text:SetText(CheckTPSpellCD())
    tpPanel.Text:SetPoint("BOTTOM", 0, 45)
	tpPanel:SetScript(
		"OnHide", function()
			PanelTemplates_SetTab(mainFrame, 1)
		end
	)tpPanel:SetScript("OnEvent", function(self, event, ...)
		if event == "CHAT_MSG_ADDON" then
			local prefix, message, channel, sender = ...
			if prefix == "KR" and message == "CHECK_TP" then
				tpPanel.Text:SetText(CheckTPSpellCD())
			end
		end
	
	end)
	
	CreateTPBtn(TPPanel)
	
	return tpPanel
end

function CreateTabs(mainFrame, dataFrame)
	local tpPanel = CreateTPPanel(mainFrame)
    local Tab1=CreateFrame("Button" ,"Tab1", mainFrame, "PanelTabButtonTemplate")
    PanelTemplates_SetNumTabs(mainFrame,1);
    Tab1:SetPoint("BOTTOMLEFT",5,-31);
    Tab1:SetText("Keys");
    Tab1:SetID(1)
	Tab1:SetScript(
		"OnClick", function()
		PanelTemplates_SetTab(mainFrame, 1)
		--C_ChatInfo.SendAddonMessage("KR", "CHECK_TP", "WHISPER", UnitName("player"))
			tpPanel:Hide()
			dataFrame:Show()
		end
	)
	
	local Tab2=CreateFrame("Button" ,"Tab2", mainFrame, "PanelTabButtonTemplate")
    PanelTemplates_SetNumTabs(mainFrame,2);
	Tab2:RegisterEvent("CHAT_MSG_ADDON")
    Tab2:SetPoint("LEFT", Tab1, "RIGHT", 5, 0)
    Tab2:SetText("Dung TP");
    Tab2:SetID(2)
		Tab2:SetScript(
		"OnClick", function()
		C_ChatInfo.SendAddonMessage("KR", "CHECK_TP", "WHISPER", UnitName("player"))
		PanelTemplates_SetTab(mainFrame, 2)
			dataFrame:Hide()
			tpPanel:Show()
		end
	)
     

	--END TABS
	
	PanelTemplates_SetTab(mainFrame, 1)

end