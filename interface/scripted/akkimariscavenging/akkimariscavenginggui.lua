require "/scripts/util.lua"

--Slots: 0 = item to be scrapped, 1 = materials returned, 2 = special materials returned

function init()
  self.conversionTables = config.getParameter("conversionTables")
  self.specialConversionTables = config.getParameter("specialConversionTables")
  self.levelMaterialTable = config.getParameter("levelMaterialTable")
  
  self.scrapItem = nil
  self.materialsItem = nil
  self.specialMaterialsItem = nil
  
  widget.setButtonEnabled("btnDismantle", false)
end

function update(dt)
  local scrapItem = world.containerItemAt(pane.containerEntityId(), 0)
  local materialsItem = world.containerItemAt(pane.containerEntityId(), 1)
  local specialMaterialsItem = world.containerItemAt(pane.containerEntityId(), 2)
  
  --Check if any of the slots changed
  if scrapItem ~= self.scrapItem or materialsItem ~= self.materialsItem or specialMaterialsItem ~= self.specialMaterialsItem then
	--If there is an item in the scrap item slot, check if we can perform a conversion
	if scrapItem then
	  local scrapItemConfig = root.itemConfig(scrapItem)
	  local scrapItemLevel = scrapItemConfig.parameters.level or scrapItemConfig.config.level or 1
	  
	  if root.itemHasTag(scrapItemConfig.config.itemName, "weapon") then
		local convertedItems = createMaterials(scrapItemConfig)
		if convertedItems then
		  widget.setText("itemLevelLabel", "level: " .. scrapItemLevel)
		  widget.setButtonEnabled("btnDismantle", true)
		else
		  widget.setText("itemLevelLabel", "slots full")
		  widget.setButtonEnabled("btnDismantle", false)
		end
	  else
		widget.setText("itemLevelLabel", "invalid item")
		widget.setButtonEnabled("btnDismantle", false)
	  end
	else
	  widget.setText("itemLevelLabel", "insert item")
	  widget.setButtonEnabled("btnDismantle", false)
	end
  end
  
  --Save the item that were in the three slots last
  self.scrapItem = scrapItem
  self.materialsItem = materialsItem
  self.specialMaterialsItem = specialMaterialsItem
end

function attemptDismantle()
  --Analyze the item in the weapon slot
  local scrapItem = world.containerItemAt(pane.containerEntityId(), 0)
  local scrapItemConfig = root.itemConfig(scrapItem)
  
  --If the item check passes, create the converted materials
  local convertedItems = createMaterials(scrapItemConfig)
  if convertedItems then
	if world.containerAddItems(pane.containerEntityId(), convertedItems[1]) then
	  if convertedItems[2] then
		world.containerAddItems(pane.containerEntityId(), convertedItems[2])
	  end
	  world.containerTakeAt(pane.containerEntityId(), 0)
	end
  end
end

function createMaterials(scrapItemConfig)
  --If we were given an item config and this item has the appropriate tags, continue with the calculations
  if scrapItemConfig and root.itemHasTag(scrapItemConfig.config.itemName, "weapon") then
	
	--Get the initial values needed for the material conversion calculations
	local materialCount = 1
	local specialMaterials = nil
	local specialMaterialCount = 1
	local specialMaterialPriority = 0
	local scrapItemTags = root.itemTags(scrapItemConfig.config.itemName) or {}
	local scrapItemLevel = scrapItemConfig.parameters.level or scrapItemConfig.config.level or 1
	
	--===================================== TAG COMPARISONS =====================================
	--For every tag on the scrap item, check against configured conversion tables
	for _, itemTag in ipairs(scrapItemTags) do
	  for _, conversion in ipairs(self.conversionTables) do
		--If the tag that's currently being checked matches the conversion tag currently being checked
		if itemTag == conversion[1] then
		  
		  --If the configured conversion count is greater than the currently set materialCount, increase our materialCount to that value
		  if conversion[2] > materialCount then
			materialCount = conversion[2]
		  end
		end
	  end
	  
	  for _, specialConversion in ipairs(self.specialConversionTables) do
		--If the tag that's currently being checked matches the conversion tag currently being checked
		if itemTag == specialConversion[1] then
		  
		  --If the configured conversion priority is greater than the currently set priority, use this conversion instead
		  if specialConversion[4] > specialMaterialPriority then
			specialMaterials = specialConversion[2]
			specialMaterialCount = specialConversion[3]
			specialMaterialPriority = specialConversion[4]
		  end
		end
	  end
	end
	
	--===================================== MATERIAL CREATION =====================================
	--Create the converted materials as an itemDescriptor
	local materials = root.createItem(self.levelMaterialTable[math.max(1, math.floor(scrapItemLevel))])
	materials.count = materialCount
	
	--If a special conversion was found, create these materials too
	if specialMaterials then
	  specialMaterials = root.createItem(specialMaterials)
	  specialMaterials.count = specialMaterialCount
	end
	
	--===================================== SLOT CHECKS =====================================
	local materialsSlotItem = world.containerItemAt(pane.containerEntityId(), 1)
	local specialMaterialsSlotItem = world.containerItemAt(pane.containerEntityId(), 2)
	local slot1Check = false
	local slot2Check = false
	
	if materialsSlotItem then
	  --Check if the items match and there is space left. Assume the items can stack to 1000
	  if materialsSlotItem.name == materials.name and (materialsSlotItem.count + materials.count) <= 1000 then
		slot1Check = true
	  end
	else
	  slot1Check = true
	end
	
	if specialMaterialsSlotItem and specialMaterials then
	  --Check if the items match and there is space left. Assume the items can stack to 1000
	  if specialMaterialsSlotItem.name == specialMaterials.name and (specialMaterialsSlotItem.count + specialMaterials.count) <= 1000 then
		slot2Check = true
	  end
	else
	  slot2Check = true
	end
	
	--===================================== RESULTS =====================================
	if slot1Check and slot2Check then
	  return {materials, specialMaterials}
	else
	  return false
	end
  else
	return false
  end
end