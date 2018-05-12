function init()
end

function update(dt)
  widget.setText("lblTokens", valueOfContents())
end

function triggerSale(widgetName, widgetData)
  world.sendEntityMessage(pane.containerEntityId(), "triggerSale")
  local total = valueOfContents()
  if total > 0 then
    player.giveItem({name = "avikanmerittoken", count = total})
  end
  pane.dismiss()
end

function valueOfContents()
  local value = 0
  local allItems = widget.itemGridItems("itemGrid")
  for _, item in pairs(allItems) do
    local itemValue = 0
	local itemConfig = root.itemConfig(item) or root.itemConfig(item.name)
	local configuredValue = itemConfig.parameters.meritTokenValue or itemConfig.config.meritTokenValue or nil
	if configuredValue and configuredValue > 0 then
	  itemValue = math.ceil(configuredValue)
	end
	value = value + ( itemValue * item.count )
  end
  return value
end
