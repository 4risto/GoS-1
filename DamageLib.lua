--[[
Version: 11.5

Usage:

require "DamageLib"

local Rdamage = getdmg("R",target,source)
-------------------------------------------------------

params:

getdmg("SKILL",target,source,stagedmg,spelllvl)

Test edit by Series
]]

print("DamageLib 11.5 loaded")

local DamageReductionTable = {
  ["Braum"] = {buff = "BraumShieldRaise", amount = function(target) return 1 - ({0.3, 0.325, 0.35, 0.375, 0.4})[target:GetSpellData(_E).level] end},
  ["Urgot"] = {buff = "urgotswapdef", amount = function(target) return 1 - ({0.3, 0.4, 0.5})[target:GetSpellData(_R).level] end},
  ["Alistar"] = {buff = "Ferocious Howl", amount = function(target) return ({0.55, 0.65, 0.75})[target:GetSpellData(_R).level] end},
  --["Amumu"] = {buff = "Tantrum", amount = function(target) return ({2, 4, 6, 8, 10})[target:GetSpellData(_E).level] + 0.03*target.bonusMagicResist + 0.03*target.bonusArmor end, damageType = 1},
  ["Galio"] = {buff = "GalioIdolOfDurand", amount = function(target) return 0.5 end},
  ["Garen"] = {buff = "GarenW", amount = function(target) return 0.3 end},
  ["Gragas"] = {buff = "GragasWSelf", amount = function(target) return ({0.1, 0.12, 0.14, 0.16, 0.18})[target:GetSpellData(_W).level] + 0.04 * target.ap / 100 end},
  ["Annie"] = {buff = "MoltenShield", amount = function(target) return 1 - ({0.10,0.13,0.16,0.19,0.22})[target:GetSpellData(_E).level] end},
  ["Malzahar"] = {buff = "malzaharpassiveshield", amount = function(target) return 0.9 end}
}

function GetPercentHP(unit)
  return 100 * unit.health / unit.maxHealth
end

function string.ends(String,End)
  return End == "" or string.sub(String,-string.len(End)) == End
end

function GetItemSlot(unit, id)
  for i = ITEM_1, ITEM_7 do
    if unit:GetItemData(i).itemID == id then
      return i
    end
  end
  return 0
end

function GotBuff(unit, buffname)
  for i = 0, unit.buffCount do
    local buff = unit:GetBuff(i)
    if buff.name == buffname and buff.count > 0 then 
      return buff.count
    end
  end
  return 0
end

function GotSpell(spellslot, spellname)
    if myHero:GetSpellData(spellslot).name == spellname then
      return 1
    end
    return 0
end

function GetBuffData(unit, buffname)
  for i = 0, unit.buffCount do
    local buff = unit:GetBuff(i)
    if buff.name == buffname and buff.count > 0 then 
      return buff
    end
  end
  return {type = 0, name = "", startTime = 0, expireTime = 0, duration = 0, stacks = 0, count = 0}
end

local function HasPoison(unit)
	for i = 0, unit.buffCount do 
	local buff = unit:GetBuff(i)
		if buff.type == 23 and Game.Timer() < buff.expireTime - 0.141  then
			return true
		end
	end
	return false
end

function CalcPhysicalDamage(source, target, amount)
  local ArmorPenPercent = source.armorPenPercent
  local ArmorPenFlat = (0.4 + target.levelData.lvl / 30) * source.armorPen
  local BonusArmorPen = source.bonusArmorPenPercent

  if source.type == Obj_AI_Minion then
    ArmorPenPercent = 1
    ArmorPenFlat = 0
    BonusArmorPen = 1
  elseif source.type == Obj_AI_Turret then
    ArmorPenFlat = 0
    BonusArmorPen = 1
    if source.charName:find("3") or source.charName:find("4") then
      ArmorPenPercent = 0.25
    else
      ArmorPenPercent = 0.7
    end
  end

  if source.type == Obj_AI_Turret then
    if target.type == Obj_AI_Minion then
      amount = amount * 1.25
      if string.ends(target.charName, "MinionSiege") then
        amount = amount * 0.7
      end
      return amount
    end
  end

  local armor = target.armor
  local bonusArmor = target.bonusArmor
  local value = 100 / (100 + (armor * ArmorPenPercent) - (bonusArmor * (1 - BonusArmorPen)) - ArmorPenFlat)

  if armor < 0 then
    value = 2 - 100 / (100 - armor)
  elseif (armor * ArmorPenPercent) - (bonusArmor * (1 - BonusArmorPen)) - ArmorPenFlat < 0 then
    value = 1
  end
  return math.max(0, math.floor(DamageReductionMod(source, target, PassivePercentMod(source, target, value) * amount, 1)))
end

function CalcMagicalDamage(source, target, amount)
  local mr = target.magicResist
  local value = 100 / (100 + (mr * source.magicPenPercent) - source.magicPen)

  if mr < 0 then
    value = 2 - 100 / (100 - mr)
  elseif (mr * source.magicPenPercent) - source.magicPen < 0 then
    value = 1
  end
  return math.max(0, math.floor(DamageReductionMod(source, target, PassivePercentMod(source, target, value) * amount, 2)))
end

function DamageReductionMod(source,target,amount,DamageType)
  if source.type == Obj_AI_Hero then
    if GotBuff(source, "Exhaust") > 0 then
      amount = amount * 0.6
    end
  end

  if target.type == Obj_AI_Hero then

    for i = 0, target.buffCount do
      if target:GetBuff(i).count > 0 then
        local buff = target:GetBuff(i)
        if buff.name == "MasteryWardenOfTheDawn" then
          amount = amount * (1 - (0.06 * buff.count))
        end
    
        if DamageReductionTable[target.charName] then
          if buff.name == DamageReductionTable[target.charName].buff and (not DamageReductionTable[target.charName].damagetype or DamageReductionTable[target.charName].damagetype == DamageType) then
            amount = amount * DamageReductionTable[target.charName].amount(target)
          end
        end

        if target.charName == "Maokai" and source.type ~= Obj_AI_Turret then
          if buff.name == "MaokaiDrainDefense" then
            amount = amount * 0.8
          end
        end

        if target.charName == "MasterYi" then
          if buff.name == "Meditate" then
            amount = amount - amount * ({0.5, 0.55, 0.6, 0.65, 0.7})[target:GetSpellData(_W).level] / (source.type == Obj_AI_Turret and 2 or 1)
          end
        end
      end
    end

    if GetItemSlot(target, 1054) > 0 then
      amount = amount - 8
    end

    if target.charName == "Kassadin" and DamageType == 2 then
      amount = amount * 0.85
    end
  end

  return amount
end

function PassivePercentMod(source, target, amount, damageType)
  local SiegeMinionList = {"Red_Minion_MechCannon", "Blue_Minion_MechCannon"}
  local NormalMinionList = {"Red_Minion_Wizard", "Blue_Minion_Wizard", "Red_Minion_Basic", "Blue_Minion_Basic"}

  if source.type == Obj_AI_Turret then
    if table.contains(SiegeMinionList, target.charName) then
      amount = amount * 0.7
    elseif table.contains(NormalMinionList, target.charName) then
      amount = amount * 1.14285714285714
    end
  end
  if source.type == Obj_AI_Hero then 
    if target.type == Obj_AI_Hero then
      if (GetItemSlot(source, 3036) > 0 or GetItemSlot(source, 3034) > 0) and source.maxHealth < target.maxHealth and damageType == 1 then
        amount = amount * (1 + math.min(target.maxHealth - source.maxHealth, 500) / 50 * (GetItemSlot(source, 3036) > 0 and 0.015 or 0.01))
      end
    end
  end
  return amount
end

local function GetBaseHealth(unit)
    if unit.charName == "Sylas" then
        return 504.73 + 80.27 * myHero.levelData.lvl
    
    elseif unit.charName == "Chogath" then
        return 574.04 + 80 * myHero.levelData.lvl
		
    elseif unit.charName == "Volibear" then
        return 580 + 65 * myHero.levelData.lvl		
    end	
end

local DamageLibTable = {
  ["Aatrox"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({10, 30, 50, 70, 90})[level] + ({0.6, 0.65, 0.7, 0.75, 0.8})[level] * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({30, 40, 50, 60, 70})[level] + 0.4 * source.totalDamage end},
  },

  ["Ahri"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 65, 90, 115, 140})[level] + 0.35 * source.ap end},
    {Slot = "Q", Stage = 2, DamageType = 3, Damage = function(source, target, level) return ({40, 65, 90, 115, 140})[level] + 0.35 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 65, 90, 115, 140})[level] + 0.3 * source.ap end},
    {Slot = "W", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({12, 19.5, 27, 34.5, 42})[level] + 0.09 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 90, 120, 150, 180})[level] + 0.4 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 90, 120})[level] + 0.35 * source.ap end},
  },

  ["Akali"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({30, 55, 80, 105, 130})[level] + 0.6 * source.ap + 0.65 * source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 85, 120, 155, 190})[level] + 0.35 * source.ap + 0.5 * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({125, 225, 325})[level] + 0.5 * source.bonusDamage end},
  },

  ["Alistar"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 105, 150, 195, 240})[level] + 0.5 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({55, 110, 165, 220, 275})[level] + 0.7 * source.ap end},
	{Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 110, 140, 170, 200})[level] + 0.4 * source.ap end},
  },

  ["Amumu"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 130, 180, 230, 280})[level] + 0.7 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({10, 15, 20, 25, 30})[level] + (({0.01, 0.0125, 0.015, 0.0175, 0.02})[level] + 0.01 * source.ap / 100) * target.maxHealth end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 100, 125, 150, 175})[level] + 0.5 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.8 * source.ap end},
  },

  ["Anivia"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 70, 90, 110, 130})[level] + 0.25 * source.ap end},
    {Slot = "Q", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({60, 95, 130, 165, 200})[level] + 0.45 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({50, 80, 110, 140, 170})[level] + 0.5 * source.ap) * (GotBuff(target, "chilled") and 2 or 1) end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({30, 45, 60})[level] + 0.125 * source.ap end},
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({90, 135, 180})[level] + 0.375 * source.ap end},
  },

  ["Annie"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 115, 150, 185, 220})[level] + 0.8 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 115, 160, 205, 250})[level] + 0.85 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 275, 400})[level] + 0.65 * source.ap end},
  },
  
  ["Aphelios"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 85, 110, 135, 160})[level] + source.ap + 0.6 * source.bonusDamage end},
    {Slot = "Q", Stage = 2, DamageType = 2, Damage = function(source, target, level) return (({10, 15, 20, 25, 30})[level] + 0.30 * source.bonusDamage) * 6 end},
    {Slot = "Q", Stage = 3, DamageType = 2, Damage = function(source, target, level) return ({50, 65, 80, 95, 110})[level] + 0.7 * source.ap + 0.35 * source.bonusDamage end},
    {Slot = "Q", Stage = 4, DamageType = 2, Damage = function(source, target, level) return ({25, 35, 45, 55, 65})[level] + 0.7 * source.ap + 0.8 * source.bonusDamage end},
    {Slot = "Q", Stage = 5, DamageType = 2, Damage = function(source, target, level) return ({25, 40, 55, 70, 85})[level] + 0.5 * source.ap + 0.5 * source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({125, 175, 225})[level] + source.ap + 0.2 * source.bonusDamage end},
    {Slot = "R", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({175, 275, 375})[level] + source.ap + 0.45 * source.bonusDamage end},
    {Slot = "R", Stage = 3, DamageType = 1, Damage = function(source, target, level) return ({125, 175, 225})[level] + source.ap + 0.2 * source.bonusDamage + (GotSpell(_Q, "ApheliosInfernumQ") * (({50, 100, 150})[level] + 0.25 * source.bonusDamage)) end},
  }, 

  ["Ashe"] = {
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 35, 50, 65, 80})[level] + source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({200, 400, 600})[level] + source.ap end},
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return (({100, 200, 300})[level] + 0.5 * source.ap) end},
  },

  ["AurelionSol"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + 0.65 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.7 * source.ap end},
  },
  
  ["Azir"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 90, 110, 130, 150})[level] + 0.3 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({55, 60, 75, 80, 90})[level] + 0.6 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 90, 120, 150, 180})[level] + 0.4 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({175, 325, 475})[level] + 0.6 * source.ap end},
  },

  ["Blitzcrank"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 120, 170, 220, 270})[level] + source.ap end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({250, 375, 500})[level] + source.ap end},
  },

  ["Bard"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 125, 170, 215, 260})[level] + 0.65 * source.ap end},
  },

  ["Brand"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 110, 140, 170, 200})[level] + 0.55 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 120, 165, 210, 255})[level] + 0.6 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 95, 120, 145, 170})[level] + 0.45 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({100, 200, 300})[level] + 0.25 * source.ap end},
  },

  ["Braum"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 125, 175, 225, 275})[level] + 0.025 * source.maxHealth end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 300, 450})[level] + 0.6 * source.ap end},
  },

  ["Caitlyn"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({50, 90, 130, 170, 210})[level] + ({1.3, 1.4, 1.5, 1.6, 1.7})[level] * source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + 0.8 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({300, 525, 750})[level] + 2 * source.bonusDamage end},
  },
  
  ["Camille"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({0.2, 0.25, 0.3, 0.35, 0.4})[level] * source.totalDamage end},
    {Slot = "Q", Stage = 2, DamageType = 3, Damage = function(source, target, level) return ({0.2, 0.25, 0.3, 0.35, 0.4})[level] * source.totalDamage * 2 end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({70, 100, 130, 160, 190})[level] + 0.6 * source.bonusDamage end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({60, 95, 130, 165, 200})[level] + 0.75 * source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({5, 10, 15})[level] + ({0.04, 0.06, 0.08})[level] * target.health end},	
  },  

  ["Cassiopeia"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 110, 145, 180, 215})[level] + 0.9 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({20, 25, 30, 35, 40})[level] + 0.15 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return 48 + 4 * myHero.levelData.lvl + 0.1 * source.ap + (HasPoison(target) and ({10, 30, 50, 70, 90})[level] + 0.6 * source.ap or 0) end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.5 * source.ap end},
  },

  ["Chogath"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 135, 190, 245, 300})[level] + source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 125, 175, 225, 275})[level] + 0.7 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({22, 34, 46, 58, 70})[level] + 0.3 * source.ap + 0.03 * target.maxHealth end},
    {Slot = "R", Stage = 1, DamageType = 3, Damage = function(source, target, level) return ({300, 475, 650})[level] + 0.5 * source.ap + 0.1 * (myHero.maxHealth - GetBaseHealth(source)) end},
  },

  ["Corki"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 120, 165, 210, 255})[level] + 0.5 * source.ap + 0.7 * source.bonusDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({120, 180, 240, 300, 360})[level] + 0.8 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({30, 45, 60, 75, 90})[level] + (1.5 * source.totalDamage) + 0.2 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 32, 44, 56, 68})[level] + 0.4 * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({90, 125, 160})[level] + 0.2 * source.ap + ({0.15, 0.45, 0.75})[level] * source.totalDamage end},
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({180, 250, 320})[level] + 0.4 * source.ap + ({0.3, 0.90, 1.5})[level] * source.totalDamage end},
  },

  ["Darius"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({50, 80, 110, 140, 170})[level] + (({1.0, 1.1, 1.2, 1.3, 1.4})[level] * source.totalDamage) end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({0.4, 0.45, 0.5, 0.55, 0.6})[level] * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 3, Damage = function(source, target, level) return ({100, 200, 300})[level] + 0.75 * source.bonusDamage end},
  },

  ["Diana"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 95, 130, 165, 200})[level] + 0.7 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({18, 30, 42, 54, 66})[level] + 0.15 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 60, 80, 100, 120})[level] + 0.4 * source.ap end},	
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({200, 300, 400})[level] + 0.6 * source.ap end},
  },

  ["DrMundo"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) if target.type == Obj_AI_Minion then return math.min(({300, 350, 400, 450, 500})[level],math.max(({80, 130, 180, 230, 280})[level], ({20, 22.5, 25, 27.5, 30})[level] / 100 * target.health)) end; return math.max(({80, 130, 180, 230, 280})[level],({20, 22.5, 25, 27.5, 30})[level] / 100 * target.health) end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({20, 27, 35, 42, 50})[level] + 0.1 * source.ap end}
  },

  ["Draven"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({35, 40, 45, 50, 55})[level] + (({0.65, 0.75, 0.85, 0.95, 1.05})[level] * source.bonusDamage) end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({75, 110, 145, 180, 215})[level] + 0.5 * source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({175, 275, 375})[level] + ({1.1, 1.3, 1.5})[level] * source.bonusDamage end},
  },

  ["Ekko"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 75, 90, 105, 120})[level] + 0.3 * source.ap end},
    {Slot = "Q", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({40, 65, 90, 115, 140})[level] + 0.6 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 75, 100, 125, 150})[level] + 0.4 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 300, 450})[level] + 1.5 * source.ap end}
  },

  ["Elise"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 70, 100, 130, 160})[level] + (0.04 + 0.03 / 100 * source.ap) * target.health end},
    {Slot = "QM", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({70, 105, 140, 175, 210})[level] + (0.08 + 0.03 / 100 * source.ap) * (target.maxHealth - target.health) end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 105, 150, 195, 240})[level] + 0.95 * source.ap end},
  },

  ["Evelynn"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({25, 30, 35, 40, 45})[level] + 0.3 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({55, 70, 85, 100, 115})[level] + (0.03 + 0.15 / 100 * source.ap) * target.maxHealth end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({125, 250, 375})[level] + 0.75 * source.ap end},
  },

  ["Ezreal"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 45, 70, 95, 120})[level] + 0.15 * source.ap + 1.3 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 135, 190, 245, 300})[level] + (({0.7, 0.75, 0.8, 0.85, 0.9})[level] * source.ap) + 0.6 * source.bonusDamage end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 130, 180, 230, 280})[level] + 0.75 * source.ap + 0.5 * source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({350, 500, 650})[level] + 0.9 * source.ap + source.bonusDamage end},
  },

  ["Fiddlesticks"] = {
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 105, 130, 155, 180})[level] + 0.45 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 105, 140, 175, 210})[level] + 0.45 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({125, 225, 325})[level] + 0.45 * source.ap end},
  },

  ["Fiora"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({70, 80, 90, 100, 110})[level] + ({0.95, 1, 1.05, 1.1, 1.15})[level] * source.bonusDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({110, 150, 190, 230, 270})[level] + source.ap end},
  },

  ["Fizz"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({10, 25, 40, 55, 70})[level] + 0.55 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 70, 90, 110, 130})[level] + 0.5 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 120, 170, 220, 270})[level] + 0.75 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.8 * source.ap end},
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({225, 325, 425})[level] + source.ap end},
    {Slot = "R", Stage = 3, DamageType = 2, Damage = function(source, target, level) return ({300, 400, 500})[level] + 1.2 * source.ap end},
  },

  ["Galio"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 105, 140, 175, 210})[level] + 0.75 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({90, 130, 170, 210, 250})[level] + 0.9 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.7 * source.ap end},
  },

  ["Gangplank"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 45, 70, 95, 120})[level] + source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 70, 100})[level] + 0.1 * source.ap end},
  },

  ["Garen"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({30, 60, 90, 120, 150})[level] + 0.5 * source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({4, 8, 12, 16, 20})[level] + (0.471 + 0.471 * myHero.levelData.lvl) + ({32, 34, 36, 38, 40})[level] / 100 * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 3, Damage = function(source, target, level) return ({150, 300, 450})[level] + ({20, 25, 30})[level] / 100 * (target.maxHealth - target.health) end},
  },

  ["Gnar"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({5, 45, 85, 125, 165})[level] + 1.15 * source.totalDamage end},
    {Slot = "QM", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({25, 70, 115, 160, 205})[level] + 1.4 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({10, 20, 30, 40, 50})[level] + source.ap + ({6, 8, 10, 12, 14})[level] / 100 * target.maxHealth end},
    {Slot = "WM", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({25, 55, 85, 115, 145})[level] + source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({80, 115, 150, 185, 220})[level] + source.maxHealth * 0.06 end},
    {Slot = "EM", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({80, 115, 150, 185, 220})[level] + source.maxHealth * 0.06 end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({200, 300, 400})[level] + source.ap + 0.5 * source.bonusDamage end},
  },

  ["Gragas"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 120, 160, 200, 240})[level] + 0.7 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({20, 50, 80, 110, 140})[level] + 0.6 * source.ap + 0.07 * target.maxHealth end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 130, 180, 230, 280})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({200, 300, 400})[level] + 0.8 * source.ap end},
  },

  ["Graves"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({45, 60, 75, 90, 105})[level] +  0.8 * source.bonusDamage end},
    {Slot = "Q", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({85, 120, 155, 190, 225})[level] + ({0.4, 0.7, 1.0, 1.3, 1.6})[level] * source.bonusDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 110, 160, 210, 260})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({250, 400, 550})[level] + 1.5 * source.bonusDamage end},
    {Slot = "R", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({200, 320, 440})[level] + 1.2 * source.bonusDamage end},	
  },

  ["Hecarim"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({60, 102, 144, 186, 228})[level] + 0.7 * source.bonusDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({20, 30, 40, 50, 60})[level] + 0.2 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({35, 65, 95, 125, 155})[level] + 0.5 * source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + source.ap end},
  },

  ["Heimerdinger"] = {
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 80, 110, 140, 170})[level] + 0.45 * source.ap end},
    {Slot = "W", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({135, 180, 225})[source:GetSpellData(_R).level] + 0.45 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 100, 140, 180, 220})[level] + 0.6 * source.ap end},
    {Slot = "E", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({100, 200, 300})[source:GetSpellData(_R).level] + 0.6 * source.ap end},
  },
  
  ["Illaoi"] = {
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return 0.02 * source.totalDamage / 100 + ({0.03, 0.035, 0.04, 0.045, 0.05})[level] * target.maxHealth end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.5 * source.bonusDamage end},
  },  

  ["Irelia"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({5, 25, 45, 65, 85})[level] + 0.6 * source.totalDamage end},
    {Slot = "Q", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({60, 100, 140, 180, 220})[level] + 0.6 * source.totalDamage end},--Minion Damage
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({10, 25, 40, 55, 70})[level] + 0.5 * source.totalDamage + 0.4 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 125, 170, 215, 260})[level] + 0.8 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({125, 250, 375})[level] + 0.7 * source.ap end},
  },
  
  ["Ivern"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 125, 170, 215, 260})[level] + 0.7 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 95, 120, 145, 170})[level] + 0.8 * source.ap end},
  },  

  ["Janna"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 85, 110, 135, 160})[level] + 0.35 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({55, 85, 115, 145, 175})[level] + 0.5 * source.ap + (({0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.35, 0.35, 0.35, 0.35, 0.35, 0.35, 0.35, 0.35, 0.35})[myHero.levelData.lvl] * source.ms) end},
  },

  ["JarvanIV"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({90, 130, 170, 210, 250})[level] + 1.2 * source.bonusDamage end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 120, 160, 200, 240})[level] + 0.8 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({200, 325, 450})[level] + 1.5 * source.bonusDamage end},
  },

  ["Jax"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({65, 105, 145, 185, 225})[level] + source.bonusDamage + 0.6 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 75, 110, 145, 180})[level] + 0.6 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({55, 80, 105, 130, 155})[level] + 0.5 * source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({100, 140, 180})[level] + 0.7 * source.ap end},
  },

  ["Jayce"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({55, 95, 135, 175, 215, 255})[level] + 1.2 * source.bonusDamage end},
    {Slot = "QM", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({55, 110, 165, 220, 275, 330})[level] + 1.2 * source.bonusDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({25, 40, 55, 70, 85, 100})[level] + 0.25 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({8, 10.4, 12.8, 15.2, 17.6, 20})[level] / 100) * target.maxHealth + source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({25, 65, 105, 145})[level] + 0.25 * source.bonusDamage end},
  },

  ["Jhin"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({45, 70, 95, 120, 145})[level] + (({0.35, 0.425, 0.5, 0.575, 0.65})[level] * source.totalDamage) + 0.6 * source.ap end},
	{Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({50, 85, 120, 155, 190})[level] + 0.5 * source.totalDamage end},
    {Slot = "W", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({37, 63, 90, 116, 142})[level] + 0.37 * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({50, 125, 200})[level] + 0.2 * source.totalDamage + 0.03 * (target.maxHealth - target.health) end}, -- 1-3 singleHit
    {Slot = "R", Stage = 2, DamageType = 1, Damage = function(source, target, level) return (({50, 125, 200})[level] + 0.2 * source.totalDamage + 0.03 * (target.maxHealth - target.health)) end} -- 4 Hit
  },

  ["Jinx"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return 0.1 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({10, 60, 110, 160, 210})[level] + 1.6 * source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 120, 170, 220, 270})[level] + source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({25, 35, 45})[level] + ({25, 30, 35})[level] / 100 * (target.maxHealth - target.health) + 0.15 * source.bonusDamage end},
    {Slot = "R", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({250, 350, 450})[level] + ({25, 30, 35})[level] / 100 * (target.maxHealth - target.health) + 1.5 * source.bonusDamage end},
  },
  
  ["Kaisa"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({40, 55, 70, 85, 100})[level] + 0.25 * source.ap + 0.4 * source.bonusDamage end},	
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({30, 55, 80, 105, 130})[level] + 1.3 * source.totalDamage + 0.7 * source.ap end},
    {Slot = "W", Stage = 2, DamageType = 2, Damage = function(source, target, level) return 0.025 * source.ap + ((target.maxHealth - target.health) / 100 * 15) end},	
  },  

  ["Karma"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({90, 135, 180, 225, 270})[level] + 0.4 * source.ap end},
    {Slot = "Q", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({90, 135, 180, 225, 270})[level] + ({25, 75, 125, 175})[source:GetSpellData(_R).level] + 0.7 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 130, 180, 230, 280})[level] + 0.9 * source.ap end},
  },

  ["Karthus"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({45, 65, 85, 105, 125})[level] + 0.35 * source.ap) * 2 end},--single Target
    {Slot = "Q", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({45, 65, 85, 105, 125})[level] + 0.35 * source.ap end},--AOE
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({30, 50, 70, 90, 110})[level] + 0.2 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({200, 350, 500})[level] + 0.75 * source.ap end},
  },

  ["Kassadin"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({65, 95, 125, 155, 185})[level] + 0.7 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 95, 120, 145, 170})[level] + 0.8 * source.ap end},
    {Slot = "W", Stage = 2, DamageType = 2, Damage = function(source, target, level) return 20 + 0.1 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 105, 130, 155, 180})[level] + 0.8 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 100, 120})[level] + 0.4 * source.ap + 0.02 * source.mana end},
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({40, 50, 60})[level] + 0.1 * source.ap + 0.01 * source.mana end},-- per stack
  },

  ["Katarina"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 105, 135, 165, 195})[level] + 0.3 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({15, 30, 45, 60, 75})[level] + 0.25 * source.ap + 0.5 * source.totalDamage end},   
	{Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({25, 37.5, 50})[level] + 0.19 * source.ap end}, -- calc for 1 Dagger
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({375, 562.5, 750})[level] + 2.85 * source.ap end},
	{Slot = "R", Stage = 3, DamageType = 1, Damage = function(source, target, level) return 0.16 * source.bonusDamage + 0.128 * source.attackSpeed end}, -- calc for 1 Dagger
  },

  ["Kayle"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 100, 140, 180, 220})[level] + 0.6 * source.bonusDamage + 0.5 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return 0.02 * source.ap / 100 + ({0.08, 0.09, 0.10, 0.11, 0.12})[level] * (target.maxHealth - target.health) end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({200, 350, 500})[level] + 0.8 * source.ap + source.bonusDamage end},	
  },

  ["Kennen"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 115, 155, 195, 235})[level] + 0.75 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 85, 110, 135, 160})[level] + 0.8 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 120, 160, 200, 240})[level] + 0.8 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 75, 110})[level] + 0.2 * source.ap end},--per Bolt
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({300, 562, 825})[level] + 1.5 * source.ap end},--total single target damage	
  },

  ["Khazix"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({60, 85, 110, 135, 160})[level] + 1.3 * source.bonusDamage end},
    {Slot = "Q", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({126, 178, 231, 283, 336})[level] + 2.73 * source.bonusDamage end},--isolated Target
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({80, 115, 145, 175, 205})[level] + source.bonusDamage end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({65, 100, 135, 170, 205})[level] + 0.2 * source.bonusDamage end},
  },

  ["KogMaw"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({90, 140, 190, 240, 290})[level] + 0.7 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) local dmg = (({0.03, 0.04, 0.05, 0.06, 0.07})[level] + (0.01*source.ap)) * target.maxHealth ; if target.type == Obj_AI_Minion and dmg > 100 then dmg = 100 end ; return dmg end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 120, 165, 210, 255})[level] + 0.5 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({100, 140, 180})[level] + 0.65 * source.bonusDamage + 0.35 * source.ap) * (GetPercentHP(target) < 25 and 3 or (GetPercentHP(target) < 50 and 2 or 1)) end},
  },

  ["Kalista"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 85, 150, 215, 280})[level] + source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({14, 15, 16, 17, 18})[level] / 100) * target.maxHealth end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) local count = GotBuff(target, "kalistaexpungemarker") if count > 0 then return (({20, 30, 40, 50, 60})[level] + 0.6* (source.totalDamage)) + ((count - 1)*(({10, 16, 22, 28, 34})[level]+({0.2, 0.24, 0.27, 0.31, 0.35})[level] * (source.totalDamage))) end; return 0 end},	
  },  
  
  ["Kayn"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({75, 95, 115, 135, 155})[level] + 0.65 * source.bonusDamage end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({90, 135, 180, 225, 270})[level] + 1.3 * source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({150, 250, 350})[level] + 1.75 * source.bonusDamage end},
  },  

  ["Kindred"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({60, 80, 100, 120, 140})[level] + source.bonusDamage * 0.65 end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({25, 30, 35, 40, 45})[level] + 0.2 * source.bonusDamage + 0.015 * (target.maxHealth - target.health) + (GetBuffData(source, "kindredmarkofthekindredstackcounter").stacks/100) * (target.maxHealth - target.health) end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({80, 100, 120, 140, 160})[level] + 0.8 * source.bonusDamage + 0.08 * (target.maxHealth - target.health) + (GetBuffData(source, "kindredmarkofthekindredstackcounter").stacks/200) * (target.maxHealth - target.health) end},
  },
  
  ["Kled"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({90, 165, 240, 315, 390})[level] + source.bonusDamage * 1.8 end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 30, 40, 50, 60})[level] + (({0.045, 0.05, 0.055, 0.06, 0.065})[level] + (0.05*source.bonusDamage)) * target.maxHealth end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({35, 60, 85, 110, 135})[level] + source.bonusDamage * 0.6 end},
  },

  ["Leblanc"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({55, 80, 105, 130, 155})[level] + 0.4 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 115, 155, 195, 235})[level] + 0.6 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 70, 90, 110, 130})[level] + 0.3 * source.ap end},
  },

  ["LeeSin"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({55, 80, 105, 130, 155})[level] + source.bonusDamage end},
    {Slot = "Q", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({55, 80, 105, 130, 155})[level] + source.bonusDamage + 0.01 * (target.maxHealth - target.health) end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({100, 140, 180, 220, 260})[level] + source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({175, 400, 625})[level] + 2 * source.bonusDamage end},
  },

  ["Leona"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({10, 35, 60, 85, 110})[level] + 0.3 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 95, 130, 165, 200})[level] + 0.4 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 90, 130, 170, 210})[level] + 0.4 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({100, 175, 250})[level] + 0.8 * source.ap end},
  },

  ["Lissandra"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 100, 130, 160, 190})[level] + 0.8 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 105, 140, 175, 210})[level] + 0.7 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 105, 140, 175, 210})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.75 * source.ap end},
  },

  ["Lucian"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({95, 130, 165, 200, 235})[level] + ({0.6, 0.75, 0.9, 1.05, 1.2})[level] * source.bonusDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 110, 145, 180, 215})[level] + 0.9 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 40, 60})[level] + 0.1 * source.ap + 0.25 * source.totalDamage end},--per Shot
  },

  ["Lulu"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 105, 140, 175, 210})[level] + 0.5 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 120, 160, 200, 240})[level] + 0.4 * source.ap end},
  },

  ["Lux"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 125, 170, 215, 260})[level] + 0.6 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 105, 150, 195, 240})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({300, 400, 500})[level] + source.ap end},
  },

  ["Malphite"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 120, 170, 220, 270})[level] + 0.6 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({30, 45, 60, 75, 90})[level] + 0.2 * source.ap + 0.15 * source.armor end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 95, 130, 165, 200})[level] + 0.4 * source.armor + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({200, 300, 400})[level] + 0.8 * source.ap end},
  },

  ["Malzahar"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 105, 140, 175, 210})[level] + 0.65 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({12, 14, 16, 18, 20})[level] + 0.2 * source.ap + 0.4 * source.bonusDamage + (2 + 3 * myHero.levelData.lvl) end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 115, 150, 185, 220})[level] + 0.8 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({125, 200, 275})[level] + 0.8 * source.ap end},	
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return 2.5 * (({10, 15, 20})[level] / 100 + 0.015 * source.ap / 100) * target.maxHealth end},
  },

  ["Maokai"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + 0.4 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 95, 120, 145, 170})[level] + 0.4 * source.ap  end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({25, 50, 75, 100, 125})[level] + (({0.07, 0.0725, 0.075, 0.0775, 0.08})[level] + (0.008*source.ap)) * target.maxHealth end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 225, 300})[level] + 0.75 * source.ap end},
  },

  ["MasterYi"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({25, 60, 95, 130, 165})[level] + source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 3, Damage = function(source, target, level) return ({20, 30, 40, 50, 60})[level] + 0.35 * source.bonusDamage end},
  },

  ["MissFortune"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 40, 60, 80, 100})[level] + 0.35 * source.ap + source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 115, 150, 185, 220})[level] + 0.8 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return 0.75 * source.totalDamage + 0.2 * source.ap end},
  },

  ["MonkeyKing"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 45, 70, 95, 120})[level] + 0.5 * source.bonusDamage end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({80, 110, 140, 170, 200})[level] + 0.8 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({0.01, 0.15, 0.02})[level] * target.maxHealth + 0.275 * source.totalDamage end}, --Per Tick
  },

  ["Mordekaiser"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 95, 115, 135, 155})[level] + 0.6 * source.ap + ({5, 9, 13, 17, 21, 25, 29, 33, 37, 41, 51, 61, 71, 81, 91, 107, 123, 139})[myHero.levelData.lvl] end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 95, 110, 125, 140})[level] + 0.6 * source.ap end},
  },

  ["Morgana"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 135, 190, 245, 300})[level] + 0.9 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 110, 160, 210, 260})[level] + 0.07 * source.ap end}, -- minimum fullDmg
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 225, 300})[level] + 0.7 * source.ap end},
  },

  ["Nami"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 130, 185, 240, 295})[level] + 0.5 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + 0.5 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({25, 40, 55, 70, 85})[level] + 0.2 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.6 * source.ap end},
  },

  ["Nasus"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return GetBuffData(source, "nasusqstacks").stacks + ({30, 50, 70, 90, 110})[level] end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({55, 95, 135, 175, 215})[level] + 0.6 * source.ap end},
    {Slot = "E", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({11, 19, 27, 35, 43})[level] + 0.12 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({3, 4, 5})[level] / 100 + 0.01 / 100 * source.ap) * target.maxHealth end},
  },

  ["Nautilus"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 115, 160, 205, 250})[level] + 0.9 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({30, 40, 50, 60, 70})[level] + 0.4 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({55, 85, 115, 145, 175})[level] + 0.3 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 275, 400})[level] + 0.8 * source.ap end},
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({125, 175, 225})[level] + 0.4 * source.ap end},
  },
  
  ["Neeko"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 125, 170, 215, 260})[level] + 0.5 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 115, 150, 185, 220})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({200, 425, 650})[level] + 1.3 * source.ap end},
  },  

  ["Nidalee"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 90, 110, 130, 150})[level] + 0.5 * source.ap end},
    {Slot = "QM", Stage = 2, DamageType = 2, Damage = function(source, target, level) local dmg = (({5, 30, 55, 80})[source:GetSpellData(_R).level] + 0.4 * source.ap + 0.75 * source.totalDamage) * ((target.maxHealth - target.health) / target.maxHealth * 1.5 + 1) dmg = dmg * (GotBuff(target, "nidaleepassivehunted") > 0 and 1.4 or 1) return dmg end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 80, 120, 160, 200})[level] + 0.2 * source.ap end},
    {Slot = "WM", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({60, 110, 160, 210})[source:GetSpellData(_R).level] + 0.3 * source.ap end},
    {Slot = "E", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({80, 140, 200, 260})[source:GetSpellData(_R).level] + 0.45 * source.ap end},
  },

  ["Nocturne"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({65, 110, 155, 200, 245})[level] + 0.75 * source.bonusDamage end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 125, 170, 215, 260})[level] + source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({150, 275, 400})[level] + 1.2 * source.bonusDamage end},
  },

  ["Nunu"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 100, 140, 180, 220})[level] + 0.65 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({36, 45, 54, 63, 72})[level] + 0.3 * source.ap end},	
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({16, 24, 32, 40, 48})[level] + 0.06 * source.ap end},--per Snowbal
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({625, 950, 1275})[level] + 2.5 * source.ap end},
  },

  ["Olaf"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({80, 125, 170, 215, 260})[level] + source.bonusDamage end},
    {Slot = "E", Stage = 1, DamageType = 3, Damage = function(source, target, level) return ({70, 115, 160, 205, 250})[level] + 0.5 * source.totalDamage end},
  },

  ["Orianna"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 90, 120, 150, 180})[level] + 0.5 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 105, 150, 195, 240})[level] + 0.7 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 90, 120, 150, 180})[level] + 0.3 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({200, 275, 350})[level] + 0.8 * source.ap end},
  },
  
  ["Ornn"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 45, 70, 95, 120})[level] + 1.1 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({0.12, 0.13, 0.14, 0.15, 0.16})[level] * target.maxHealth end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({80, 125, 170, 215, 260})[level] + 0.4 * source.bonusArmor + 0.4 * source.bonusMagicResist end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({125, 175, 225})[level] + 0.2 * source.ap end},
  },  

  ["Pantheon"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({70, 100, 130, 160, 190})[level] + 1.15 * source.bonusDamage end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({60, 100, 140, 180, 220})[level] + source.ap end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({55, 105, 155, 205, 255})[level] + 1.5 * source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({300, 500, 700})[level] + source.ap end},
  },

  ["Poppy"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({40, 60, 80, 100, 120})[level] + 0.9 * source.bonusDamage + 0.08 * target.maxHealth end},
    {Slot = "Q", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({80, 120, 160, 200, 240})[level] + 1.8 * source.bonusDamage + 0.16 * target.maxHealth end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + 0.7 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({60, 80, 100, 120, 140})[level] + 0.5 * source.bonusDamage end},
    {Slot = "E", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({120, 160, 200, 240, 280})[level] + source.bonusDamage end},--Target collide with terrain
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({100, 150, 200})[level] + 0.45 * source.bonusDamage end},
  },
  
  ["Pyke"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({85, 135, 185, 235, 285})[level] + 0.6 * source.bonusDamage end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({105, 135, 165, 195, 225})[level] + source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({250, 250, 250, 250, 250, 250, 290, 330, 370, 400, 430, 450, 470, 490, 510, 530, 540, 550})[myHero.levelData.lvl] + 0.8 * source.bonusDamage + 1.5 * source.armorPen end},
  }, 

  ["Qiyana"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({60, 85, 110, 135, 160})[level] + 0.9 * source.bonusDamage end},
    {Slot = "Q", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({96, 136, 176, 216, 256})[level] + 1.44 * source.bonusDamage end},--Terrain Damage	
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({8, 22, 36, 50, 64})[level] + 0.1 * source.bonusDamage + 0.45 * source.ap end},--Passive
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({60, 90, 120, 140, 180})[level] + 0.7 * source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({100, 200, 300})[level] + 1.7 * source.bonusDamage + 0.1 * target.maxHealth end},
  },  

  ["Quinn"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 45, 70, 95, 120})[level] + (({0.8, 0.9, 1.0, 1.1, 1.2})[level] * source.totalDamage) + 0.5 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({40, 70, 100, 130, 160})[level] + 0.2 * source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return 0.4 * source.totalDamage end},
  },
  
  ["Rakan"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 115, 160, 205, 250})[level] + 0.6 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 125, 180, 235, 290})[level] + 0.7 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({100, 200, 300})[level] + 0.5 * source.ap end},
  },  

  ["Rammus"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({100, 135, 170, 205, 240})[level] + source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({15, 25, 35, 45, 55})[level] + 0.1 * source.armor end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({30, 60, 90})[level] + 0.2 * source.ap end},-- per Second
  },
  
  ["Reksai"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 25, 30, 35, 40})[level] + 0.5 * source.bonusDamage end},--UNBURROWED 
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({60, 90, 120, 150, 180})[level] + 0.5 * source.bonusDamage + 0.7 * source.ap end},--BURROWED 		
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({55, 70, 85, 100, 115})[level] + 0.8 * source.bonusDamage end},--BURROWED   
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({50, 60, 70, 80, 90})[level] + 0.85 * source.bonusDamage end},--UNBURROWED 
    {Slot = "E", Stage = 1, DamageType = 3, Damage = function(source, target, level) return ({100, 120, 140, 160, 180})[level] + 1.7 * source.bonusDamage end},--UNBURROWED + Max FURY 
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({100, 250, 400})[level] + 1.75 * source.bonusDamage + ({20, 25, 30})[level] / 100 * (target.maxHealth - target.health) end},
  }, 

  ["Rell"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 105, 140, 175, 210})[level] + 0.5 * source.ap end}, 		
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 105, 140, 175, 210})[level] + 0.6 * source.ap end}, -- if mounted  
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 120, 160, 200, 240})[level] + 0.3 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({120, 200, 280})[level] + 1.1 * source.ap end},
  },  

  ["Renekton"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({65, 100, 135, 170, 205})[level] + 0.8 * source.bonusDamage end},
    {Slot = "Q", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({100, 150, 200, 250, 300})[level] + 1.2 * source.bonusDamage end},--REIGN OF ANGER	
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({10, 30, 50, 70, 90})[level] + 1.5 * source.totalDamage end},
    {Slot = "W", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({15, 45, 75, 105, 135})[level] + 2.25 * source.totalDamage end},--REIGN OF ANGER
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({40, 70, 100, 130, 160})[level] + 0.9 * source.bonusDamage end},
    {Slot = "E", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({40, 70, 100, 130, 160})[level] + 0.9 * source.totalDamage * 1.5 end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({20, 40, 60})[level] + 0.1 * source.ap end},--per half Second
  },

  ["Rengar"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({30, 60, 90, 120, 150})[level] + ({0, 5, 10, 15, 20})[level] / 100 * source.totalDamage end},
    {Slot = "Q", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({30, 45, 60, 75, 90, 105, 120, 135, 150, 160, 170, 180, 190, 200, 210, 220, 230, 240})[myHero.levelData.lvl] + 0.4 * source.totalDamage end},--EMPOWERED ACTIVE
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 80, 110, 140, 170})[level] + 0.8 * source.ap end},
    {Slot = "W", Stage = 2, DamageType = 2, Damage = function(source, target, level) return (40 + 10 * myHero.levelData.lvl) + 0.8 * source.ap end},--EMPOWERED ACTIVE	
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({55, 100, 145, 190, 235})[level] + 0.8 * source.bonusDamage end},
    {Slot = "E", Stage = 2, DamageType = 1, Damage = function(source, target, level) return (35 + 15 * myHero.levelData.lvl) + 0.8 * source.bonusDamage end},--EMPOWERED ACTIVE
  },

  ["Riven"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({15, 35, 55, 75, 95})[level] + ({45, 50, 55, 60, 65})[level] / 100 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({55, 85, 115, 145, 175})[level] + source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return (({100, 150, 200})[level] + 0.6 * source.bonusDamage) * math.max(0.04 * math.min(100 - GetPercentHP(target), 75), 1) end},
  },

  ["Rumble"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({180, 220, 260, 300, 340})[level] + 1.1 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 85, 110, 135, 160})[level] + 0.4 * source.ap end},
    {Slot = "E", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({90, 127.5, 165, 202.5, 240})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 105, 140})[level] + 0.175 * source.ap end},--per half Second
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({840, 1260, 1680})[level] + 2.1 * source.ap end},--full Damage
  },

  ["Ryze"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 100, 125, 150, 175})[level] + 0.45 * source.ap + 0.03 * source.maxMana end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 110, 140, 170, 200})[level] + 0.6 * source.ap + 0.04 * source.maxMana end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 80, 100, 120, 140})[level] + 0.3 * source.ap + 0.02 * source.maxMana end},
  },
  
  ["Samira"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({0, 5, 10, 15, 20})[level] + ({0.8, 0.9, 1, 1.1, 1.2})[level] * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 35, 50, 65, 80})[level] + 0.8 * source.bonusDamage end}, -- 1 Hit
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 60, 70, 80, 90})[level] + 0.2 * source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({100, 200, 300})[level] + 6 * source.totalDamage end},	-- Full Damage
  },  

  ["Sejuani"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 130, 180, 230, 280})[level] + 0.6 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({20, 25, 30, 35, 40})[level] + 0.2 * source.ap + 0.02 * source.maxHealth end},
    {Slot = "W", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({30, 70, 110, 150, 190})[level] + 0.6 * source.ap + 0.06 * source.maxHealth end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({55, 105, 155, 205, 255})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({200, 300, 400})[level] + 0.8 * source.ap end},
  },
  
  ["Senna"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({40, 70, 100, 130, 160})[level] + 0.4 * source.bonusDamage end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({70, 115, 160, 205, 250})[level] + 0.7 * source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({250, 375, 500})[level] + source.bonusDamage + 0.5 * source.ap end},
  },
  
    ["Seraphine"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({55, 70, 85, 100, 115})[level] + ({40, 45, 50, 55, 60})[level] / 100 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 80, 100, 120, 140})[level] + 0.35 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 200, 250})[level] + 0.6 * source.ap end},
  },

  ["Sett"] = {
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({80, 100, 120, 140, 160})[level] + 0.1 * source.bonusDamage end}, -- without expended Grit
    {Slot = "W", Stage = 2, DamageType = 3, Damage = function(source, target, level) return ({80, 100, 120, 140, 160})[level] + 0.1 * source.bonusDamage end}, -- True Damage without expended Grit
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({50, 70, 90, 110, 130})[level] + 0.6 * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({200, 300, 400})[level] + source.bonusDamage end}, -- without Target BonusHealth
  },  

  ["Shaco"] = {
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({25, 40, 55, 70, 85})[level] + 0.2 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (GetPercentHP(target) < 30 and ({105, 142, 180, 217, 255})[level] + 0.9 * source.ap + 1.2 * source.bonusDamage or ({70, 95, 120, 145, 170})[level] + 0.55 * source.ap + 0.7 * source.bonusDamage) end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 225, 300})[level] + 0.7 * source.ap end},
  },

  ["Shen"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) local dmg = (({2, 2.5, 3, 3.5, 4})[level] + 0.015 * source.ap) * target.maxHealth / 100; if target.type == Obj_AI_Hero then return dmg end; return math.min(({30, 50, 70, 90, 110})[level]+dmg, ({75, 100, 125, 150, 175})[level]) end},
    {Slot = "Q", Stage = 2, DamageType = 2, Damage = function(source, target, level) local dmg = (({5, 5.5, 6, 6.5, 7})[level] + 0.02 * source.ap) * target.maxHealth / 100; if target.type == Obj_AI_Hero then return dmg end; return math.min(({30, 50, 70, 90, 110})[level]+dmg, ({75, 100, 125, 150, 175})[level]) end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({60, 85, 110, 135, 160})[level] + 0.15 * (540 + 85 * myHero.levelData.lvl) end},
  },

  ["Shyvana"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 35, 50, 65, 80})[level] / 100 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({20, 32, 45, 57, 70})[level] + 0.2 * source.bonusDamage end},--per Second
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 100, 140, 180, 220})[level] + 0.7 * source.ap + 0.3 * source.totalDamage end},
    {Slot = "E", Stage = 2, DamageType = 2, Damage = function(source, target, level) return (60 + 5 * myHero.levelData.lvl) + 0.2 * source.ap + 0.1 * source.totalDamage end},--Dragon Form per Second	
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + source.ap end},
  },

  ["Singed"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({5, 7, 10, 12, 15})[level] + 0.11 * source.ap end},--per 0.25 Second
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 65, 80, 95, 110})[level] + 0.75 * source.ap + ({6, 6.5, 7, 7.5, 8})[level] / 100 * target.maxHealth end},
  },

  ["Sion"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({30, 50, 70, 90, 110})[level] + ({45, 52, 60, 67, 75})[level] / 100 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 65, 90, 115, 140})[level] + 0.4 * source.ap + ({10, 11, 12, 13, 14})[level] / 100 * target.maxHealth end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({65, 100, 135, 170, 205})[level] + 0.55 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({150, 300, 450})[level] + 0.4 * source.bonusDamage end},
  },

  ["Sivir"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({35, 50, 65, 80, 95})[level] + ({70, 85, 100, 115, 130})[level] / 100 * source.totalDamage + 0.5 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({90, 120, 150, 180, 210})[level] / 100 * source.totalDamage end},
  },

  ["Skarner"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return 0.2 * source.totalDamage + ({1, 1.5, 2, 2.5, 3})[level] / 100 * target.maxHealth end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 65, 90, 115, 140})[level] + 0.2 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({20, 60, 100})[level] + 0.5 * source.ap) + (0.60 * source.totalDamage) end},
  },

  ["Sona"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 70, 100, 130, 160})[level] + 0.4 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.5 * source.ap end},
  },

  ["Soraka"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({85, 120, 155, 190, 225})[level] + 0.35 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 95, 120, 145, 170})[level] + 0.4 * source.ap end},
  },

  ["Swain"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({55, 75, 95, 115, 135})[level] + 0.4 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 120, 160, 200, 240})[level] + 0.7 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({35, 70, 105, 140, 175})[level] + 0.25 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({35, 50, 65})[level] + 0.14 * source.ap end},--per Second
  },
  
  ["Sylas"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 60, 80, 100, 120})[level] + 0.4 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 105, 140, 175, 210})[level] + 0.90 * source.ap end},
    {Slot = "W", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({97, 150, 202, 255, 307})[level] + 0.97 * source.ap end},--if Target below 40%	
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 130, 180, 230, 280})[level] + source.ap end},
	{Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 65, 80, 95, 180})[level] + 0.4 * source.ap end},     
	{Slot = "R", Stage = 2, DamageType = 3, Damage = function(source, target, level) return ({300, 475, 650})[level] + 0.5 * source.ap + 0.1 * (myHero.maxHealth - GetBaseHealth(myHero)) end}, --cho'garh  
	{Slot = "R", Stage = 3, DamageType = 2, Damage = function(source, target, level) return (({200, 400, 600})[level] + source.ap) end}, --ashe
	{Slot = "R", Stage = 4, DamageType = 2, Damage = function(source, target, level) return (({175, 250, 325})[level] + 0.75 * source.ap) end}, --vaiger
	{Slot = "R", Stage = 5, DamageType = 2, Damage = function(source, target, level) return (({150, 250, 350})[level] + 0.8 * source.ap) end}, --leona
	{Slot = "R", Stage = 6, DamageType = 2, Damage = function(source, target, level) return (({350, 500, 650})[level] + 0.9 * source.ap + 0.45 * source.ap) end}, --ezreal
 	{Slot = "R", Stage = 7, DamageType = 2, Damage = function(source, target, level) return ({25, 35, 45})[level]/ 100 * 0.7 + (({0.25, 0.30, 0.35})[level] * (target.maxHealth - target.health)) + 0.15 * source.bonusDamage/100 * 0.5 end}, --jinx 
 	{Slot = "R", Stage = 8, DamageType = 2, Damage = function(source, target, level) return (({250, 400, 550})[level] + 0.75 * source.ap) end}, --kartus
 	{Slot = "R", Stage = 9, DamageType = 2, Damage = function(source, target, level) return (({200, 300, 400})[level] + 0.733 * source.ap) end}, --ziggs
 	{Slot = "R", Stage = 10, DamageType = 2, Damage = function(source, target, level) return (({150, 250, 350})[level] + 0.5 * source.ap) end}, --cassio
 	{Slot = "R", Stage = 11, DamageType = 2, Damage = function(source, target, level) return (({300, 400, 500})[level] + 0.75 * source.ap) end}, --lux
  	{Slot = "R", Stage = 12, DamageType = 2, Damage = function(source, target, level) return (({300, 400, 500})[level] + source.ap) end}, --tristana
    {Slot = "R", Stage = 13, DamageType = 2, Damage = function(source, target, level) return ({40, 60, 80})[level] + 0.125 * source.ap end},--Anivia
    {Slot = "R", Stage = 14, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.7 * source.ap end},--AurelionSol
  	{Slot = "R", Stage = 15, DamageType = 2, Damage = function(source, target, level) return (({150, 250, 350})[level] + 0.6 * source.ap) end}, --Braum
  	{Slot = "R", Stage = 16, DamageType = 2, Damage = function(source, target, level) return (({125, 225, 325})[level] + 0.7 * source.ap) end}, --Irelia 
  	{Slot = "R", Stage = 17, DamageType = 2, Damage = function(source, target, level) return (({625, 950, 1275})[level] + 2.5 * source.ap) end}, --Nunu
  	{Slot = "R", Stage = 18, DamageType = 2, Damage = function(source, target, level) return (({150, 250, 350})[level] + 0.6 * source.ap) end}, -- Lissandra	
  	{Slot = "R", Stage = 19, DamageType = 2, Damage = function(source, target, level) return (({125, 200, 275})[level] + 0.8 * source.ap) end}, --Malzahar
  	{Slot = "R", Stage = 20, DamageType = 2, Damage = function(source, target, level) return (({85, 150, 215})[level]/100 * 0.7 + 0.25 * source.ap) end}, --Akali
  	{Slot = "R", Stage = 21, DamageType = 2, Damage = function(source, target, level) return (({85, 150, 215})[level] + 0.3 * source.ap) end}, --Akalib
   	{Slot = "R", Stage = 22, DamageType = 2, Damage = function(source, target, level) return (({150, 250, 350})[level] + 0.8 * source.ap) end}, --Amumu
  	{Slot = "R", Stage = 23, DamageType = 2, Damage = function(source, target, level) return (({150, 250, 450})[level] + 0.6 * source.ap) end}, --azir
   	{Slot = "R", Stage = 24, DamageType = 2, Damage = function(source, target, level) return (({125, 250, 375})[level] + 0.75 * source.ap) end}, --evelynn 
   	{Slot = "R", Stage = 25, DamageType = 2, Damage = function(source, target, level) return (({250, 375, 500})[level] + 1.0 * source.ap) end}, --blitzgrank
  	{Slot = "R", Stage = 26, DamageType = 2, Damage = function(source, target, level) return (({175, 275, 375})[level]/100 * 0.7 + 0.55 * source.ap) end}, -- draven
   	{Slot = "R", Stage = 27, DamageType = 2, Damage = function(source, target, level) return (({150, 250, 350})[level] + 0.6 * source.ap) end}, --fizz        
  	{Slot = "R", Stage = 28, DamageType = 2, Damage = function(source, target, level) return (({200, 300, 400})[level]/100 * 0.7 + 0.1 * source.ap + 0.5 * source.ap) end}, -- gnar
  	{Slot = "R", Stage = 29, DamageType = 2, Damage = function(source, target, level) return (({200, 300, 400})[level] + 0.70 * source.ap) end}, -- gragas
   	{Slot = "R", Stage = 30, DamageType = 2, Damage = function(source, target, level) return (({90, 115, 140})[level] + (({0.075, 0.225, 0.375})[level]* source.ap) + 0.2 * source.ap) end}, --Corki
  	{Slot = "R", Stage = 31, DamageType = 2, Damage = function(source, target, level) return (({250, 400, 550})[level]/100*0.7 + 0.75 * source.ap) end}, -- graves
   	{Slot = "R", Stage = 32, DamageType = 2, Damage = function(source, target, level) return (({150, 250, 350})[level] + 1.0 * source.ap) end}, --hecarim
  	{Slot = "R", Stage = 33, DamageType = 2, Damage = function(source, target, level) return (({122, 306, 490})[level] + 0.35 * source.ap) end}, --Jhin
  	{Slot = "R", Stage = 34, DamageType = 2, Damage = function(source, target, level) return ({100, 160, 220})[level] + 0.6 * source.ap end}, -- Diana	
  	{Slot = "R", Stage = 35, DamageType = 2, Damage = function(source, target, level) return (({375, 562, 750})[level] + 1.65 * source.ap + 2.85 * source.ap) end}, --katarina
  	{Slot = "R", Stage = 36, DamageType = 2, Damage = function(source, target, level) return (({40, 75, 110})[level] + 0.2 * source.ap) end}, --Kennen    
  	{Slot = "R", Stage = 37, DamageType = 2, Damage = function(source, target, level) return (({150, 225, 300})[level] + 0.75 * source.ap) end}, --Maokai
  	{Slot = "R", Stage = 38, DamageType = 2, Damage = function(source, target, level) return (({250, 400, 500})[level] + 1.0 * source.ap) end}, --Missfortune  
   	{Slot = "R", Stage = 39, DamageType = 2, Damage = function(source, target, level) return (({150, 250, 350})[level] + 0.6 * source.ap) end}, --Nami
   	{Slot = "R", Stage = 40, DamageType = 2, Damage = function(source, target, level) return (({200, 325, 450})[level] + 0.8 * source.ap) end}, --Nautilus
   	{Slot = "R", Stage = 41, DamageType = 2, Damage = function(source, target, level) return (({130, 185, 240})[level] + 0.3 * source.ap) end}, --rumble   
  	{Slot = "R", Stage = 42, DamageType = 2, Damage = function(source, target, level) return (({100, 125, 150})[level] + 0.4 * source.ap) end}, --Sejuani 
   	{Slot = "R", Stage = 43, DamageType = 2, Damage = function(source, target, level) return (({150, 250, 350})[level] + 0.5 * source.ap) end}, --sona
  	{Slot = "R", Stage = 44, DamageType = 2, Damage = function(source, target, level) return (({50, 175, 300})[level]/100*0.7 + 0.25 * source.ap) end}, --urgot  
  	{Slot = "R", Stage = 45, DamageType = 2, Damage = function(source, target, level) return (({150, 200, 250})[level] + 1.0 * source.ap) end}, --varus
   	{Slot = "R", Stage = 46, DamageType = 2, Damage = function(source, target, level) return (({180, 265, 350})[level] + 0.7 * source.ap) end}, --Zyra
  	{Slot = "R", Stage = 47, DamageType = 2, Damage = function(source, target, level) return (({175, 350, 525})[level]/100*0.7 + 0.835 * source.ap) end}, --Warwick
  	{Slot = "R", Stage = 48, DamageType = 2, Damage = function(source, target, level) return (({100, 200, 300})[level] + 0.3 * source.ap) end}, --brand
  	{Slot = "R", Stage = 49, DamageType = 2, Damage = function(source, target, level) return (({175, 350, 525})[level]) end}, --Geran  
  	{Slot = "R", Stage = 50, DamageType = 2, Damage = function(source, target, level) return (({200, 300, 400})[level] + 1.0 * source.ap) end}, --malphite
  	{Slot = "R", Stage = 51, DamageType = 2, Damage = function(source, target, level) return (({150, 250, 350})[level] + source.ap) end}, --shyvana
  	{Slot = "R", Stage = 52, DamageType = 2, Damage = function(source, target, level) return (({150, 225, 300})[level] + 0.7 * source.ap) end}, --morgana
  	{Slot = "R", Stage = 53, DamageType = 2, Damage = function(source, target, level) return (({20, 110, 200})[level]/100*0.7 + 0.55 * source.ap) end},	--wukong
	{Slot = "R", Stage = 54, DamageType = 2, Damage = function(source, target, level) return ({125, 225, 325})[level] + 0.45 * source.ap end}, --Fiddlesticks
	{Slot = "R", Stage = 55, DamageType = 2, Damage = function(source, target, level) return ({105, 180, 255})[level] + 0.3 * source.ap end}, --Gangplank
	{Slot = "R", Stage = 56, DamageType = 2, Damage = function(source, target, level) return (({150, 250, 350})[level]/100*0.7 + 0.55 * source.ap) end}, --Illaoi
	{Slot = "R", Stage = 57, DamageType = 2, Damage = function(source, target, level) return ({200, 325, 450})[level]/100*0.7 + 0.75 * source.ap end}, --Jarvan
	{Slot = "R", Stage = 58, DamageType = 2, Damage = function(source, target, level) return ({80, 100, 120})[level]+ 0.4 * source.ap + 0.02 * source.maxMana end}, --Kassadin
	{Slot = "R", Stage = 59, DamageType = 2, Damage = function(source, target, level) return (({100, 140, 180})[level] + 0.325 * source.ap + 0.25 * source.ap) * (GetPercentHP(target) < 25 and 3 or (GetPercentHP(target) < 50 and 2 or 1)) end}, --Kogmaw
	{Slot = "R", Stage = 60, DamageType = 2, Damage = function(source, target, level) return (({70, 140, 210})[level] + 0.4 * source.ap) end},-- Leblanc
	{Slot = "R", Stage = 61, DamageType = 2, Damage = function(source, target, level) return ({20, 35, 50})[level]/100*0.7 + 0.1 * source.ap + 0.25 * source.totalDamage/100 * 0.7 end}, --Lucian
	{Slot = "R", Stage = 62, DamageType = 2, Damage = function(source, target, level) return ({40, 80, 120})[level] + 0.2 * source.ap end},--Rammus
	{Slot = "R", Stage = 63, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.7 * source.ap end},--Vladimir
	{Slot = "R", Stage = 64, DamageType = 2, Damage = function(source, target, level) return ({250, 475, 700})[level]/100*0.7 + source.ap end},--Caitlyn
	{Slot = "R", Stage = 65, DamageType = 2, Damage = function(source, target, level) return (({200, 425, 650})[level] + 1.3 * source.ap) end},--Neeko
	{Slot = "R", Stage = 66, DamageType = 2, Damage = function(source, target, level) return ({150, 225, 300})[level] + 0.7 * source.ap end},--Orianna
	{Slot = "R", Stage = 67, DamageType = 2, Damage = function(source, target, level) return ({50, 70, 90})[level] + 0.2 * source.ap end},--Swain
	{Slot = "R", Stage = 68, DamageType = 2, Damage = function(source, target, level) return ({250, 400, 550})[level] + source.ap end}, --Thresh
	{Slot = "R", Stage = 69, DamageType = 2, Damage = function(source, target, level) return ({250, 475, 700})[level] + 1.25 * source.ap + 2.5 * source.bonusDamage end},--Volibear
	{Slot = "R", Stage = 70, DamageType = 2, Damage = function(source, target, level) return ({180, 270, 360})[level] + 1.05 * source.ap end},--Ahri
	{Slot = "R", Stage = 71, DamageType = 3, Damage = function(source, target, level) return ({100, 200, 300})[level] + 0.375 * source.ap end},--Darius
	{Slot = "R", Stage = 72, DamageType = 2, Damage = function(source, target, level) return ({150, 300, 450})[level] + 1.5 * source.ap end},--Ekko
	{Slot = "R", Stage = 73, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.7 * source.ap end},--Galio
	{Slot = "R", Stage = 74, DamageType = 2, Damage = function(source, target, level) return ({105, 262, 420})[level] + source.ap end},--LeeSin
	{Slot = "R", Stage = 75, DamageType = 2, Damage = function(source, target, level) return ({105, 192, 280})[level] + 0.6 * source.ap end},--Nocturne
	{Slot = "R", Stage = 76, DamageType = 2, Damage = function(source, target, level) return ({200, 350, 500})[level] + 0.5 * source.ap end},--Pantheon
	{Slot = "R", Stage = 77, DamageType = 2, Damage = function(source, target, level) return ({140, 210, 280})[level] + 0.45 * source.ap end},--Poppy
	{Slot = "R", Stage = 78, DamageType = 2, Damage = function(source, target, level) return ({100, 200, 300})[level] + 0.5 * source.ap end},--Rakan
	{Slot = "R", Stage = 79, DamageType = 2, Damage = function(source, target, level) return ({70, 175, 280})[level] + source.ap + (({0.20, 0.25, 0.30})[level] * (target.maxHealth - target.health)) end},--RekSai
	{Slot = "R", Stage = 80, DamageType = 2, Damage = function(source, target, level) return ({200, 300, 400})[level] + source.ap end},--Shaco
	{Slot = "R", Stage = 81, DamageType = 2, Damage = function(source, target, level) return ({63, 94, 126})[level] + 0.5 * source.ap end},--Talon
	{Slot = "R", Stage = 82, DamageType = 2, Damage = function(source, target, level) return ({105, 210, 315})[level] + 0.7 * source.ap end},--Vi
	{Slot = "R", Stage = 83, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.6 * source.ap end},--Viktor
	{Slot = "R", Stage = 84, DamageType = 2, Damage = function(source, target, level) return ({70, 105, 140})[level] + 0.5 * source.ap end},--Xayah
	{Slot = "R", Stage = 85, DamageType = 2, Damage = function(source, target, level) return ({140, 210, 280})[level] + 0.75 * source.ap end},--Yasuo
	{Slot = "R", Stage = 86, DamageType = 1, Damage = function(source, target, level) return ({250, 250, 250, 250, 250, 250, 290, 330, 370, 400, 430, 450, 470, 490, 510, 530, 540, 550})[source.levelData.lvl] + 0.8 * source.bonusDamage + 1.5 * source.armorPen end}, --Pyke	
  },  

  ["Syndra"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 105, 140, 175, 210})[level] + 0.65 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + 0.7 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({85, 130, 175, 220, 265})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({270, 420, 570})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({90, 140, 190})[level] + 0.2 * source.ap end},-- PER SPHERE
  },

  ["Talon"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({60, 90, 115, 140, 165})[level] + 1.1 * source.bonusDamage end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({45, 60, 75, 90, 105})[level] + 0.55 * source.bonusDamage end},--INITIAL DAMAGE
    {Slot = "W", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({45, 70, 95, 120, 145})[level] + 0.7 * source.bonusDamage end},--RETURN DAMAGE
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({90, 135, 180})[level] + source.bonusDamage end},
  },

  ["Taliyah"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 95, 120, 145, 170})[level] + 0.45 * source.ap end},
    {Slot = "Q", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({210, 285, 360, 435, 510})[level] + 1.35 * source.ap end},--Single Target
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 80, 100, 120, 140})[level] + 0.4 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 90, 110, 130, 150})[level] + 0.4 * source.ap end},
    {Slot = "E", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({160, 210, 260, 310, 360})[level] + 0.8 * source.ap end},
  },

  ["Taric"] = {
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({90, 130, 170, 210, 250})[level] end},
  },

  ["TahmKench"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 130, 180, 230, 280})[level] + 0.7 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return target.type == Obj_AI_Minion and ({400, 450, 500, 550, 600})[level] or (({0.20, 0.23, 0.26, 0.29, 0.32})[level] + 0.02 * source.ap / 100) * target.maxHealth end},
    {Slot = "W", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({100, 135, 170, 205, 240})[level] + 0.6 * source.ap end},--PROJECTILE DAMAGE
  },


  ["Teemo"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 125, 170, 215, 260})[level] + 0.8 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({34, 68, 102, 136, 170})[level] + 0.7 * source.ap end},
    {Slot = "E", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({10, 20, 30, 40, 50})[level] + 0.3 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({200, 325, 450})[level] + 0.5 * source.ap end},
  },

  ["Thresh"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 120, 160, 200, 240})[level] + 0.5 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({65, 95, 125, 155, 185})[level] + 0.4 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({250, 400, 550})[level] + source.ap end},
  },

  ["Tristana"] = {
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({95, 145, 195, 245, 295})[level] + 0.5 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({70, 80, 90, 100, 110})[level] + ({0.5, 0.75, 1, 1.25, 1.5})[level] * source.bonusDamage + 0.5 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({300, 400, 500})[level] + source.ap end},
  },

  ["Trundle"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 40, 60, 80, 100})[level] + ({0.15, 0.25, 0.35, 0.45, 0.55})[level] * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({20, 27, 35})[level] / 100 + 0.02 * source.ap / 100) * target.maxHealth end},
  },

  ["Tryndamere"] = {
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({80, 110, 140, 170, 200})[level] + 1.3 * source.bonusDamage + 0.8 * source.ap end},
  },

  ["TwistedFate"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 105, 150, 195, 240})[level] + 0.65 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 60, 80, 100, 120})[level] + source.totalDamage + 0.9 * source.ap end},--Blue Card
    {Slot = "W", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({30, 45, 60, 75, 90})[level] + source.totalDamage + 0.6 * source.ap end},--Red Card
    {Slot = "W", Stage = 3, DamageType = 2, Damage = function(source, target, level) return ({15, 22.5, 30, 37.5, 45})[level] + source.totalDamage + 0.5 * source.ap end},--Gold Card
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({65, 90, 115, 140, 165})[level] + 0.5 * source.ap end},
  },

  ["Twitch"] = {
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return (GotBuff(target, "twitchdeadlyvenom") * ({15, 20, 25, 30, 35})[level] + 0.25 * source.ap + 0.35 * source.bonusDamage) + ({20, 35, 50, 65, 80})[level] end},
    {Slot = "E", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({15, 20, 25, 30, 35})[level] + 0.333 * source.ap + 0.35 * source.bonusDamage + ({20, 35, 50, 65, 80})[level] end},
  },

  ["Udyr"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({30, 60, 90, 120, 150, 180})[level] + (({110, 125, 140, 155, 170, 185})[level] / 100) * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 80, 120, 160, 200, 240})[level] + source.ap end},

  },

  ["Urgot"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({25, 70, 115, 160, 205})[level] + 0.7 * source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({90, 120, 150, 180, 210})[level] + source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({100, 225, 350})[level] + 0.5 * source.bonusDamage end},	
  },

  ["Varus"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({10, 47, 83, 120, 157})[level] + source.totalDamage end},
    {Slot = "Q", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({15, 70, 125, 180, 235})[level] + 1.65 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({7, 8, 9, 10, 11})[level] + 0.25 * source.ap end},
    {Slot = "W", Stage = 2, DamageType = 2, Damage = function(source, target, level) return (({3, 3.5, 4, 4.5, 5})[level] / 100 + 0.02 * source.ap / 100) * target.maxHealth end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({60, 100, 140, 180, 220})[level] + 0.6 * source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 200, 250})[level] + source.ap end},
  },

  ["Vayne"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({60, 65, 70, 75, 80})[level] / 100 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 3, Damage = function(source, target, level) return math.max(({50, 65, 80, 95, 110})[level], (({4, 6.5, 9, 11.5, 14})[level] / 100) * target.maxHealth) end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({50, 85, 120, 155, 190})[level] + 0.5 * source.bonusDamage end},
  },

  ["Veigar"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 120, 160, 200, 240})[level] + 0.6 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({100, 150, 200, 250, 300})[level] + source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) local dmg = GetPercentHP(target) > 33.3 and ({175, 250, 325})[level] + 0.75 * source.ap or ({350, 500, 650})[level] + 1.5 * source.ap; return dmg+((0.015 * dmg) * (100 - ((target.health / target.maxHealth) * 100))) end},
  },

  ["Velkoz"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 120, 160, 200, 240})[level] + 0.8 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({30, 50, 70, 90, 110})[level] + ({45, 75, 105, 135, 165})[level] + 0.4 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 100, 130, 160, 190})[level] + 0.3 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 3, Damage = function(source, target, level) return (GotBuff(target, "velkozresearchedstack") > 0 and ({450, 625, 800})[level] + 1.25* source.ap or CalcMagicalDamage(source, target, ({450, 625, 800})[level] + 1.25 * source.ap)) end},
  },
  
  ["Viego"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({25, 40, 55, 70, 85})[level] + 0.6 * source.totalDamage + 0.075 * source.critChance end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 135, 190, 245, 300})[level] + source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return (({0.15, 0.20, 0.25})[level] * (target.maxHealth - target.health)) + 1.2 * source.totalDamage + 0.075 * source.critChance end},
  },  

  ["Vi"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({55, 80, 105, 130, 155})[level] + 0.7 * source.bonusDamage end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return (({4, 5.5, 7, 8.5, 10})[level] / 100 + 0.01 * source.bonusDamage / 35) * target.maxHealth end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({10, 30, 50, 70, 90})[level] + 1.1 * source.totalDamage + 0.9 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({150, 325, 500})[level] + 1.1 * source.bonusDamage end},
  },

  ["Viktor"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 120, 160, 200, 240})[level] + source.ap + source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + 0.5 * source.ap end},
    {Slot = "E", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({90, 170, 250, 330, 410})[level] + 1.3 * source.ap end},--Total Damage
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({100, 175, 250})[level] + 0.5 * source.ap end},
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({65, 105, 145})[level] + 0.45 * source.ap end},--Per Tick
  },

  ["Vladimir"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 100, 120, 140, 160})[level] + 0.6 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 135, 190, 245, 300})[level] + 0.1 * (source.maxHealth - 537 + 96 * myHero.levelData.lvl) end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({30, 45, 60, 75, 90})[level] + 0.35 * source.ap + 0.025 * source.maxHealth end},
    {Slot = "E", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({60, 90, 120, 150, 180})[level] + 0.8 * source.ap + 0.06 * source.maxHealth end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.7 * source.ap end},
  },

  ["Volibear"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 40, 60, 80, 100})[level] + 1.2 * source.bonusDamage end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return (({15, 52, 90, 127, 165})[level]) + 1.5 * source.totalDamage + 0.09 * (myHero.maxHealth - GetBaseHealth(myHero)) end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 90, 120, 150, 180})[level] + 0.8 * source.ap + ({0.07, 0.085, 0.1, 0.115, 0.13})[level] * target.maxHealth end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({300, 500, 700})[level] + 1.25 * source.ap + 2.5 * source.bonusDamage end},
  },

  ["Warwick"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({6, 7, 8, 9, 10})[level] / 100  * target.maxHealth) + source.ap + 1.2 * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({175, 350, 525})[level] + 1.67 * source.bonusDamage end},
  },
  
  ["Xayah"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({45, 65, 85, 105, 125})[level] + 0.5 * source.bonusDamage end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({55, 65, 75, 85, 95})[level] + 0.6 * source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({125, 250, 375})[level] + source.bonusDamage end},
  },  

  ["Xerath"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 120, 160, 200, 240})[level] + 0.75 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 90, 120, 150, 180})[level] + 0.6 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 110, 140, 170, 200})[level] + 0.45 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({200, 250, 300})[level] + 0.43 * source.ap end},
  },

  ["XinZhao"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 28, 36, 44, 52})[level] + 0.4 * source.bonusDamage end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({70, 115, 160, 205, 250})[level] + 1.1 * source.totalDamage end},	
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 75, 100, 125, 150})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({75, 175, 275})[level] + source.bonusDamage + 0.15 * target.health end},
  },

  ["Yasuo"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 45, 70, 95, 120})[level] + source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 70, 80, 90, 100})[level] + 0.2 * source.bonusDamage + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({200, 350, 500})[level] + 1.5 * source.bonusDamage end},
  },
  
  ["Yone"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 40, 60, 80, 100})[level] + source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({5, 10, 15, 20, 25})[level] + ({0.055, 0.06, 0.065, 0.07, 0.075})[level] * target.maxHealth end}, -- Ap Damage
    {Slot = "W", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({5, 10, 15, 20, 25})[level] + ({0.055, 0.06, 0.065, 0.07, 0.075})[level] * target.maxHealth end}, -- AD Damage
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({100, 200, 300})[level] + 0.4 * source.totalDamage end}, -- Ap Damage
    {Slot = "R", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({100, 200, 300})[level] + 0.4 * source.totalDamage end}, -- Ad Damage
  },  

  ["Yorick"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({30, 55, 80, 105, 130})[level] + 0.4 * source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 105, 140, 175, 210})[level] + 0.7 * source.ap + 0.15 * target.health end},
  },
  
  ["Yuumi"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 70, 100, 130, 160, 190})[level] + 0.3 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({240, 320, 400})[level] + 0.8 * source.ap end},
  },  

  ["Zac"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 55, 70, 85, 100})[level] + 0.3 * source.ap + 0.025 * source.maxHealth end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({25, 40, 55, 70, 85})[level] + (({4, 5, 6, 7, 8})[level] / 100 + 0.02 * source.ap / 100) * target.maxHealth end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 110, 160, 210, 260})[level] + 0.9 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({140, 210, 280})[level] + 0.4 * source.ap end},
  },

  ["Zed"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({80, 115, 150, 185, 220})[level] + source.bonusDamage end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({70, 90, 110, 130, 150})[level] + 0.8 * source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return source.totalDamage end},
  },

  ["Ziggs"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({85, 130, 175, 220, 265})[level] + 0.65 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 105, 140, 175, 210})[level] + 0.5 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 75, 110, 145, 180})[level] + 0.3 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({300, 450, 600})[level] + 1.1 * source.ap end},
  },

  ["Zilean"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 115, 165, 230, 300})[level] + 0.9 * source.ap end},
  },
  
  ["Zoe"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 80, 110, 140, 170})[level] + 0.6 * source.ap + ({7, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 29, 32, 35, 38, 42, 46, 50})[myHero.levelData.lvl] end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 105, 135, 165, 195})[level] + 0.4 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 100, 140, 180, 220})[level] + 0.4 * source.ap end},
  },  

  ["Zyra"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 95, 130, 165, 200})[level] + 0.6 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 105, 150, 195, 240})[level] + 0.5 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({180, 265, 350})[level] + 0.7 * source.ap end},
  }

}


function getdmg(spell,target,source,stage,level)
  local source = source or myHero
  local stage = stage or 1
  local swagtable = {}
  local k = 0
  if stage > 4 then stage = 4 end
  if spell == "Q" or spell == "W" or spell == "E" or spell == "R" or spell == "QM" or spell == "WM" or spell == "EM" then
    local level = level or source:GetSpellData(({["Q"] = _Q, ["QM"] = _Q, ["W"] = _W, ["WM"] = _W, ["E"] = _E, ["EM"] = _E, ["R"] = _R})[spell]).level
    if level <= 0 then return 0 end
    if level > 5 then level = 5 end
    if DamageLibTable[source.charName] then
      for i, spells in pairs(DamageLibTable[source.charName]) do
        if spells.Slot == spell then
          table.insert(swagtable, spells)
        end
      end
      if stage > #swagtable then stage = #swagtable end
      for v = #swagtable, 1, -1 do
        local spells = swagtable[v]
        if spells.Stage == stage then
          if spells.DamageType == 1 then
            return CalcPhysicalDamage(source, target, spells.Damage(source, target, level))
          elseif spells.DamageType == 2 then
            return CalcMagicalDamage(source, target, spells.Damage(source, target, level))
          elseif spells.DamageType == 3 then
            return spells.Damage(source, target, level)
          end
        end
      end
    end
  end
  if spell == "AA" then
    return CalcPhysicalDamage(source, target, source.totalDamage)
  end
  if spell == "IGNITE" then
    return 50+20*source.levelData.lvl - (target.hpRegen*3)
  end
  if spell == "SMITE" then
    if Smite then
      if target.type == Obj_AI_Hero then
        if source:GetSpellData(Smite).name == "s5_summonersmiteplayerganker" then
          return 20+8*source.levelData.lvl
        end
        if source:GetSpellData(Smite).name == "s5_summonersmiteduel" then
          return 54+6*source.levelData.lvl
        end
      end
      return ({390, 410, 430, 450, 480, 510, 540, 570, 600, 640, 680, 720, 760, 800, 850, 900, 950, 1000})[source.levelData.lvl]
    end
  end
  if spell == "BILGEWATER" then
    return CalcMagicalDamage(source, target, 100)
  end
  if spell == "BOTRK" then
    return CalcMagicalDamage(source, target, 100)
  end
  if spell == "HEXTECH" then
    return CalcMagicalDamage(source, target, 150+0.4*source.ap)
  end
  return 0
end
