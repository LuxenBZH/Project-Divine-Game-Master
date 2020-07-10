---- Talents ----
---@param character EsvCharacter
---@param talent string
---@param unlocked boolean
function CheckBoostTalents(character, talent, unlocked)
	Ext.Print("Talent ",talent," changed :",unlocked)
	if unlocked == 1 then
		unlocked = true
	else
		unlocked = false
	end
	
	if talent == "Resurrection" then
		Ext.Print("[LXGDM_Talents.CheckBoostTalents] Check Talents after resurrection...")
		CheckAllTalents(character)
	end
	
	if talent == "Demon" then
		BoostFromTalentInt(character, "LX_DEMON", unlocked)
	elseif talent == "IceKing" then
		BoostFromTalentInt(character, "LX_ICEKING", unlocked)
	elseif talent == "Leech" then
		BoostFromTalentInt(character, "LX_LEECH", unlocked)
	elseif talent == "Stench" then
		BoostFromTalentInt(character, "LX_STENCH", unlocked)
	elseif talent == "AnimalEmpathy" then
		BoostFromTalentInt(character, "LX_PETPALSUMMONER", unlocked)
	elseif talent == "ResurrectToFullHealth" then
		BoostFromTalentInt(character, "LX_MORNINGPERSON", unlocked)
	elseif talent == "NoAttackOfOpportunity" then
		BoostFromTalentInt(character, "LX_DDGOOSE", unlocked)
	elseif talent == "Memory" then
		ManageMemory(character, unlocked)
	elseif talent == "Perfectionist" then
		CheckHothead(character)
	end
end

---@param character EsvCharacter
---@param unlocked boolean
function ManageMemory(character, unlocked)
	if unlocked then
		InitCharacterStatCheck(character)
	else
		local memBonus = NRD_CharacterGetPermanentBoostInt(character, "Memory")
		local mem = CharacterGetBaseAttribute(character, "Memory") - 10 - memBonus
		if memBonus == mem then
			NRD_CharacterSetPermanentBoostInt(character, "Memory", 0)
		else
			NRD_CharacterSetPermanentBoostInt(character, "Memory", memBonus - mem)
		end
		CharacterAddAttribute(character, "Dummy", 0)
	end
end

---@param character EsvCharacter
function CheckAllTalents(character)
	local boostedTalents = {
		"Demon",
		"IceKing",
		"Leech",
		"Stench",
		"AnimalEmpathy",
		"ResurrectToFullHealth",
		"NoAttackOfOpportunity"
	}
	for i,talent in pairs(boostedTalents) do
		local hasTalent = CharacterHasTalent(character, talent)
		--print("[LXDGM_Talents.CheckAllTalents] Character has talent:",talent,hasTalent)
		if hasTalent == 1 then CheckBoostTalents(character, talent, 1) end
	end
	if CharacterHasTalent(character, "ExtraStatPoints") == 1 then CheckDuelist(character) end
end

---@param character EsvCharacter
function CheckDuelist(character)
	local mainHand = Ext.GetCharacter(character).Stats.MainWeapon
	--Ext.Print("[LXDGM_Talents.CheckDuelist] Main hand :",mainHand)
	local offhand = Ext.GetCharacter(character).Stats.OffHandWeapon
	local shield = CharacterGetEquippedShield(character)
	if offhand ~= nil or (mainHand ~= nil and mainHand.IsTwoHanded) or mainHand.WeaponType == "None" or shield ~= nil then
		RemoveStatus(character, "LX_DUELIST")
	else
		ApplyStatus(character, "LX_DUELIST", -1.0, 1)
	end
end

---@param character EsvCharacter
---@param status string
---@param unlocked boolean
function BoostFromTalentInt(character, status, unlocked)
	if unlocked then
		ApplyStatus(character, status, -1.0, 1)
	else
		RemoveStatus(character, status)
	end
end

---@param target EsvCharacter
---@param handle string
function SetWalkItOff(target, handle)
	-- Call this function during damage control to potentially apply Walk It Off bonus
	local hasTalent = CharacterHasTalent(target, "WalkItOff")
	-- Ext.Print("Target has WalkItOff: ",hasTalent)
	if hasTalent == 1 then
		local hitType = NRD_StatusGetInt(target, handle, "HitType")
		if hitType ~= 4 then WalkItOffReplacement(target) end
	end
end

---@param character EsvCharacter
function WalkItOffReplacement(character)
	local hasStatus = 0
	local wioStates = {"LX_WALKITOFF", "LX_WALKITOFF_2", "LX_WALKITOFF_3"}
	local reapply = false
	for i,stage in pairs(wioStates) do
		if reapply == true then
			ApplyStatus(character, stage, 6.0)
			return 
		end
		hasStatus = HasActiveStatus(character, stage)
		--Ext.Print("Has ",stage, ": ", hasStatus)
		if hasStatus == 1 then reapply = true end
		if stage == "LX_WALKITOFF_5" then return end
	end
	ApplyStatus(character, "LX_WALKITOFF", 6.0)
end

---@param character EsvCharacter
function CheckHothead(character)
	local HPperc = Ext.Round(NRD_CharacterGetStatInt(character, "CurrentVitality") / NRD_CharacterGetStatInt(character, "MaxVitality") * 100)
	--Ext.Print(HPperc)
	if HPperc > Ext.ExtraData.DGM_HotheadApplicationThreshold then ApplyStatus(character, "LX_HOTHEAD", -1.0, 1) end
end

---@param character EsvCharacter
---@param skill string
---@param cooldown number
function ManageAllSkilledUp(character, skill, cooldown)
	local hasUsedSkill = GetVarInteger(character, "LX_AllSkilledUp_Counter")
	if hasUsedSkill == 0 and cooldown > 6.0 then
		NRD_SkillSetCooldown(character, skill, (cooldown-6.0))
		SetVarInteger(character, "LX_AllSkilledUp_Counter", 1)
	end
end

---@param character EsvCharacter
---@param summon any
function ManagePetPal(character, summon)
	local summons = Osi.DB_DGM_Available_Summons:Get(character, nil);
	if summons[1] ~= nil and summons[2] ~= nil then
		ApplyStatus(summons[1][2], "LX_PETPAL", -1.0, 1)
		ApplyStatus(summons[2][2], "LX_PETPAL", -1.0, 1)
	end
end

---@param character EsvCharacter
---@param summon any
function RestorePetPalPower(character, summon)
	-- Call this function on DB remove of the second summon
	local summons = Osi.DB_DGM_Available_Summons:Get(character, nil)
	if summons[1] == nil then return end
	RemoveStatus(summons[1][2], "LX_PETPAL")
end