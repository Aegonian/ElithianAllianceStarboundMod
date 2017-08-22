require "/scripts/util.lua"
require "/scripts/interp.lua"

function init()
  self.itemList = "itemScrollArea.itemList"

  self.upgradeLevel = config.getParameter("upgradeLevel")

  self.upgradeableWeaponItems = {}
  self.selectedItem = nil
  populateItemList()
end

function update(dt)
  populateItemList()
end

function upgradeCost(itemConfig)
  if itemConfig == nil then return 0 end

  local prevValue = root.evalFunction("weaponEssenceValue", itemConfig.parameters.level or itemConfig.config.level or 1)
  local newValue = root.evalFunction("weaponEssenceValue", self.upgradeLevel)

  return math.floor(newValue - prevValue)
end

function populateItemList(forceRepop)
  local upgradeableWeaponItems = player.itemsWithTag("allianceAttachmentCompatible")
  for i = 1, #upgradeableWeaponItems do
    upgradeableWeaponItems[i].count = 1
  end

  local playerEssence = player.currency("essence")

  if forceRepop or not compare(upgradeableWeaponItems, self.upgradeableWeaponItems) then
    self.upgradeableWeaponItems = upgradeableWeaponItems
    widget.clearListItems(self.itemList)
    widget.setButtonEnabled("btnUpgrade", false)

    local showEmptyLabel = true

    for i, item in pairs(self.upgradeableWeaponItems) do
      local config = root.itemConfig(item)

      if (config.parameters.level or config.config.level or 1) < self.upgradeLevel then
        showEmptyLabel = false

        local listItem = string.format("%s.%s", self.itemList, widget.addListItem(self.itemList))
        local name = config.config.shortdescription

        widget.setText(string.format("%s.itemName", listItem), name)
        widget.setItemSlotItem(string.format("%s.itemIcon", listItem), item)

        local price = upgradeCost(config)
        widget.setData(listItem,
          {
            index = i,
            price = price
          })

        widget.setVisible(string.format("%s.unavailableoverlay", listItem), price > playerEssence)
      end
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

  widget.setButtonEnabled("btnUpgrade", enableButton)
end

function itemSelected()
  local listItem = widget.getListSelected(self.itemList)
  self.selectedItem = listItem

  if listItem then
    local itemData = widget.getData(string.format("%s.%s", self.itemList, listItem))
    local weaponItem = self.upgradeableWeaponItems[itemData.index]
    showWeapon(weaponItem, itemData.price)
  end
end

function doUpgrade()
  if self.selectedItem then
    local selectedData = widget.getData(string.format("%s.%s", self.itemList, self.selectedItem))
    local upgradeItem = self.upgradeableWeaponItems[selectedData.index]

    if upgradeItem then
      local consumedItem = player.consumeItem(upgradeItem, false, true)
      --Functional code!
	  --if consumedItem then
        --local consumedCurrency = player.consumeCurrency("essence", selectedData.price)
		--local itemConfig = root.itemConfig(consumedItem)
		--local newitem = itemConfig.config.itemName
		
		--Getting the intended spawn position
		--local sourceEntity = pane.sourceEntity()
		--local position = world.entityPosition(sourceEntity)
		
		--Setting up parameters for the new weapon
		--local parameters = {}
		--parameters.altAbilityType = "thea-grenadelauncher"
		--parameters.level = itemConfig.parameters.level or itemConfig.config.level or 1
		--parameters.shortdescription = "TEST"
		
		--Spawning the item
		--world.spawnItem(newitem, position, 1, parameters)
      --end
	  
	  if consumedItem then
        local consumedCurrency = player.consumeCurrency("essence", selectedData.price)
		local itemConfig = root.itemConfig(consumedItem)
		local upgradedItem = copy(consumedItem)
		
		--Setting up parameters for the new weapon
		upgradedItem.parameters.shortdescription = "TEST"
		upgradedItem.parameters.level = itemConfig.parameters.level or itemConfig.config.level or 1
		upgradedItem.parameters.altAbilityType = "thea-grenadelauncher"
		
		--Spawning the item
		player.giveItem(upgradedItem)
      end
    end
    populateItemList(true)
  end
end
