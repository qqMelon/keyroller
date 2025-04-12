std = "lua54"

unused_args = false
allow_defined_top = true
unused = false
shadowing = false
max_line_length = 130

exclude_files = {
	"KeyRoller/Libs/",
	".luacheckrc"
}

ignore = {
    "SLASH_KR1"
}

globals = {
    "CreateFrame",
    "UIParent",
    "C_ChatInfo",
    "C_Container",
    "C_MythicPlus",
    "C_ChallengeMode",
    "IsInRaid",
    "IsInGroup",
    "SendChatMessage",
    "UnitName",
    "RandomRoll",
    "GetNumGroupMembers",
    "GetRaidRosterInfo",
    "SlashCmdList",
    "KRFrame",
    "date",

    "LibStub",
}