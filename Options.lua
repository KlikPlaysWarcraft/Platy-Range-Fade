-- Fadey/UI/Options.lua
-- Options window: per-spec spell IDs, OOR alpha, tick rate.
-- UI patterns sourced from PRF dev reference (confirmed working in 12.0.1).

local addonName, ns = ...

-- ── Layout constants ──────────────────────────────────────────────────────────

local WINDOW_W      = 680
local WINDOW_H      = 560
local TITLE_H       = 28   -- height of BasicFrameTemplateWithInset title bar
local PADDING       = 12
local SECTION_GAP   = 14
local LABEL_W       = 200
local SLIDER_W      = 220
local SLIDER_H      = 20
local ROW_H         = 22
local LIST_ITEM_H   = 20
local ACTIVE_COLOR  = { r = 1,    g = 0.82, b = 0 }   -- gold for active spec
local HEADER_COLOR  = { r = 0.9,  g = 0.9,  b = 0.9 }

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function MakeLabel(parent, text, font, x, y, w, h)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	if w then fs:SetWidth(w) end
	if h then fs:SetHeight(h) end
	fs:SetText(text)
	return fs
end

--- Build a horizontal slider from scratch (UISliderTemplate does not exist in 12.0.1).
local function MakeSlider(parent, name, minVal, maxVal, step, x, y, width)
	local s = CreateFrame("Slider", name, parent)
	s:SetOrientation("HORIZONTAL")
	s:SetSize(width, SLIDER_H)
	s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	s:SetMinMaxValues(minVal, maxVal)
	s:SetValueStep(step)
	s:SetObeyStepOnDrag(true)
	s:EnableMouse(true)
	s:EnableMouseWheel(true)

	-- Track: solid white line, 3px tall, inset from thumb overhang
	local track = s:CreateTexture(nil, "BACKGROUND")
	track:SetColorTexture(1, 1, 1, 0.8)
	track:SetPoint("LEFT",  s, "LEFT",  14, 0)
	track:SetPoint("RIGHT", s, "RIGHT", -14, 0)
	track:SetHeight(3)

	-- Thumb
	local thumb = s:CreateTexture(nil, "OVERLAY")
	thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	thumb:SetSize(32, 18)
	s:SetThumbTexture(thumb)

	return s
end

-- ── Spec list helpers ─────────────────────────────────────────────────────────

--- Resolve display name for a spellID, or "(none)" if nil/false.
local function SpellName(spellID)
	if not spellID then return "|cffaaaaaa(none)|r" end
	local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
	if info and info.name then return info.name end
	return string.format("|cffaaaaaa(unknown %d)|r", spellID)
end

--- Return the specID of the player's current active spec, or nil.
local function CurrentSpecID()
	local idx = GetSpecialization and GetSpecialization()
	if not idx then return nil end
	local specID = GetSpecializationInfo and GetSpecializationInfo(idx)
	return specID
end

-- ── Window construction ───────────────────────────────────────────────────────

local optionsWindow = nil

local function BuildOptions()
	-- ── Root frame ────────────────────────────────────────────────────────────
	local win = CreateFrame("Frame", "FadeyOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
	win:SetSize(WINDOW_W, WINDOW_H)
	win:SetPoint("CENTER")
	win:SetMovable(true)
	win:EnableMouse(true)
	win:RegisterForDrag("LeftButton")
	win:SetScript("OnDragStart", win.StartMoving)
	win:SetScript("OnDragStop",  win.StopMovingOrSizing)
	win:SetClampedToScreen(true)
	win.TitleText:SetText("Fadey — Options")
	tinsert(UISpecialFrames, "FadeyOptionsFrame")

	-- ── Y cursor (counts down from top inside the window) ────────────────────
	-- Content starts below the title bar.
	local yOff = TITLE_H + PADDING   -- absolute offset from top of frame

	-- ── Section: General ─────────────────────────────────────────────────────
	local secGeneral = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	secGeneral:SetPoint("TOPLEFT", win, "TOPLEFT", PADDING, -yOff)
	secGeneral:SetText("General")
	yOff = yOff + 20 + 6

	-- Enable checkbox
	local cbEnable = CreateFrame("CheckButton", "FadeyOptEnableCB", win, "UICheckButtonTemplate")
	cbEnable:SetPoint("TOPLEFT", win, "TOPLEFT", PADDING, -yOff)
	cbEnable:SetSize(24, 24)
	local cbLabel = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	cbLabel:SetPoint("LEFT", cbEnable, "RIGHT", 2, 0)
	cbLabel:SetText("Enable Fadey")
	cbEnable:SetScript("OnClick", function(self)
		if self:GetChecked() then
			ns.EnableFadey()
		else
			ns.DisableFadey()
		end
	end)
	win.cbEnable = cbEnable
	yOff = yOff + 28 + 8

	-- Mode label
	local modeLabel = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	modeLabel:SetPoint("TOPLEFT", win, "TOPLEFT", PADDING, -yOff)
	modeLabel:SetText("Mode:")
	yOff = yOff + 14 + 4

	-- Mode buttons (Default / Platynator) — simple radio-style pair of buttons.
	-- We avoid the complex dropdown API (changed significantly in 12.0) and use
	-- two toggle buttons instead, which have no API compatibility concerns.
	local function MakeModeButton(label, mode, xPos)
		local btn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
		btn:SetSize(120, 22)
		btn:SetPoint("TOPLEFT", win, "TOPLEFT", xPos, -yOff)
		btn:SetText(label)
		btn.mode = mode
		return btn
	end

	local btnDefault = MakeModeButton("Default Nameplates", "default", PADDING)
	local btnPlaty   = MakeModeButton("Platynator",         "platy",   PADDING + 128)

	local function UpdateModeButtons(activeMode)
		-- Highlight the active button by desaturating the inactive one.
		if activeMode == "default" then
			btnDefault:SetAlpha(1.0)
			btnPlaty:SetAlpha(0.5)
		else
			btnDefault:SetAlpha(0.5)
			btnPlaty:SetAlpha(1.0)
		end
	end

	local function SwitchMode(newMode)
		local current = ns.DB_GetMode()
		if newMode == current then return end
		local wasEnabled = ns.DB_GetEnabled()
		-- Tear down the current mode cleanly before switching.
		if wasEnabled then
			if current == "platy" then
				ns.Platy_Disable()
			else
				-- Stop ticker and restore default nameplate alphas.
				-- Call internal stop without touching the enabled flag.
				ns.StopDefaultMode()
			end
		end
		ns.DB_SetMode(newMode)
		UpdateModeButtons(newMode)
		-- Re-enable in the new mode if Fadey was enabled.
		if wasEnabled then
			ns.EnableFadey()
		end
		ns.DebugLog("Mode switched to: " .. newMode)
	end

	btnDefault:SetScript("OnClick", function() SwitchMode("default") end)
	btnPlaty:SetScript("OnClick",   function() SwitchMode("platy")   end)

	win.btnDefault       = btnDefault
	win.btnPlaty         = btnPlaty
	win.UpdateModeButtons = UpdateModeButtons
	yOff = yOff + 22 + SECTION_GAP

	-- ── Section: Alpha ────────────────────────────────────────────────────────
	local secAlpha = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	secAlpha:SetPoint("TOPLEFT", win, "TOPLEFT", PADDING, -yOff)
	secAlpha:SetText("Out-of-Range Alpha")
	yOff = yOff + 20 + 4

	local alphaDesc = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	alphaDesc:SetPoint("TOPLEFT", win, "TOPLEFT", PADDING, -yOff)
	alphaDesc:SetText("Alpha applied to hostile nameplates outside spell range.  0 = invisible, 1 = fully opaque.")
	alphaDesc:SetWidth(WINDOW_W - PADDING * 2)
	yOff = yOff + 16 + 6

	-- Min / Max labels
	local alphaMin = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	alphaMin:SetPoint("TOPLEFT", win, "TOPLEFT", PADDING, -yOff - 14)
	alphaMin:SetText("0")
	local alphaMax = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	alphaMax:SetPoint("TOPLEFT", win, "TOPLEFT", PADDING + SLIDER_W + 6, -yOff - 14)
	alphaMax:SetText("1")

	local alphaSlider = MakeSlider(win, "FadeyOptAlphaSlider", 0, 1, 0.05, PADDING + 14, yOff, SLIDER_W)

	local alphaValLabel = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	alphaValLabel:SetPoint("LEFT", alphaSlider, "RIGHT", 10, 0)
	alphaValLabel:SetText("0.35")

	alphaSlider:SetScript("OnValueChanged", function(self, val)
		-- Round to nearest step for clean display
		val = math.floor(val * 20 + 0.5) / 20
		alphaValLabel:SetText(string.format("%.2f", val))
		ns.DB_SetOORAlpha(val)
	end)
	win.alphaSlider = alphaSlider
	yOff = yOff + SLIDER_H + SECTION_GAP + 8

	-- ── Section: Tick Rate ────────────────────────────────────────────────────
	local secTick = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	secTick:SetPoint("TOPLEFT", win, "TOPLEFT", PADDING, -yOff)
	secTick:SetText("Tick Rate")
	yOff = yOff + 20 + 4

	local tickDesc = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	tickDesc:SetPoint("TOPLEFT", win, "TOPLEFT", PADDING, -yOff)
	tickDesc:SetText("How often (in seconds) Fadey checks spell range.  Lower = more responsive, higher = more efficient.")
	tickDesc:SetWidth(WINDOW_W - PADDING * 2)
	yOff = yOff + 16 + 6

	local tickMin = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	tickMin:SetPoint("TOPLEFT", win, "TOPLEFT", PADDING, -yOff - 14)
	tickMin:SetText("0.05s")
	local tickMax = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	tickMax:SetPoint("TOPLEFT", win, "TOPLEFT", PADDING + SLIDER_W + 6, -yOff - 14)
	tickMax:SetText("1.00s")

	local tickSlider = MakeSlider(win, "FadeyOptTickSlider", 0.05, 1.00, 0.05, PADDING + 14, yOff, SLIDER_W)

	local tickValLabel = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	tickValLabel:SetPoint("LEFT", tickSlider, "RIGHT", 10, 0)
	tickValLabel:SetText("0.15s")

	tickSlider:SetScript("OnValueChanged", function(self, val)
		val = math.floor(val * 20 + 0.5) / 20
		tickValLabel:SetText(string.format("%.2fs", val))
		ns.DB_SetTickRate(val)
		ns.RestartTicker()
	end)
	win.tickSlider = tickSlider
	yOff = yOff + SLIDER_H + SECTION_GAP + 8

	-- ── Section: Spec Spell IDs ───────────────────────────────────────────────
	local secSpells = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	secSpells:SetPoint("TOPLEFT", win, "TOPLEFT", PADDING, -yOff)
	secSpells:SetText("Spec Spell IDs")
	yOff = yOff + 20 + 4

	local spellDesc = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	spellDesc:SetPoint("TOPLEFT", win, "TOPLEFT", PADDING, -yOff)
	spellDesc:SetText("The spell used to measure range for each spec.  Your active spec is highlighted in gold.")
	spellDesc:SetWidth(WINDOW_W - PADDING * 2)
	yOff = yOff + 16 + 4

	-- The spec list lives in a scroll frame that fills the remaining height.
	-- IMPORTANT: sf:GetWidth() returns 0 here because the frame hasn't been
	-- laid out by the renderer yet.  Compute width from known constants instead.
	-- Scrollbar (UIPanelScrollFrameTemplate) is 16px wide + 4px gap.
	local SCROLLBAR_W  = 20
	local contentWidth = WINDOW_W - PADDING * 2 - SCROLLBAR_W - 4

	local sf = CreateFrame("ScrollFrame", "FadeyOptSpecScroll", win, "UIPanelScrollFrameTemplate")
	sf:SetPoint("TOPLEFT",     win, "TOPLEFT",     PADDING,  -yOff)
	sf:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -PADDING - SCROLLBAR_W, PADDING)

	local content = CreateFrame("Frame", nil, sf)
	content:SetWidth(contentWidth)
	sf:SetScrollChild(content)

	-- Column header
	local hSpec  = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	hSpec:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
	hSpec:SetText("Spec")
	hSpec:SetWidth(180)

	local hSpell = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	hSpell:SetPoint("TOPLEFT", content, "TOPLEFT", 190, 0)
	hSpell:SetText("Spell ID")
	hSpell:SetWidth(80)

	local hName  = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	hName:SetPoint("TOPLEFT", content, "TOPLEFT", 278, 0)
	hName:SetText("Spell Name")
	hName:SetWidth(200)

	local rowY = 18   -- content-relative Y, counting down

	-- Row collection for RefreshSpecList
	local specRows = {}

	-- Build rows from SPEC_DATA
	for _, classEntry in ipairs(ns.SPEC_DATA) do
		-- Class header row
		local classLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		classLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -rowY)
		classLabel:SetWidth(contentWidth)
		local c = classEntry.color
		classLabel:SetTextColor(c.r, c.g, c.b)
		classLabel:SetText(classEntry.name)
		rowY = rowY + LIST_ITEM_H + 2

		-- Spec rows
		for _, spec in ipairs(classEntry.specs) do
			local specID = spec.id
			local row    = {}

			-- Spec name label
			local specLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			specLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -rowY)
			specLabel:SetWidth(170)
			specLabel:SetText(spec.name)
			row.specLabel = specLabel

			-- Spell ID EditBox
			local eb = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
			eb:SetPoint("TOPLEFT", content, "TOPLEFT", 190, -rowY + 2)
			eb:SetSize(72, 18)
			eb:SetAutoFocus(false)
			eb:SetNumeric(true)
			eb:SetMaxLetters(7)
			eb:SetScript("OnEnterPressed", function(self)
				self:ClearFocus()
				local numStr = self:GetText()
				local spellID = tonumber(numStr)
				ns.DB_SetSpellForSpec(specID, spellID or false)
				-- Refresh the spell name label immediately
				row.spellNameLabel:SetText(SpellName(spellID))
				ns.DebugLog(string.format(
					"Options: spec %d spell set to %s", specID, tostring(spellID)
				))
			end)
			eb:SetScript("OnEscapePressed", function(self)
				-- Revert EditBox to saved value on Escape
				local saved = ns.DB_GetSpellForSpec(specID)
				self:SetText(saved and tostring(saved) or "")
				self:ClearFocus()
			end)
			row.editBox = eb

			-- Spell name label
			local nameLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			nameLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 278, -rowY)
			nameLabel:SetWidth(260)
			row.spellNameLabel = nameLabel

			row.specID = specID
			specRows[specID] = row
			rowY = rowY + LIST_ITEM_H + 2
		end

		rowY = rowY + 4   -- a little breathing room between classes
	end

	-- Content height is now known
	content:SetHeight(rowY + 4)

	win.sf         = sf
	win.content    = content
	win.specRows   = specRows

	-- ── Refresh function (populates values from DB, highlights active spec) ──
	function win:RefreshValues()
		local db         = FadeyDB
		local activeSpec = CurrentSpecID()

		-- Top controls
		self.cbEnable:SetChecked(ns.DB_GetEnabled())
		self.alphaSlider:SetValue(ns.DB_GetOORAlpha())
		self.tickSlider:SetValue(ns.DB_GetTickRate())
		self.UpdateModeButtons(ns.DB_GetMode())

		-- Spec rows
		for specID, row in pairs(self.specRows) do
			local spellID = ns.DB_GetSpellForSpec(specID)
			row.editBox:SetText(spellID and tostring(spellID) or "")
			row.spellNameLabel:SetText(SpellName(spellID))

			-- Highlight the active spec in gold; others in normal white
			if specID == activeSpec then
				row.specLabel:SetTextColor(ACTIVE_COLOR.r, ACTIVE_COLOR.g, ACTIVE_COLOR.b)
			else
				row.specLabel:SetTextColor(1, 1, 1)
			end
		end
	end

	win:SetScript("OnShow", function(self)
		self:RefreshValues()
	end)

	win:Hide()
	return win
end

-- ── Public entry point ────────────────────────────────────────────────────────

function ns.OpenOptions()
	if not optionsWindow then
		optionsWindow = BuildOptions()
	end
	if optionsWindow:IsShown() then
		optionsWindow:Hide()
	else
		optionsWindow:RefreshValues()
		optionsWindow:Show()
	end
end
