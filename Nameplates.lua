-- Fadey/Core/Nameplates.lua
-- Main controller: event registration, ticker, nameplate alpha management.
-- Routes events to Default or Platy subsystem based on current mode.

local addonName, ns = ...

-- Localise heavy-use globals.
local C_NamePlate   = C_NamePlate
local C_Timer       = C_Timer
local UnitCanAttack = UnitCanAttack
local UnitExists    = UnitExists

-- ── State ─────────────────────────────────────────────────────────────────────

-- Maps unitToken → inRange (true | false | nil)
-- A key present in the table (even with value nil) means the unit is tracked.
-- Use trackedUnits[unit] to read; use rawget to distinguish "key absent" from "key = nil".
local trackedUnits = {}
-- Separate membership set so we can reliably tell "is this unit tracked at all"
-- without the nil-value ambiguity of the main table.
local trackedSet   = {}

-- Ticker handle so we can cancel and restart when tick rate changes.
local ticker = nil

-- ── Alpha helpers (Default Nameplates) ────────────────────────────────────────

--- Per the CLAUDE.md nameplate rules:
---   • Use SetAlpha(0) — never Hide() — so HitTestFrame stays active.
---   • Target is plate.UnitFrame (the visual layer for default nameplates).
local function GetVisualFrame(plate)
	if plate and plate.UnitFrame then
		return plate.UnitFrame
	end
	return nil
end

--- Apply the correct alpha to a nameplate based on in-range state.
--- inRange: true → full alpha 1.0 | false → OOR alpha | nil → full alpha (unknown = show)
local function ApplyAlpha(unit, inRange)
	local plate = C_NamePlate.GetNamePlateForUnit(unit, false)
	if not plate then return end

	local vf = GetVisualFrame(plate)
	if not vf then return end

	if inRange == false then
		vf:SetAlpha(ns.DB_GetOORAlpha())
	else
		-- In range or unknown → fully visible
		vf:SetAlpha(1.0)
	end
end

--- Restore full alpha on a nameplate (used on unit removal).
local function RestoreAlpha(unit)
	local plate = C_NamePlate.GetNamePlateForUnit(unit, false)
	if not plate then return end
	local vf = GetVisualFrame(plate)
	if vf then vf:SetAlpha(1.0) end
end

-- ── Ticker ────────────────────────────────────────────────────────────────────

local function TickAllUnits()
	if not ns.DB_GetEnabled() then return end

	for unit in pairs(trackedSet) do
		local inRange = ns.IsUnitInRange(unit)
		local prev    = trackedUnits[unit]

		-- Always apply on the first tick (prev == nil and unit is freshly added).
		-- After that, only call SetAlpha when state changes to minimise API churn.
		if inRange ~= prev then
			trackedUnits[unit] = inRange
			ApplyAlpha(unit, inRange)
			ns.DebugLog(string.format(
				"Tick: %s  range=%s → %s",
				unit, tostring(prev), tostring(inRange)
			))
		end
	end
end

local function StartTicker()
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
	local rate = ns.DB_GetTickRate()
	ticker = C_Timer.NewTicker(rate, TickAllUnits)
	ns.DebugLog(string.format("Ticker started: rate=%.3fs", rate))
end

local function StopTicker()
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
	ns.DebugLog("Ticker stopped")
end

-- ── Public: restart ticker (called by Options when rate changes) ──────────────

function ns.RestartTicker()
	if ns.DB_GetEnabled() then
		if ns.DB_GetMode() == "platy" then
			ns.Platy_RestartTicker()
		else
			StartTicker()
		end
	end
end

-- ── Nameplate events ──────────────────────────────────────────────────────────

--- Determine whether a unit is a hostile we should track.
--- UnitCanAttack returns true, false, or nil (unit not loaded yet).
--- We only fade hostile nameplates; friendly / neutral / unknown are left alone.
local function IsHostile(unit)
	return UnitCanAttack("player", unit) == true
end

local function OnUnitAdded(unit)
	if not ns.DB_GetEnabled() then return end
	if not IsHostile(unit) then return end

	if ns.DB_GetMode() == "platy" then
		ns.Platy_OnUnitAdded(unit)
		return
	end

	-- Default mode: mark as tracked; inRange starts nil until ticker fires.
	trackedSet[unit]   = true
	trackedUnits[unit] = nil

	ns.DebugLog(string.format("UnitAdded: %s", unit))
end

local function OnUnitRemoved(unit)
	if ns.DB_GetMode() == "platy" then
		ns.Platy_OnUnitRemoved(unit)
		return
	end

	if trackedSet[unit] then
		-- Restore full alpha before the frame gets recycled.
		RestoreAlpha(unit)
	end
	trackedSet[unit]   = nil
	trackedUnits[unit] = nil
	ns.DebugLog(string.format("UnitRemoved: %s", unit))
end

-- ── Enable / Disable ─────────────────────────────────────────────────────────

--- Stop default-mode ticker and restore all tracked nameplate alphas,
--- without touching the enabled flag. Used during mode transitions.
function ns.StopDefaultMode()
	StopTicker()
	for unit in pairs(trackedSet) do
		RestoreAlpha(unit)
	end
	wipe(trackedSet)
	wipe(trackedUnits)
	ns.DebugLog("Default mode stopped (mode transition)")
end

function ns.EnableFadey()
	ns.DB_SetEnabled(true)
	if ns.DB_GetMode() == "platy" then
		ns.Platy_Enable()
	else
		StartTicker()
	end
	ns.DebugLog("Fadey enabled (mode=" .. ns.DB_GetMode() .. ")")
end

function ns.DisableFadey()
	ns.DB_SetEnabled(false)
	if ns.DB_GetMode() == "platy" then
		ns.Platy_Disable()
	else
		StopTicker()
		-- Restore all tracked nameplates to full alpha.
		for unit in pairs(trackedSet) do
			RestoreAlpha(unit)
		end
		wipe(trackedSet)
		wipe(trackedUnits)
	end
	ns.DebugLog("Fadey disabled")
end

-- ── Event frame ───────────────────────────────────────────────────────────────

local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_SOFT_ENEMY_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name ~= addonName then return end

		ns.InitDB()
		self:UnregisterEvent("ADDON_LOADED")
		ns.DebugLog("ADDON_LOADED: DB ready")

	elseif event == "PLAYER_LOGIN" then
		ns.Range_OnPlayerLogin()
		if ns.DB_GetEnabled() then
			if ns.DB_GetMode() == "platy" then
				ns.Platy_Enable()
			else
				StartTicker()
			end
		end
		ns.DebugLog("PLAYER_LOGIN: Fadey active (mode=" .. ns.DB_GetMode() .. ")")

	elseif event == "PLAYER_LOGOUT" then
		StopTicker()

	elseif event == "NAME_PLATE_UNIT_ADDED" then
		local unit = ...
		OnUnitAdded(unit)

	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		local unit = ...
		OnUnitRemoved(unit)

	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		local unit = ...
		ns.Range_OnSpecChanged(unit)
		ns.DebugLog(string.format(
			"Spec changed → new spellID=%s",
			tostring(ns.GetActiveSpellID())
		))

	elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_SOFT_ENEMY_CHANGED" then
		if ns.DB_GetMode() == "platy" then
			ns.Platy_OnTargetChanged()
		end
	end
end)
