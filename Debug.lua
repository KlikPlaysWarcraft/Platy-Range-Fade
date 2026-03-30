---@class PRF_Namespace
local addonName, ns = ...

-- ============================================================
--  Debug log (stored in SavedVariables so logs survive /reload)
-- ============================================================
local MAX_LOG_ENTRIES = 500

-- ns.PRF_Log is called from Core.lua and UI.lua.
-- Before DB is initialized this is a no-op (rare, only during load).
function ns.PRF_Log(msg)
	local db = ns.DB
	if not db then return end

	if not db.debugLog then db.debugLog = {} end
	local entry = date("%H:%M:%S") .. "  " .. tostring(msg)
	table.insert(db.debugLog, entry)
	while #db.debugLog > MAX_LOG_ENTRIES do
		table.remove(db.debugLog, 1)
	end
end

-- ============================================================
--  Debug window (lazy-created, opened via /prf debug)
-- ============================================================
local debugFrame = nil

local function CreateDebugWindow()
	local frame = CreateFrame("Frame", "PlatyRangeFadeDebug", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(620, 420)
	frame:SetPoint("CENTER", 0, -60)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
	frame:SetToplevel(true)
	frame:Hide()

	tinsert(UISpecialFrames, "PlatyRangeFadeDebug")

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.title:SetPoint("TOPLEFT", frame.TitleBg, "TOPLEFT", 5, -3)
	frame.title:SetText("Platy Range Fade — Debug Log")

	-- Instruction text
	local hint = frame.Inset:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	hint:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", 6, -4)
	hint:SetText("Click inside the box → Ctrl+A → Ctrl+C to copy all entries.")
	hint:SetTextColor(0.7, 0.7, 0.7)

	-- Clear button
	local clearBtn = CreateFrame("Button", nil, frame.Inset, "UIPanelButtonTemplate")
	clearBtn:SetPoint("TOPRIGHT", frame.Inset, "TOPRIGHT", -4, -2)
	clearBtn:SetSize(60, 22)
	clearBtn:SetText("Clear")
	clearBtn:SetScript("OnClick", function()
		if ns.DB and ns.DB.debugLog then
			wipe(ns.DB.debugLog)
		end
		frame.editBox:SetText("")
	end)

	-- Scroll frame
	local sf = CreateFrame("ScrollFrame", nil, frame.Inset, "UIPanelScrollFrameTemplate")
	sf:SetPoint("TOPLEFT",     frame.Inset, "TOPLEFT",     4,  -24)
	sf:SetPoint("BOTTOMRIGHT", frame.Inset, "BOTTOMRIGHT", -26,  4)

	-- EditBox inside scroll frame (multi-line, selectable, read-only feel).
	-- Width is set explicitly; GetWidth() returns 0 before first layout.
	local eb = CreateFrame("EditBox", nil, sf)
	eb:SetMultiLine(true)
	eb:SetFontObject(GameFontHighlightSmall)
	eb:SetWidth(560)   -- 620 frame - scrollbar - inset padding
	eb:SetAutoFocus(false)
	eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	-- Keep the editbox at least as wide as the scroll frame once it sizes
	sf:SetScript("OnSizeChanged", function(self)
		eb:SetWidth(self:GetWidth())
	end)
	sf:SetScrollChild(eb)
	frame.editBox = eb
	frame.scrollFrame = sf  -- keep reference for scroll-to-bottom

	-- Refresh content every time the window is shown
	frame:SetScript("OnShow", function(self)
		local log = (ns.DB and ns.DB.debugLog) or {}
		self.editBox:SetText(table.concat(log, "\n"))
		-- Scroll to bottom so newest entries are visible
		C_Timer.After(0, function()
			local range = self.scrollFrame:GetVerticalScrollRange()
			self.scrollFrame:SetVerticalScroll(range)
		end)
	end)

	return frame
end

function ns.ShowDebugWindow()
	if not debugFrame then
		debugFrame = CreateDebugWindow()
	end
	-- Refresh log text each time
	local log = (ns.DB and ns.DB.debugLog) or {}
	debugFrame.editBox:SetText(table.concat(log, "\n"))
	debugFrame:Show()
end
