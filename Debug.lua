-- Fadey/Core/Debug.lua
-- Scrollable, copy-pasteable debug log window.
-- Rule: NEVER use print() for debug output.

local addonName, ns = ...

local LOG_MAX = 1000

-- The log lives on the saved-variable table once DB is ready,
-- but we buffer here during early load so nothing is lost.
local earlyBuffer = {}
local dbReady = false

local function timestamp()
	return date("%H:%M:%S")
end

--- Write a line to the debug log.
--- Safe to call at any time, including before ADDON_LOADED.
function ns.DebugLog(msg)
	local entry = timestamp() .. "  " .. tostring(msg)
	if dbReady and FadeyDB then
		table.insert(FadeyDB.debugLog, entry)
		while #FadeyDB.debugLog > LOG_MAX do
			table.remove(FadeyDB.debugLog, 1)
		end
	else
		table.insert(earlyBuffer, entry)
	end
end

--- Called by DB.lua after FadeyDB is initialised to flush the early buffer.
function ns.DebugFlushBuffer()
	dbReady = true
	if FadeyDB then
		for _, entry in ipairs(earlyBuffer) do
			table.insert(FadeyDB.debugLog, entry)
		end
		while #FadeyDB.debugLog > LOG_MAX do
			table.remove(FadeyDB.debugLog, 1)
		end
	end
	earlyBuffer = {}
end

-- ── Window ───────────────────────────────────────────────────────────────────

local debugWindow

local function BuildDebugWindow()
	local frame = CreateFrame("Frame", "FadeyDebugFrame", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(640, 420)
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
	frame:SetClampedToScreen(true)

	-- Title
	frame.TitleText:SetText("Fadey — Debug Log")

	-- Scroll frame
	local sf = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	sf:SetPoint("TOPLEFT",     frame, "TOPLEFT",  12, -36)
	sf:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 8)

	-- EditBox (multi-line, read-only feel — user can select-all and copy)
	local eb = CreateFrame("EditBox", nil, sf)
	eb:SetMultiLine(true)
	eb:SetFontObject(GameFontHighlightSmall)
	eb:SetWidth(sf:GetWidth())
	eb:SetAutoFocus(false)
	eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	sf:SetScrollChild(eb)
	frame.editBox = eb

	tinsert(UISpecialFrames, "FadeyDebugFrame")
	frame:Hide()
	return frame
end

local function ShowDebugWindow()
	if not debugWindow then
		debugWindow = BuildDebugWindow()
	end
	-- Populate from saved log
	local lines = (FadeyDB and FadeyDB.debugLog) or earlyBuffer
	debugWindow.editBox:SetText(table.concat(lines, "\n"))
	debugWindow:Show()
end

-- ── Slash commands ────────────────────────────────────────────────────────────

SLASH_FADEY1 = "/fadey"
SlashCmdList["FADEY"] = function(msg)
	local cmd = msg and msg:match("^%s*(%S*)") or ""
	cmd = cmd:lower()

	if cmd == "debug" then
		ShowDebugWindow()
	elseif cmd == "clear" then
		if FadeyDB then wipe(FadeyDB.debugLog) end
		wipe(earlyBuffer)
		ns.DebugLog("Log cleared.")
	elseif cmd == "options" or cmd == "config" or cmd == "" then
		ns.OpenOptions()
	else
		-- Use DEFAULT_CHAT_FRAME to give the user a hint without polluting the
		-- debug log and without violating the no-print rule for diagnostic output.
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffFadey|r: /fadey [options | debug | clear]")
	end
end
