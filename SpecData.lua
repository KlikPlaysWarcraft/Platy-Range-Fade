-- Fadey/Data/SpecData.lua
-- Spec definitions for options UI and default spell selection.
-- Source: PRF development reference doc (KlikPlaysWarcraft, 2026).

local addonName, ns = ...

-- DEFAULT_SPELLS: specID → default spellID
-- Selection rationale: tanks → taunt, melee → melee filler, ranged → ranged filler
ns.DEFAULT_SPELLS = {
	-- Death Knight
	[250] = 56222,   -- Blood      → Dark Command        (30 yd taunt)
	[251] = 49020,   -- Frost      → Obliterate          (melee)
	[252] = 55090,   -- Unholy     → Scourge Strike       (melee)
	-- Demon Hunter
	[577] = 162794,  -- Havoc      → Chaos Strike         (melee)
	[581] = 185245,  -- Vengeance  → Torment             (30 yd taunt)
	[1480]= 473662,  -- Devourer   → Consume             (25 yd)
	-- Druid
	[102] = 5176,    -- Balance    → Wrath               (40 yd)
	[103] = 5221,    -- Feral      → Shred               (melee)
	[104] = 6795,    -- Guardian   → Growl               (30 yd taunt)
	[105] = 5176,    -- Restoration→ Wrath               (40 yd)
	-- Evoker
	[1467]= 356995,  -- Devastation → Disintegrate       (25 yd)
	[1468]= 361469,  -- Preservation→ Living Flame       (25 yd)
	[1473]= 395160,  -- Augmentation→ Eruption           (25 yd)
	-- Hunter
	[253] = 193455,  -- Beast Mastery → Cobra Shot       (40 yd)
	[254] = 19434,   -- Marksmanship  → Aimed Shot       (40 yd)
	[255] = 186270,  -- Survival      → Raptor Strike    (melee)
	-- Mage
	[62]  = 30451,   -- Arcane     → Arcane Blast        (40 yd)
	[63]  = 133,     -- Fire       → Fireball            (40 yd)
	[64]  = 116,     -- Frost      → Frostbolt           (40 yd)
	-- Monk
	[268] = 116189,  -- Brewmaster → Provoke             (40 yd taunt)
	[270] = 100780,  -- Mistweaver → Tiger Palm          (melee)
	[269] = 100780,  -- Windwalker → Tiger Palm          (melee)
	-- Paladin
	[65]  = 35395,   -- Holy       → Crusader Strike     (melee)
	[66]  = 62124,   -- Protection → Hand of Reckoning   (30 yd taunt)
	[70]  = 35395,   -- Retribution→ Crusader Strike     (melee)
	-- Priest
	[256] = 585,     -- Discipline → Smite               (40 yd)
	[257] = 585,     -- Holy       → Smite               (40 yd)
	[258] = 15407,   -- Shadow     → Mind Flay           (30 yd)
	-- Rogue
	[259] = 1329,    -- Assassination→ Mutilate          (melee)
	[260] = 193315,  -- Outlaw    → Sinister Strike       (melee)
	[261] = 185438,  -- Subtlety  → Shadowstrike          (melee)
	-- Shaman
	[262] = 188196,  -- Elemental  → Lightning Bolt      (40 yd)
	[263] = 17364,   -- Enhancement→ Stormstrike         (melee)
	[264] = 188196,  -- Restoration→ Lightning Bolt      (40 yd)
	-- Warlock
	[265] = 686,     -- Affliction → Shadow Bolt         (40 yd)
	[266] = 686,     -- Demonology → Shadow Bolt         (40 yd)
	[267] = 29722,   -- Destruction→ Incinerate          (40 yd)
	-- Warrior
	[71]  = 12294,   -- Arms       → Mortal Strike       (melee)
	[72]  = 23881,   -- Fury       → Bloodthirst         (melee)
	[73]  = 355,     -- Protection → Taunt               (30 yd)
}

-- SPEC_DATA: ordered list for UI display, grouped by class.
-- Each class entry: { name, color={r,g,b}, specs={ {id, name}, ... } }
ns.SPEC_DATA = {
	{
		name  = "Death Knight",
		color = { r = 0.77, g = 0.12, b = 0.23 },
		specs = {
			{ id = 250, name = "Blood"  },
			{ id = 251, name = "Frost"  },
			{ id = 252, name = "Unholy" },
		},
	},
	{
		name  = "Demon Hunter",
		color = { r = 0.64, g = 0.19, b = 0.79 },
		specs = {
			{ id = 577,  name = "Havoc"    },
			{ id = 581,  name = "Vengeance"},
			{ id = 1480, name = "Devourer" },
		},
	},
	{
		name  = "Druid",
		color = { r = 1.00, g = 0.49, b = 0.04 },
		specs = {
			{ id = 102, name = "Balance"     },
			{ id = 103, name = "Feral"       },
			{ id = 104, name = "Guardian"    },
			{ id = 105, name = "Restoration" },
		},
	},
	{
		name  = "Evoker",
		color = { r = 0.20, g = 0.58, b = 0.50 },
		specs = {
			{ id = 1467, name = "Devastation" },
			{ id = 1468, name = "Preservation"},
			{ id = 1473, name = "Augmentation"},
		},
	},
	{
		name  = "Hunter",
		color = { r = 0.67, g = 0.83, b = 0.45 },
		specs = {
			{ id = 253, name = "Beast Mastery"},
			{ id = 254, name = "Marksmanship" },
			{ id = 255, name = "Survival"     },
		},
	},
	{
		name  = "Mage",
		color = { r = 0.41, g = 0.80, b = 0.94 },
		specs = {
			{ id = 62, name = "Arcane"},
			{ id = 63, name = "Fire"  },
			{ id = 64, name = "Frost" },
		},
	},
	{
		name  = "Monk",
		color = { r = 0.00, g = 1.00, b = 0.59 },
		specs = {
			{ id = 268, name = "Brewmaster"},
			{ id = 270, name = "Mistweaver"},
			{ id = 269, name = "Windwalker"},
		},
	},
	{
		name  = "Paladin",
		color = { r = 0.96, g = 0.55, b = 0.73 },
		specs = {
			{ id = 65, name = "Holy"       },
			{ id = 66, name = "Protection" },
			{ id = 70, name = "Retribution"},
		},
	},
	{
		name  = "Priest",
		color = { r = 1.00, g = 1.00, b = 1.00 },
		specs = {
			{ id = 256, name = "Discipline"},
			{ id = 257, name = "Holy"      },
			{ id = 258, name = "Shadow"    },
		},
	},
	{
		name  = "Rogue",
		color = { r = 1.00, g = 0.96, b = 0.41 },
		specs = {
			{ id = 259, name = "Assassination"},
			{ id = 260, name = "Outlaw"       },
			{ id = 261, name = "Subtlety"     },
		},
	},
	{
		name  = "Shaman",
		color = { r = 0.00, g = 0.44, b = 0.87 },
		specs = {
			{ id = 262, name = "Elemental"  },
			{ id = 263, name = "Enhancement"},
			{ id = 264, name = "Restoration"},
		},
	},
	{
		name  = "Warlock",
		color = { r = 0.58, g = 0.51, b = 0.79 },
		specs = {
			{ id = 265, name = "Affliction" },
			{ id = 266, name = "Demonology" },
			{ id = 267, name = "Destruction"},
		},
	},
	{
		name  = "Warrior",
		color = { r = 0.78, g = 0.61, b = 0.43 },
		specs = {
			{ id = 71, name = "Arms"      },
			{ id = 72, name = "Fury"      },
			{ id = 73, name = "Protection"},
		},
	},
}
