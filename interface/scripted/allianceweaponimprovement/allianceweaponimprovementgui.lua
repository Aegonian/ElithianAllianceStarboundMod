require "/scripts/util.lua"

function init()
  self.itemList = "itemScrollArea.itemList"
  
  self.upgradeItemTag = config.getParameter("upgradeItemTag")
  self.upgradeKitTag = config.getParameter("upgradeKitTag")
  
  self.upgradeableWeaponItems = {}
  self.selectedItem = nil
  self.upgradeToLevel = nil
  self.lastUpgradeLevel = nil
  populateItemList()
end

function update(dt)
  populateItemList()
  checkUpgradeItemSlot()
  
  --If the upgradeKit item changed, force the interface to recheck the currently selected item
  if not compare(self.lastUpgradeLevel, self.upgradeToLevel) then
	itemSelected()
	populateItemList(true)
  end
  self.lastUpgradeLevel = self.upgradeToLevel
end

function populateItemList(forceRepop)
  local upgradeableWeaponItems = player.itemsWithTag(self.upgradeItemTag)
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
	  local name = config.parameters.shortdescription or config.config.shortdescription

	  widget.setText(string.format("%s.itemName", listItem), name)
	  widget.setItemSlotItem(string.format("%s.itemIcon", listItem), item)

	  widget.setData(listItem,
		{
		  index = i
		})
	  
	  local hideWeapon = true
	  if (config.parameters.level or config.config.level) < (self.upgradeToLevel or 0) then
		hideWeapon = false
	  end
	  widget.setVisible(string.format("%s.unavailableoverlay", listItem), hideWeapon)
    end

	self.selectedItem = nil
	showWeapon(nil)
	checkUpgradeItemSlot()

    widget.setVisible("emptyLabel", showEmptyLabel)
  end
end

function checkUpgradeItemSlot()
  local upgradeKit = world.containerItemAt(pane.containerEntityId(), 0)
  local upgradeKitConfig = root.itemConfig(upgradeKit)
  local upgradeKitCheck = false
  
  if upgradeKit then
	if root.itemHasTag(upgradeKitConfig.config.itemName, self.upgradeKitTag) then
	  upgradeKitCheck = true
	  self.upgradeToLevel = upgradeKitConfig.config.upgradeToLevel or 1
	  widget.setText("newLevelLabel", self.upgradeToLevel)
	else
	  widget.setText("newLevelLabel", "-")
	  self.upgradeToLevel = nil
	end
  else
	widget.setText("newLevelLabel", "-")
	self.upgradeToLevel = nil
  end
end

function showWeapon(item, price)
  local enableButton = false

  if item then
    local config = root.itemConfig(item)
	local level = config.parameters.level or config.config.level or 1
    widget.setText("currentLevelLabel", level)
	
	if self.upgradeToLevel then
	  enableButton = level < self.upgradeToLevel
	else
	  enableButton = false
	end
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
	  local itemConfig = root.itemConfig(consumedItem)
      
	  --If we successfully consumed both the weapon and the upgradeKit, generate the upgraded weapon
	  if consumedItem then
        local upgradedItem = copy(consumedItem)
		upgradedItem.parameters.level = self.upgradeToLevel
		upgradedItem.parameters.shortdescription = itemConfig.config.shortdescription .. " [L." .. self.upgradeToLevel .."]"
        
		world.containerTakeNumItemsAt(pane.containerEntityId(), 0, 1)
		player.giveItem(upgradedItem)
      end
    end
    populateItemList(true)
  end
end
