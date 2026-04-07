-- Fadey/Platy.lua
-- Platynator mode: hooks into Platynator's overlay SetAlpha to override it.
--
-- Architecture (from PRF dev reference):
--   • Platynator acquires a frame from its pool and parents it to the nameplate
--     root during Install(). This frame is called newDisplay and has .kind set
--     to "enemy", "friend", etc. by the pool factory.
--   • Platynator calls newDisplay:SetAlpha(alpha) in UpdateVisual(), which fires
--     on every relevant WoW event and on its own tickers.
--   • Silent re-installs (combat status change every 0.08s, faction ticker every
--     0.1s, UNIT_FACTION, settings refresh) call Uninstall()+Install(), replacing
--     newDisplay with a NEW frame object from the pool — any hook on the old frame
--     becomes useless. We must find and hook the overlay fresh each time.
--   • NAME_PLATE_UNIT_ADDED fires BEFORE Platynator's Install() completes, so we
--     defer overlay discovery by one frame with C_Timer.After(0, ...).
--
-- Range-based fading:
--   • In range (or unknown) → alpha = 1.0 (fully visible)
--   • Out of range         → alpha = oorAlpha

local addonName, ns = ...

local C_NamePlate   = C_NamePlate
local C_Timer       = C_Timer
local UnitCanAttack = UnitCanAttack

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function IsHostile(unit)
	return UnitCanAttack("player", unit) == true
end

-- ── State ─────────────────────────────────────────────────────────────────────

-- Maps unitToken → the overlay frame we currently have hooked.
-- Used to detect stale hooks when Platynator silently re-installs.
local hookedOverlay = {}

-- Set of frame objects we have already called hooksecurefunc on.
-- hooksecurefunc cannot be undone — calling it twice on the same frame
-- installs two permanent hooks. This set prevents that.
local hookedFrames = {}

-- Re-entrancy lock per frame: prevents our hook's SetAlpha call from
-- re-triggering the hook infinitely.
local hookLocked = {}

-- Per-unit range cache: true=in range, false=OOR, nil=unknown.
-- Updated by PlatyTick; used by both the ticker and the hook.
local rangeCache = {}

-- ── Overlay discovery ─────────────────────────────────────────────────────────
-- FadeyDiag revealed that Platynator parents MULTIPLE overlay frames to the
-- same nameplate root simultaneously (e.g. kind="enemy", kind="enemySimplified",
-- and another kind="enemy" all present at once). FindPlatyOverlay was returning
-- only the first one found via pairs() — leaving the others at alpha=1 and making
-- the plate appear unfaded. We must operate on ALL of them.

--- Walk the nameplate root's children and return ALL Platynator overlay frames.
--- Identification: frame.kind ~= nil.
--- Returns a table (possibly empty) of overlay frames.
local function FindPlatyOverlays(plate)
	local overlays = {}
	for _, child in pairs({plate:GetChildren()}) do
		if not child:IsForbidden() and child.kind ~= nil then
			table.insert(overlays, child)
		end
	end
	if #overlays == 0 then
		ns.DebugLog("FindPlatyOverlays: no kind-children found on plate")
	end
	return overlays
end

-- ── Hook installation ─────────────────────────────────────────────────────────

--- Resolve the correct alpha for a unit based on range.
--- in range or unknown → 1.0 (show fully); out of range → oorAlpha.
local function AlphaForUnit(unit)
	local inRange = rangeCache[unit]  -- true | false | nil
	if inRange == false then
		return ns.DB_GetOORAlpha()
	else
		return 1.0
	end
end

--- Apply alpha and install hooks for all Platynator overlays on a unit's plate.
--- Multiple overlays can be present simultaneously (FadeyDiag confirmed this).
--- Each overlay gets its own hook, keyed in hookedFrames to prevent duplicates.
local function ApplyToOverlays(unit, overlays)
	if not IsHostile(unit) then return end
	local targetAlpha = AlphaForUnit(unit)

	for _, overlay in ipairs(overlays) do
		-- Apply alpha directly.
		if not hookLocked[overlay] then
			hookLocked[overlay] = true
			overlay:SetAlpha(targetAlpha)
			hookLocked[overlay] = nil
		end

		-- Install hook once per unique frame object.
		-- The hook fires when Platynator calls SetAlpha between ticks;
		-- it reads rangeCache[capturedUnit] for the current correct alpha.
		if not hookedFrames[overlay] then
			hookedFrames[overlay] = true
			local capturedUnit = unit
			hooksecurefunc(overlay, "SetAlpha", function(self, alpha)
				if hookLocked[self] then return end
				if not ns.DB_GetEnabled() then return end
				if ns.DB_GetMode() ~= "platy" then return end
				local a = AlphaForUnit(capturedUnit)
				hookLocked[self] = true
				self:SetAlpha(a)
				hookLocked[self] = nil
			end)
			ns.DebugLog(string.format("ApplyToOverlays: hooked %s kind=%s",
				unit, tostring(overlay.kind)))
		end
	end
end

--- Discover all overlays for a unit and apply alpha + hooks to each.
--- Called deferred (C_Timer.After(0)) so Platynator has finished Install().
local function AttachUnit(unit)
	if ns.DB_GetMode() ~= "platy" then return end
	if not ns.DB_GetEnabled() then return end
	if not IsHostile(unit) then return end

	local plate = C_NamePlate.GetNamePlateForUnit(unit, false)
	if not plate then return end

	local overlays = FindPlatyOverlays(plate)
	if #overlays == 0 then
		ns.DebugLog(string.format("PlatyAttach: no overlays found for %s", unit))
		return
	end

	ApplyToOverlays(unit, overlays)
end

-- ── Ticker: stale-hook detection ─────────────────────────────────────────────
-- Platynator's silent re-installs replace the overlay with a new frame object.
-- Each tick we check whether the current overlay for a unit still matches what
-- we have hooked. If not, we find and hook the new one.

local platyTicker = nil

local function PlatyTick()
	if not ns.DB_GetEnabled() then return end
	if ns.DB_GetMode() ~= "platy" then return end

	for i = 1, 40 do
		local unit = "nameplate" .. i
		local plate = C_NamePlate.GetNamePlateForUnit(unit, false)
		if plate and IsHostile(unit) then
			-- Update range cache for this unit.
			rangeCache[unit] = ns.IsUnitInRange(unit)

			local overlays = FindPlatyOverlays(plate)
			if #overlays > 0 then
				ApplyToOverlays(unit, overlays)
			end
		else
			-- Unit no longer visible or no longer hostile — clear cache.
			rangeCache[unit] = nil
		end
	end
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Called on PLAYER_TARGET_CHANGED and PLAYER_SOFT_ENEMY_CHANGED.
--- Platynator resets the target's overlay to alpha=1 on these events,
--- and may silently re-install (new frame object) at the same time.
--- We defer one frame so any re-install finishes, then force our alpha.
function ns.Platy_OnTargetChanged()
	C_Timer.After(0, function()
		if not ns.DB_GetEnabled() then return end
		if ns.DB_GetMode() ~= "platy" then return end
		for i = 1, 40 do
			local unit = "nameplate" .. i
			local plate = C_NamePlate.GetNamePlateForUnit(unit, false)
			if plate and IsHostile(unit) then
				ApplyToOverlays(unit, FindPlatyOverlays(plate))
			end
		end
	end)
end

--- Called when a nameplate unit is added (deferred by one frame).
function ns.Platy_OnUnitAdded(unit)
	C_Timer.After(0, function()
		AttachUnit(unit)
	end)
end

--- Called when a nameplate unit is removed.
function ns.Platy_OnUnitRemoved(unit)
	-- Restore alpha on all currently hooked frames for this unit.
	-- We no longer track a single hookedOverlay[unit], so walk hookedFrames
	-- and restore any frame whose hook closure references this unit.
	-- Simpler: the plate is being removed so we can't get its children anyway.
	-- The frame will be returned to Platynator's pool and reused; the hook's
	-- re-entrancy guard will prevent interference. Nothing to do here.
	hookedOverlay[unit] = nil
end

--- Start Platy mode: attach to all currently visible nameplates and start ticker.
function ns.Platy_Enable()
	if platyTicker then platyTicker:Cancel() end
	platyTicker = C_Timer.NewTicker(ns.DB_GetTickRate(), PlatyTick)
	ns.DebugLog("Platy mode enabled")
end

--- Stop Platy mode: restore all overlays to full alpha.
function ns.Platy_Disable()
	if platyTicker then
		platyTicker:Cancel()
		platyTicker = nil
	end
	-- Restore alpha on all currently visible nameplate overlays.
	for i = 1, 40 do
		local unit = "nameplate" .. i
		local plate = C_NamePlate.GetNamePlateForUnit(unit, false)
		if plate then
			for _, overlay in ipairs(FindPlatyOverlays(plate)) do
				if not hookLocked[overlay] then
					hookLocked[overlay] = true
					overlay:SetAlpha(1.0)
					hookLocked[overlay] = nil
				end
			end
		end
	end
	wipe(hookedOverlay)
	wipe(rangeCache)
	ns.DebugLog("Platy mode disabled")
end

--- Restart the stale-hook ticker (called when tick rate changes).
function ns.Platy_RestartTicker()
	if platyTicker then platyTicker:Cancel() end
	if ns.DB_GetEnabled() and ns.DB_GetMode() == "platy" then
		platyTicker = C_Timer.NewTicker(ns.DB_GetTickRate(), PlatyTick)
	end
end
