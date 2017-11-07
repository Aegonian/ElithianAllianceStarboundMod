require "/scripts/util.lua"
require "/scripts/interp.lua"

--Slots: 0 = unmodded weapon, 1 = attachment, 2 = assembled weapon

function init()
  
end

function update(dt)
  
end

function attemptAttach()
  --Analyze the item in the weapon slot
  local weapon = world.containerItemAt(pane.containerEntityId(), 0)
  local weaponConfig = root.itemConfig(weapon)
  local weaponCheck = false
  
  if weapon then
	if root.itemHasTag(weaponConfig.config.itemName, "weapon") and weaponConfig.config.theaAttachmentType ~= nil then
	  weaponCheck = true
	  sb.logInfo("WEAPONATTACHMENT - WeaponInfo - "..weaponConfig.config.itemName)
	  sb.logInfo("WEAPONATTACHMENT - WeaponInfo - "..weaponConfig.config.theaAttachmentType)
	else
	  sb.logInfo("WEAPONATTACHMENT - Weapon Check Failed")
	end
  else
	sb.logInfo("WEAPONATTACHMENT - No weapon!")
  end
  
  --Analyze the item in the mod slot
  local mod = world.containerItemAt(pane.containerEntityId(), 1)
  local modConfig = root.itemConfig(mod)
  local modCheck = false
  
  if mod then
	if root.itemHasTag(modConfig.config.itemName, "thea_attachment") and modConfig.config.theaAttachmentType ~= nil and modConfig.config.theaAttachmentAbility ~= nil then
	  modCheck = true
	  sb.logInfo("WEAPONATTACHMENT - ModInfo - "..modConfig.config.itemName)
	  sb.logInfo("WEAPONATTACHMENT - ModInfo - "..modConfig.config.theaAttachmentType)
	  sb.logInfo("WEAPONATTACHMENT - ModInfo - "..modConfig.config.theaAttachmentAbility)
	else
	  sb.logInfo("WEAPONATTACHMENT - Mod Check Failed")
	end
  else
	sb.logInfo("WEAPONATTACHMENT - No Mod!")
  end
  
  --If both checks are passed, compare the weapon and mod to see if they are compatible
  if weaponCheck and modCheck then
	if weaponConfig.config.theaAttachmentType == modConfig.config.theaAttachmentType then
	  createModdedWeapon(weaponConfig, modConfig)
	end
  end
end

function createModdedWeapon(weaponConfig, modConfig)
  --Consume the weapon and mod
  if weaponConfig and modConfig and not world.containerItemAt(pane.containerEntityId(), 2) then
	sb.logInfo("WEAPONATTACHMENT - Items Consumed...")
	
	--Create the new weapon
	local newWeapon = root.createItem(weaponConfig.config.itemName)
	
	--Set up new spawn parameters
	newWeapon.parameters.level = weaponConfig.parameters.level or weaponConfig.config.level or 1
	newWeapon.parameters.altAbilityType = modConfig.config.theaAttachmentAbility
	
	--player.giveItem(newWeapon)
	if world.containerAddItems(pane.containerEntityId(), newWeapon) then
	  sb.logInfo("WEAPONATTACHMENT - Assembled weapon given!")
	  world.containerTakeAt(pane.containerEntityId(), 0)
	  world.containerTakeAt(pane.containerEntityId(), 1)
	end
  end
end

function attemptDetach()
  --TO-DO!
  
  local newGun = {
	name = "thea-tier3rifle",
	count = 1,
	parameters = {}
  }
  --world.containerPutItemsAt(pane.containerEntityId(), newGun, 0)
  world.containerAddItems(pane.containerEntityId(), newGun)
end