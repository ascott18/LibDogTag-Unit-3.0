local MAJOR_VERSION = "LibDogTag-Unit-3.0"
local MINOR_VERSION = tonumber(("$Revision$"):match("%d+")) or 0

if MINOR_VERSION > _G.DogTag_Unit_MINOR_VERSION then
	_G.DogTag_Unit_MINOR_VERSION = MINOR_VERSION
end

DogTag_Unit_funcs[#DogTag_Unit_funcs+1] = function(DogTag_Unit, DogTag)

local L = DogTag_Unit.L

local newList = DogTag.newList

local hasEvent = DogTag.hasEvent

local currentAuras, currentDebuffTypes, currentAuraTimes, currentNumDebuffs

local function func(self, unit)
	local t = newList()
	local u = newList()
	local v = newList()
	for i = 1, 40 do
		local name, _, _, count, _, timeLeft = UnitBuff(unit, i)
		if not name then
			break
		end
		if count == 0 then
			count = 1
		end
		t[name] = (t[name] or 0) + count
		if timeLeft and timeLeft > 0 and (not v[name] or v[name] > timeLeft) then
			v[name] = timeLeft
		end
	end
	local numDebuffs = 0
	local isFriend = UnitIsFriend("player", unit)
	for i = 1, 40 do
		local name, _, _, count, dispelType, _, timeLeft = UnitDebuff(unit, i)
		if not name then
			break
		end
		if count == 0 then
			count = 1
		end
		numDebuffs = numDebuffs + 1
		t[name] = (t[name] or 0) + count
		if isFriend and dispelType then
			u[dispelType] = true
		end
		if timeLeft and timeLeft > 0 and (not v[name] or v[name] > timeLeft) then
			v[name] = timeLeft
		end
	end
	currentAuras[unit] = t
	currentDebuffTypes[unit] = u
	local currentTime = GetTime()
	for name, timeLeft in pairs(v) do
		v[name] = timeLeft + currentTime
	end
	currentAuraTimes[unit] = v
	currentNumDebuffs[unit] = numDebuffs
	return self[unit]
end

local x = {__index=func}
currentAuras = setmetatable({},x)
currentDebuffTypes = setmetatable({},x)
currentAuraTimes = setmetatable({},x)
currentNumDebuffs = setmetatable({},x)
x = nil

local auraQueue = {}

local nextAuraUpdate = 0
local nextWackyAuraUpdate = 0
DogTag:AddTimerHandler(function(num, currentTime)
	if currentTime >= nextAuraUpdate and hasEvent('Aura') then
		nextAuraUpdate = currentTime + 0.25
		if currentTime >= nextWackyAuraUpdate then
			nextWackyAuraUpdate = currentTime + 1
			for unit, v in pairs(currentAuras) do
				if not IsNormalUnit[unit] then
					currentAuras[unit] = del(v)
					currentDebuffTypes[unit] = del(currentDebuffTypes[unit])
					currentAuraTimes[unit] = del(currentAuraTimes[unit])
					currentNumDebuffs[unit] = nil
				end
			end
		end
		for unit in pairs(auraQueue) do
			auraQueue[unit] = nil
			local t = newList()
			local u = newList()
			local v = newList()
			for i = 1, 40 do
				local name, _, _, count, _, timeLeft = UnitBuff(unit, i)
				if not name then
					break
				end
				if count == 0 then
					count = 1
				end
				t[name] = (t[name] or 0) + count
				if timeLeft and timeLeft > 0 and (not v[name] or v[name] > timeLeft) then
					v[name] = timeLeft
				end
			end
			local numDebuffs = 0
			local isFriend = UnitIsFriend("player", unit)
			for i = 1, 40 do
				local name, _, _, count, dispelType, _, timeLeft = UnitDebuff(unit, i)
				if not name then
					break
				end
				if count == 0 then
					count = 1
				end
				numDebuffs = numDebuffs + 1
				t[name] = (t[name] or 0) + count
				if isFriend and dispelType then
					u[dispelType] = true
				end
				if timeLeft and timeLeft > 0 and (not v[name] or v[name] > timeLeft) then
					v[name] = timeLeft
				end
			end
			for k, time in pairs(v) do
				v[k] = time + currentTime
			end
			local old = rawget(currentAuras, unit) or newList()
			local oldType = rawget(currentDebuffTypes, unit) or newList()
			local oldTimes = rawget(currentAuraTimes, unit) or newList()
			local changed = newList()
			local changedDebuffTypes = newList()
			for k, num in pairs(t) do
				if not old[k] then
					changed[k] = true
				else
					if num ~= old[k] then
						changed[k] = true
					end
					old[k] = nil
				end
			end
			for k in pairs(old) do
				changed[k] = true
			end
			for k in pairs(u) do
				if not oldType[k] then
					changedDebuffTypes[k] = true
				else
					oldType[k] = nil
				end
			end
			for k in pairs(oldType) do
				changedDebuffTypes[k] = true
			end
			for k, time in pairs(v) do
				if not oldTimes[k] then
					changed[k] = true
				else
					if math.abs(time - oldTimes[k]) > 0.2 then
						changed[k] = true
					end
					oldTimes[k] = nil
				end
			end
			for k, time in pairs(oldTimes) do
				changed[k] = true
			end
			currentAuras[unit] = t
			currentDebuffTypes[unit] = u
			currentAuraTimes[unit] = v
			local oldNumDebuffs = currentNumDebuffs[unit]
			currentNumDebuffs[unit] = numDebuffs
			if oldNumDebuffs ~= numDebuffs then
				if hasEvent.NumDebuffs then
					for text in pairs(eventData.NumDebuffs) do
						toUpdate[text] = true
					end
				end
			end
			old = del(old)
			oldType = del(oldType)
			oldTimes = del(oldTimes)
			for name in pairs(changed) do
				DogTag:FireEvent("Aura", unit, name)
			end
			changed = del(changed)
			for dispelType in pairs(changedDebuffTypes) do
				DogTag:FireEvent("Aura", unit, dispelType)
			end
			changedDebuffTypes = del(changedDebuffTypes)
		end
	end
end)


DogTag:AddEventHandler("UnitChanged", function(unit)
	if rawget(currentAuras, unit) then
		currentAuras[unit] = del(currentAuras[unit])
		currentDebuffTypes[unit] = del(currentDebuffTypes[unit])
		currentAuraTimes[unit] = del(currentAuraTimes[unit])
		currentNumDebuffs[unit] = nil
		auraQueue[unit] = true
	end
end)

DogTag:AddEventHandler("UNIT_AURA", function(unit)
	auraQueue[unit] = true
end)

DogTag:AddTag("Unit", "HasAura", {
	code = function(aura, unit)
		return currentAuras[unit][aura]
	end,
	arg = {
		'aura', 'string', '@req',
		'unit', 'string', '@req',
	},
	ret = "boolean",
	events = "Aura#$unit#$aura",
	doc = L["Return True if unit has the aura argument"],
	example = ('[HasAura("Shadowform")] => %q; [HasAura("Shadowform")] => ""'):format(L["True"]),
	category = L["Auras"]
})

DogTag:AddTag("Unit", "NumAura", {
	code = function(aura, unit)
		return currentAuras[unit][aura] or 0
	end,
	arg = {
		'aura', 'string', '@req',
		'unit', 'string', '@req',
	},
	ret = "number",
	events = "Aura#$unit#$aura",
	doc = L["Return the number of auras on the unit"],
	example = ('[NumAura("Shadowform")] => %q; [NumAura("Shadowform")] => ""'):format(L["True"]),
	category = L["Auras"]
})

local MOONKIN_FORM = GetSpellInfo(24858)
local AQUATIC_FORM = GetSpellInfo(1066)
local FLIGHT_FORM = GetSpellInfo(33943)
local SWIFT_FLIGHT_FORM = GetSpellInfo(40120)
local TRAVEL_FORM = GetSpellInfo(783)
local TREE_OF_LIFE = GetSpellInfo(33891)

DogTag:AddTag("Unit", "DruidForm", {
	code = function(unit)
		local _, c = UnitClass(unit)
		if c ~= "DRUID" then
			return nil
		end
		local power = UnitPowerType(unit)
		if power == 1 then
			return L["Bear"]
		elseif power == 3 then
			return L["Cat"]
		end
		local auras = currentAuras[unit]
		if auras[MOONKIN_FORM] then
			return L["Moonkin"]
		elseif auras[AQUATIC_FORM] then
			return L["Aquatic"]
		elseif auras[FLIGHT_FORM] or auras[SWIFT_FLIGHT_FORM] then
			return L["Flight"]
		elseif auras[TRAVEL_FORM] then
			return L["Travel"]
		elseif auras[TREE_OF_LIFE] and auras[TREE_OF_LIFE] >= 2 then
			return L["Tree"]
		end
		return nil
	end,
	arg = {
		'unit', 'string', '@req',
	},
	ret = "string;nil",
	events = "UNIT_DISPLAYPOWER#$unit;Aura#$unit#" .. MOONKIN_FORM .. ";Aura#$unit#" .. AQUATIC_FORM .. ";Aura#$unit#" .. FLIGHT_FORM .. ";Aura#$unit#" .. SWIFT_FLIGHT_FORM .. ";Aura#$unit#" .. TRAVEL_FORM .. ";Aura#$unit#" .. TREE_OF_LIFE,
	doc = L["Return the shapeshift form the unit is in if unit is a druid"],
	example = ('[DruidForm] => %q; [DruidForm] => %q; [DruidForm] => ""'):format(L["Bear"], L["Cat"]),
	category = L["Auras"]
})

DogTag:AddTag("Unit", "NumDebuffs", {
	code = function(unit)
		return currentNumDebuffs[unit]
	end,
	arg = {
		'unit', 'string', '@req',
	},
	ret = "number",
	events = "Aura#$unit",
	doc = L["Return the total number of debuffs that unit has"],
	example = '[NumDebuffs] => "5"; [NumDebuffs] => "40"',
	category = L["Auras"]
})


DogTag:AddTag("Unit", "AuraDuration", {
	code = function(aura, unit)
		local t = currentAuraTimes[unit][aura]
		if t then
			return GetTime() - t
		end
		return nil
	end,
	arg = {
		'aura', 'string', '@req',
		'unit', 'string', '@req',
	},
	events = "Update",
	ret = "number;nil",
	doc = L["Return the duration until the aura for unit is finished"],
	example = '[AuraDuration("Renew")] => "10.135123"',
	category = L["Auras"],
})

local SHADOWFORM = GetSpellInfo(15473)
DogTag:AddTag("Unit", "IsShadowform", {
	alias = ("HasAura(aura=%q, unit=unit)"):format(SHADOWFORM),
	arg = {
		'unit', 'string', '@req',
	},
	doc = L["Return True if the unit has the shadowform buff"],
	example = ('[IsShadowform] => %q; [IsShadowform] => ""'):format(L["True"]),
	category = L["Auras"],
})

local STEALTH = GetSpellInfo(1784)
local SHADOWFORM = GetSpellInfo(20580)
local PROWL = GetSpellInfo(5215)
DogTag:AddTag("Unit", "IsStealthed", {
	alias = ("HasAura(aura=%q, unit=unit) or HasAura(aura=%q, unit=unit) or HasAura(aura=%q, unit=unit)"):format(STEALTH, SHADOWFORM, PROWL),
	arg = {
		'unit', 'string', '@req',
	},
	doc = L["Return True if the unit is stealthed in some way"],
	example = ('[IsStealthed] => %q; [IsStealthed] => ""'):format(L["True"]),
	category = L["Auras"]
})

local SHIELD_WALL = GetSpellInfo(871)
DogTag:AddTag("Unit", "HasShieldWall", {
	alias = ("HasAura(aura=%q, unit=unit)"):format(SHIELD_WALL),
	arg = {
		'unit', 'string', '@req',
	},
	doc = L["Return True if the unit has the Shield Wall buff"],
	example = ('[HasShieldWall] => %q; [HasShieldWall] => ""'):format(L["True"]),
	category = L["Auras"]
})

local LAST_STAND = GetSpellInfo(12975)
DogTag:AddTag("Unit", "HasLastStand", {
	alias = ("HasAura(aura=%q, unit=unit)"):format(LAST_STAND),
	arg = {
		'unit', 'string', '@req',
	},
	doc = L["Return True if the unit has the Last Stand buff"],
	example = ('[HasLastStand] => %q; [HasLastStand] => ""'):format(L["True"]),
	category = L["Auras"]
})

local SOULSTONE_RESURRECTION = GetSpellInfo(20707)
DogTag:AddTag("Unit", "HasSoulstone", {
	alias = ("HasAura(aura=%q, unit=unit)"):format(SOULSTONE_RESURRECTION),
	arg = {
		'unit', 'string', '@req',
	},
	doc = L["Return True if the unit has the Soulstone buff"],
	example = ('[HasSoulstone] => %q; [HasSoulstone] => ""'):format(L["True"]),
	category = L["Auras"]
})

local MISDIRECTION = GetSpellInfo(34477)
DogTag:AddTag("Unit", "HasMisdirection", {
	alias = ("HasAura(aura=%q, unit=unit)"):format(MISDIRECTION),
	arg = {
		'unit', 'string', '@req',
	},
	doc = L["Return True if the unit has the Misdirection buff"],
	example = ('[HasMisdirection] => %q; [HasMisdirection] => ""'):format(L["True"]),
	category = L["Auras"]
})

local ICE_BLOCK = GetSpellInfo(27619)
DogTag:AddTag("Unit", "HasIceBlock", {
	alias = ("HasAura(aura=%q, unit=unit)"):format(ICE_BLOCK),
	arg = {
		'unit', 'string', '@req',
	},
	doc = L["Return True if the unit has the Ice Block buff"],
	example = ('[HasIceBlock] => %q; [HasIceBlock] => ""'):format(L["True"]),
	category = L["Auras"]
})

local INVISIBILITY = GetSpellInfo(66)
DogTag:AddTag("Unit", "HasInvisibility", {
	alias = ("HasAura(aura=%q, unit=unit)"):format(INVISIBILITY),
	arg = {
		'unit', 'string', '@req',
	},
	doc = L["Return True if the unit has the Invisibility buff"],
	example = ('[HasInvisibility] => %q; [HasInvisibility] => ""'):format(L["True"]),
	category = L["Auras"]
})

local DIVINE_INTERVENTION = GetSpellInfo(19752)
DogTag:AddTag("Unit", "HasDivineIntervention", {
	alias = ("HasAura(aura=%q, unit=unit)"):format(DIVINE_INTERVENTION),
	arg = {
		'unit', 'string', '@req',
	},
	doc = L["Return True if the unit has the Divine Intervention buff"],
	example = ('[HasDivineIntervention] => %q; [HasDivineIntervention] => ""'):format(L["True"]),
	category = L["Auras"]
})

DogTag:AddTag("Unit", "HasDebuffType", {
	code = function(type, unit)
		return currentDebuffTypes[unit][type]
	end,
	arg = {
		'type', 'string', '@req',
		'unit', 'string', '@req',
	},
	ret = "boolean",
	events = "Aura#$unit#$type",
	doc = L["Return True if friendly unit is has a debuff of type"],
	example = ('[HasDebuffType(Poison)] => %q; [HasDebuffType(Poison)] => ""'):format(L["True"]),
	category = L["Auras"],
})

DogTag:AddTag("Unit", "HasMagicDebuff", {
	alias = ("HasDebuffType(type=%q, unit=unit)"):format(L["Magic"]),
	arg = {
		'unit', 'string', '@req',
	},
	doc = L["Return True if the unit has a Magic debuff"],
	example = ('[HasMagicDebuff] => %q; [HasMagicDebuff] => ""'):format(L["True"]),
	category = L["Auras"]
})

DogTag:AddTag("Unit", "HasCurseDebuff", {
	alias = ("HasDebuffType(type=%q, unit=unit)"):format(L["Curse"]),
	arg = {
		'unit', 'string', '@req',
	},
	doc = L["Return True if the unit has a Curse debuff"],
	example = ('[HasCurseDebuff] => %q; [HasCurseDebuff] => ""'):format(L["True"]),
	category = L["Auras"]
})

DogTag:AddTag("Unit", "HasPoisonDebuff", {
	alias = ("HasDebuffType(type=%q, unit=unit)"):format(L["Poison"]),
	arg = {
		'unit', 'string', '@req',
	},
	doc = L["Return True if the unit has a Poison debuff"],
	example = ('[HasPoisonDebuff] => %q; [HasPoisonDebuff] => ""'):format(L["True"]),
	category = L["Auras"]
})

DogTag:AddTag("Unit", "HasDiseaseDebuff", {
	alias = ("HasDebuffType(type=%q, unit=unit)"):format(L["Disease"]),
	arg = {
		'unit', 'string', '@req',
	},
	doc = L["Return True if the unit has a Disease debuff"],
	example = ('[HasDiseaseDebuff] => %q; [HasDiseaseDebuff] => ""'):format(L["True"]),
	category = L["Auras"]
})

end