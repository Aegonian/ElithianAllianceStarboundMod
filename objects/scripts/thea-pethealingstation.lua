require "/scripts/util.lua"

function craftingRecipe(items)
  if #items ~= 1 then return end
  local item = items[1]
  if not item or item.name ~= "filledcapturepod" then return end

  local healedParams = copy(item.parameters) or {}
  jremove(healedParams, "inventoryIcon")
  jremove(healedParams, "currentPets")
  for _,pet in pairs(healedParams.pets) do
    jremove(pet, "status")
  end
  healedParams.podItemHasPriority = true

  local healed = {
      name = item.name,
      count = item.count,
      parameters = healedParams
    }

  if animator.animationState("canisters") == "idle" then
	animator.setAnimationState("canisters", "healing")
  end
  
  return {
      input = items,
      output = healed,
      duration = 0.8
    }
end

function update(dt)
  local containsPod = false

  for _,item in pairs(world.containerItems(entity.id())) do
    if item.parameters and item.parameters.podUuid then
      containsPod = true
      break
    end
  end

  if containsPod then
    animator.setAnimationState("capturepod", "full")
  else
    animator.setAnimationState("capturepod", "empty")
  end
end
