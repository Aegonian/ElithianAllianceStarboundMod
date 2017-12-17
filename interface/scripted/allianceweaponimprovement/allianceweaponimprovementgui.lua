require "/scripts/util.lua"
require "/scripts/interp.lua"

function init()
  self.itemList = "itemScrollArea.itemList"

  self.upgradeableWeaponItems = {}
  self.selectedItem = nil
  populateItemList()
end

function update(dt)
  populateItemList()
end

function populateItemList(forceRepop)
  local upgradeableWeaponItems = player.itemsWithTag("allianceUpgradeable")
  for i = 1, #upgradeableWeaponItems do
    upgradeableWeaponItems[i].count = 1
  end

  if forceRepop or not compare(upgradeableWeaponItems, self.upgradeableWeaponItems) then
    self.upgradeableWeaponItems = upgradeableWeaponItems
    widget.clearListItems(self.itemList)
    widget.setButtonEnabled("btnUpgrade", false)

    local showEmptyLabel = true

    for i, item in pairs(self.upgradeableWeaponItems) do
      local config = root.itemConfig(item)

	  showEmptyLabel = false

	  local listItem = string.format("%s.%s", self.itemList, widget.addListItem(self.itemList))
	  local name = config.config.shortdescription

	  widget.setText(string.format("%s.itemName", listItem), name)
	  widget.setItemSlotItem(string.format("%s.itemIcon", listItem), item)

	  widget.setData(listItem,
		{
		  index = i
		})
    end

    self.selectedItem = nil
    showWeapon(nil)

    widget.setVisible("emptyLabel", showEmptyLabel)
  end
end

function showWeapon(item, price)
  local enableButton = false

  if item then
    enableButton = true
    local config = root.itemConfig(item)
	local level = config.parameters.level or config.config.level or 1
    widget.setText("currentLevelLabel", level)
  else
    widget.setText("currentLevelLabel", "-")
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
      if consumedItem then
        local consumedCurrency = player.consumeCurrency("essence", selectedData.price)
        local upgradedItem = copy(consumedItem)
        if consumedCurrency then
          upgradedItem.parameters.level = self.upgradeLevel
          local itemConfig = root.itemConfig(upgradedItem)
          if itemConfig.config.upgradeParameters then
            upgradedItem.parameters = util.mergeTable(upgradedItem.parameters, itemConfig.config.upgradeParameters)
          end
        end
        player.giveItem(upgradedItem)
      end
    end
    populateItemList(true)
  end
end
