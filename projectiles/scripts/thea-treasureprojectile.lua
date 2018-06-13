require "/scripts/vec2.lua"

function init()
end

function update(dt)
end

function destroy()
  local treasurePool = config.getParameter("treasurePool")
  if root.isTreasurePool(treasurePool) then
	local itemList = root.createTreasure(treasurePool, world.threatLevel())
	for _, item in ipairs(itemList) do
	  local velocity = config.getParameter("itemVelocity")
	  local scatterAngle = config.getParameter("scatterAngle")
	  local targetVelocity = vec2.rotate(velocity, math.random(-scatterAngle, scatterAngle))
	  world.spawnItem(item, mcontroller.position(), 1, nil, targetVelocity, config.getParameter("intangibleTime"))
	end
  end
end
