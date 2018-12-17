require "/scripts/util.lua"

function init()
  self.itemList = "itemScrollArea.itemList"

  self.reconstructCost = config.getParameter("reconstructCost")
  self.reconstructCostWeapon = config.getParameter("reconstructCostWeapon")
  self.reconstructCostArmour = config.getParameter("reconstructCostArmour")
  self.reconstructCostAttachment = config.getParameter("reconstructCostAttachment")
  
  self.collectionItems = {}
  self.selectedItem = nil
  self.upgradeToLevel = nil
  self.lastUpgradeLevel = nil
  populateItemList()
end

function update(dt)
  populateItemList()
end

function populateItemList(forceRepop)
  local collectionItems = player.collectables("thea_weapons")

  local playerEssence = player.currency("essence")
  
  if forceRepop or not compare(collectionItems, self.collectionItems) then
    self.collectionItems = collectionItems
    widget.clearListItems(self.itemList)
    widget.setButtonEnabled("btnUpgrade", false)
	
	--sb.logInfo("Player has the following items in their Unique Weapons collection: " .. sb.printJson(collectionItems, 1))
	
    local showEmptyLabel = true

    for i, item in pairs(self.collectionItems) do
      local config = root.itemConfig(item)

	  showEmptyLabel = false

	  local listItem = string.format("%s.%s", self.itemList, widget.addListItem(self.itemList))
	  local name = config.parameters.shortdescription or config.config.shortdescription
	  local cost = self.reconstructCost
	  if root.itemHasTag(config.config.itemName, "theaUnique") then
		cost = self.reconstructCostWeapon
	  elseif root.itemHasTag(config.config.itemName, "theaUniqueArmour") then
		cost = self.reconstructCostArmour
	  elseif root.itemHasTag(config.config.itemName, "theaUniqueAttachment") then
		cost = self.reconstructCostAttachment
	  end

	  widget.setText(string.format("%s.itemName", listItem), name)
	  widget.setItemSlotItem(string.format("%s.itemIcon", listItem), item)

	  widget.setData(listItem,
		{
		  index = i,
		  price = cost
		}
	  )
	  
	  widget.setVisible(string.format("%s.unavailableoverlay", listItem), cost > playerEssence)
    end

	self.selectedItem = nil
	showWeapon(nil)

    widget.setVisible("emptyLabel", showEmptyLabel)
  end
end

function showWeapon(item, price)
  local playerEssence = player.currency("essence")
  local enableButton = false

  if item then
    enableButton = playerEssence >= price
    local directive = enableButton and "^green;" or "^red;"
    widget.setText("essenceCost", string.format("%s%s / %s", directive, playerEssence, price))
  else
    widget.setText("essenceCost", string.format("%s / --", playerEssence))
  end

  widget.setButtonEnabled("btnReconstruct", enableButton)
end

function itemSelected()
  local listItem = widget.getListSelected(self.itemList)
  self.selectedItem = listItem

  if listItem then
    local itemData = widget.getData(string.format("%s.%s", self.itemList, listItem))
    local weaponItem = self.collectionItems[itemData.index]
    showWeapon(weaponItem, itemData.price)
  end
end

function doReconstruct()
  if self.selectedItem then
    local selectedData = widget.getData(string.format("%s.%s", self.itemList, self.selectedItem))
    local selectedItem = self.collectionItems[selectedData.index]

    if selectedItem then
	  --Create the item config for our newly reconstructed weapon
	  local reconstructItem = root.createItem(selectedItem)
	  reconstructItem.parameters.meritTokenValue = 10
	  
	  --If we successfully consumed enough currency, give the new item to the player
	  local consumedCurrency = player.consumeCurrency("essence", selectedData.price)
	  if consumedCurrency then
		player.giveItem(reconstructItem)
	  end
    end
    populateItemList(true)
  end
end
