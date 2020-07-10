--Ext.Require("NRD_SkillMath.lua")
Ext.Require("LXDGM_StatsPatching.lua")
Ext.Require("LXDGM_Helpers.lua")
Ext.Require("LXDGM_Tooltips.lua")
--Ext.AddPathOverride("Public\\Game\\GUI\\enemyHealthBar.swf", "Public\\lx_enhanced_divine_combat_3ff156e2-289e-4dac-81f5-a44e3e304163\\Game\\GUI\\characterSheet.swf")

local DamageSourceCalcTable = {
	BaseLevelWeaponDamage = function(attacker, target, level)
		return Ext.Round(Game.Math.GetLevelScaledWeaponDamage(level))
	end,
    BaseLevelDamage = function (attacker, target, level)
        return Ext.Round(Game.Math.GetLevelScaledDamage(level))
    end,
    AverageLevelDamge = function (attacker, target, level)
        return Ext.Round(Game.Math.GetAverageLevelDamage(level))
    end,
    MonsterWeaponDamage = function (attacker, target, level)
        return Ext.Round(Game.Math.GetLevelScaledMonsterWeaponDamage(level))
    end,
    SourceMaximumVitality = function (attacker, target, level)
        return attacker.MaxVitality
    end,
    SourceMaximumPhysicalArmor = function (attacker, target, level)
        return attacker.MaxArmor
    end,
    SourceMaximumMagicArmor = function (attacker, target, level)
        return attacker.MaxMagicArmor
    end,
    SourceCurrentVitality = function (attacker, target, level)
        return attacker.CurrentVitality
    end,
    SourceCurrentPhysicalArmor = function (attacker, target, level)
        return attacker.CurrentArmor
    end,
    SourceCurrentMagicArmor = function (attacker, target, level)
        return attacker.CurrentMagicArmor
    end,
    SourceShieldPhysicalArmor = function (attacker, target, level)
        return Ext.Round(Game.Math.GetShieldPhysicalArmor(attacker))
    end,
    TargetMaximumVitality = function (attacker, target, level)
        return target.MaxVitality
    end,
    TargetMaximumPhysicalArmor = function (attacker, target, level)
        return target.MaxArmor
    end,
    TargetMaximumMagicArmor = function (attacker, target, level)
        return target.MaxMagicArmor
    end,
    TargetCurrentVitality = function (attacker, target, level)
        return target.CurrentVitality
    end,
    TargetCurrentPhysicalArmor = function (attacker, target, level)
        return target.CurrentArmor
    end,
    TargetCurrentMagicArmor = function (attacker, target, level)
        return target.CurrentMagicArmor
    end
}

---@param skillDamageType string
---@param attacker StatCharacter
---@param target StatCharacter
---@param level integer
local function CalculateBaseDamage(skillDamageType, attacker, target, level)
    return DamageSourceCalcTable[skillDamageType](attacker, target, level)
end

---@param character StatCharacter
---@param weapon StatEntryWeapon
local function CalculateWeaponDamageRange(character, weapon)
    local damages, damageBoost = Game.Math.ComputeBaseWeaponDamage(weapon)

    local abilityBoosts = character.DamageBoost 
        + Game.Math.ComputeWeaponCombatAbilityBoost(character, weapon)
        + Game.Math.ComputeWeaponRequirementScaledDamage(character, weapon)
    abilityBoosts = math.max(abilityBoosts + 100.0, 0.0) / 100.0

    local boost = 1.0 + damageBoost * 0.01
    -- if character.NotSneaking then
        -- boost = boost + Ext.ExtraData['Sneak Damage Multiplier']
    -- end

    local ranges = {}
    for damageType, damage in pairs(damages) do
        local min = damage.Min * boost * abilityBoosts
		local max = damage.Max * boost * abilityBoosts
		--Ext.Print(min, max)

        if min > max then
            max = min
        end

        ranges[damageType] = {min, max}
    end

    return ranges
end

---@param character StatCharacter
---@param skill StatEntrySkillData
local function GetSkillDamageRange(character, skill)
    local desc = skill.StatsDescriptionParams

	--Ext.Print(skill.DamageMultiplier)
    local damageMultiplier = skill['Damage Multiplier'] * 0.01
    if desc:find("Skill:") ~= nil then
        local skillStat = desc:gsub("^[A-z]*:", ""):gsub(":.*", "")
        local skillDamage = Ext.StatGetAttribute(skillStat, "Damage")
        skill.DamageType = Ext.StatGetAttribute(skillStat, "DamageType")
        damageMultiplier = Ext.StatGetAttribute(skillStat, "Damage Multiplier")*0.01
        skill["Damage Range"] = Ext.StatGetAttribute(skillStat, "Damage Range")
        skill.UseWeaponDamage = Ext.StatGetAttribute(skillStat, "UseWeaponDamage")
    end

    local amplifierMult = 1.0
    if character.MainWeapon.WeaponType == "Staff" then
        amplifierMult = amplifierMult + 0.1
    elseif character.MainWeapon.WeaponType == "Wand" then
        amplifierMult = amplifierMult + 0.025
    end
    if character.OffHandWeapon ~= nil then
        if character.OffHandWeapon.WeaponType == "Wand" then amplifierMult = amplifierMult + 0.025 end
    end

	if skill.UseWeaponDamage == "Yes" then
		local mainWeapon = character.MainWeapon
        local mainDamageRange = CalculateWeaponDamageRange(character, mainWeapon)
		local offHandWeapon = character.OffHandWeapon

        if offHandWeapon ~= nil and Game.Math.IsRangedWeapon(mainWeapon) == Game.Math.IsRangedWeapon(offHandWeapon) then
            local offHandDamageRange = CalculateWeaponDamageRange(character, offHandWeapon)

            local dualWieldPenalty = Ext.ExtraData.DualWieldingDamagePenalty
            for damageType, range in pairs(offHandDamageRange) do
                local min = range[1] * dualWieldPenalty
                local max = range[2] * dualWieldPenalty
                if mainDamageRange[damageType] ~= nil then
                    mainDamageRange[damageType][1] = mainDamageRange[damageType][1] + min
                    mainDamageRange[damageType][2] = mainDamageRange[damageType][2] + max
                else
                    mainDamageRange[damageType] = {min, max}
                end
            end
        end
		
		local globalMult = 1 + (character.Strength-10) * (Ext.ExtraData.DGM_StrengthGlobalBonus*0.01 + Ext.ExtraData.DGM_StrengthWeaponBonus*0.01) +
		(character.Finesse-10) * (Ext.ExtraData.DGM_FinesseGlobalBonus*0.01) +
		(character.Intelligence-10) * (Ext.ExtraData.DGM_IntelligenceGlobalBonus*0.01 + Ext.ExtraData.DGM_IntelligenceSkillBonus*0.01)
        for damageType, range in pairs(mainDamageRange) do
            local min = Ext.Round(range[1] * damageMultiplier * globalMult)
            local max = Ext.Round(range[2] * damageMultiplier * globalMult)
            range[1] = min + math.ceil(min * Game.Math.GetDamageBoostByType(character, damageType) * amplifierMult)
            range[2] = max + math.ceil(max * Game.Math.GetDamageBoostByType(character, damageType) * amplifierMult)
        end

        local damageType = skill.DamageType
        if damageType ~= "None" and damageType ~= "Sentinel" then
            local min, max = 0, 0
            for damageType, range in pairs(mainDamageRange) do
                min = min + range[1]
                max = max + range[2]
				
            end

            mainDamageRange = {}
            mainDamageRange[damageType] = {min, max}
        end
		--Ext.Print("Use Weapon")
        return mainDamageRange
	else
		local skillDamageType = skill.Damage
		local desc = skill.StatsDescriptionParams
		if desc:find("Weapon:") ~= nil then
			local damageConvert = {
				"BaseLevelWeaponDamage",
				"AverageLevelDamge",
				"MonsterWeaponDamage"
			}
			local weaponStat = desc:gsub("^[A-z]*:", ""):gsub(":.*", "")
			local weaponDamage = Ext.StatGetAttribute(weaponStat, "Damage")
			if weaponDamage > 2 then return end
			skillDamageType = damageConvert[tonumber(weaponDamage)+1]
			skill.DamageType = Ext.StatGetAttribute(weaponStat, "Damage Type")
			damageMultiplier = Ext.StatGetAttribute(weaponStat, "DamageFromBase")*0.01
			skill["Damage Range"] = Ext.StatGetAttribute(weaponStat, "Damage Range")
        end
        local damageType = skill.DamageType
        if damageMultiplier <= 0 then
            return {}
        end

        local level = character.Level
        if (level < 0 or skill.OverrideSkillLevel == "Yes") and skill.Level > 0 then
            level = skill.Level
        end
        
        local attrDamageScale
        if skillDamageType == "BaseLevelDamage" or skillDamageType == "AverageLevelDamge" then
            attrDamageScale = Game.Math.GetSkillAttributeDamageScale(skill, character)
        else
            attrDamageScale = 1.0
        end
		--Ext.Print("Damage:", skillDamageType)
		
		local globalMult = 1.0
		
		if skill.StatsDescriptionParams:find("Weapon:") ~= nil then
			local weaponStat = skill.StatsDescriptionParams:gsub("^[A-z]*:", ""):gsub(":.*", "")
			globalMult = 1 + (character.Strength-10) * (Ext.ExtraData.DGM_StrengthGlobalBonus*0.01 + Ext.ExtraData.DGM_StrengthWeaponBonus*0.01) +
		(character.Finesse-10) * (Ext.ExtraData.DGM_FinesseGlobalBonus*0.01) +
		(character.Intelligence-10) * (Ext.ExtraData.DGM_IntelligenceGlobalBonus*0.01)
		else
			globalMult = 1 + (character.Strength-10) * (Ext.ExtraData.DGM_StrengthGlobalBonus*0.01) +
		(character.Finesse-10) * (Ext.ExtraData.DGM_FinesseGlobalBonus*0.01) +
		(character.Intelligence-10) * (Ext.ExtraData.DGM_IntelligenceGlobalBonus*0.01 + Ext.ExtraData.DGM_IntelligenceSkillBonus*0.01)
		end
		--Ext.Print("Global mult", globalMult, skillDamageType)
		
        local baseDamage = CalculateBaseDamage(skillDamageType, character, 0, level) * attrDamageScale * damageMultiplier * globalMult
        local damageRange = skill['Damage Range'] * baseDamage * 0.005

        local damageType = skill.DamageType
        local damageTypeBoost = 1.0 + Game.Math.GetDamageBoostByType(character, damageType)
        local damageBoost = 1.0 + (character.DamageBoost / 100.0)
        local damageRanges = {}
        damageRanges[damageType] = {
            math.ceil(math.ceil(Ext.Round(baseDamage - damageRange) * damageBoost) * damageTypeBoost * amplifierMult),
            math.ceil(math.ceil(Ext.Round(baseDamage + damageRange) * damageBoost) * damageTypeBoost * amplifierMult)
        }
        return damageRanges
    end
end

---@param dmgType string
local function getDamageColor(dmgType)
	local colorCode = ""
	local types = {}
	types["Physical"]="'#A8A8A8'"
	types["Corrosive"]="'#454545'"
	types["Magic"]="'#7F00FF'"
	types["Fire"]="'#FE6E27'"
	types["Water"]="'#4197E2'"
	types["Earth"]="'#7F3D00'"
	types["Poison"]="'#65C900'"
	types["Air"]="'#7D71D9'"
	types["Shadow"]="'#797980'"
	types["Piercing"]="'#C80030'"
	
	for t,code in pairs(types) do
		if dmgType == t then return code end
	end
	return "'#A8A8A8'"
end

---@param status EsvStatus
---@param statusSource EsvGameObject
---@param character StatCharacter
---@param par string
local function StatusGetDescriptionParam(status, statusSource, character, par)
    
    if par == "Damage" then
		local dmgStat = Ext.GetStat(status.DamageStats)
		local globalMult = 1 + (statusSource.Strength-10) * (Ext.ExtraData.DGM_StrengthDoTBonus*0.01) --From the overhaul
		if dmgStat.Damage == 1 then
			dmg = Game.Math.GetAverageLevelDamage(character.Level)
		elseif dmgStat.Damage == 0 and dmgStat.BonusWeapon == nil then
			dmg = Game.Math.GetLevelScaledDamage(character.Level)
		else
			dmg = Game.Math.GetLevelScaledWeaponDamage(character.Level)
		end
		--Ext.Print("AverageLevelDamage "..Game.Math.GetAverageLevelDamage(character.Level))
		dmg = dmg*(dmgStat.DamageFromBase/100)
		dmgRange = dmg*(dmgStat["Damage Range"])*0.005
		--Ext.Print(dmg, dmgRange, globalMult)
		local minDmg = math.floor(Ext.Round(dmg - dmgRange * globalMult))
		local maxDmg = math.floor(Ext.Round(dmg + dmgRange * globalMult))
		if maxDmg <= minDmg then maxDmg = maxDmg+1 end
		local color = getDamageColor(dmgStat["Damage Type"])
		--Ext.Print(minDmg, maxDmg)
		return "<font color="..color..">"..tostring(minDmg).."-"..tostring(maxDmg).." "..dmgStat["Damage Type"].." damage".."</font>"
	end
	return nil
end

-- Odinblade compatibility
Game.Math.GetSkillDamageRange = GetSkillDamageRange

local SkillGetDescriptionParamForbidden = {"Projectile_OdinHUN_HuntersTrap", "Target_ElementalArrowheads", "Projectile_OdinHUN_TheHunt"}

---@param skill StatEntrySkillData
---@param character StatCharacter
---@param isFromItem boolean
---@param par string
local function SkillGetDescriptionParam(skill, character, isFromItem, par)
	--Ext.Print(skill.Damage, skill.DamageMultiplier)
	-- Ext.Print("BaseLevelDamage:",Game.Math.GetLevelScaledDamage(character.Level))
	-- Ext.Print("AverageLevelDamage:",Game.Math.GetAverageLevelDamage(character.Level))
	-- Ext.Print("LevelScaledMonsterWeaponDamage:", Game.Math.GetLevelScaledMonsterWeaponDamage(character.Level))
    -- Ext.Print("LevelScaledWeaponDamage:", Game.Math.GetLevelScaledWeaponDamage(character.Level))
    for _, name in pairs(SkillGetDescriptionParamForbidden) do
        if name == skill.Name then
            return nil
        end
    end

	local pass = false
	local desc = skill.StatsDescriptionParams
	if desc:find("Weapon:") ~= nil or desc:find("Skill:") then
		pass = true
	end
    if par == "Damage" or pass then
		if skill.Damage ~= "BaseLevelDamage" and skill.Damage ~= "AverageLevelDamge" then return nil end
		local dmg = GetSkillDamageRange(character, skill)
		local result = ""
		local once = false
		
		for dmgType, damages in pairs(dmg) do
			local minDmg = math.floor(damages[1])
			local maxDmg = math.floor(damages[2])
			local color = getDamageColor(dmgType)
			if not once then
				result = result.."<font color="..color..">"..tostring(minDmg).."-"..tostring(maxDmg).." "..dmgType.." damage".."</font>"
				once = true
			else
				result = result.." + ".."<font color="..color..">"..tostring(minDmg).."-"..tostring(maxDmg).." "..dmgType.." damage".."</font>"
			end
        end
        return result
	end
	return nil
end

local DamageTypes = {
    None = 0,
    Physical = 1,
    Piercing = 2,
    Corrosive = 3,
    Magic = 4,
    Chaos = 5,
    Fire = 6,
    Air = 7,
    Water = 8,
    Earth = 9,
    Poison = 10,
    Shadow = 11
}

------ UI Values

---@param ui UIObject
---@param call string
---@param state any
local function changeDamageValue(ui, call, state)

    if ui:GetValue("secStat_array", "string", 2) == nil then return end
    
    local strength = ui:GetValue("primStat_array", "string", 2):gsub('<font color="#00547F">', ""):gsub("</font>", "")
    strength = tonumber(strength) - Ext.ExtraData.AttributeBaseValue
    local finesse = ui:GetValue("primStat_array", "string", 6):gsub('<font color="#00547F">', ""):gsub("</font>", "")
    finesse = tonumber(finesse)  - Ext.ExtraData.AttributeBaseValue
    local intelligence = ui:GetValue("primStat_array", "string", 10):gsub('<font color="#00547F">', ""):gsub("</font>", "")
    intelligence = tonumber(intelligence) - Ext.ExtraData.AttributeBaseValue
    
    local damage = ui:GetValue("secStat_array", "string", 24)
    Ext.Print(damage)
    
    local minDamage = damage:gsub(" - .*", "")
    local maxDamage = damage:gsub(".* - ", "")
    local globalMult = 100 + strength * Ext.ExtraData.DGM_StrengthGlobalBonus + strength * Ext.ExtraData.DGM_StrengthWeaponBonus +
        finesse * Ext.ExtraData.DGM_FinesseGlobalBonus + intelligence * Ext.ExtraData.DGM_IntelligenceGlobalBonus

    minDamage = math.floor(tonumber(minDamage) * globalMult * 0.01)
    maxDamage = math.floor(tonumber(maxDamage) * globalMult * 0.01)

    ui:SetValue("secStat_array", minDamage.." - "..maxDamage, 24)
end

local dynamicTooltips = {
    ["Strength"] = "he1708d1eg243dg4b72g8f48gddb9bc8d62ff",
    ["Finesse"] = "h2e87e6cfg0183g4968g8ec1g325614c7d9fa",
    ["Intelligence"] = "h58e777ddgd569g4c0dg8f58gece56cce053d",
    ["Damage"] = "h7fec5db8g58d3g4abbgab7ag03e19b542bef",
    ["Dual-Wielding"] = {current = "hc5d5552bg6b33g44c1gbb0cg8d55a101f081", new = "h2baa6ed9gdca0g4731gb999g098d9c2d90b0"},
    ["Ranged"] = {current = "he86bfd28ge123g42a4g8c0cg2f9bcd7d9e05", new = "hffc37ae5g6651g4a60ga1c1g49d233cb1ca2"},
    ["Single-Handed"] = {current = "h70707bb2g5a48g4571g9a68ged2fe5a030ea", new = "h2afdc1f0g4650g4ea9gafb7gb0c042367766"},
    ["Two-Handed"] = {current = "h6e9ec88dgcbb7g426bgb1d9g69df0240825a", new = "hda7ee9a4g5bbeg4c62g96b7ge31b21e094f3"},
    ["Perseverance"] = {current = "h5d0c3ad0g3d9dg4cf1g92b7g20d6d7d26344", new = "h443a51dcgbd6fg46c2g8988gbfe93a3123a5"}
}

---@param str string
local function SubstituteString(str, ...)
    local args = {...}
    local result = str
    for k, v in pairs(args) do
        result = result:gsub("%["..tostring(k).."%]", v)
    end
    return result
end

---@param character EsvCharacter
---@param skill string
---@param tooltip TooltipData
local function OnStatTooltip(character, stat, tooltip)

    -- Ext.Print(Ext.JsonStringify(tooltip))
    
    local stat = tooltip:GetElement("StatName").Label
    local statsPointValue = tooltip:GetElement("StatsPointValue")

    local attrBonus = CharGetDGMAttributeBonus(character, 0)

    local str = nil
    if dynamicTooltips[stat] then
        str = Ext.GetTranslatedString(dynamicTooltips[stat], "Handle Error!")
    end

    if stat == "Strength" then
        str = SubstituteString(str, attrBonus["str"], attrBonus["strGlobal"], attrBonus["strWeapon"], attrBonus["strDot"])
        statsPointValue.Label = str
    elseif stat == "Finesse" then
        str = SubstituteString(str, attrBonus["fin"], attrBonus["finGlobal"], attrBonus["finDodge"], attrBonus["finMovement"])
        statsPointValue.Label = str
    elseif stat == "Intelligence" then
        str = SubstituteString(str, attrBonus["int"], attrBonus["intGlobal"], attrBonus["intSkill"], attrBonus["intAcc"])
        statsPointValue.Label = str
    elseif stat == "Damage" then
        local damageText = tooltip:GetElement("StatsTotalDamage")
        local minDamage = damageText.Label:gsub("^.* ", ""):gsub("-[1-9]*", "")
        local maxDamage = damageText.Label:gsub("^.*-", "")
        
        minDamage = math.floor(tonumber(minDamage) * (100+attrBonus["strGlobal"]+attrBonus["strWeapon"]+attrBonus["finGlobal"]+attrBonus["intGlobal"])/100)
        maxDamage = math.floor(tonumber(maxDamage) * (100+attrBonus["strGlobal"]+attrBonus["strWeapon"]+attrBonus["finGlobal"]+attrBonus["intGlobal"])/100)
        
        str = SubstituteString(str, minDamage, maxDamage)
        damageText.Label = str
    end

    -- Ext.Print(Ext.JsonStringify(tooltip))
end

---@param character EsvCharacter
---@param stat string
---@param tooltip TooltipData
local function OnAbilityTooltip(character, stat, tooltip)
    
    local stat = tooltip:GetElement("StatName").Label
    local abilityDescription = tooltip:GetElement("AbilityDescription")
    local attrBonus = CharGetDGMAttributeBonus(character, 0)
    local attrBonusNew = CharGetDGMAttributeBonus(character, 1)
    local stats = character.Stats

    local str = ""

    if stat == "Dual-Wielding" then

        if stats.DualWielding > 0 then
            str = Ext.GetTranslatedString(dynamicTooltips[stat].current, "Handle Error!")
            str = SubstituteString(str, stats.DualWielding, attrBonus["dual"], attrBonus["dualDodge"], attrBonus["dualOff"])
            abilityDescription.CurrentLevelEffect = str
        end
        
        str = Ext.GetTranslatedString(dynamicTooltips[stat].new, "Handle Error!")
        str = SubstituteString(str, stats.DualWielding+1, attrBonusNew["dual"], attrBonusNew["dualDodge"], attrBonusNew["dualOff"])
        abilityDescription.NextLevelEffect = str
        
    elseif stat == "Ranged" then
        if stats.Ranged > 0 then
            str = Ext.GetTranslatedString(dynamicTooltips[stat].current, "Handle Error!")
            str = SubstituteString(str, stats.Ranged, attrBonus["ranged"], attrBonus["rangedCrit"], attrBonus["rangedRange"])
            abilityDescription.CurrentLevelEffect = str
        end
        
        str = Ext.GetTranslatedString(dynamicTooltips[stat].new, "Handle Error!")
        str = SubstituteString(str, stats.Ranged+1, attrBonusNew["ranged"], attrBonusNew["rangedCrit"], attrBonusNew["rangedRange"])
        abilityDescription.NextLevelEffect = str

    elseif stat == "Single-Handed" then
        if stats.SingleHanded > 0 then
            str = Ext.GetTranslatedString(dynamicTooltips[stat].current, "Handle Error!")
            str = SubstituteString(str, stats.SingleHanded, attrBonus["single"], attrBonus["singleAcc"], attrBonus["singleArm"], attrBonus["singleEle"])
            abilityDescription.CurrentLevelEffect = str
        end
        
        str = Ext.GetTranslatedString(dynamicTooltips[stat].new, "Handle Error!")
        str = SubstituteString(str, stats.SingleHanded+1, attrBonusNew["single"], attrBonusNew["singleAcc"], attrBonusNew["singleArm"], attrBonusNew["singleEle"])
        abilityDescription.NextLevelEffect = str
        
    elseif stat == "Two-Handed" then
        if stats.TwoHanded > 0 then
            str = Ext.GetTranslatedString(dynamicTooltips[stat].current, "Handle Error!")
            str = SubstituteString(str, stats.TwoHanded, attrBonus["two"], attrBonus["twoCrit"], attrBonus["twoAcc"])
            abilityDescription.CurrentLevelEffect = str
        end
        
        str = Ext.GetTranslatedString(dynamicTooltips[stat].new, "Handle Error!")
        str = SubstituteString(str, stats.TwoHanded+1, attrBonusNew["two"], attrBonusNew["twoCrit"], attrBonusNew["twoAcc"])
        abilityDescription.NextLevelEffect = str

    elseif stat == "Perseverance" then
        if stats.Perseverance > 0 then
            str = Ext.GetTranslatedString(dynamicTooltips[stat].current, "Handle Error!")
            str = SubstituteString(str, stats.Perseverance, attrBonus["persArm"], attrBonus["persVit"])
            abilityDescription.CurrentLevelEffect = str
        end
        
        str = Ext.GetTranslatedString(dynamicTooltips[stat].new, "Handle Error!")
        str = SubstituteString(str, stats.Perseverance+1, attrBonusNew["persArm"], attrBonusNew["persVit"])
        abilityDescription.NextLevelEffect = str

    end

    -- Ext.Print(Ext.JsonStringify(tooltip))
end

local function DGM_SetupUI()
    local charSheet = Ext.GetBuiltinUI("Public/Game/GUI/characterSheet.swf")
    
    Ext.RegisterUIInvokeListener(charSheet, "updateArraySystem", changeDamageValue)
    Game.Tooltip.RegisterListener("Stat", nil, OnStatTooltip)
    Game.Tooltip.RegisterListener("Ability", nil, OnAbilityTooltip)

end

Ext.RegisterListener("SessionLoaded", DGM_SetupUI)
--Ext.Print("Registering SessionLoaded for SetupUI")

Ext.RegisterListener("SkillGetDescriptionParam", SkillGetDescriptionParam)
--Ext.Print("Registering SkillGetDescripitonParam")

Ext.RegisterListener("StatusGetDescriptionParam", StatusGetDescriptionParam)
--Ext.Print("Registering StatusGetDescriptionParam")
