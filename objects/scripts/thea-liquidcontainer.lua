function init()
  animator.setAnimationState("liquidState", "noLiquid")
end

function update(dt) 
  updateAnimationState()
end

function updateAnimationState()
  local containerItems = world.containerItems(entity.id())
  
  local containsLiquids = false
  
  if containerItems then
	for _, item in pairs(containerItems) do
	  local itemType = root.itemType(item.name)
	  world.debugText(sb.printJson(item.name), entity.position(), "yellow")
	  
	  --If we have no configured whitelist, check if there is any type liquid in the container
	  if itemType == "liquid" and not config.getParameter("liquidWhitelist") then
		containsLiquids = true
		
	  --If we have a configured whitelist, check if the item in the container matches any of the configured liquid items
	  elseif config.getParameter("liquidWhitelist") then
		local acceptedLiquids = config.getParameter("liquidWhitelist")
		for _, liquid in ipairs(acceptedLiquids) do
		  if item.name == liquid then
			containsLiquids = true
		  end
		end
	  end
	end
  end
  
  --Update the object's animation state
  if containsLiquids then
	animator.setAnimationState("liquidState", "hasLiquid")
  else
	animator.setAnimationState("liquidState", "noLiquid")
  end
end
