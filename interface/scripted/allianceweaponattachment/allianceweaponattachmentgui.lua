require "/scripts/util.lua"

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
	if root.itemHasTag(weaponConfig.config.itemName, "weapon") and weaponConfig.config.theaAttachmentType ~= nil and not weapon.parameters.theaCurrentAttachment then
	  weaponCheck = true
	  --sb.logInfo("WEAPONATTACHMENT - WeaponInfo - "..weaponConfig.config.itemName)
	  --sb.logInfo("WEAPONATTACHMENT - WeaponInfo - "..weaponConfig.config.theaAttachmentType)
	else
	  --sb.logInfo("WEAPONATTACHMENT - Weapon Check Failed")
	end
  else
	--sb.logInfo("WEAPONATTACHMENT - No weapon!")
  end
  
  --Analyze the item in the mod slot
  local mod = world.containerItemAt(pane.containerEntityId(), 1)
  local modConfig = root.itemConfig(mod)
  local modCheck = false
  
  if mod then
	if root.itemHasTag(modConfig.config.itemName, "thea_attachment") and modConfig.config.theaAttachmentType ~= nil and modConfig.config.theaAttachmentAbility ~= nil then
	  modCheck = true
	  --sb.logInfo("WEAPONATTACHMENT - ModInfo - "..modConfig.config.itemName)
	  --sb.logInfo("WEAPONATTACHMENT - ModInfo - "..modConfig.config.theaAttachmentType)
	  --sb.logInfo("WEAPONATTACHMENT - ModInfo - "..modConfig.config.theaAttachmentAbility)
	else
	  --sb.logInfo("WEAPONATTACHMENT - Mod Check Failed")
	end
  else
	--sb.logInfo("WEAPONATTACHMENT - No Mod!")
  end
  
  --If both checks are passed, compare the weapon and mod to see if they are compatible
  if weaponCheck and modCheck then
	if weaponConfig.config.theaAttachmentType == modConfig.config.theaAttachmentType then
	  createModdedWeapon(weaponConfig, modConfig)
	else
	  --sb.logInfo("WEAPONATTACHMENT - Attachment Types Incompatible")
	end
  end
end

function createModdedWeapon(weaponConfig, modConfig)
  --Consume the weapon and mod
  if weaponConfig and modConfig and not world.containerItemAt(pane.containerEntityId(), 2) then
	--sb.logInfo("WEAPONATTACHMENT - Items Consumed...")
	
	--Create the new weapon
	local newWeapon = root.createItem(weaponConfig.config.itemName)
	
	--Set up new spawn parameters
	newWeapon.parameters.level = weaponConfig.parameters.level or weaponConfig.config.level or 1
	newWeapon.parameters.altAbilityType = modConfig.config.theaAttachmentAbility
	newWeapon.parameters.theaCurrentAttachment = modConfig.config.itemName
	
	if weaponConfig.parameters.shortdescription then
	  newWeapon.parameters.shortdescription = weaponConfig.parameters.shortdescription
	end
	
	--player.giveItem(newWeapon)
	if world.containerAddItems(pane.containerEntityId(), newWeapon) then
	  --sb.logInfo("WEAPONATTACHMENT - Assembled weapon given!")
	  world.containerTakeAt(pane.containerEntityId(), 0)
	  world.containerTakeAt(pane.containerEntityId(), 1)
	end
  end
end

function attemptDetach()
  --Analyze the item in the weapon slot
  local weapon = world.containerItemAt(pane.containerEntityId(), 2)
  local weaponConfig = root.itemConfig(weapon)
  local weaponCheck = false
  
  if weapon then
	if root.itemHasTag(weaponConfig.config.itemName, "weapon") and weaponConfig.config.theaAttachmentType ~= nil and weapon.parameters.theaCurrentAttachment ~= nil then
	  weaponCheck = true
	  --sb.logInfo("WEAPONATTACHMENT - WeaponInfo - "..weaponConfig.config.itemName)
	  --sb.logInfo("WEAPONATTACHMENT - WeaponInfo - "..weaponConfig.config.theaAttachmentType)
	  --sb.logInfo("WEAPONATTACHMENT - WeaponInfo - "..weapon.parameters.theaCurrentAttachment)
	else
	  --sb.logInfo("WEAPONATTACHMENT - Weapon Check Failed")
	end
  else
	--sb.logInfo("WEAPONATTACHMENT - No weapon!")
  end
  
  if weaponCheck then
	dismantleModdedWeapon(weaponConfig, weapon.parameters.theaCurrentAttachment)
  end
end

function dismantleModdedWeapon(weaponConfig, attachmentType)
  if weaponConfig and attachmentType and not world.containerItemAt(pane.containerEntityId(), 0) and not world.containerItemAt(pane.containerEntityId(), 1) then
	--Generate an unmodded version of the dismantled weapon
	local newWeapon = root.createItem(weaponConfig.config.itemName)
	
	newWeapon.parameters.level = weaponConfig.parameters.level or weaponConfig.config.level or 1
	if weaponConfig.parameters.shortdescription then
	  newWeapon.parameters.shortdescription = weaponConfig.parameters.shortdescription
	end
	
	if world.containerAddItems(pane.containerEntityId(), newWeapon) and world.containerAddItems(pane.containerEntityId(), attachmentType) then
	  --sb.logInfo("WEAPONATTACHMENT - Weapon Dismantled!")
	  world.containerTakeAt(pane.containerEntityId(), 2)
	end
  end
end