---@class PRF_Namespace
local addonName, ns = ...

-- ============================================================
--  Layout constants
-- ============================================================
local FRAME_W    = 500
local FRAME_H    = 540
local PADDING    = 12

-- Spec list column x-offsets within each row
local ROW_H         = 26
local HEADER_H      = 22
local CLASS_GAP     = 6
local COL_SPECNAME  = 14
local COL_EDITBOX   = 168
local COL_SPELLNAME = 252
local CONTENT_W     = FRAME_W - 2*PADDING - 26   -- room for scrollbar

-- ============================================================
--  Helpers
-- ============================================================
local function GetSpellName(spellID)
	if not spellID or spellID == 0 then return "" end
	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(spellID)
		return info and info.name or ("? (" .. spellID .. ")")
	end
	return tostring(spellID)
end

-- ============================================================
--  Slider builder — no template at all.
--  UISliderTemplate does not exist in 12.0.1.  We build from
--  a bare Slider frame with explicit thumb texture and
--  EnableMouse(true).
-- ============================================================
local function BuildSlider(parent, name, w, initVal, onChange)
	local s = CreateFrame("Slider", name, parent)
	s:SetWidth(w)
	s:SetHeight(16)
	s:SetOrientation("HORIZONTAL")
	s:SetMinMaxValues(0.0, 1.0)
	s:SetValueStep(0.05)
	s:SetObeyStepOnDrag(true)
	s:EnableMouse(true)

	-- Track (background bar)
	local track = s:CreateTexture(nil, "BACKGROUND")
	track:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")
	track:SetPoint("TOPLEFT",     s, "TOPLEFT",     8,  -3)
	track:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -8,  3)
	track:SetTexCoord(0, 1, 0.285, 0.715)

	-- Left/right track caps
	local left = s:CreateTexture(nil, "BACKGROUND")
	left:SetTexture("Interface\\Buttons\\UI-SliderBar-Border")
	left:SetSize(8, 20)
	left:SetPoint("RIGHT", track, "LEFT", 0, 0)
	left:SetTexCoord(0, 0.125, 0, 0.625)

	local right = s:CreateTexture(nil, "BACKGROUND")
	right:SetTexture("Interface\\Buttons\\UI-SliderBar-Border")
	right:SetSize(8, 20)
	right:SetPoint("LEFT", track, "RIGHT", 0, 0)
	right:SetTexCoord(0.875, 1, 0, 0.625)

	-- Thumb
	local thumb = s:CreateTexture(nil, "OVERLAY")
	thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	thumb:SetSize(32, 18)
	s:SetThumbTexture(thumb)

	-- Low/high labels
	local lowLabel = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	lowLabel:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -1)
	lowLabel:SetText("0.0")

	local highLabel = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	highLabel:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", 0, -1)
	highLabel:SetText("1.0")

	s:SetValue(initVal)
	s:SetScript("OnValueChanged", function(self, value)
		local snapped = math.floor(value / 0.05 + 0.5) * 0.05
		snapped = math.max(0.0, math.min(1.0, snapped))
		onChange(snapped)
	end)

	-- Mouse wheel support as extra affordance
	s:EnableMouseWheel(true)
	s:SetScript("OnMouseWheel", function(self, delta)
		local cur = self:GetValue()
		self:SetValue(math.max(0.0, math.min(1.0, cur + delta * 0.05)))
	end)

	return s
end

-- ============================================================
--  Scrollable spec list
-- ============================================================
local function BuildSpecList(parent, specRows, topY)
	-- UIPanelScrollFrameTemplate: stable, confirmed in SecureUIPanelTemplates.xml
	local sf = CreateFrame("ScrollFrame", "PlatyRangeFadeScroll", parent,
	                       "UIPanelScrollFrameTemplate")
	sf:SetPoint("TOPLEFT",     parent, "TOPLEFT",     PADDING,      -topY)
	sf:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -PADDING - 20, PADDING)

	local content = CreateFrame("Frame", nil, sf)
	content:SetWidth(CONTENT_W)
	sf:SetScrollChild(content)

	local rowY = 4

	for _, classData in ipairs(ns.SPEC_DATA) do
		local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		header:SetPoint("TOPLEFT", content, "TOPLEFT", COL_SPECNAME - 2, -rowY)
		local c = classData.color
		header:SetTextColor(c.r, c.g, c.b)
		header:SetText(classData.name)
		rowY = rowY + HEADER_H + 2

		for _, specData in ipairs(classData.specs) do
			local specID = specData.id

			local row = CreateFrame("Frame", nil, content)
			row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -rowY)
			row:SetSize(CONTENT_W, ROW_H)
			row.specID = specID

			local bg = row:CreateTexture(nil, "BACKGROUND")
			bg:SetAllPoints()
			bg:SetColorTexture(0, 0, 0, 0.12)

			local specName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			specName:SetPoint("LEFT", row, "LEFT", COL_SPECNAME, 0)
			specName:SetWidth(COL_EDITBOX - COL_SPECNAME - 6)
			specName:SetJustifyH("LEFT")
			specName:SetText(specData.name)

			local marker = row:CreateFontString(nil, "OVERLAY", "GameFontGreenSmall")
			marker:SetPoint("RIGHT", specName, "LEFT", -2, 0)
			marker:SetText("◄")
			marker:Hide()
			row.marker = marker

			-- InputBoxTemplate: confirmed in SecureUIPanelTemplates.xml
			local eb = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
			eb:SetPoint("LEFT", row, "LEFT", COL_EDITBOX, 0)
			eb:SetSize(72, 20)
			eb:SetAutoFocus(false)
			eb:SetNumeric(true)
			eb:SetMaxLetters(7)
			local saved    = ns.DB.specSpells[specID]
			local savedNum = type(saved) == "number" and saved or nil
			eb:SetText(savedNum and tostring(savedNum) or "")
			row.editBox = eb

			local spellLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			spellLabel:SetPoint("LEFT", row, "LEFT", COL_SPELLNAME, 0)
			spellLabel:SetWidth(CONTENT_W - COL_SPELLNAME - 4)
			spellLabel:SetJustifyH("LEFT")
			spellLabel:SetText(GetSpellName(savedNum))
			row.spellLabel = spellLabel

			local function CommitValue(editBox)
				editBox:ClearFocus()
				local val = tonumber(editBox:GetText())
				if val and val > 0 then
					ns.DB.specSpells[specID] = val
					spellLabel:SetText(GetSpellName(val))
					ns.PRF_Log("Spec " .. specID .. " -> spell " .. val
					           .. " (" .. GetSpellName(val) .. ")")
				else
					ns.DB.specSpells[specID] = false
					editBox:SetText("")
					spellLabel:SetText("")
					ns.PRF_Log("Spec " .. specID .. " -> cleared (no fade)")
				end
				ns.Core.RefreshAllPlates()
			end

			eb:SetScript("OnEscapePressed", function(self)
				local cur = ns.DB.specSpells[specID]
				self:SetText(type(cur) == "number" and tostring(cur) or "")
				self:ClearFocus()
			end)
			eb:SetScript("OnEnterPressed", function(self) CommitValue(self) end)
			eb:SetScript("OnEditFocusLost", function(self) CommitValue(self) end)

			table.insert(specRows, row)
			rowY = rowY + ROW_H + 2
		end

		rowY = rowY + CLASS_GAP
	end

	content:SetHeight(rowY + 4)
end

-- ============================================================
--  Main settings frame
-- ============================================================
local settingsFrame = nil

local function CreateSettingsFrame()
	-- BasicFrameTemplateWithInset: confirmed in
	-- Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml.
	-- Child keys: TitleText (FontString), CloseButton (Button).
	-- No "Inset" child frame — content sits directly on the frame.
	local frame = CreateFrame("Frame", "PlatyRangeFadeSettings", UIParent,
	                          "BasicFrameTemplateWithInset")
	frame:SetSize(FRAME_W, FRAME_H)
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
	frame:SetToplevel(true)
	frame:Hide()

	tinsert(UISpecialFrames, "PlatyRangeFadeSettings")

	-- TitleText is the parentKey in BaseBasicFrameTemplate
	frame.TitleText:SetText("Platy Range Fade")

	-- All content anchors below the title bar (approx 28px tall)
	local TOP = -32

	-- ── Enable checkbox + label ───────────────────────────────
	-- UICheckButtonTemplate: in DeprecatedTemplates.xml, still works.
	-- We create our own label FontString so we never touch .text/.Text.
	local enabledCB = CreateFrame("CheckButton", "PlatyRangeFadeEnabledCB",
	                              frame, "UICheckButtonTemplate")
	enabledCB:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING - 2, TOP)
	enabledCB:SetSize(24, 24)
	enabledCB:SetChecked(ns.DB.enabled)
	enabledCB:SetScript("OnClick", function(self)
		ns.DB.enabled = self:GetChecked()
		ns.Core.RefreshAllPlates()
	end)
	frame.enabledCB = enabledCB

	local enableLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	enableLabel:SetPoint("LEFT", enabledCB, "RIGHT", 2, 0)
	enableLabel:SetText("Enable range fading on hostile nameplates")

	-- ── Alpha row: label + live value ────────────────────────
	local alphaLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	alphaLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, TOP - 34)
	alphaLabel:SetText("Out-of-range alpha:")

	local alphaVal = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	alphaVal:SetPoint("LEFT", alphaLabel, "RIGHT", 8, 0)
	alphaVal:SetText(string.format("%.2f", ns.DB.oorAlpha))
	frame.alphaVal = alphaVal

	-- ── Slider (bare Slider frame — no template) ──────────────
	local slider = BuildSlider(frame, "PlatyRangeFadeAlphaSlider",
		FRAME_W - PADDING*2 - 8, ns.DB.oorAlpha,
		function(snapped)
			ns.DB.oorAlpha = snapped
			alphaVal:SetText(string.format("%.2f", snapped))
			ns.Core.RefreshAllPlates()
		end)
	slider:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING + 4, TOP - 52)
	frame.alphaSlider = slider

	-- ── Tick rate row ─────────────────────────────────────────
	local tickLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	tickLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, TOP - 84)
	tickLabel:SetText("Tick rate (seconds):")

	local tickVal = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	tickVal:SetPoint("LEFT", tickLabel, "RIGHT", 8, 0)
	tickVal:SetText(string.format("%.2f", ns.DB.tickRate or 0.15))
	frame.tickVal = tickVal

	-- Tick rate: 0.05s (very fast) to 1.0s (slow).
	-- Lower = more responsive but more CPU; higher = less responsive.
	local tickSlider = BuildSlider(frame, "PlatyRangeFadeTickSlider",
		FRAME_W - PADDING*2 - 8, ns.DB.tickRate or 0.15,
		function(snapped)
			ns.DB.tickRate = snapped
			tickVal:SetText(string.format("%.2f", snapped))
			ns.Core.RestartTicker()
		end)
	-- Override the slider's min/max/step to suit tick rates
	tickSlider:SetMinMaxValues(0.05, 1.0)
	tickSlider:SetValueStep(0.05)
	tickSlider:SetValue(ns.DB.tickRate or 0.15)
	-- Update end labels (BuildSlider set them for the alpha range)
	local tLow  = tickSlider.Low  or _G["PlatyRangeFadeTickSliderLow"]
	local tHigh = tickSlider.High or _G["PlatyRangeFadeTickSliderHigh"]
	if tLow  then tLow:SetText("0.05")  end
	if tHigh then tHigh:SetText("1.0")  end
	tickSlider:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING + 4, TOP - 102)
	frame.tickSlider = tickSlider

	-- ── Divider ───────────────────────────────────────────────
	local div = frame:CreateTexture(nil, "ARTWORK")
	div:SetColorTexture(0.5, 0.5, 0.5, 0.5)
	div:SetPoint("TOPLEFT",  frame, "TOPLEFT",  PADDING,  TOP - 134)
	div:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, TOP - 134)
	div:SetHeight(1)

	-- ── Spec list header ──────────────────────────────────────
	local listHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	listHeader:SetPoint("TOPLEFT",  frame, "TOPLEFT",  PADDING,  TOP - 142)
	listHeader:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, TOP - 142)
	listHeader:SetJustifyH("LEFT")
	listHeader:SetTextColor(0.8, 0.8, 0.8)
	listHeader:SetText(
		"Spell ID per spec — defaults pre-filled. " ..
		"Clear a box to disable fading. " ..
		"/prf reset restores all defaults.")

	-- ── Scrollable spec list ──────────────────────────────────
	-- List top = distance from frame top to start of scroll area
	local listTopY = 32 + (-TOP) + 134 + 22   -- title + gap + divider offset + header
	frame.specRows = {}
	BuildSpecList(frame, frame.specRows, listTopY)

	-- ── OnShow sync ───────────────────────────────────────────
	frame:SetScript("OnShow", function(self)
		self.enabledCB:SetChecked(ns.DB.enabled)
		self.alphaSlider:SetValue(ns.DB.oorAlpha)
		self.alphaVal:SetText(string.format("%.2f", ns.DB.oorAlpha))
		self.tickSlider:SetValue(ns.DB.tickRate or 0.15)
		self.tickVal:SetText(string.format("%.2f", ns.DB.tickRate or 0.15))
		self:RefreshSpecMarkers()
		self:SyncEditBoxes()
	end)

	function frame:RefreshSpecMarkers()
		local idx   = GetSpecialization and GetSpecialization() or nil
		local curID = idx and select(1, GetSpecializationInfo(idx)) or nil
		for _, row in ipairs(self.specRows) do
			row.marker:SetShown(row.specID == curID)
		end
	end

	function frame:SyncEditBoxes()
		for _, row in ipairs(self.specRows) do
			local val    = ns.DB.specSpells[row.specID]
			local numVal = type(val) == "number" and val or nil
			row.editBox:SetText(numVal and tostring(numVal) or "")
			row.spellLabel:SetText(GetSpellName(numVal))
		end
	end

	return frame
end

-- ============================================================
--  Public toggle
-- ============================================================
function ns.ToggleSettingsUI()
	if not settingsFrame then
		settingsFrame = CreateSettingsFrame()
	end
	if settingsFrame:IsShown() then
		settingsFrame:Hide()
	else
		settingsFrame:Show()
	end
end
