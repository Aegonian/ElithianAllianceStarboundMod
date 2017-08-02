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
	  if itemType == "liquid" then
		containsLiquids = true
	  end
	end
  end
  
  if containsLiquids then
	animator.setAnimationState("liquidState", "hasLiquid")
  else
	animator.setAnimationState("liquidState", "noLiquid")
  end
end
