require "/scripts/util.lua"

--Slots: 0 = unique item, 1 = sacrificed item, 2 = upgraded item

function init()
  
end

function update(dt)
  --Check item
  local item = world.containerItemAt(pane.containerEntityId(), 0)
  local itemConfig = root.itemConfig(item)
  local itemCheck = false
  local itemLevel = nil
  
  if item then
	if root.itemHasTag(itemConfig.config.itemName, "theaUnique") or root.itemHasTag(itemConfig.config.itemName, "theaUniqueArmour") then
	  itemCheck = true
	end
	
	if itemConfig.parameters.level or itemConfig.config.level then
	  widget.setText("itemLevelLabel", itemConfig.parameters.level or itemConfig.config.level)
	  itemLevel = itemConfig.parameters.level or itemConfig.config.level
	else
	  widget.setText("itemLevelLabel", "-")
	  itemLevel = nil
	end
  else
	widget.setText("itemLevelLabel", "-")
	itemLevel = nil
  end
  
  --Check sacrifice
  local sacrifice = world.containerItemAt(pane.containerEntityId(), 1)
  local sacrificeConfig = root.itemConfig(sacrifice)
  local sacrificeCheck = false
  local sacrificeLevel = nil
  
  if sacrifice then
	if (root.itemHasTag(sacrificeConfig.config.itemName, "weapon") or root.itemHasTag(sacrificeConfig.config.itemName, "theaUnique") or root.itemHasTag(sacrificeConfig.config.itemName, "theaUniqueArmour")) and not root.itemHasTag(sacrificeConfig.config.itemName, "theaUninfusable") then
	  sacrificeCheck = true
	end
	
	if sacrificeConfig.parameters.level or sacrificeConfig.config.level then
	  widget.setText("sacrificeLevelLabel", sacrificeConfig.parameters.level or sacrificeConfig.config.level)
	  sacrificeLevel = sacrificeConfig.parameters.level or sacrificeConfig.config.level
	else
	  widget.setText("sacrificeLevelLabel", "-")
	  sacrificeLevel = nil
	end
  else
	widget.setText("sacrificeLevelLabel", "-")
	sacrificeLevel = nil
  end
  
  --Enable or disable infusion button
  local enableButton = false
  
  if itemCheck and sacrificeCheck then
	if itemLevel and sacrificeLevel then
	  if sacrificeLevel > itemLevel then
		enableButton = true
	  end
	end
  end
  
  widget.setButtonEnabled("btnInfuse", enableButton)
end

function attemptInfuse()
  --sb.logInfo("=============================================")
  --sb.logInfo("UNIQUEINFUSION - Attempting a new infusion...")
  
  --Analyze the item in the unique item slot
  local item = world.containerItemAt(pane.containerEntityId(), 0)
  local itemConfig = root.itemConfig(item)
  local itemCheck = false
  local itemLevel = 0
  
  if item then
	if root.itemHasTag(itemConfig.config.itemName, "theaUnique") or root.itemHasTag(itemConfig.config.itemName, "theaUniqueArmour") then
	  itemCheck = true
	  itemLevel = itemConfig.parameters.level or itemConfig.config.level
	  --sb.logInfo("UNIQUEINFUSION - ItemInfo - " .. itemConfig.config.itemName)
	  --sb.logInfo("UNIQUEINFUSION - ItemInfo - " .. itemLevel)
	  --sb.logInfo("UNIQUEINFUSION - ItemInfo - Full parameters below:")
	  --sb.logInfo(sb.printJson(itemConfig.parameters or {}, 1))
	else
	  --sb.logInfo("UNIQUEINFUSION - Item Check Failed")
	end
  else
	--sb.logInfo("UNIQUEINFUSION - No unique item!")
  end
  
  --Analyze the item in the sacrifice slot
  local sacrifice = world.containerItemAt(pane.containerEntityId(), 1)
  local sacrificeConfig = root.itemConfig(sacrifice)
  local sacrificeCheck = false
  local sacrificeLevel = 0
  
  if sacrifice then
	if root.itemHasTag(sacrificeConfig.config.itemName, "weapon") or root.itemHasTag(sacrificeConfig.config.itemName, "theaUnique") or root.itemHasTag(sacrificeConfig.config.itemName, "theaUniqueArmour") then
	  sacrificeCheck = true
	  sacrificeLevel = sacrificeConfig.parameters.level or sacrificeConfig.config.level
	  --sb.logInfo("UNIQUEINFUSION - SacrificeInfo - " .. sacrificeLevel)
	  --sb.logInfo("UNIQUEINFUSION - ItemInfo - Full parameters below:")
	  --sb.logInfo(sb.printJson(sacrificeConfig.parameters or {}, 1))
	else
	  --sb.logInfo("UNIQUEINFUSION - Sacrifice Check Failed")
	end
  else
	--sb.logInfo("UNIQUEINFUSION - No sacrifice item!")
  end
  
  --If both checks are passed, compare the weapon and mod to see if they are compatible
  if itemCheck and sacrificeCheck then
	if sacrificeLevel > itemLevel then
	  createInfusedItem(itemConfig, sacrificeLevel)
	else
	  --sb.logInfo("UNIQUEINFUSION - Sacrifice level insufficient! Tried to upgrade item (level " .. itemLevel .. ") using sacrifice (level " .. sacrificeLevel .. ")" )
	end
  end
end

function createInfusedItem(itemConfig, sacrificeLevel)
  --Consume the weapon and mod
  if itemConfig and sacrificeLevel and not world.containerItemAt(pane.containerEntityId(), 2) then
	--sb.logInfo("UNIQUEINFUSION - Items Consumed...")
	
	--Create the new weapon
	local newItem = root.createItem(itemConfig.config.itemName)
	
	--Set up new spawn parameters
	local addedParameters = {}
	addedParameters.level = sacrificeLevel
	addedParameters.shortdescription = itemConfig.config.shortdescription .. " [L." .. sacrificeLevel .."]"
	
	--Merge the new parameters with any parameters that may have already been applied to the weapon
	newItem.parameters = util.mergeTable(itemConfig.parameters or {}, addedParameters)
	--newItem.parameters.level = itemConfig.parameters.level or itemConfig.config.level or 1
	
	--player.giveItem(newItem)
	if world.containerAddItems(pane.containerEntityId(), newItem) then
	  --sb.logInfo("UNIQUEINFUSION - Upgraded item given!")
	  world.containerTakeAt(pane.containerEntityId(), 0)
	  world.containerTakeAt(pane.containerEntityId(), 1)
	end
  end
end