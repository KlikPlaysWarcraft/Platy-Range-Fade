-- Fadey/Core/DB.lua
-- SavedVariables initialisation and typed accessors.
-- All SavedVariables access MUST happen at or after ADDON_LOADED.

local addonName, ns = ...

-- ── Defaults ─────────────────────────────────────────────────────────────────

local DEFAULTS = {
	enabled   = true,
	mode      = "default",  -- "default" or "platy"
	oorAlpha  = 0.35,   -- alpha applied to OOR hostile nameplates (0.0–1.0)
	tickRate  = 0.15,   -- range-check ticker interval in seconds
	specSpells = {},    -- specID → spellID  (false = user explicitly cleared)
	debugLog  = {},
}

-- ── Init ─────────────────────────────────────────────────────────────────────

--- Called by the event listener in Core/Nameplates.lua on ADDON_LOADED.
function ns.InitDB()
	FadeyDB = FadeyDB or {}
	local db = FadeyDB

	-- Top-level scalar defaults
	for k, v in pairs(DEFAULTS) do
		if db[k] == nil then
			if type(v) == "table" then
				db[k] = {}
			else
				db[k] = v
			end
		end
	end

	-- specSpells: ensure any missing spec entry gets its compiled-in default.
	-- A value of false means the user deliberately cleared a spell — honour it.
	for specID, spellID in pairs(ns.DEFAULT_SPELLS) do
		if db.specSpells[specID] == nil then
			db.specSpells[specID] = spellID
		end
	end

	ns.DebugFlushBuffer()
	ns.DebugLog("DB initialised. version=0.1.0")
end

-- ── Typed accessors ───────────────────────────────────────────────────────────
-- Using these keeps logic modules from reaching into FadeyDB directly.

function ns.DB_GetEnabled()
	return FadeyDB and FadeyDB.enabled or false
end

function ns.DB_SetEnabled(val)
	if FadeyDB then FadeyDB.enabled = val end
end

function ns.DB_GetOORAlpha()
	return FadeyDB and FadeyDB.oorAlpha or DEFAULTS.oorAlpha
end

function ns.DB_SetOORAlpha(val)
	if FadeyDB then FadeyDB.oorAlpha = val end
end

function ns.DB_GetTickRate()
	return FadeyDB and FadeyDB.tickRate or DEFAULTS.tickRate
end

function ns.DB_SetTickRate(val)
	if FadeyDB then FadeyDB.tickRate = val end
end

--- Returns the spellID for the given specID, or nil if none is set.
function ns.DB_GetSpellForSpec(specID)
	if not FadeyDB then return nil end
	local v = FadeyDB.specSpells[specID]
	-- false means explicitly cleared by the user
	if v == false then return nil end
	return v
end

--- Set spellID for specID.  Pass false to explicitly clear (no default fallback).
function ns.DB_SetSpellForSpec(specID, spellID)
	if FadeyDB then
		FadeyDB.specSpells[specID] = spellID
	end
end

--- Reset a spec's spell ID back to its compiled-in default.
function ns.DB_ResetSpellForSpec(specID)
	if FadeyDB then
		FadeyDB.specSpells[specID] = ns.DEFAULT_SPELLS[specID] or false
	end
end

--- Returns the current mode: "default" or "platy".
function ns.DB_GetMode()
	return FadeyDB and FadeyDB.mode or DEFAULTS.mode
end

function ns.DB_SetMode(val)
	if FadeyDB then FadeyDB.mode = val end
end
