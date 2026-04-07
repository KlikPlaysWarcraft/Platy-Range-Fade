-- Fadey/Core/Range.lua
-- Resolves the active spell for range checking and wraps C_Spell.IsSpellInRange.

local addonName, ns = ...

-- Localise globals used frequently.
local C_Spell           = C_Spell
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local issecretvalue     = issecretvalue   -- 12.0.1 secret-value guard

-- ── Spec tracking ─────────────────────────────────────────────────────────────

local activeSpecID = nil

--- Refresh activeSpecID from the current in-game spec.
--- Safe to call any time after PLAYER_LOGIN.
local function RefreshSpec()
	local idx = GetSpecialization()
	if not idx then
		activeSpecID = nil
		ns.DebugLog("Range: GetSpecialization() returned nil")
		return
	end
	local specID = GetSpecializationInfo(idx)
	activeSpecID = specID
	ns.DebugLog(string.format("Range: spec updated  idx=%d  specID=%s", idx, tostring(specID)))
end

--- Returns the specID currently active, or nil.
function ns.GetActiveSpecID()
	return activeSpecID
end

--- Returns the spellID Fadey should use for range checks this session, or nil.
function ns.GetActiveSpellID()
	if not activeSpecID then return nil end
	return ns.DB_GetSpellForSpec(activeSpecID)
end

-- ── Range check ───────────────────────────────────────────────────────────────

--- Check whether `unit` is in range of the active spell.
--- Returns:
---   true  → in range
---   false → out of range
---   nil   → unknown (unit not ready, no spell configured, secret value)
function ns.IsUnitInRange(unit)
	local spellID = ns.GetActiveSpellID()
	if not spellID then return nil end

	-- C_Spell.IsSpellInRange moved from global IsSpellInRange in 11.0; verify.
	if not (C_Spell and C_Spell.IsSpellInRange) then
		ns.DebugLog("Range: C_Spell.IsSpellInRange not available")
		return nil
	end

	local result = C_Spell.IsSpellInRange(spellID, unit)

	-- Guard against secret booleans (12.0.1 tainted contexts).
	if issecretvalue and issecretvalue(result) then
		return nil
	end

	-- nil → unit not ready / wrong faction / spell unknown → treat as unknown
	return result  -- true or false
end

-- ── Event wiring ──────────────────────────────────────────────────────────────
-- Nameplates.lua owns the main event frame; Range exposes a callback it calls.

function ns.Range_OnPlayerLogin()
	RefreshSpec()
end

function ns.Range_OnSpecChanged(unit)
	if unit == "player" then
		RefreshSpec()
	end
end
