require "/scripts/util.lua"

--Slots: 0 = item to be scrapped, 1 = materials returned

function init()
  self.conversionTables = config.getParameter("conversionTables")
  self.specialConversionTables = config.getParameter("specialConversionTables")
  self.levelMaterialTable = config.getParameter("levelMaterialTable")
end

function update(dt)
  local scrapItem = world.containerItemAt(pane.containerEntityId(), 0)
  
  if scrapItem then
	local scrapItemConfig = root.itemConfig(scrapItem)
	local scrapItemLevel = scrapItemConfig.parameters.level or scrapItemConfig.config.level or 1
	if root.itemHasTag(scrapItemConfig.config.itemName, "weapon") then
	  widget.setText("itemLevelLabel", "level: " .. scrapItemLevel)
	  widget.setButtonEnabled("btnDismantle", true)
	else
	  widget.setText("itemLevelLabel", "invalid!")
	  widget.setButtonEnabled("btnDismantle", false)
	end	
  else
	widget.setText("itemLevelLabel", "no item!")
	widget.setButtonEnabled("btnDismantle", false)
  end
end

function attemptDismantle()
  --Analyze the item in the weapon slot
  local scrapItem = world.containerItemAt(pane.containerEntityId(), 0)
  local scrapItemConfig = root.itemConfig(scrapItem)
  local scrapItemCheck = false
  
  --sb.logInfo("ITEMSCRAPPER - =================== Attempting a new dismantle action ===================")
  if scrapItem then
	if root.itemHasTag(scrapItemConfig.config.itemName, "weapon") then
	  scrapItemCheck = true
	  --sb.logInfo("ITEMSCRAPPER - Scrap Item Info - "..scrapItemConfig.config.itemName)
	else
	  --sb.logInfo("ITEMSCRAPPER - Scrap Item Check Failed")
	end
  else
	--sb.logInfo("ITEMSCRAPPER - No item!")
  end
  
  --If the item check passes and there's no item in the second slot, go to material creation
  if scrapItemCheck and not world.containerItemAt(pane.containerEntityId(), 1) and not world.containerItemAt(pane.containerEntityId(), 2) then
	createMaterials(scrapItemConfig)
  end
end

function createMaterials(scrapItemConfig)
  --Consume the item
  if scrapItemConfig and not world.containerItemAt(pane.containerEntityId(), 1) and not world.containerItemAt(pane.containerEntityId(), 2) then
	
	local materialCount = 1
	local specialMaterials = nil
	local specialMaterialCount = 1
	local specialMaterialPriority = 0
	local scrapItemTags = root.itemTags(scrapItemConfig.config.itemName) or {}
	local scrapItemLevel = scrapItemConfig.parameters.level or scrapItemConfig.config.level or 1
	
	--sb.logInfo("ITEMSCRAPPER - =================== Starting Conversion Check ===================")
	
	--For every tag on the scrap item, check against configured conversion tables
	for _, itemTag in ipairs(scrapItemTags) do
	  --sb.logInfo("ITEMSCRAPPER - Checking conversion tables for tag [" .. itemTag .."]")
	  for _, conversion in ipairs(self.conversionTables) do
		--If the tag that's currently being checked matches the conversion tag currently being checked
		if itemTag == conversion[1] then
		  --sb.logInfo("ITEMSCRAPPER - Tag [" .. itemTag .."] matches one of the configured conversion tags!")
		  --sb.logInfo("ITEMSCRAPPER - Material worth was [" .. materialCount .. "]. This tag is configured for a material worth of [" .. conversion[2] .. "]")
		  
		  --If the configured conversion count is greater than the currently set materialCount, increase our materialCount to that value
		  if conversion[2] > materialCount then
			materialCount = conversion[2]
		  end
		end
	  end
	  
	  --sb.logInfo("ITEMSCRAPPER - Checking special conversion tables for tag [" .. itemTag .."]")
	  for _, specialConversion in ipairs(self.specialConversionTables) do
		--If the tag that's currently being checked matches the conversion tag currently being checked
		if itemTag == specialConversion[1] then
		  --sb.logInfo("ITEMSCRAPPER - Tag [" .. itemTag .."] matches one of the configured special conversion tags!")
		  --sb.logInfo("ITEMSCRAPPER - Tag priority was [" .. specialMaterialPriority .. "]. This tag is configured for a priority of [" .. specialConversion[4] .. "]")
		  
		  --If the configured conversion priority is greater than the currently set priority, use this conversion instead
		  if specialConversion[4] > specialMaterialPriority then
			specialMaterials = specialConversion[2]
			specialMaterialCount = specialConversion[3]
			specialMaterialPriority = specialConversion[4]
		  end
		end
	  end
	end
	
	--sb.logInfo("ITEMSCRAPPER - Final material worth determined to be [" .. materialCount .."]")
	--sb.logInfo("ITEMSCRAPPER - Scrap item level is [" .. scrapItemLevel .."]")
	--if specialMaterials then
	  --sb.logInfo("ITEMSCRAPPER - Final special material determined to be [" .. specialMaterials .."]")
	--end
	--sb.logInfo("ITEMSCRAPPER - =================== Ending Conversion Check ===================")
	
	--Create the converted materials as an itemDescriptor
	local materials = root.createItem(self.levelMaterialTable[scrapItemLevel])
	materials.count = materialCount
	
	--If a special conversion was found, create these materials too
	if specialMaterials then
	  specialMaterials = root.createItem(specialMaterials)
	  specialMaterials.count = specialMaterialCount
	end
	
	if world.containerAddItems(pane.containerEntityId(), materials) then
	  if specialMaterials then
		world.containerAddItems(pane.containerEntityId(), specialMaterials)
	  end
	  world.containerTakeAt(pane.containerEntityId(), 0)
	  --sb.logInfo("ITEMSCRAPPER - Materials created and stored in the appropriate slot")
	end
  end
end