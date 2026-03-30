---@class PRF_Namespace
local addonName, ns = ...

-- ============================================================
--  Spec data: all 40 retail specs, grouped by class.
--  specID is the global spec ID returned by GetSpecializationInfo().
--  NOTE: hostile-targetable spells only work for range checks
--  against enemies. Healers/tanks should pick an offensive
--  ability (taunt, ranged attack, etc.) with a matching range.
-- ============================================================
ns.SPEC_DATA = {
	{
		name  = "Death Knight",
		color = { r = 0.77, g = 0.12, b = 0.23 },
		specs = {
			{ id = 250, name = "Blood"   },
			{ id = 251, name = "Frost"   },
			{ id = 252, name = "Unholy"  },
		},
	},
	{
		name  = "Demon Hunter",
		color = { r = 0.64, g = 0.19, b = 0.79 },
		specs = {
			{ id = 577,  name = "Havoc"      },
			{ id = 581,  name = "Vengeance"  },
			{ id = 1480, name = "Devourer"   },  -- added 12.0.0
		},
	},
	{
		name  = "Druid",
		color = { r = 1.0, g = 0.49, b = 0.04 },
		specs = {
			{ id = 102, name = "Balance"      },
			{ id = 103, name = "Feral"        },
			{ id = 104, name = "Guardian"     },
			{ id = 105, name = "Restoration" },
		},
	},
	{
		name  = "Evoker",
		color = { r = 0.2, g = 0.58, b = 0.5 },
		specs = {
			{ id = 1467, name = "Devastation"   },
			{ id = 1468, name = "Preservation"  },
			{ id = 1473, name = "Augmentation"  },
		},
	},
	{
		name  = "Hunter",
		color = { r = 0.67, g = 0.83, b = 0.45 },
		specs = {
			{ id = 253, name = "Beast Mastery"   },
			{ id = 254, name = "Marksmanship"    },
			{ id = 255, name = "Survival"        },
		},
	},
	{
		name  = "Mage",
		color = { r = 0.41, g = 0.8, b = 0.94 },
		specs = {
			{ id = 62, name = "Arcane" },
			{ id = 63, name = "Fire"   },
			{ id = 64, name = "Frost"  },
		},
	},
	{
		name  = "Monk",
		color = { r = 0.0, g = 1.0, b = 0.6 },
		specs = {
			{ id = 268, name = "Brewmaster"  },
			{ id = 270, name = "Mistweaver"  },
			{ id = 269, name = "Windwalker"  },
		},
	},
	{
		name  = "Paladin",
		color = { r = 0.96, g = 0.55, b = 0.73 },
		specs = {
			{ id = 65, name = "Holy"          },
			{ id = 66, name = "Protection"    },
			{ id = 70, name = "Retribution"   },
		},
	},
	{
		name  = "Priest",
		color = { r = 1.0, g = 1.0, b = 1.0 },
		specs = {
			{ id = 256, name = "Discipline"  },
			{ id = 257, name = "Holy"        },
			{ id = 258, name = "Shadow"      },
		},
	},
	{
		name  = "Rogue",
		color = { r = 1.0, g = 0.96, b = 0.41 },
		specs = {
			{ id = 259, name = "Assassination" },
			{ id = 260, name = "Outlaw"        },
			{ id = 261, name = "Subtlety"      },
		},
	},
	{
		name  = "Shaman",
		color = { r = 0.0, g = 0.44, b = 0.87 },
		specs = {
			{ id = 262, name = "Elemental"    },
			{ id = 263, name = "Enhancement"  },
			{ id = 264, name = "Restoration" },
		},
	},
	{
		name  = "Warlock",
		color = { r = 0.58, g = 0.51, b = 0.79 },
		specs = {
			{ id = 265, name = "Affliction"    },
			{ id = 266, name = "Demonology"    },
			{ id = 267, name = "Destruction"   },
		},
	},
	{
		name  = "Warrior",
		color = { r = 0.78, g = 0.61, b = 0.43 },
		specs = {
			{ id = 71, name = "Arms"        },
			{ id = 72, name = "Fury"        },
			{ id = 73, name = "Protection"  },
		},
	},
}

-- ============================================================
--  Default spells per spec.
--
--  Selection logic:
--    Tanks    → taunt (best represents "can I pull this mob")
--    Melee DPS / healers with melee (Paladin, Monk) → melee filler
--    Ranged / mid-range DPS (incl. Augmentation) → ranged filler
--    Healers with ranged DPS → ranged DPS filler
--
--  All spells here are hostile-targetable.
--  IsSpellInRange returns nil if the player doesn't know the spell
--  yet (e.g. fresh character), which is treated as in-range — safe.
--
--  Ranges are approximate and noted for reference only.
-- ============================================================
ns.DEFAULT_SPELLS = {
	-- ── Death Knight ──────────────────────────────────────────
	[250] = 56222,   -- Blood (tank)      Dark Command        30 yd taunt
	[251] = 49020,   -- Frost (melee)     Obliterate          melee
	[252] = 55090,   -- Unholy (melee)    Scourge Strike      melee

	-- ── Demon Hunter ──────────────────────────────────────────
	[577]  = 162794, -- Havoc (melee)     Chaos Strike        melee
	[581]  = 185245, -- Vengeance (tank)  Torment             30 yd taunt
	[1480] = 473662, -- Devourer (25 yd)  Consume             25 yd filler

	-- ── Druid ─────────────────────────────────────────────────
	[102] = 5176,    -- Balance (ranged)  Wrath               40 yd filler
	[103] = 5221,    -- Feral (melee)     Shred               melee
	[104] = 6795,    -- Guardian (tank)   Growl               30 yd taunt
	[105] = 5176,    -- Restoration       Wrath               40 yd DPS filler

	-- ── Evoker ────────────────────────────────────────────────
	[1467] = 356995, -- Devastation       Disintegrate        25 yd filler
	[1468] = 361469, -- Preservation      Living Flame        25 yd DPS filler
	[1473] = 395160, -- Augmentation      Eruption            25 yd filler

	-- ── Hunter ────────────────────────────────────────────────
	[253] = 193455,  -- Beast Mastery     Cobra Shot          40 yd filler
	[254] = 19434,   -- Marksmanship      Aimed Shot          40 yd filler
	[255] = 186270,  -- Survival (melee)  Raptor Strike       melee

	-- ── Mage ──────────────────────────────────────────────────
	[62] = 30451,    -- Arcane            Arcane Blast        40 yd filler
	[63] = 133,      -- Fire              Fireball            40 yd filler
	[64] = 116,      -- Frost             Frostbolt           40 yd filler

	-- ── Monk ──────────────────────────────────────────────────
	[268] = 116189,  -- Brewmaster (tank) Provoke             40 yd taunt
	[270] = 100780,  -- Mistweaver        Tiger Palm          melee filler
	[269] = 100780,  -- Windwalker        Tiger Palm          melee filler

	-- ── Paladin ───────────────────────────────────────────────
	[65] = 35395,    -- Holy              Crusader Strike     melee filler
	[66] = 62124,    -- Protection (tank) Hand of Reckoning   30 yd taunt
	[70] = 35395,    -- Retribution       Crusader Strike     melee filler

	-- ── Priest ────────────────────────────────────────────────
	[256] = 585,     -- Discipline        Smite               40 yd DPS filler
	[257] = 585,     -- Holy              Smite               40 yd DPS filler
	[258] = 15407,   -- Shadow            Mind Flay           30 yd filler

	-- ── Rogue ─────────────────────────────────────────────────
	[259] = 1329,    -- Assassination     Mutilate            melee
	[260] = 193315,  -- Outlaw            Sinister Strike     melee
	[261] = 185438,  -- Subtlety          Shadowstrike        melee

	-- ── Shaman ────────────────────────────────────────────────
	[262] = 188196,  -- Elemental         Lightning Bolt      40 yd filler
	[263] = 17364,   -- Enhancement       Stormstrike         melee
	[264] = 188196,  -- Restoration       Lightning Bolt      40 yd DPS filler

	-- ── Warlock ───────────────────────────────────────────────
	[265] = 686,     -- Affliction        Shadow Bolt         40 yd filler
	[266] = 686,     -- Demonology        Shadow Bolt         40 yd filler
	[267] = 29722,   -- Destruction       Incinerate          40 yd filler

	-- ── Warrior ───────────────────────────────────────────────
	[71] = 12294,    -- Arms              Mortal Strike       melee
	[72] = 23881,    -- Fury              Bloodthirst         melee
	[73] = 355,      -- Protection (tank) Taunt               30 yd taunt
}

-- ============================================================
--  Database init  (called from Core.lua on ADDON_LOADED)
-- ============================================================
function ns.InitDB()
	PLATY_RANGE_FADE_DB = PLATY_RANGE_FADE_DB or {}
	local db = PLATY_RANGE_FADE_DB

	-- Apply defaults for any missing keys
	if db.enabled    == nil then db.enabled    = true end
	if db.oorAlpha   == nil then db.oorAlpha   = 0.5  end
	if db.tickRate   == nil then db.tickRate   = 0.15 end
	if db.specSpells == nil then db.specSpells = {}   end

	-- Seed any spec that has no saved value with the built-in default.
	-- We only write if the key is genuinely absent (nil), so a user
	-- who explicitly cleared a spell to "none" (stored as false) is
	-- not overwritten.
	for specID, spellID in pairs(ns.DEFAULT_SPELLS) do
		if db.specSpells[specID] == nil then
			db.specSpells[specID] = spellID
		end
	end

	-- Expose on ns so all files can reach it without a global
	ns.DB = db
end
