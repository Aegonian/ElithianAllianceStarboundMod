require "/scripts/util.lua"

function init()
  self.searchDistance = config.getParameter("searchRadius")
  
  script.setUpdateDelta(50)
end

function update(dt)
  local targets = world.entityQuery(entity.position(), self.searchDistance, {
      withoutEntityId = entity.id(),
      includedTypes = {"creature"},
      order = "nearest"
    })
	
  for _, target in ipairs(targets) do
    if entity.entityInSight(target) and world.entityCanDamage(entity.id(), target) then
	  if world.entityExists(target) then
		--world.debugText(world.magnitude(mcontroller.position(), world.entityPosition(target)), world.entityPosition(target), "red")
		
		if world.getProperty("entityinvisible" .. tostring(target)) then
		  local successChance = math.random(100)
		  if successChance > config.getParameter("stealthMarkerSuccessRate") then
			return
		  end
		end
		
		if world.entityAggressive(target) then
		  world.spawnProjectile(config.getParameter("agressiveMarkerProjectile"), world.entityPosition(target), entity.id(), {0,0}, false, nil)
		else
		  world.spawnProjectile(config.getParameter("passiveMarkerProjectile"), world.entityPosition(target), entity.id(), {0,0}, false, nil)
		end
	  end
    end
  end
end

function uninit()
end
