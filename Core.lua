---@class PRF_Namespace
local addonName, ns = ...

-- ============================================================
--  Localized globals
-- ============================================================
local C_NamePlate           = C_NamePlate
local C_Timer               = C_Timer
local C_Spell               = C_Spell
local IsSpellInRange        = (C_Spell and C_Spell.IsSpellInRange) or IsSpellInRange
local UnitCanAttack         = UnitCanAttack
local UnitExists            = UnitExists
local GetSpecialization     = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local issecretvalue         = issecretvalue
local hooksecurefunc        = hooksecurefunc

-- ============================================================
--  Module table
-- ============================================================
ns.Core = {}
local Core = ns.Core

-- ============================================================
--  State
--
--  activePlates:  unit → overlay frame (Platynator's newDisplay, or
--                 UnitFrame when Platynator is absent).
--                 Resolved once in OnPlateAdded; never changes for
--                 the lifetime of that nameplate.
--
--  rangeCache:    unit → true (in range) | false (out of range) | nil
--                 Updated by the 0.25s range-check ticker.
--                 The SetAlpha hook reads this to decide whether to
--                 multiply Platynator's alpha down.
--
--  hookedFrames:  frame → true
--                 Tracks which overlay frames already have our hook
--                 installed so we never double-hook the same frame.
-- ============================================================
local activePlates  = {}   -- unit → overlayFrame
local rangeCache    = {}   -- unit → bool (in range?)
local hookedFrames  = {}   -- frame → true
local currentSpecID = nil
local ticker        = nil

-- ============================================================
--  Spec detection
-- ============================================================
local function RefreshSpecID()
	local specIndex = GetSpecialization()
	if specIndex then
		currentSpecID = GetSpecializationInfo(specIndex)
	else
		currentSpecID = nil
	end
	ns.PRF_Log("Spec refreshed: " .. tostring(currentSpecID))
end

-- ============================================================
--  Target frame resolution  (called once per plate lifetime)
-- ============================================================
local function ResolveTargetFrame(plate)
	if not plate or plate:IsForbidden() then return nil end
	for _, child in pairs({plate:GetChildren()}) do
		if child ~= plate.UnitFrame and not child:IsForbidden() then
			return child   -- Platynator overlay
		end
	end
	local uf = plate.UnitFrame
	if uf and not uf:IsForbidden() then return uf end
	return nil
end

-- ============================================================
--  Range check  →  returns a plain boolean (or nil)
--
--  Unlike before we resolve the secret value here rather than
--  passing it raw, because the hook path receives a plain numeric
--  alpha from Platynator and just needs to know in/out state.
--  nil = invalid check → treat as in range (no fade).
-- ============================================================
local function CheckInRange(unit)
	local db = ns.DB
	if not db.enabled then return true end

	local spellID = currentSpecID and db.specSpells[currentSpecID] or nil
	if not spellID or spellID == 0 then return true end

	local result = IsSpellInRange(spellID, unit)
	if result == nil then return true end

	-- Resolve secret boolean safely
	if issecretvalue and issecretvalue(result) then
		-- Can't read the value; default to in-range (no fade)
		return true
	end
	return result == true or result == 1
end

-- ============================================================
--  SetAlpha hook factory
--
--  We install one hook per overlay frame, keyed to its unit via
--  an indirection table.  When Platynator (or anyone) calls
--  frame:SetAlpha(v), our hook fires immediately after and
--  multiplies v by the OOR factor if the unit is OOR.
--
--  Frame pool reuse: Platynator recycles overlay frames via a
--  frame pool (Uninstall → pool:Release → later pool:Acquire →
--  Install for a new unit).  The hook must always look up the
--  CURRENT unit for this frame, not the unit at install time.
--  We solve this with a shared "unit pointer" table: instead of
--  capturing unit directly in the closure, we capture a one-element
--  table `ptr` and update ptr[1] whenever a frame is reused.
-- ============================================================
local frameUnit = {}   -- frame → current unit string (updated on reuse)

local function InstallHook(frame, unit)
	frameUnit[frame] = unit   -- always update (handles pool reuse)

	if hookedFrames[frame] then return end   -- hook already on this frame object
	hookedFrames[frame] = true

	local locked = false

	hooksecurefunc(frame, "SetAlpha", function(self, alpha)
		if locked then return end
		local db = ns.DB
		if not db or not db.enabled then return end

		local currentUnit = frameUnit[self]
		if not currentUnit then return end

		local inRange = rangeCache[currentUnit]
		if inRange == false then
			locked = true
			self:SetAlpha(alpha * (db.oorAlpha or 0.5))
			locked = false
		end
	end)

	ns.PRF_Log("Hooked frame for " .. unit)
end

-- ============================================================
--  Direct alpha application.
--
--  Called by the ticker on state transitions and by RefreshAllPlates.
--  Sets the exact correct alpha value explicitly:
--    in range  → 1.0      (hook fires but passes through since inRange=true)
--    out of range → oorAlpha  (hook fires and would multiply, but we set
--                              the final value directly; lock prevents
--                              the hook from double-applying)
--
--  This avoids the GetAlpha() pitfall: if we read the current alpha
--  and pass it through the hook, a previously-faded value compounds
--  further rather than recovering to full alpha on in-range transitions.
-- ============================================================
local function DirectApply(frame, inRange, oorAlpha)
	if not frame or frame:IsForbidden() then return end
	if inRange then
		frame:SetAlpha(1.0)
	else
		frame:SetAlpha(oorAlpha)
	end
end

-- ============================================================
--  Ticker — dual purpose:
--  1. Keeps rangeCache up to date (range polling)
--  2. Directly applies correct alpha every tick (belt-and-suspenders)
--     This catches any Platynator SetAlpha calls that happened since
--     the last tick and ensures the fade is always visible even if
--     Platynator reset it between hook firings.
-- ============================================================
local function OnTick()
	local db = ns.DB
	if not db or not db.enabled then return end
	local oorAlpha = db.oorAlpha or 0.5

	for unit, frame in pairs(activePlates) do
		if UnitExists(unit) then
			local inRange = CheckInRange(unit)
			local changed = (inRange ~= rangeCache[unit])
			rangeCache[unit] = inRange

			if changed then
				ns.PRF_Log(unit .. " range changed: " .. tostring(inRange))
			end

			-- Apply every tick so Platynator can't overwrite our value
			-- between ticks without us correcting it on the next tick.
			DirectApply(frame, inRange, oorAlpha)
		end
	end
end

-- ============================================================
--  Public: reset all plates to full alpha
-- ============================================================
function Core.ResetAllAlpha()
	wipe(rangeCache)   -- clear first so hook sees nil → no-op
	for unit, frame in pairs(activePlates) do
		if frame and not frame:IsForbidden() then
			frame:SetAlpha(1.0)
		end
	end
end

-- ============================================================
--  Public: re-check all plates immediately (after settings change)
-- ============================================================
function Core.RefreshAllPlates()
	local db = ns.DB
	if not db or not db.enabled then
		Core.ResetAllAlpha()
		return
	end
	local oorAlpha = db.oorAlpha or 0.5
	for unit, frame in pairs(activePlates) do
		if UnitExists(unit) then
			local inRange = CheckInRange(unit)
			rangeCache[unit] = inRange
			DirectApply(frame, inRange, oorAlpha)
		end
	end
end

-- ============================================================
--  Nameplate added
-- ============================================================
local function OnPlateAdded(unit)
	if not UnitCanAttack("player", unit) then return end

	local plate = C_NamePlate.GetNamePlateForUnit(unit, false)
	local frame = ResolveTargetFrame(plate)
	if not frame then return end

	activePlates[unit] = frame
	InstallHook(frame, unit)

	-- Immediate range check and alpha apply
	local inRange = CheckInRange(unit)
	rangeCache[unit] = inRange
	DirectApply(frame, inRange, ns.DB.oorAlpha or 0.5)
end

-- ============================================================
--  Nameplate removed
-- ============================================================
local function OnPlateRemoved(unit)
	local frame = activePlates[unit]
	if frame then
		frameUnit[frame] = nil   -- disassociate frame from unit; hook becomes no-op
	end
	activePlates[unit] = nil
	rangeCache[unit]   = nil
end

-- ============================================================
--  Event frame
-- ============================================================
local eventFrame = CreateFrame("Frame")

eventFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name ~= addonName then return end
		ns.InitDB()
		ticker = C_Timer.NewTicker(ns.DB.tickRate or 0.15, OnTick)
		RefreshSpecID()
		self:UnregisterEvent("ADDON_LOADED")
		ns.PRF_Log("Initialized.")

	elseif event == "NAME_PLATE_UNIT_ADDED" then
		OnPlateAdded(...)

	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		OnPlateRemoved(...)

	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		local unit = ...
		if unit == "player" then
			RefreshSpecID()
			Core.RefreshAllPlates()
		end

	elseif event == "PLAYER_ENTERING_WORLD" then
		RefreshSpecID()
		wipe(activePlates)
		wipe(rangeCache)
		-- Don't wipe hookedFrames — frame objects may be reused and
		-- hooks survive across zone transitions correctly.
	end
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- ============================================================
--  Public: restart ticker with a new rate
--  Called by UI when the user changes the tick rate slider.
-- ============================================================
function Core.RestartTicker()
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
	local rate = (ns.DB and ns.DB.tickRate) or 0.15
	ticker = C_Timer.NewTicker(rate, OnTick)
	ns.PRF_Log("Ticker restarted at " .. rate .. "s interval")
end
SLASH_PLATYRANGEFADE1 = "/prfade"
SLASH_PLATYRANGEFADE2 = "/prf"
SlashCmdList["PLATYRANGEFADE"] = function(msg)
	local cmd = msg and msg:match("^(%S*)") or ""
	if cmd == "debug" then
		ns.ShowDebugWindow()
	elseif cmd == "reset" then
		if ns.DB then
			ns.DB.specSpells = {}
			for specID, spellID in pairs(ns.DEFAULT_SPELLS) do
				ns.DB.specSpells[specID] = spellID
			end
			ns.DB.oorAlpha = 0.5
			ns.DB.enabled  = true
			ns.DB.tickRate = 0.15
			Core.RestartTicker()
			Core.RefreshAllPlates()
			ns.PRF_Log("Settings reset to defaults.")
		end
	else
		ns.ToggleSettingsUI()
	end
end
